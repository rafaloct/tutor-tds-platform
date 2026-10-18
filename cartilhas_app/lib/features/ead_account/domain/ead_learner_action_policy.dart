/// Pure LearnPress action policy. It does not execute requests or issue academic
/// success; only an authenticated LearnPress origin can confirm resulting state.
///
/// F0 evidence: Issue #252 / PR #254 (synthetic SQLite sandbox only).
/// Decisions: Issue #249 / PR #250. No SSO is implemented by this file.
///
/// In particular, a Tutor TDS user ID or public LearnPress course listing must
/// never be used as proof of a LearnPress enrollment or lesson completion.
enum EadEnrollmentState { unknown, notEnrolled, enrolled, finished }

enum EadUnitState { unknown, unavailable, available, started, completed }

enum EadActionType { enroll, finishLesson, startQuiz, finishQuiz, finishCourse }

/// A command proposal, not a completed LearnPress fact.
class EadAction {
  const EadAction(this.type, {this.itemId});

  final EadActionType type;
  final int? itemId;
}

/// A short-lived, verified identity reference expected from a future audited
/// EAD identity broker. Never contains a WordPress password, JWT or cookie.
class EadSessionProof {
  const EadSessionProof({
    required this.wpUserId,
    required this.environmentId,
    required this.verifiedAt,
    required this.expiresAt,
    required this.brokerVerified,
  });

  final int wpUserId;
  final String environmentId;
  final DateTime verifiedAt;
  final DateTime expiresAt;
  final bool brokerVerified;

  /// Ending the local session invalidates eligibility instantly; it does NOT
  /// assert revocation of LearnPress's observed stateless remote JWT.
  EadSessionProof signOutLocally() => EadSessionProof(
    wpUserId: wpUserId,
    environmentId: environmentId,
    verifiedAt: verifiedAt,
    expiresAt: expiresAt,
    brokerVerified: false,
  );
}

/// The *authenticated LearnPress* source is responsible for these values.
/// CourseVersion, local cartilha progress and Tutor TDS attendance are distinct.
class EadCourseSnapshot {
  const EadCourseSnapshot({
    required this.wpUserId,
    required this.wpCourseId,
    required this.environmentId,
    required this.observedAt,
    required this.fromAuthenticatedLearnPress,
    required this.enrollment,
    required this.requiredLessons,
    required this.requiredQuizzes,
    required this.requirementsVerified,
    required this.learnPressAllowsFinish,
    this.pendingMutation = false,
  });

  final int wpUserId;
  final int wpCourseId;
  final String environmentId;
  final DateTime observedAt;
  final bool fromAuthenticatedLearnPress;
  final EadEnrollmentState enrollment;

  /// Keys are LearnPress lesson IDs, not TDS message IDs.
  final Map<int, EadUnitState> requiredLessons;

  /// Keys are LearnPress quiz IDs, not TDS assessment IDs.
  final Map<int, EadUnitState> requiredQuizzes;

  /// True only after the LMS has provided the full required-item inventory,
  /// including an explicit empty quiz list if no quizzes are required.
  final bool requirementsVerified;

  /// Explicit positive permission from a future authenticated adapter; not
  /// inferred from local percentages or the crosswalk of public course titles.
  final bool learnPressAllowsFinish;

  /// A previous mutation has been sent but not canonically re-read.
  final bool pendingMutation;
}

enum EadGateCode {
  eligibleToRequest,
  needsEadLogin,
  sessionExpiredOrUnverified,
  wrongUserOrCourse,
  offline,
  snapshotNotVerified,
  refreshRequired,
  pendingOperation,
  alreadyEnrolled,
  notEnrolled,
  courseFinishedLocked,
  invalidActivity,
  activityNotAvailable,
  activityAlreadyCompleted,
  quizNotStarted,
  requirementsUnknown,
  prerequisitesIncomplete,
  courseFinishNotPermitted,
}

class EadGateDecision {
  const EadGateDecision(this.code);

  final EadGateCode code;

  /// An eligible request still has no academic effects until LearnPress
  /// accepts the command AND a fresh canonical state is read.
  bool get canRequest => code == EadGateCode.eligibleToRequest;
}

/// Pure, fail-closed guard for the next generation of Flutter Minha Area.
///
/// This class never accesses HTTP, WordPress tokens, TDS credential storage,
/// certificates, gradebook or persistence. Nothing is wired into production.
class EadLearnerActionPolicy {
  const EadLearnerActionPolicy({
    this.maxSnapshotAge = const Duration(minutes: 3),
  });

  final Duration maxSnapshotAge;

  EadGateDecision evaluate({
    required EadSessionProof? session,
    required EadCourseSnapshot? snapshot,
    required EadAction action,
    required int expectedWpCourseId,
    required DateTime now,
    required bool networkOnline,
  }) {
    if (session == null) {
      return const EadGateDecision(EadGateCode.needsEadLogin);
    }
    if (!session.brokerVerified ||
        session.wpUserId <= 0 ||
        session.environmentId.isEmpty ||
        !session.verifiedAt.isBefore(session.expiresAt) ||
        session.expiresAt.difference(session.verifiedAt) >
            const Duration(minutes: 15) ||
        session.verifiedAt.isAfter(now.add(const Duration(seconds: 5))) ||
        !now.isBefore(session.expiresAt)) {
      return const EadGateDecision(EadGateCode.sessionExpiredOrUnverified);
    }
    if (!networkOnline) {
      return const EadGateDecision(EadGateCode.offline);
    }
    if (snapshot == null || !snapshot.fromAuthenticatedLearnPress) {
      return const EadGateDecision(EadGateCode.snapshotNotVerified);
    }
    if (expectedWpCourseId <= 0 ||
        snapshot.wpCourseId != expectedWpCourseId ||
        snapshot.wpUserId != session.wpUserId ||
        snapshot.environmentId != session.environmentId) {
      return const EadGateDecision(EadGateCode.wrongUserOrCourse);
    }
    final snapshotAge = now.difference(snapshot.observedAt);
    if (snapshotAge.isNegative ||
        snapshotAge > maxSnapshotAge ||
        snapshot.observedAt.isBefore(session.verifiedAt)) {
      return const EadGateDecision(EadGateCode.refreshRequired);
    }
    if (snapshot.pendingMutation) {
      return const EadGateDecision(EadGateCode.pendingOperation);
    }
    if (snapshot.enrollment == EadEnrollmentState.finished) {
      return const EadGateDecision(EadGateCode.courseFinishedLocked);
    }

    if (action.type == EadActionType.enroll) {
      if (action.itemId != null) {
        return const EadGateDecision(EadGateCode.invalidActivity);
      }
      // No blind POST retries on an unknown or already enrolled state.
      if (snapshot.enrollment == EadEnrollmentState.unknown) {
        return const EadGateDecision(EadGateCode.refreshRequired);
      }
      if (snapshot.enrollment == EadEnrollmentState.enrolled) {
        return const EadGateDecision(EadGateCode.alreadyEnrolled);
      }
      return const EadGateDecision(EadGateCode.eligibleToRequest);
    }

    if (snapshot.enrollment == EadEnrollmentState.unknown) {
      return const EadGateDecision(EadGateCode.refreshRequired);
    }
    if (snapshot.enrollment != EadEnrollmentState.enrolled) {
      return const EadGateDecision(EadGateCode.notEnrolled);
    }
    if (!snapshot.requirementsVerified) {
      return const EadGateDecision(EadGateCode.requirementsUnknown);
    }
    switch (action.type) {
      case EadActionType.enroll:
        // Evaluated above, exhaustive case retained for the Dart compiler.
        return const EadGateDecision(EadGateCode.alreadyEnrolled);
      case EadActionType.finishLesson:
        return _activity(
          action.itemId,
          snapshot.requiredLessons,
          finishingQuiz: false,
        );
      case EadActionType.startQuiz:
        return _activity(
          action.itemId,
          snapshot.requiredQuizzes,
          finishingQuiz: false,
          startingQuiz: true,
        );
      case EadActionType.finishQuiz:
        return _activity(
          action.itemId,
          snapshot.requiredQuizzes,
          finishingQuiz: true,
        );
      case EadActionType.finishCourse:
        if (action.itemId != null) {
          return const EadGateDecision(EadGateCode.invalidActivity);
        }
        if (!snapshot.requirementsVerified ||
            (snapshot.requiredLessons.isEmpty &&
                snapshot.requiredQuizzes.isEmpty)) {
          return const EadGateDecision(EadGateCode.requirementsUnknown);
        }
        if (snapshot.requiredLessons.values.any(
              (state) => state != EadUnitState.completed,
            ) ||
            snapshot.requiredQuizzes.values.any(
              (state) => state != EadUnitState.completed,
            )) {
          return const EadGateDecision(EadGateCode.prerequisitesIncomplete);
        }
        if (!snapshot.learnPressAllowsFinish) {
          return const EadGateDecision(EadGateCode.courseFinishNotPermitted);
        }
        return const EadGateDecision(EadGateCode.eligibleToRequest);
    }
  }

  EadGateDecision _activity(
    int? itemId,
    Map<int, EadUnitState> items, {
    required bool finishingQuiz,
    bool startingQuiz = false,
  }) {
    if (itemId == null || itemId <= 0 || !items.containsKey(itemId)) {
      return const EadGateDecision(EadGateCode.invalidActivity);
    }
    final state = items[itemId]!;
    if (state == EadUnitState.unknown || state == EadUnitState.unavailable) {
      return const EadGateDecision(EadGateCode.activityNotAvailable);
    }
    if (state == EadUnitState.completed) {
      return const EadGateDecision(EadGateCode.activityAlreadyCompleted);
    }
    if (finishingQuiz && state != EadUnitState.started) {
      return const EadGateDecision(EadGateCode.quizNotStarted);
    }
    if (startingQuiz && state == EadUnitState.started) {
      // A running quiz should be resumed using the LMS's own state, rather
      // than re-sending start and potentially duplicating an attempt.
      return const EadGateDecision(EadGateCode.refreshRequired);
    }
    return const EadGateDecision(EadGateCode.eligibleToRequest);
  }
}

/// Interprets transport/application status *without* treating 200 as an
/// academic completion, since the LearnPress REST API can return
/// HTTP 200 with a response body declaring status:error (F0 evidence).
enum EadRemoteOutcome {
  readCanonicalStateAgain,
  reauthenticateEad,
  forbidden,
  notFoundOrNotReleased,
  conflictNeedsRefresh,
  backoffThenReconcile,
  unknownResultReconcile,
  applicationRejected,
}

/// The output of any mutation is only a reconciliation instruction.
/// Never automatically retry a non-idempotent POST after a timeout/5xx.
class EadRemoteResponsePolicy {
  const EadRemoteResponsePolicy();

  EadRemoteOutcome classify(int httpStatus, {String? applicationStatus}) {
    if (httpStatus == 401) {
      return EadRemoteOutcome.reauthenticateEad;
    }
    if (httpStatus == 403) {
      return EadRemoteOutcome.forbidden;
    }
    if (httpStatus == 404) {
      return EadRemoteOutcome.notFoundOrNotReleased;
    }
    if (httpStatus == 409) {
      return EadRemoteOutcome.conflictNeedsRefresh;
    }
    if (httpStatus == 429) {
      return EadRemoteOutcome.backoffThenReconcile;
    }
    if (httpStatus >= 500 && httpStatus <= 599) {
      return EadRemoteOutcome.unknownResultReconcile;
    }
    if (httpStatus >= 200 && httpStatus <= 299) {
      if (applicationStatus == 'error' ||
          applicationStatus == 'failed' ||
          applicationStatus == 'failure') {
        return EadRemoteOutcome.applicationRejected;
      }
      // An HTTP success from the command is never the canonical state.
      return EadRemoteOutcome.readCanonicalStateAgain;
    }
    return EadRemoteOutcome.applicationRejected;
  }

  EadRemoteOutcome transportUncertain() =>
      EadRemoteOutcome.unknownResultReconcile;
}
