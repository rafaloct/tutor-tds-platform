import 'package:cartilhas_app/features/media/data/media_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva e retoma posição e favorito localmente', () async {
    const repository = MediaProgressRepository();
    final progress = MediaProgress(
      mediaId: 'media-1',
      positionSeconds: 75,
      durationSeconds: 300,
      saved: true,
      updatedAt: DateTime.utc(2026, 9, 20),
    );

    await repository.save(progress);
    final restored = await repository.load('media-1');

    expect(restored?.positionSeconds, 75);
    expect(restored?.fraction, 0.25);
    expect(restored?.saved, isTrue);
  });

  test('cache corrompido cai para null', () async {
    SharedPreferences.setMockInitialValues({
      'media:progress:media-1': '{invalido',
    });
    expect(await const MediaProgressRepository().load('media-1'), isNull);
  });
}
