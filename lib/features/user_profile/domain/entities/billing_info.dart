class BillingInfo {
  const BillingInfo({
    required this.plan,
    required this.description,
    this.paymentHistory = const [],
  });

  final String plan;
  final String description;
  final List<PaymentRecord> paymentHistory;

  factory BillingInfo.empty() => const BillingInfo(
    plan: 'Zedu Free',
    description:
        'You are enjoying the full Zedu experience with the ability to add as many users to your organisation.',
  );
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.status,
  });

  final String id;
  final String description;
  final String amount;
  final String date;
  final String status;
}
