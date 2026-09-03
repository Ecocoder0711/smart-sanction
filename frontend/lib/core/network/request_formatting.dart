/// Rounds a rupee amount to the two decimal places the backend accepts.
///
/// Money fields on the API are `Decimal` with `decimal_places=2`, so a value
/// carrying more precision is rejected with a 422 the applicant cannot act on.
/// Amount fields only validate "greater than zero" on screen, and a Dart
/// `double` readily produces more digits than that, so requests round here
/// before they are sent.
///
/// Rounding is half-away-from-zero, matching `toStringAsFixed`.
double roundToPaise(double amount) => double.parse(amount.toStringAsFixed(2));
