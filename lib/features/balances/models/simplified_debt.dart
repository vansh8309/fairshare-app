class SimplifiedDebt {
  final String fromUid; // UID of the user who needs to pay
  final String toUid;   // UID of the user who needs to receive
  final double amount; // The positive amount to be transferred

  SimplifiedDebt({
    required this.fromUid,
    required this.toUid,
    required this.amount,
  });

  @override
  String toString() {
    return 'SimplifiedDebt{from: $fromUid, to: $toUid, amount: $amount}';
  }
}