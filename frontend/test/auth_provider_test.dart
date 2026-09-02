import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/registration_draft_provider.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every request so a test can assert the call sequence the wizard
/// screens rely on (register then login, for instance).
class _Recorder {
  final List<http.Request> requests = [];

  List<String> get paths =>
      requests.map((request) => request.url.path).toList();

  Map<String, dynamic> bodyAt(int index) =>
      jsonDecode(requests[index].body) as Map<String, dynamic>;
}

AuthProvider _providerWith(
  _Recorder recorder,
  Future<http.Response> Function(http.Request request) handler,
) {
  final client = MockClient((request) async {
    recorder.requests.add(request);
    return handler(request);
  });
  return AuthProvider(authService: AuthService(client: client));
}

http.Response _json(Object payload, int status) => http.Response(
  jsonEncode(payload),
  status,
  headers: {'content-type': 'application/json'},
);

const _completeUser = {
  'id': 7,
  'full_name': 'Asha Devi',
  'phone': '9880000001',
  'annual_income': '325000.00',
  'category': 'GENERAL',
  'gender': 'FEMALE',
  'profile_complete': true,
};

const _incompleteUser = {
  'id': 7,
  'full_name': 'Asha Devi',
  'phone': '9880000001',
  'profile_complete': false,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('registerMinimal', () {
    test('registers, then logs in, and persists the returned token', () async {
      final recorder = _Recorder();
      final provider = _providerWith(recorder, (request) async {
        if (request.url.path.endsWith('/auth/register')) {
          return _json(_incompleteUser, 201);
        }
        return _json({
          'access_token': 'token-abc',
          'token_type': 'bearer',
          'user': _incompleteUser,
        }, 200);
      });

      await provider.registerMinimal(
        fullName: 'Asha Devi',
        phone: '9880000001',
        password: 'CorrectHorse123!',
      );

      // Registration returns a profile but no token, so a login must follow
      // or the later profile steps would have nothing to authenticate with.
      expect(recorder.paths, ['/api/auth/register', '/api/auth/login']);
      expect(provider.token, 'token-abc');
      expect(provider.isLoggedIn, isTrue);
      expect(
        await SharedPreferences.getInstance().then(
          (prefs) => prefs.getString('access_token'),
        ),
        'token-abc',
      );
      // A credentials-only registration must leave the profile incomplete.
      expect(provider.isProfileComplete, isFalse);
    });

    test('sends no profile fields, so nothing is defaulted server-side', () async {
      final recorder = _Recorder();
      final provider = _providerWith(recorder, (request) async {
        if (request.url.path.endsWith('/auth/register')) {
          return _json(_incompleteUser, 201);
        }
        return _json({'access_token': 't', 'user': _incompleteUser}, 200);
      });

      await provider.registerMinimal(
        fullName: 'Asha Devi',
        phone: '9880000001',
        password: 'CorrectHorse123!',
      );

      expect(recorder.bodyAt(0).keys.toSet(), {
        'full_name',
        'phone',
        'password',
      });
    });

    test('a duplicate phone throws and stores no token', () async {
      final recorder = _Recorder();
      final provider = _providerWith(
        recorder,
        (_) async => _json({'detail': 'Phone number is already registered'}, 409),
      );

      await expectLater(
        provider.registerMinimal(
          fullName: 'Asha Devi',
          phone: '9880000001',
          password: 'CorrectHorse123!',
        ),
        throwsA(isA<PhoneAlreadyRegisteredException>()),
      );

      expect(provider.token, isNull);
      expect(provider.isLoggedIn, isFalse);
      // No login attempt after a failed registration.
      expect(recorder.paths, ['/api/auth/register']);
      // The loading flag must be released even on the failure path.
      expect(provider.isLoading, isFalse);
    });
  });

  group('login', () {
    test('persists the token and caches the user', () async {
      final recorder = _Recorder();
      final provider = _providerWith(
        recorder,
        (_) async => _json({
          'access_token': 'token-xyz',
          'user': _completeUser,
        }, 200),
      );

      await provider.login(phone: '9880000001', password: 'CorrectHorse123!');

      expect(provider.token, 'token-xyz');
      expect(provider.isProfileComplete, isTrue);
    });

    test('bad credentials throw a 401 and leave the session empty', () async {
      final provider = _providerWith(
        _Recorder(),
        (_) async => _json({'detail': 'Invalid phone or password'}, 401),
      );

      await expectLater(
        provider.login(phone: '9880000001', password: 'wrong-password'),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(provider.isLoggedIn, isFalse);
      expect(provider.isLoading, isFalse);
    });
  });

  group('updateProfile', () {
    test('sends the draft body with the bearer token and refreshes the user',
        () async {
      final recorder = _Recorder();
      final provider = _providerWith(recorder, (request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _json({'access_token': 'token-abc', 'user': _incompleteUser}, 200);
        }
        return _json(_completeUser, 200);
      });
      await provider.login(phone: '9880000001', password: 'CorrectHorse123!');
      expect(provider.isProfileComplete, isFalse);

      final draft = RegistrationDraftProvider()
        ..setProfileDetails(
          annualIncome: 325000,
          state: 'Madhya Pradesh',
          district: 'Bhopal',
          category: 'General',
          gender: 'Female',
        );
      await provider.updateProfile(draft.toProfileUpdate());

      final update = recorder.requests.last;
      expect(update.method, 'PUT');
      expect(update.url.path, '/api/users/me');
      expect(update.headers['Authorization'], 'Bearer token-abc');
      expect(recorder.bodyAt(1), {
        'annual_income': 325000,
        'category': 'General',
        'gender': 'Female',
        'state': 'Madhya Pradesh',
        'district': 'Bhopal',
      });
      // The refreshed user is what the screen gates navigation on.
      expect(provider.isProfileComplete, isTrue);
    });

    test('a location update without GPS omits coordinates entirely', () async {
      final recorder = _Recorder();
      final provider = _providerWith(recorder, (request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _json({'access_token': 't', 'user': _completeUser}, 200);
        }
        return _json(_completeUser, 200);
      });
      await provider.login(phone: '9880000001', password: 'CorrectHorse123!');

      // Manual state/district only: no coordinates are invented.
      final draft = RegistrationDraftProvider()
        ..setProfileDetails(state: 'Madhya Pradesh', district: 'Bhopal');
      await provider.updateProfile(draft.toLocationUpdate());

      final body = recorder.bodyAt(1);
      expect(body.containsKey('latitude'), isFalse);
      expect(body.containsKey('longitude'), isFalse);
      expect(body, {'state': 'Madhya Pradesh', 'district': 'Bhopal'});
    });

    test('a location update with GPS sends the captured coordinates', () async {
      final recorder = _Recorder();
      final provider = _providerWith(recorder, (request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _json({'access_token': 't', 'user': _completeUser}, 200);
        }
        return _json(_completeUser, 200);
      });
      await provider.login(phone: '9880000001', password: 'CorrectHorse123!');

      final draft = RegistrationDraftProvider()
        ..setCoordinates(latitude: 23.2599, longitude: 77.4126);
      await provider.updateProfile(draft.toLocationUpdate());

      expect(recorder.bodyAt(1), {'latitude': 23.2599, 'longitude': 77.4126});
    });

    test('refuses to call the API when no token is stored', () async {
      final recorder = _Recorder();
      final provider = _providerWith(recorder, (_) async => _json({}, 200));

      await expectLater(
        provider.updateProfile({'category': 'General'}),
        throwsA(isA<AuthException>()),
      );
      expect(recorder.requests, isEmpty);
    });

    test('an expired token surfaces a 401 for the screen to act on', () async {
      final provider = _providerWith(_Recorder(), (request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _json({'access_token': 't', 'user': _incompleteUser}, 200);
        }
        return _json({'detail': 'Not authenticated'}, 401);
      });
      await provider.login(phone: '9880000001', password: 'CorrectHorse123!');

      await expectLater(
        provider.updateProfile({'category': 'General'}),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(provider.isLoading, isFalse);
    });
  });

  group('logout', () {
    test('clears the token, the cached user, and the stored preference',
        () async {
      final provider = _providerWith(
        _Recorder(),
        (_) async => _json({'access_token': 't', 'user': _completeUser}, 200),
      );
      await provider.login(phone: '9880000001', password: 'CorrectHorse123!');
      expect(provider.isLoggedIn, isTrue);

      await provider.logout();

      expect(provider.token, isNull);
      expect(provider.user, isNull);
      expect(provider.isProfileComplete, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });
  });
}
