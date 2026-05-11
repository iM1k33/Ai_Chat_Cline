class AccountBalance {
  const AccountBalance({
    required this.providerId,
    required this.fetchedAt,
    required this.rawSummary,
    this.balance,
    this.currencyCode,
    this.subscriptionStatus,
  });

  final String providerId;
  final DateTime fetchedAt;
  final double? balance;
  final String? currencyCode;
  final String? subscriptionStatus;
  final String rawSummary;
}
