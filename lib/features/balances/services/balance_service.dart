import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fair_share/features/expenses/models/expense_model.dart';
import 'package:fair_share/features/balances/models/simplified_debt.dart';
import 'dart:math';

class BalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;
  Stream<Map<String, double>> getGroupBalancesStream(String groupId) {
    if (groupId.isEmpty) {
      print("BalanceService: Cannot calculate balances - invalid Group ID.");
      return Stream.value({});
    }
    final String? myUid = _currentUserId;

    try {
      Stream<QuerySnapshot> expenseStream = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .snapshots();

      return expenseStream.map((expenseSnapshot) {
        Map<String, double> memberBalances = {};
        Set<String> membersInvolved = {};

        if (myUid != null) membersInvolved.add(myUid);

        for (var doc in expenseSnapshot.docs) {
          try {
             final Expense expense = Expense.fromFirestore(doc);
             membersInvolved.add(expense.paidByUid);
             membersInvolved.addAll(expense.splitDetails.keys);
             memberBalances.putIfAbsent(expense.paidByUid, () => 0.0);
             expense.splitDetails.forEach((uid, _) {
                memberBalances.putIfAbsent(uid, () => 0.0);
             });

             memberBalances[expense.paidByUid] = (memberBalances[expense.paidByUid] ?? 0.0) + expense.amount;

             double totalForSplit = 0;
              Map<String, double> sharesCalculated = {};

             switch (expense.splitType) {
               case SplitType.equal:
                  int numberOfParticipants = expense.splitDetails.length;
                  if (numberOfParticipants > 0) {
                     double share = expense.amount / numberOfParticipants;
                     expense.splitDetails.forEach((uid, _) {
                         sharesCalculated[uid] = share;
                         totalForSplit += share;
                     });
                  }
                  break;
               case SplitType.exact:
                   expense.splitDetails.forEach((uid, amount) {
                       sharesCalculated[uid] = amount;
                       totalForSplit += amount;
                   });
                   if ((totalForSplit - expense.amount).abs() > 0.01) {
                      print("Warning: Exact split amounts for expense ${expense.id} do not sum to total!");
                   }
                  break;
               case SplitType.percentage:
                   expense.splitDetails.forEach((uid, percentage) {
                      double share = expense.amount * (percentage / 100.0);
                       sharesCalculated[uid] = share;
                       totalForSplit += share;
                   });
                   if ((totalForSplit - expense.amount).abs() > 0.01) {
                       print("Warning: Percentage split amounts for expense ${expense.id} do not sum to total!");
                   }
                  break;
               case SplitType.share:
                   double totalShares = expense.splitDetails.values.fold(0.0, (prev, shares) => prev + shares);
                   if (totalShares > 0) {
                      expense.splitDetails.forEach((uid, shares) {
                         double share = (expense.amount / totalShares) * shares;
                         sharesCalculated[uid] = share;
                         totalForSplit += share;
                      });
                   }
                    if ((totalForSplit - expense.amount).abs() > 0.01) {
                       print("Warning: Share split amounts for expense ${expense.id} do not sum to total!");
                   }
                  break;
             }

              sharesCalculated.forEach((uid, share) {
                  memberBalances[uid] = (memberBalances[uid] ?? 0.0) - share;
              });

          } catch (e) {
              print("BalanceService: Error processing expense doc ${doc.id} for balances: $e");
          }
        }

        print("BalanceService: Calculated balances for group $groupId = $memberBalances");
        return memberBalances;

      }).handleError((error) {
        print("BalanceService: Error in expense stream for balance calculation ($groupId): $error");
        return <String, double>{};
      });

    } catch (e) {
      print("BalanceService: Exception setting up balance stream for $groupId: $e");
      return Stream.value({});
    }
  }

  double calculateMyShareOfExpense(Expense expense, String myUid) {
     if (myUid.isEmpty || !expense.splitDetails.containsKey(myUid)) return 0.0; try { switch (expense.splitType) { case SplitType.equal: int numP = expense.splitDetails.length; return (numP > 0) ? expense.amount / numP : 0.0; case SplitType.exact: return expense.splitDetails[myUid] ?? 0.0; case SplitType.percentage: double myP = expense.splitDetails[myUid] ?? 0.0; return expense.amount * (myP / 100.0); case SplitType.share: double totalS = expense.splitDetails.values.fold(0.0, (p, s) => p + s); if (totalS > 0) { double myS = expense.splitDetails[myUid] ?? 0.0; return (expense.amount / totalS) * myS; } return 0.0; } } catch (e) { print("BalanceService: Error calculating share: $e"); return 0.0; }
  }

  List<SimplifiedDebt> simplifyDebts(Map<String, double> netBalances) {
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    netBalances.forEach((uid, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(uid, balance.abs()));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(uid, balance));
      }
    });

    List<SimplifiedDebt> simplifiedDebts = [];

    int debtorIdx = 0;
    int creditorIdx = 0;

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
      var debtor = debtors[debtorIdx];
      var creditor = creditors[creditorIdx];
      double debtorAmount = debtor.value;
      double creditorAmount = creditor.value;

      double transferAmount = min(debtorAmount, creditorAmount);

      simplifiedDebts.add(SimplifiedDebt(
          fromUid: debtor.key, toUid: creditor.key, amount: transferAmount));

      debtorAmount -= transferAmount;
      creditorAmount -= transferAmount;

      if (debtorAmount < 0.01) {
        debtorIdx++;
      } else {
        debtors[debtorIdx] = MapEntry(debtor.key, debtorAmount);
      }

      if (creditorAmount < 0.01) {
        creditorIdx++;
      } else {
        creditors[creditorIdx] = MapEntry(creditor.key, creditorAmount);
      }
    }

     print("BalanceService: Simplified Debts: $simplifiedDebts");
    return simplifiedDebts;
  }

  Stream<List<SimplifiedDebt>> getSimplifiedDebtsForUserStream(String groupId) {
     final String? myUid = _currentUserId;
     if (myUid == null) return Stream.value([]);

     return getGroupBalancesStream(groupId).map((netBalances) {
        List<SimplifiedDebt> allSimplifiedDebts = simplifyDebts(netBalances);
        return allSimplifiedDebts
            .where((debt) => debt.fromUid == myUid || debt.toUid == myUid)
            .toList();
     }).handleError((error) {
        print("BalanceService: Error in simplified debts stream for $groupId: $error");
        return [];
     });
  }
}