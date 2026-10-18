import 'package:cartilhas_app/features/ead_account/domain/ead_learner_action_policy.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 10, 18, 14);
final verifiedAt = now.subtract(const Duration(minutes: 5));
final fresh = now.subtract(const Duration(seconds: 30));

EadSessionProof session({
  int userId = 3,
  String environment = 'staging',
  bool verified = true,
  DateTime? at,
  DateTime? expiration,
}) => EadSessionProof(
  wpUserId: userId,
  environmentId: environment,
  brokerVerified: verified,
  verifiedAt: at ?? verifiedAt,
  expiresAt: expiration ?? now.add(const Duration(minutes: 5)),
);

EadCourseSnapshot view({
  int userId = 3,
  int courseId = 23,
  String environment = 'staging',
  DateTime? at,
  bool authenticated = true,
  EadEnrollmentState enrollment = EadEnrollmentState.enrolled,
  Map<int, EadUnitState> lessons = const {24: EadUnitState.available},
  Map<int, EadUnitState> quizzes = const {26: EadUnitState.available},
  bool inventory = true,
  bool serverAllowsFinish = false,
  bool pending = false,
}) => EadCourseSnapshot(
  wpUserId: userId,
  wpCourseId: courseId,
  environmentId: environment,
  observedAt: at ?? fresh,
  fromAuthenticatedLearnPress: authenticated,
  enrollment: enrollment,
  requiredLessons: lessons,
  requiredQuizzes: quizzes,
  requirementsVerified: inventory,
  learnPressAllowsFinish: serverAllowsFinish,
  pendingMutation: pending,
);

EadGateDecision decision(
  EadAction action, {
  EadSessionProof? identity,
  EadCourseSnapshot? course,
  int courseId = 23,
  bool online = true,
  DateTime? time,
}) => const EadLearnerActionPolicy().evaluate(
  session: identity ?? session(),
  snapshot: course ?? view(),
  action: action,
  expectedWpCourseId: courseId,
  now: time ?? now,
  networkOnline: online,
);

void main() {
  group('learnpress session and source boundary', () {
    test('logged out guest cannot request EAD enrollment', () {
      final outcome = const EadLearnerActionPolicy().evaluate(
        session: null,
        snapshot: view(),
        action: const EadAction(EadActionType.enroll),
        expectedWpCourseId: 23,
        now: now,
        networkOnline: true,
      );
      expect(outcome.code, EadGateCode.needsEadLogin);
      expect(outcome.canRequest, isFalse);
    });

    test('institutional login alone is not a verified LearnPress proof', () {
      final outcome = decision(
        const EadAction(EadActionType.finishLesson, itemId: 24),
        identity: session(verified: false),
      );
      expect(outcome.code, EadGateCode.sessionExpiredOrUnverified);
    });

    test('expired EAD proof blocks all mutations', () {
      final outcome = decision(
        const EadAction(EadActionType.enroll),
        identity: session(expiration: now.subtract(const Duration(seconds: 1))),
      );
      expect(outcome.code, EadGateCode.sessionExpiredOrUnverified);
    });

    test('seven-day stateless LMS token must not become a broker proof', () {
      expect(
        decision(
          const EadAction(EadActionType.enroll),
          identity: session(expiration: now.add(const Duration(days: 7))),
        ).code,
        EadGateCode.sessionExpiredOrUnverified,
      );
    });

    test('proof dated in future is refused', () {
      expect(
        decision(
          const EadAction(EadActionType.enroll),
          identity: session(at: now.add(const Duration(minutes: 1))),
        ).code,
        EadGateCode.sessionExpiredOrUnverified,
      );
    });

    test(
      'local logout immediately blocks even with remote JWT outstanding',
      () {
        final loggedOut = session().signOutLocally();
        expect(
          decision(
            const EadAction(EadActionType.finishLesson, itemId: 24),
            identity: loggedOut,
          ).code,
          EadGateCode.sessionExpiredOrUnverified,
        );
        expect(loggedOut.expiresAt.isAfter(now), isTrue);
      },
    );

    test('two synthetic users A and B are isolated', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          identity: session(userId: 4),
          course: view(userId: 3),
        ).code,
        EadGateCode.wrongUserOrCourse,
      );
    });

    test('same user cannot cross staging and production cache', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          identity: session(environment: 'production'),
          course: view(environment: 'staging'),
        ).code,
        EadGateCode.wrongUserOrCourse,
      );
    });

    test('course 23 does not authorize course 1298', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          courseId: 1298,
        ).code,
        EadGateCode.wrongUserOrCourse,
      );
    });

    test('untrusted public catalog cannot be used as learner state', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          course: view(authenticated: false),
        ).code,
        EadGateCode.snapshotNotVerified,
      );
    });

    test('expired snapshot must be reconciled, never silently reused', () {
      expect(
        decision(
          const EadAction(EadActionType.enroll),
          course: view(at: now.subtract(const Duration(minutes: 4))),
        ).code,
        EadGateCode.refreshRequired,
      );
    });

    test('snapshot predating identity verification is rejected', () {
      expect(
        decision(
          const EadAction(EadActionType.enroll),
          identity: session(at: now.subtract(const Duration(seconds: 12))),
          course: view(at: now.subtract(const Duration(seconds: 30))),
        ).code,
        EadGateCode.refreshRequired,
      );
    });

    test('no EAD write allowed offline', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          online: false,
        ).code,
        EadGateCode.offline,
      );
    });

    test('pending server mutation locks out new academic command', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          course: view(pending: true),
        ).code,
        EadGateCode.pendingOperation,
      );
    });
  });

  group('LearnPress enrollment, lesson and quiz ordering', () {
    test('confirmed not-enrolled can request enrollment only', () {
      final notEnrolled = view(enrollment: EadEnrollmentState.notEnrolled);
      expect(
        decision(
          const EadAction(EadActionType.enroll),
          course: notEnrolled,
        ).canRequest,
        isTrue,
      );
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          course: notEnrolled,
        ).code,
        EadGateCode.notEnrolled,
      );
    });

    test('unknown enrollment cannot produce duplicate enroll POST', () {
      expect(
        decision(
          const EadAction(EadActionType.enroll),
          course: view(enrollment: EadEnrollmentState.unknown),
        ).code,
        EadGateCode.refreshRequired,
      );
    });

    test('enrollment command never accepts a lesson/quiz item ID', () {
      expect(
        decision(
          const EadAction(EadActionType.enroll, itemId: 24),
          course: view(enrollment: EadEnrollmentState.notEnrolled),
        ).code,
        EadGateCode.invalidActivity,
      );
    });

    test('already enrolled is not a success or new POST permission', () {
      final status = decision(const EadAction(EadActionType.enroll));
      expect(status.code, EadGateCode.alreadyEnrolled);
      expect(status.canRequest, isFalse);
    });

    test('course finished before quiz locks further commands', () {
      final finished = view(enrollment: EadEnrollmentState.finished);
      for (final action in [
        const EadAction(EadActionType.enroll),
        const EadAction(EadActionType.startQuiz, itemId: 26),
        const EadAction(EadActionType.finishQuiz, itemId: 26),
        const EadAction(EadActionType.finishLesson, itemId: 24),
        const EadAction(EadActionType.finishCourse),
      ]) {
        expect(
          decision(action, course: finished).code,
          EadGateCode.courseFinishedLocked,
        );
      }
    });

    test('lesson finish needs lesson from authenticated course inventory', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
        ).canRequest,
        isTrue,
      );
      expect(
        decision(const EadAction(EadActionType.finishLesson, itemId: 999)).code,
        EadGateCode.invalidActivity,
      );
    });

    test('quiz should start first, then finish', () {
      expect(
        decision(
          const EadAction(EadActionType.startQuiz, itemId: 26),
        ).canRequest,
        isTrue,
      );
      expect(
        decision(const EadAction(EadActionType.finishQuiz, itemId: 26)).code,
        EadGateCode.quizNotStarted,
      );
      expect(
        decision(
          const EadAction(EadActionType.finishQuiz, itemId: 26),
          course: view(quizzes: const {26: EadUnitState.started}),
        ).canRequest,
        isTrue,
      );
    });

    test('starting a started quiz needs canonical resume instead', () {
      expect(
        decision(
          const EadAction(EadActionType.startQuiz, itemId: 26),
          course: view(quizzes: const {26: EadUnitState.started}),
        ).code,
        EadGateCode.refreshRequired,
      );
    });

    test('cannot re-finish an already completed activity', () {
      final completed = view(
        quizzes: const {26: EadUnitState.completed},
        lessons: const {24: EadUnitState.completed},
      );
      expect(
        decision(
          const EadAction(EadActionType.finishQuiz, itemId: 26),
          course: completed,
        ).code,
        EadGateCode.activityAlreadyCompleted,
      );
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          course: completed,
        ).code,
        EadGateCode.activityAlreadyCompleted,
      );
    });

    test('draft or unknown lesson cannot be finished', () {
      for (final state in [EadUnitState.unknown, EadUnitState.unavailable]) {
        expect(
          decision(
            const EadAction(EadActionType.finishLesson, itemId: 24),
            course: view(lessons: {24: state}),
          ).code,
          EadGateCode.activityNotAvailable,
        );
      }
    });

    test('lesson mutations cannot run with unverified item inventory', () {
      expect(
        decision(
          const EadAction(EadActionType.finishLesson, itemId: 24),
          course: view(inventory: false),
        ).code,
        EadGateCode.requirementsUnknown,
      );
    });

    test('no course finish with unknown inventory', () {
      expect(
        decision(
          const EadAction(EadActionType.finishCourse),
          course: view(inventory: false, serverAllowsFinish: true),
        ).code,
        EadGateCode.requirementsUnknown,
      );
    });

    test('no course finish with empty unverified curriculum', () {
      expect(
        decision(
          const EadAction(EadActionType.finishCourse),
          course: view(
            lessons: const {},
            quizzes: const {},
            serverAllowsFinish: true,
          ),
        ).code,
        EadGateCode.requirementsUnknown,
      );
    });

    test('no course finish until both lessons AND quizzes completed', () {
      expect(
        decision(
          const EadAction(EadActionType.finishCourse),
          course: view(
            lessons: const {24: EadUnitState.completed},
            quizzes: const {26: EadUnitState.available},
            serverAllowsFinish: true,
          ),
        ).code,
        EadGateCode.prerequisitesIncomplete,
      );
    });

    test('required lessons completed but LMS has not allowed finish', () {
      expect(
        decision(
          const EadAction(EadActionType.finishCourse),
          course: view(
            lessons: const {24: EadUnitState.completed},
            quizzes: const {26: EadUnitState.completed},
          ),
        ).code,
        EadGateCode.courseFinishNotPermitted,
      );
    });

    test(
      'course finish eligible only after verified requirements and LMS flag',
      () {
        final checked = view(
          lessons: const {24: EadUnitState.completed},
          quizzes: const {26: EadUnitState.completed},
          serverAllowsFinish: true,
        );
        final result = decision(
          const EadAction(EadActionType.finishCourse),
          course: checked,
        );
        expect(result.canRequest, isTrue);
        expect(result.code, EadGateCode.eligibleToRequest);
        // No completion is ever declared by this pure local policy.
        expect(checked.enrollment, EadEnrollmentState.enrolled);
      },
    );

    test('course finish refuses lesson id as a command parameter', () {
      expect(
        decision(const EadAction(EadActionType.finishCourse, itemId: 24)).code,
        EadGateCode.invalidActivity,
      );
    });

    test(
      'course with no required quiz can finish only with confirmed inventory',
      () {
        expect(
          decision(
            const EadAction(EadActionType.finishCourse),
            course: view(
              quizzes: const {},
              lessons: const {24: EadUnitState.completed},
              serverAllowsFinish: true,
            ),
          ).canRequest,
          isTrue,
        );
      },
    );
  });

  group('LearnPress remote command outcomes', () {
    const classifier = EadRemoteResponsePolicy();

    test('HTTP 200 is not proof of academic completion', () {
      expect(
        classifier.classify(200),
        EadRemoteOutcome.readCanonicalStateAgain,
      );
    });

    test('HTTP 200 with status:error is not success', () {
      expect(
        classifier.classify(200, applicationStatus: 'error'),
        EadRemoteOutcome.applicationRejected,
      );
    });

    test('duplicate enrollment error stays rejected until refreshed', () {
      expect(
        classifier.classify(400, applicationStatus: 'error'),
        EadRemoteOutcome.applicationRejected,
      );
    });

    test('LP token cannot be assumed to authenticate WP core REST', () {
      expect(classifier.classify(401), EadRemoteOutcome.reauthenticateEad);
    });

    test('forbidden lesson/quiz remains forbidden', () {
      expect(classifier.classify(403), EadRemoteOutcome.forbidden);
    });

    test('missing or unpublished resource is distinct', () {
      expect(classifier.classify(404), EadRemoteOutcome.notFoundOrNotReleased);
    });

    test('conflict requires server refresh', () {
      expect(classifier.classify(409), EadRemoteOutcome.conflictNeedsRefresh);
    });

    test(
      'rate limit signals backoff and reconcile, no immediate POST replay',
      () {
        expect(classifier.classify(429), EadRemoteOutcome.backoffThenReconcile);
      },
    );

    test('5xx does not trigger unsafe duplicate POST replay', () {
      expect(classifier.classify(502), EadRemoteOutcome.unknownResultReconcile);
    });

    test('transport timeout requires reconciliation before retry', () {
      expect(
        classifier.transportUncertain(),
        EadRemoteOutcome.unknownResultReconcile,
      );
    });

    test('unexpected code never marks student as enrolled', () {
      expect(classifier.classify(418), EadRemoteOutcome.applicationRejected);
    });
  });
}
