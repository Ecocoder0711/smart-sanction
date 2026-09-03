class Scheme {
  const Scheme({
    required this.id,
    required this.name,
    required this.category,
    required this.maxLoanLimit,
    required this.interestRate,
    this.moratoriumMonths,
  });

  final int id;
  final String name;
  final String category;
  final double maxLoanLimit;
  final double interestRate;

  /// Repayment holiday the scheme grants, in months, straight from
  /// `SchemeResponse.moratorium_months`. Real seeded schemes range from 2 to
  /// 12, so it must never be displayed as a fixed number.
  ///
  /// Nullable only because trimmed scheme payloads (the Dashboard's static
  /// list) omit it; when the backend supplies it, it is used as-is.
  final int? moratoriumMonths;

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
      moratoriumMonths: json['moratorium_months'] as int?,
    );
  }
}
