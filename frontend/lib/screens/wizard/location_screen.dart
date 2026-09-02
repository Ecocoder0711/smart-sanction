import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/india_locations.dart';
import '../../core/network/api_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../providers/registration_draft_provider.dart';
import '../auth/widgets/trust_footer.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _progressTrackColor = Color(0xFFD9E3F4);

  final _formKey = GlobalKey<FormState>();
  final _specificLocationController = TextEditingController();

  String? _selectedState;
  String? _selectedDistrict;

  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _locationError;

  @override
  void dispose() {
    _specificLocationController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({String? hintText, String? labelText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: AppColors.softGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.deepNavy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(
          () => _locationError = 'location.location_service_disabled'.tr(),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(
          () => _locationError = 'location.location_permission_denied'.tr(),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(
          () => _locationError = 'location.location_permission_denied_forever'
              .tr(),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } on LocationServiceDisabledException {
      setState(
        () => _locationError = 'location.location_service_disabled'.tr(),
      );
    } catch (error) {
      // Surface the underlying reason instead of a generic message — common
      // causes: emulator has no mock GPS fix set, or the app needs a fresh
      // install for the newly-added location permission to take effect.
      setState(
        () =>
            _locationError = '${'location.location_fetch_error'.tr()}: $error',
      );
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    // Unchanged: GPS coordinates satisfy the step on their own, otherwise the
    // manual state/district fields must validate.
    final hasGpsLocation = _latitude != null && _longitude != null;

    if (!hasGpsLocation && !_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final draft = context.read<RegistrationDraftProvider>();

    if (hasGpsLocation) {
      draft.setCoordinates(latitude: _latitude!, longitude: _longitude!);
    }
    // Without GPS there are no coordinates to send, and none are invented:
    // state/district alone are stored. Partner recommendations stay
    // unavailable until real coordinates exist, which the backend already
    // reports rather than guessing.
    draft.setProfileDetails(state: _selectedState, district: _selectedDistrict);

    try {
      await auth.updateProfile(draft.toLocationUpdate());
    } on Exception catch (error) {
      if (!mounted) return;
      if (isUnauthorized(error)) {
        await _returnToLogin();
        return;
      }
      _showError(describeApiError(error, fallbackKey: 'location.save_failed'));
      return;
    }

    // The wizard is done and the profile now lives on the server; drop the
    // in-memory copy.
    draft.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  /// Sends an expired session back to Login instead of on to the Dashboard.
  Future<void> _returnToLogin() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    _showError('auth.session_expired'.tr());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final districtOptions = _selectedState == null
        ? const <String>[]
        : IndiaLocations.stateDistricts[_selectedState] ?? const <String>[];
    final hasGpsLocation = _latitude != null && _longitude != null;
    final isSubmitting = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'location.step_of_label'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'location.header_label'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: const LinearProgressIndicator(
                              value: 1.0,
                              minHeight: 8,
                              backgroundColor: _progressTrackColor,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.emeraldGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'location.description'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _isFetchingLocation
                                        ? null
                                        : _fetchLocation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.deepNavy,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: _isFetchingLocation
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.my_location),
                                    label: Text(
                                      'location.allow_location_button'.tr(),
                                    ),
                                  ),
                                ),
                                if (_locationError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _locationError!,
                                    style: const TextStyle(
                                      color: AppColors.errorRed,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (hasGpsLocation) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.emeraldGreen,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'location.location_acquired'.tr(
                                            namedArgs: {
                                              'lat': _latitude!.toStringAsFixed(
                                                4,
                                              ),
                                              'lng': _longitude!
                                                  .toStringAsFixed(4),
                                            },
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.emeraldGreen,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(color: _borderColor),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'location.manual_divider_label'.tr(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(color: _borderColor),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _fieldLabel(
                                        'eligibility.state_label'.tr(),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedState,
                                        isExpanded: true,
                                        decoration: _fieldDecoration(),
                                        hint: Text(
                                          'eligibility.state_placeholder'.tr(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        items: IndiaLocations.states
                                            .map(
                                              (state) => DropdownMenuItem(
                                                value: state,
                                                child: Text(
                                                  state,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedState = value;
                                            _selectedDistrict = null;
                                          });
                                        },
                                        validator: hasGpsLocation
                                            ? null
                                            : (value) {
                                                if (value == null) {
                                                  return 'eligibility.state_error'
                                                      .tr();
                                                }
                                                return null;
                                              },
                                      ),
                                      const SizedBox(height: 16),
                                      _fieldLabel(
                                        'eligibility.district_label'.tr(),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedDistrict,
                                        isExpanded: true,
                                        decoration: _fieldDecoration(),
                                        hint: Text(
                                          _selectedState == null
                                              ? 'eligibility.district_select_state_first'
                                                    .tr()
                                              : 'eligibility.district_placeholder'
                                                    .tr(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        items: districtOptions
                                            .map(
                                              (district) => DropdownMenuItem(
                                                value: district,
                                                child: Text(
                                                  district,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _selectedState == null
                                            ? null
                                            : (value) {
                                                setState(
                                                  () =>
                                                      _selectedDistrict = value,
                                                );
                                              },
                                        validator: hasGpsLocation
                                            ? null
                                            : (value) {
                                                if (value == null) {
                                                  return 'eligibility.district_error'
                                                      .tr();
                                                }
                                                return null;
                                              },
                                      ),
                                      const SizedBox(height: 16),
                                      _fieldLabel(
                                        'location.location_field_label'.tr(),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _specificLocationController,
                                        decoration: _fieldDecoration(
                                          hintText:
                                              'location.location_field_hint'
                                                  .tr(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    // Disabled while the request is in flight
                                    // so a second tap cannot submit twice.
                                    onPressed: isSubmitting ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.emeraldGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'location.continue_button'.tr(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const TrustFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
