import 'package:flutter/foundation.dart';

/// Holds the applicant details collected across the registration wizard.
///
/// The wizard spans several screens (register -> profile -> location) while
/// the backend receives the data in three separate calls, so the values need
/// somewhere to live in between. This is deliberately a plain in-memory
/// holder: nothing here is persisted to disk, and [clear] wipes it once the
/// data has been submitted.
///
/// It is intentionally NOT wired into any screen yet -- screens continue to
/// own their own controllers until the integration step.
class RegistrationDraftProvider extends ChangeNotifier {
  // Step 1 - registration credentials.
  String? _fullName;
  String? _phone;
  String? _password;

  // Step 2 - profile / eligibility details.
  double? _annualIncome;
  String? _state;
  String? _district;
  String? _category;
  String? _gender;

  // Step 3 - location.
  double? _latitude;
  double? _longitude;

  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get password => _password;
  double? get annualIncome => _annualIncome;
  String? get state => _state;
  String? get district => _district;
  String? get category => _category;
  String? get gender => _gender;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  /// Whether step 1 has everything `POST /api/auth/register` requires.
  bool get hasRegistrationDetails =>
      _isFilled(_fullName) && _isFilled(_phone) && _isFilled(_password);

  /// Whether step 2 has everything the backend counts towards
  /// `profile_complete` (annual income, category, and gender).
  bool get hasProfileDetails =>
      _annualIncome != null && _isFilled(_category) && _isFilled(_gender);

  /// Whether step 3 captured usable coordinates.
  bool get hasCoordinates => _latitude != null && _longitude != null;

  void setRegistrationDetails({
    required String fullName,
    required String phone,
    required String password,
  }) {
    _fullName = fullName;
    _phone = phone;
    _password = password;
    notifyListeners();
  }

  void setProfileDetails({
    double? annualIncome,
    String? state,
    String? district,
    String? category,
    String? gender,
  }) {
    if (annualIncome != null) _annualIncome = annualIncome;
    if (state != null) _state = state;
    if (district != null) _district = district;
    if (category != null) _category = category;
    if (gender != null) _gender = gender;
    notifyListeners();
  }

  void setCoordinates({required double latitude, required double longitude}) {
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  /// Body for `PUT /api/users/me` after the profile screen.
  ///
  /// Only supplied values are included: the backend forbids unknown keys and
  /// rejects nulling required fields, so absent values must be omitted rather
  /// than sent as null.
  Map<String, dynamic> toProfileUpdate() {
    return {
      if (_annualIncome != null) 'annual_income': _annualIncome,
      if (_isFilled(_category)) 'category': _category,
      if (_isFilled(_gender)) 'gender': _gender,
      if (_isFilled(_state)) 'state': _state,
      if (_isFilled(_district)) 'district': _district,
    };
  }

  /// Body for `PUT /api/users/me` after the location screen.
  Map<String, dynamic> toLocationUpdate() {
    return {
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
      if (_isFilled(_state)) 'state': _state,
      if (_isFilled(_district)) 'district': _district,
    };
  }

  /// Drops everything, including the password held in memory.
  void clear() {
    _fullName = null;
    _phone = null;
    _password = null;
    _annualIncome = null;
    _state = null;
    _district = null;
    _category = null;
    _gender = null;
    _latitude = null;
    _longitude = null;
    notifyListeners();
  }

  /// Clears only the password once it has been exchanged for a token.
  void clearPassword() {
    _password = null;
    notifyListeners();
  }

  static bool _isFilled(String? value) => value != null && value.trim().isNotEmpty;
}
