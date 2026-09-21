import 'package:cartilhas_app/features/evidence/data/checkin_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persiste apenas metadados mínimos e chave idempotente', () async {
    final now = DateTime.utc(2026, 9, 20, 14);
    final store = SharedPreferencesCheckinDraftStore(now: () => now);
    await store.write(
      CheckinDraft(
        classId: 'class-1',
        sessionId: 'session-1',
        kind: 'checkin',
        idempotencyKey: 'mobile:12345678',
        createdAt: now,
      ),
    );

    final raw = (await SharedPreferences.getInstance()).getString(
      SharedPreferencesCheckinDraftStore.storageKey,
    );
    expect(raw, isNotNull);
    expect(raw, isNot(contains('token')));
    expect((await store.read())?.idempotencyKey, 'mobile:12345678');
  });

  test(
    'descarta pendência antiga em vez de tentar uma sessão obsoleta',
    () async {
      final createdAt = DateTime.utc(2026, 9, 19, 10);
      final store = SharedPreferencesCheckinDraftStore(
        now: () => DateTime.utc(2026, 9, 20, 14),
      );
      await store.write(
        CheckinDraft(
          classId: 'class-1',
          sessionId: 'session-1',
          kind: 'checkout',
          idempotencyKey: 'mobile:12345678',
          createdAt: createdAt,
        ),
      );

      expect(await store.read(), isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          SharedPreferencesCheckinDraftStore.storageKey,
        ),
        isFalse,
      );
    },
  );
}
