/// One row from `GET /api/applications`, which returns only the authenticated
/// user's own applications.
///
/// Deliberately narrow: it carries the fields the Dashboard card renders plus
/// the identifiers needed to open the application later. The response also
/// includes `ml_match_score` and `ml_approval_probability`, but the backend
/// never writes them today (they stay SQL NULL until an explicit persistence
/// policy exists), so they are not modelled here rather than parsed as
/// always-null noise.
class LoanApplication {
  const LoanApplication({
    required this.id,
    required this.schemeId,
    required this.schemeName,
    this.partnerId,
    this.partnerName,
    required this.requestedAmount,
    required this.status,
    this.applicationDate,
  });

  final int id;
  final int schemeId;
  final String schemeName;

  /// Null on a draft saved before the applicant chose where to apply. Every
  /// non-draft application has one -- the backend enforces that in the
  /// database.
  final int? partnerId;
  final String? partnerName;

  final double requestedAmount;

  /// Backend lifecycle state: submitted, under_review, approved, rejected or
  /// completed. There is no draft state, so nothing here may be labelled one.
  final String status;

  final DateTime? applicationDate;

  factory LoanApplication.fromJson(Map<String, dynamic> json) {
    final date = json['application_date'];

    return LoanApplication(
      id: json['id'] as int,
      schemeId: json['scheme_id'] as int,
      schemeName: json['scheme_name'] as String,
      partnerId: json['partner_id'] as int?,
      partnerName: json['partner_name'] as String?,
      requestedAmount: double.parse(json['requested_amount'].toString()),
      status: json['status'] as String,
      applicationDate: date == null ? null : DateTime.tryParse(date.toString()),
    );
  }

  /// Whether this is unsent work rather than a lodged application.
  ///
  /// The Dashboard partitions on exactly this, so a draft can never appear
  /// under My Applications.
  bool get isDraft => status == 'draft';

  /// Translation key for [status], e.g. `dashboard.status_under_review`.
  ///
  /// Falls back to the raw value if the backend ever adds a state the app has
  /// no wording for, so an unknown status still renders something truthful
  /// instead of throwing.
  String get statusKey => 'dashboard.status_$status';
}
