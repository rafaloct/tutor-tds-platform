import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/data/learner_offline_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/classrooms/presentation/learner_classrooms_screen.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalIdentity extends AuthRepository {
  LocalIdentity() : super(apiUrl: 'https://test.example');
  String? owner = 'student-a';
  @override
  Future<String?> localUserId() async => owner;
}

class RemoteClasses implements LearnerClassroomGateway {
  bool offline = false;
  int? denied;
  bool empty = false;
  String version = 'version-1';
  String contentVersion = 'version-1';
  String classStatus = 'active';
  Future<void> Function()? duringCourse;
  @override
  Future<AuthUser> currentUser() async {
    if (offline) {
      throw const AuthException('offline', allowOfflineFallback: true);
    }
    if (denied != null) throw const AuthException('denied');
    return const AuthUser(
      id: 'student-a',
      name: 'Private name',
      role: 'student',
    );
  }

  ClassroomDetails row() => ClassroomDetails(
    id: 'class',
    programId: 'program',
    courseId: 'course',
    teacherId: 'private-teacher',
    name: 'Turma',
    startDate: DateTime(2026),
    endDate: DateTime(2027),
    status: classStatus,
    studentIds: const ['private-peer'],
    monitorIds: const ['private-monitor'],
    courseVersionId: version,
  );

  void check() {
    if (denied != null) throw ClassroomException('denied', statusCode: denied);
    if (offline) {
      throw const ClassroomException('offline', allowOfflineFallback: true);
    }
  }

  @override
  Future<List<ClassroomDetails>> learnerClassrooms() async {
    check();
    return empty ? [] : [row()];
  }

  @override
  Future<Cartilha> course(String id) async {
    check();
    await duringCourse?.call();
    return Cartilha(
      id: 'course',
      title: 'Snapshot',
      author: 'TDS',
      courseVersionId: contentVersion,
      classId: id,
      legacyProgressCompatible: false,
      sections: [
        Section(
          id: 'module',
          title: 'Module',
          messages: [Message(type: 'bot', content: 'Exact snapshot')],
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalIdentity auth;
  late RemoteClasses remote;
  late DateTime now;
  LearnerOfflineRepository repo({String url = 'https://api.example/staging'}) =>
      LearnerOfflineRepository(
        remote: remote,
        auth: auth,
        apiUrl: url,
        clock: () => now,
      );
  Future<LearnerOfflineRepository> saved() async {
    final gateway = repo();
    await gateway.currentUser();
    await gateway.learnerClassrooms();
    await gateway.course('class');
    return gateway;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = LocalIdentity();
    remote = RemoteClasses();
    now = DateTime.utc(2026, 9, 21);
  });
  tearDown(() => auth.dispose());

  test(
    'cold offline reopen retains exact pin and does not store roster or name',
    () async {
      await saved();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefs.getKeys().single)!;
      for (final secret in [
        'Private name',
        'private-peer',
        'private-monitor',
        'private-teacher',
      ]) {
        expect(raw, isNot(contains(secret)));
      }
      remote.offline = true;
      final reopened = repo();
      expect((await reopened.currentUser()).id, 'student-a');
      expect((await reopened.learnerClassrooms()).single.id, 'class');
      final course = await reopened.course('class');
      expect(course.courseVersionId, 'version-1');
      expect(course.classId, 'class');
      expect(course.legacyProgressCompatible, isFalse);
      expect(course.sections.single.messages.single.content, 'Exact snapshot');
      expect(reopened.usingSavedData, isTrue);
    },
  );

  test(
    'logout, different owner and different environment cannot open copy',
    () async {
      await saved();
      remote.offline = true;
      auth.owner = null;
      await expectLater(
        repo().currentUser(),
        throwsA(isA<ClassroomException>()),
      );
      auth.owner = 'student-b';
      await expectLater(repo().currentUser(), throwsA(isA<AuthException>()));
      auth.owner = 'student-a';
      await expectLater(
        repo(url: 'https://api.example/production').currentUser(),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'expired lease and clock rollback do not grant offline access',
    () async {
      await saved();
      remote.offline = true;
      now = now.add(const Duration(days: 7));
      await expectLater(repo().currentUser(), throwsA(isA<AuthException>()));
      now = DateTime.utc(2026, 9, 20);
      await expectLater(repo().currentUser(), throwsA(isA<AuthException>()));
    },
  );

  for (final status in [401, 403, 404, 500]) {
    test(
      'HTTP $status never falls back and invalidates saved course',
      () async {
        final gateway = await saved();
        remote.denied = status;
        await expectLater(
          gateway.course('class'),
          throwsA(isA<ClassroomException>()),
        );
        remote.denied = null;
        remote.offline = true;
        final reopened = repo();
        await expectLater(
          reopened.currentUser(),
          throwsA(isA<AuthException>()),
        );
      },
    );
  }

  test('revoked account clears all local membership entitlement', () async {
    await saved();
    remote.denied = 403;
    await expectLater(repo().currentUser(), throwsA(isA<AuthException>()));
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test(
    'successful empty list removes classes and downloaded snapshots',
    () async {
      final gateway = await saved();
      remote.empty = true;
      expect(await gateway.learnerClassrooms(), isEmpty);
      remote.offline = true;
      final reopened = repo();
      await reopened.currentUser();
      expect(await reopened.learnerClassrooms(), isEmpty);
      await expectLater(
        reopened.course('class'),
        throwsA(isA<ClassroomException>()),
      );
    },
  );

  test(
    'changed pin discards old snapshot; never substitutes public course',
    () async {
      final gateway = await saved();
      remote.version = 'version-2';
      await gateway.learnerClassrooms();
      await expectLater(
        gateway.course('class'),
        throwsA(isA<ClassroomException>()),
      );
      remote.offline = true;
      await expectLater(
        gateway.course('class'),
        throwsA(isA<ClassroomException>()),
      );
    },
  );

  test(
    'switching owner while response arrives cannot save or return it',
    () async {
      final gateway = await saved();
      remote.duringCourse = () async {
        auth.owner = 'student-b';
      };
      await expectLater(
        gateway.course('class'),
        throwsA(isA<ClassroomException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getKeys().any(
          (key) => key.endsWith('student-b'),
        ),
        isFalse,
      );
    },
  );

  test(
    'refreshing list does not silently renew old content authorization',
    () async {
      final gateway = await saved();
      now = now.add(const Duration(days: 6));
      await gateway.learnerClassrooms();
      now = now.add(const Duration(days: 2));
      remote.offline = true;
      final reopened = repo();
      await reopened.currentUser();
      await reopened.learnerClassrooms();
      await expectLater(
        reopened.course('class'),
        throwsA(isA<ClassroomException>()),
      );
    },
  );

  testWidgets(
    'offline screen explains saved copy at 200 percent and opens exact owner',
    (tester) async {
      await saved();
      remote.offline = true;
      Cartilha? opened;
      String? owner;
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: LearnerClassroomsScreen(
            gateway: repo(),
            onOpenCourse: (course, id) {
              opened = course;
              owner = id;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sem conexão: exibindo turmas salvas'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Turma'), 180);
      await tester.tap(find.text('Turma'));
      await tester.pumpAndSettle();
      expect(opened?.courseVersionId, 'version-1');
      expect(owner, 'student-a');
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['planned', 'closed']) {
    test(
      'authorized $status class remains readable online and offline',
      () async {
        remote.classStatus = status;
        await saved();
        remote.offline = true;
        final reopened = repo();
        await reopened.currentUser();
        expect((await reopened.learnerClassrooms()).single.status, status);
        expect((await reopened.course('class')).courseVersionId, 'version-1');
      },
    );
  }

  test('valid online list repairs a corrupt downloaded entry', () async {
    final gateway = await saved();
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    final data = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    data['courses']['class'] = null;
    await prefs.setString(key, jsonEncode(data));
    expect((await gateway.learnerClassrooms()).single.id, 'class');
    expect((await gateway.course('class')).courseVersionId, 'version-1');
  });

  test(
    'refresh rejection invalidates grant after tokens were already cleared',
    () async {
      final gateway = await saved();
      remote.duringCourse = () async {
        auth.owner = null;
        throw const ClassroomException('Sua sessão expirou. Entre novamente.');
      };
      await expectLater(
        gateway.course('class'),
        throwsA(isA<ClassroomException>()),
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test(
    'one gateway cannot rebind identity during an in-flight request',
    () async {
      final gateway = await saved();
      remote.duringCourse = () async {
        auth.owner = 'student-b';
        await expectLater(
          gateway.currentUser(),
          throwsA(isA<ClassroomException>()),
        );
      };
      await expectLater(
        gateway.course('class'),
        throwsA(isA<ClassroomException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getKeys().any(
          (key) => key.endsWith('student-b'),
        ),
        isFalse,
      );
    },
  );

  test('corrupt persisted content cannot become a public fallback', () async {
    await saved();
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    final data = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    data['courses']['class']['content']['course_version_id'] = 'wrong';
    await prefs.setString(key, jsonEncode(data));
    remote.offline = true;
    final reopened = repo();
    await reopened.currentUser();
    await reopened.learnerClassrooms();
    await expectLater(
      reopened.course('class'),
      throwsA(isA<ClassroomException>()),
    );
  });
}
