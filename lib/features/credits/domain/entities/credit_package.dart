class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.credits,
    required this.benefits,
    this.planSlug,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final int credits;
  final List<String> benefits;
  final String? planSlug;

  // Enterprise has no list price, but it is not free: its card contacts sales.
  bool get isFree => price == 0 && name.toLowerCase() != 'enterprise';

  String get priceLabel => price == 0 ? r'$0' : '\$$price';

  String get ctaLabel {
    if (isFree) return 'Current Plan';
    return 'Buy $name';
  }
}
