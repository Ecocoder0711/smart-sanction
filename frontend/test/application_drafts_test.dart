import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/loan_application.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Mirrors a real `/api/applications` row. A draft may carry nulls where a
/// lodged application never can.
Map<String, dynamic> _applicationJson({
  int id = 21,
  String status = 'draft',
  Object? partnerId,
  Object? partnerName,
  String requestedAmount = '250000.00',
}) => {
  'id': id,
  'user_id': 39,
  'user_name': 'Draft Owner',
  'scheme_id': 6,
  'scheme_name': 'Demo Enterprise Business Boost',
  'partner_id': partnerId,
  'partner_name': partnerName,
  'requested_amount': requestedAmount,
  'ml_match_score': null,
  'ml_approval_probability': null,
  'application_date': '2026-09-05T10:00:00Z',
  'status': status,
  'created_at': '2026-09-05T10:00:00Z',
  'updated_at': '2026-09-05T10:00:00Z',
};

ApiService _serviceReturning(
  Object payload, {
  int status = 201,
  void Function(http.Request)? capture,
}) => ApiService(
  client: MockClient((request) async {
    capture?.call(request);
    return http.Response(
      jsonEncode(payload),
      status,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  group('draft parsing', () {
    test('a draft without a partner parses with nulls', () {
      final draft = LoanApplication.fromJson(_applicationJson());

      expect(draft.status, 'draft');
      expect(draft.isDraft, isTrue);
      expect(draft.partnerId, isNull);
      expect(draft.partnerName, isNull);
      // Everything else still parses.
      expect(draft.schemeId, 6);
      expect(draft.schemeName, 'Demo Enterprise Business Boost');
      expect(draft.requestedAmount, 250000.00);
    });

    test('a draft with a chosen partner keeps it', () {
      final draft = LoanApplication.fromJson(
        _applicationJson(partnerId: 2, partnerName: 'Prototype Livelihood Bank'),
      );

      expect(draft.isDraft, isTrue);
      expect(draft.partnerId, 2);
      expect(draft.partnerName, 'Prototype Livelihood Bank');
    });

    test('isDraft is false for every lodged status', () {
      for (final status in [
        'submitted',
        'under_review',
        'approved',
        'rejected',
        'completed',
      ]) {
        final application = LoanApplication.fromJson(
          _applicationJson(status: status, partnerId: 2, partnerName: 'Bank'),
        );
        expect(application.isDraft, isFalse, reason: status);
      }
    });

    test('draft has its own translation key', () {
      expect(
        LoanApplication.fromJson(_applicationJson()).statusKey,
        'dashboard.status_draft',
      );
    });
  });

  group('ApiService.saveApplicationDraft', () {
    test('omits partner_id entirely when no centre was selected', () async {
      late http.Request captured;
      final service = _serviceReturning(
        _applicationJson(),
        capture: (r) => captured = r,
      );

      await service.saveApplicationDraft(
        schemeId: 6,
        requestedAmount: 250000.00,
        token: 'token-abc',
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/applications');
      expect(captured.headers['Authorization'], 'Bearer token-abc');
      expect(body['status'], 'draft');
      expect(body['scheme_id'], 6);
      expect(body['requested_amount'], 250000.0);
      // Absent, not null: the backend forbids unknown/extra shapes and a draft
      // legitimately has no partner.
      expect(body.containsKey('partner_id'), isFalse);
    });

    test('includes partner_id when a centre was selected', () async {
      late http.Request captured;
      final service = _serviceReturning(
        _applicationJson(partnerId: 2, partnerName: 'Bank'),
        capture: (r) => captured = r,
      );

      await service.saveApplicationDraft(
        schemeId: 6,
        requestedAmount: 250000.00,
        partnerId: 2,
        token: 'token-abc',
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['partner_id'], 2);
      expect(body['status'], 'draft');
    });

    test('never sends a status other than draft', () async {
      late http.Request captured;
      final service = _serviceReturning(
        _applicationJson(),
        capture: (r) => captured = r,
      );

      await service.saveApplicationDraft(
        schemeId: 6,
        requestedAmount: 250000.00,
        token: 't',
      );

      expect(jsonDecode(captured.body)['status'], 'draft');
    });

    test('rounds the amount to what the backend accepts', () async {
      late http.Request captured;
      final service = _serviceReturning(
        _applicationJson(),
        capture: (r) => captured = r,
      );

      await service.saveApplicationDraft(
        schemeId: 6,
        requestedAmount: 250000.999,
        token: 't',
      );

      expect(jsonDecode(captured.body)['requested_amount'], 250001.0);
    });

    test('accepts 201 and returns the created draft', () async {
      final service = _serviceReturning(_applicationJson(id: 42));

      final draft = await service.saveApplicationDraft(
        schemeId: 6,
        requestedAmount: 250000.00,
        token: 't',
      );

      expect(draft.id, 42);
      expect(draft.isDraft, isTrue);
    });

    test('a 422 surfaces so the screen can stay put', () async {
      final service = _serviceReturning(
        {'detail': 'partner_id is required unless status is draft'},
        status: 422,
      );

      await expectLater(
        service.saveApplicationDraft(
          schemeId: 6,
          requestedAmount: 250000.00,
          token: 't',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
    });

    test('a 401 surfaces for the screen to log out on', () async {
      final service = _serviceReturning(
        {'detail': 'Not authenticated'},
        status: 401,
      );

      await expectLater(
        service.saveApplicationDraft(
          schemeId: 6,
          requestedAmount: 250000.00,
          token: 'expired',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  group('dashboard partitioning', () {
    /// Exactly the split the Dashboard performs on one fetched list.
    ({List<LoanApplication> drafts, List<LoanApplication> lodged}) partition(
      List<LoanApplication> all,
    ) => (
      drafts: all.where((a) => a.isDraft).toList(),
      lodged: all.where((a) => !a.isDraft).toList(),
    );

    test('drafts and lodged applications never overlap', () {
      final all = [
        _applicationJson(id: 1, status: 'draft'),
        _applicationJson(id: 2, status: 'submitted', partnerId: 2, partnerName: 'B'),
        _applicationJson(id: 3, status: 'draft', partnerId: 5, partnerName: 'C'),
        _applicationJson(id: 4, status: 'approved', partnerId: 2, partnerName: 'B'),
        _applicationJson(id: 5, status: 'rejected', partnerId: 2, partnerName: 'B'),
      ].map(LoanApplication.fromJson).toList();

      final split = partition(all);

      expect(split.drafts.map((a) => a.id), [1, 3]);
      expect(split.lodged.map((a) => a.id), [2, 4, 5]);
      // No row appears twice, and none is lost.
      expect(split.drafts.length + split.lodged.length, all.length);
      final draftIds = split.drafts.map((a) => a.id).toSet();
      final lodgedIds = split.lodged.map((a) => a.id).toSet();
      expect(draftIds.intersection(lodgedIds), isEmpty);
    });

    test('a draft never appears under My Applications', () {
      final all = [
        _applicationJson(id: 1, status: 'draft'),
      ].map(LoanApplication.fromJson).toList();

      final split = partition(all);

      expect(split.lodged, isEmpty);
      expect(split.drafts, hasLength(1));
    });

    test('both sections are empty for a new applicant', () {
      final split = partition(const <LoanApplication>[]);

      expect(split.drafts, isEmpty);
      expect(split.lodged, isEmpty);
    });

    test('only-drafts leaves My Applications empty, and vice versa', () {
      final onlyDrafts = partition(
        [_applicationJson(id: 1)].map(LoanApplication.fromJson).toList(),
      );
      final onlyLodged = partition(
        [
          _applicationJson(
            id: 2,
            status: 'submitted',
            partnerId: 2,
            partnerName: 'B',
          ),
        ].map(LoanApplication.fromJson).toList(),
      );

      expect(onlyDrafts.lodged, isEmpty);
      expect(onlyDrafts.drafts, hasLength(1));
      expect(onlyLodged.drafts, isEmpty);
      expect(onlyLodged.lodged, hasLength(1));
    });

    test('partitioning one fetch cannot duplicate a row across sections', () {
      // The reason the Dashboard fetches once instead of twice: two filtered
      // calls could straddle a save and disagree.
      final all = List.generate(
        6,
        (i) => LoanApplication.fromJson(
          _applicationJson(
            id: i,
            status: i.isEven ? 'draft' : 'submitted',
            partnerId: i.isEven ? null : 2,
            partnerName: i.isEven ? null : 'B',
          ),
        ),
      );

      final split = partition(all);

      expect(split.drafts.length + split.lodged.length, 6);
      expect(
        {...split.drafts.map((a) => a.id), ...split.lodged.map((a) => a.id)},
        hasLength(6),
      );
    });
  });
}
