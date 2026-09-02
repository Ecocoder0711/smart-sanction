class Scheme {
  const Scheme({
    required this.id,
    required this.name,
    required this.category,
    required this.maxLoanLimit,
    required this.interestRate,
  });

  final int id;
  final String name;
  final String category;
  final double maxLoanLimit;
  final double interestRate;

  factory Scheme.fromJson(Map<String, dynamic> json) {
    final categoryField = json['category'];
    final categoryName = categoryField is Map<String, dynamic>
        ? categoryField['category_name'] as String
        : categoryField as String;

    return Scheme(
      id: json['id'] as int,
      name: json['scheme_name'] as String,
      category: categoryName,
      maxLoanLimit: double.parse(json['max_loan_limit'].toString()),
      interestRate: double.parse(json['interest_rate'].toString()),
    );
  }
}
