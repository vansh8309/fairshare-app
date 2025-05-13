import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitType { equal, exact, percentage, share }

class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String currencyCode;
  final DateTime paidAt;
  final String paidByUid;
  final String paidByName;
  final String? paidByPicUrl;
  final SplitType splitType;
  final Map<String, double> splitDetails;
  final DateTime createdAt;
  final bool isSettlement;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.currencyCode,
    required this.paidAt,
    required this.paidByUid,
    required this.paidByName,
    this.paidByPicUrl,
    required this.splitType,
    required this.splitDetails,
    required this.createdAt,
    this.isSettlement = false,
  });

  static SplitType _splitTypeFromString(String? typeString) {
    switch (typeString?.toUpperCase()) {
      case 'EQUAL': return SplitType.equal;
      case 'EXACT': return SplitType.exact;
      case 'PERCENTAGE': return SplitType.percentage;
      case 'SHARE': return SplitType.share;
      default: return SplitType.equal;
    }
  }

  String get splitTypeString => splitType.name.toUpperCase();

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return Expense(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      description: data['description'] as String? ?? 'No description',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: data['currencyCode'] as String? ?? 'INR',
      paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidByUid: data['paidByUid'] as String? ?? '',
      paidByName: data['paidByName'] as String? ?? 'Unknown Payer',
      paidByPicUrl: data['paidByPicUrl'] as String?,
      splitType: _splitTypeFromString(data['splitType'] as String?),
      splitDetails: Map<String, double>.from(
          (data['splitDetails'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0.0),
              ) ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSettlement: data['isSettlement'] as bool? ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'paidAt': Timestamp.fromDate(paidAt),
      'paidByUid': paidByUid,
      'paidByName': paidByName,
      'paidByPicUrl': paidByPicUrl,
      'splitType': splitTypeString,
      'splitDetails': splitDetails,
      'createdAt': Timestamp.fromDate(createdAt),
      'isSettlement': isSettlement,
    };
  }
}