import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/registration_draft_provider.dart';

void main() {
  group('RegistrationDraftProvider', () {
    test('starts empty', () {
      final draft = RegistrationDraftProvider();

      expect(draft.hasRegistrationDetails, isFalse);
      expect(draft.hasProfileDetails, isFalse);
      expect(draft.hasCoordinates, isFalse);
      expect(draft.toProfileUpdate(), isEmpty);
      expect(draft.toLocationUpdate(), isEmpty);
    });

    test('retains values across the three wizard steps', () {
      final draft = RegistrationDraftProvider()
        ..setRegistrationDetails(
          fullName: 'Asha Devi',
          phone: '9880000001',
          password: 'CorrectHorse123!',
        )
        ..setProfileDetails(
          annualIncome: 325000,
          state: 'Madhya Pradesh',
          district: 'Bhopal',
          category: 'General',
          gender: 'Female',
        )
        ..setCoordinates(latitude: 23.2599, longitude: 77.4126);

      expect(draft.hasRegistrationDetails, isTrue);
      expect(draft.hasProfileDetails, isTrue);
      expect(draft.hasCoordinates, isTrue);
      expect(draft.fullName, 'Asha Devi');
      expect(draft.category, 'General');
      expect(draft.latitude, 23.2599);
    });

    test('profile update body omits values that were never supplied', () {
      final draft = RegistrationDraftProvider()
        ..setProfileDetails(annualIncome: 200000, category: 'OBC');

      final body = draft.toProfileUpdate();

      expect(body, {'annual_income': 200000.0, 'category': 'OBC'});
      expect(body.containsKey('gender'), isFalse);
      expect(body.containsKey('state'), isFalse);
      expect(draft.hasProfileDetails, isFalse, reason: 'gender still missing');
    });

    test('location update body carries coordinates and known area', () {
      final draft = RegistrationDraftProvider()
        ..setProfileDetails(state: 'Madhya Pradesh', district: 'Bhopal')
        ..setCoordinates(latitude: 23.2599, longitude: 77.4126);

      expect(draft.toLocationUpdate(), {
        'latitude': 23.2599,
        'longitude': 77.4126,
        'state': 'Madhya Pradesh',
        'district': 'Bhopal',
      });
    });

    test('blank strings do not count as supplied values', () {
      final draft = RegistrationDraftProvider()
        ..setRegistrationDetails(fullName: '  ', phone: '', password: '');

      expect(draft.hasRegistrationDetails, isFalse);
    });

    test('setProfileDetails leaves untouched fields alone', () {
      final draft = RegistrationDraftProvider()
        ..setProfileDetails(category: 'SC', gender: 'Male')
        ..setProfileDetails(annualIncome: 150000);

      expect(draft.category, 'SC');
      expect(draft.gender, 'Male');
      expect(draft.annualIncome, 150000);
    });

    test('clear wipes everything including the password', () {
      final draft = RegistrationDraftProvider()
        ..setRegistrationDetails(
          fullName: 'Asha Devi',
          phone: '9880000001',
          password: 'CorrectHorse123!',
        )
        ..setCoordinates(latitude: 1, longitude: 2);

      draft.clear();

      expect(draft.password, isNull);
      expect(draft.fullName, isNull);
      expect(draft.hasCoordinates, isFalse);
    });

    test('clearPassword keeps the rest of the draft', () {
      final draft = RegistrationDraftProvider()
        ..setRegistrationDetails(
          fullName: 'Asha Devi',
          phone: '9880000001',
          password: 'CorrectHorse123!',
        );

      draft.clearPassword();

      expect(draft.password, isNull);
      expect(draft.fullName, 'Asha Devi');
      expect(draft.phone, '9880000001');
    });

    test('notifies listeners when values change', () {
      final draft = RegistrationDraftProvider();
      var notifications = 0;
      draft.addListener(() => notifications++);

      draft.setProfileDetails(category: 'ST');
      draft.setCoordinates(latitude: 1, longitude: 2);

      expect(notifications, 2);
    });
  });
}
