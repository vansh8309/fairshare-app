import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fair_share/features/expenses/models/expense_model.dart'; 
import 'package:fair_share/features/balances/models/simplified_debt.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  String? get _currentUserId => _auth.currentUser?.uid;
  DocumentReference _groupDocRef(String groupId) {
     return _firestore.collection('groups').doc(groupId);
  }

  DocumentReference _expenseDocRef(String groupId, String expenseId) {
    return _groupDocRef(groupId).collection('expenses').doc(expenseId);
  }

  CollectionReference _expensesCollectionRef(String groupId) {
     return _groupDocRef(groupId).collection('expenses');
  }

  Future<String?> addExpense(String groupId, Map<String, dynamic> expenseData) async {
    final String? userId = _currentUserId;
    if (userId == null || groupId.isEmpty || expenseData['paidByUid'] != userId) {
      print("ExpenseService Error: Precondition failed for adding expense.");
      return null;
    }

    try {
      expenseData['createdAt'] = FieldValue.serverTimestamp();
      expenseData['groupId'] = groupId; 
      expenseData['isSettlement'] = false;

      final docRef = await _expensesCollectionRef(groupId).add(expenseData);
      print("ExpenseService: Expense added: ${docRef.id} to group $groupId");
      await _groupDocRef(groupId).update({'lastActivityAt': FieldValue.serverTimestamp()});
      print("ExpenseService: Updated lastActivityAt for group $groupId after adding expense");

      return docRef.id;
    } catch (e) {
      print("ExpenseService: Error adding expense to Firestore: $e");
      return null;
    }
  }
  Future<bool> recordSettlementPayment(String groupId, String currencyCode, SimplifiedDebt debtToSettle) async {
     final String? myUid = _currentUserId;
     if (myUid == null) { print("ExpenseService Error: User not logged in."); return false; }
     if (groupId.isEmpty || debtToSettle.amount <= 0) { print("ExpenseService Error: Invalid group ID or settlement amount."); return false; }

     try {
        final UserProfile? payerProfile = await _userService.getUserProfile(debtToSettle.fromUid);
        final UserProfile? payeeProfile = await _userService.getUserProfile(debtToSettle.toUid);

        if (payerProfile == null || payeeProfile == null) {
           print("ExpenseService Error: Could not find payer or payee profile for settlement.");
           return false;
        }
        final Map<String, dynamic> settlementData = {
           'groupId': groupId,
           'description': 'Settlement: ${payerProfile.name} paid ${payeeProfile.name}',
           'amount': debtToSettle.amount,
           'currencyCode': currencyCode,
           'paidAt': Timestamp.now(),
           'paidByUid': debtToSettle.fromUid,
           'paidByName': payerProfile.name,
           'paidByPicUrl': payerProfile.profilePicUrl,
           'splitType': SplitType.exact.name.toUpperCase(),
           'splitDetails': { debtToSettle.toUid : debtToSettle.amount },
           'createdAt': FieldValue.serverTimestamp(),
           'isSettlement': true,
        };
         final docRef = await _expensesCollectionRef(groupId).add(settlementData);
         print("ExpenseService: Settlement recorded as expense: ${docRef.id} in group $groupId");
         await _groupDocRef(groupId).update({'lastActivityAt': FieldValue.serverTimestamp()});
          print("ExpenseService: Updated lastActivityAt for group $groupId after settlement");

         return true;

     } catch (e) {
         print("ExpenseService: Error recording settlement: $e");
         return false;
     }
  }

  Stream<List<Expense>> getGroupExpensesStream(String groupId) {
    if (groupId.isEmpty) return Stream.value([]);

    try {
      return _expensesCollectionRef(groupId)
          .where('isSettlement', isEqualTo: false)
          .orderBy('paidAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
          })
          .handleError((error) {
            print("ExpenseService: Error in getGroupExpensesStream for $groupId: $error");
             if (error is FirebaseException && error.code == 'failed-precondition') { print("ExpenseService: Query requires Firestore index on expenses(isSettlement Asc, paidAt Desc). Check Firestore console."); }
            return [];
          });
    } catch (e) { print("ExpenseService: Exception setting up expense stream for $groupId: $e"); return Stream.value([]); }
  }
  Stream<Expense?> getExpenseStream(String groupId, String expenseId) {
     if (groupId.isEmpty || expenseId.isEmpty) return Stream.value(null);
     try {
       return _expenseDocRef(groupId, expenseId).snapshots()
           .map((snapshot) => snapshot.exists ? Expense.fromFirestore(snapshot) : null)
           .handleError((error) {
              print("ExpenseService: Error in getExpenseStream for $groupId/$expenseId: $error");
              return null;
           });
     } catch (e) {
        print("ExpenseService: Exception setting up single expense stream: $e");
        return Stream.value(null);
     }
  }
  Future<bool> updateExpense(String groupId, String expenseId, Map<String, dynamic> updatedData) async {
     if (groupId.isEmpty || expenseId.isEmpty || updatedData.isEmpty) return false;
     updatedData['lastUpdatedAt'] = FieldValue.serverTimestamp();
     try {
        await _expenseDocRef(groupId, expenseId).update(updatedData);
        await _groupDocRef(groupId).update({'lastActivityAt': FieldValue.serverTimestamp()});
        print("ExpenseService: Expense $expenseId updated successfully.");
        return true;
     } catch (e) {
        print("ExpenseService: Error updating expense $expenseId: $e");
        return false;
     }
  }

  Future<bool> deleteExpense(String groupId, String expenseId) async {
     if (groupId.isEmpty || expenseId.isEmpty) return false;
     try {
        await _expenseDocRef(groupId, expenseId).delete();
        print("ExpenseService: Expense $expenseId deleted successfully.");
        return true;
     } catch (e) {
        print("ExpenseService: Error deleting expense $expenseId: $e");
        return false;
     }
  }
}