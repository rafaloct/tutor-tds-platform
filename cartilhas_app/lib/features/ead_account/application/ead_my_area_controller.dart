import 'package:flutter/foundation.dart';

import '../domain/ead_learner_action_policy.dart';
import '../presentation/ead_my_area_preview.dart';

/// A verified learner-scoped response supplied by a future audited EAD broker.
/// This type is NOT a credential, token, authentication protocol or REST client.
class EadAccountReadSnapshot {
  const EadAccountReadSnapshot({
    required this.wpUserId,
    required this.environmentId,
    required this.observedAt,
    required this.authenticatedLearnPressOrigin,
    required this.courses,
  });

  final int wpUserId;
  final String environmentId;
  final DateTime observedAt;
  final bool authenticatedLearnPressOrigin;
  final List<EadAreaCourse> courses;
}

/// Interface for a future server-side adapter that verifies LearnPress rights.
///
/// Do not implement this with the public user directory or a Flutter-stored
/// WordPress password. No HTTP implementation is included in this slice.
abstract interface class EadMyAreaReader {
  Future<EadAccountReadSnapshot> read(EadSessionProof proof);
}

enum EadAccountReadFailure { loginRequired, forbidden, offline, unavailable }

class EadAccountReadException implements Exception {
  const EadAccountReadException(this.reason);
  final EadAccountReadFailure reason;
}

typedef EadClock = DateTime Function();

/// Safely reconciles an injected, scoped LearnPress reader into the detached
/// Minha Area widget. It never writes enrollment, grades, courses or presence.
class EadMyAreaController extends ChangeNotifier {
  EadMyAreaController({
    required this.reader,
    EadClock? clock,
    this.maxFreshAge = const Duration(minutes: 3),
    this.maxOfflineAge = const Duration(hours: 1),
  }) : _clock = clock ?? DateTime.now {
    assert(maxFreshAge <= maxOfflineAge);
  }

  final EadMyAreaReader reader;
  final EadClock _clock;
  final Duration maxFreshAge;
  final Duration maxOfflineAge;

  EadSessionProof? _session;
  EadAccountReadSnapshot? _lastVerified;
  int _generation = 0;
  bool _disposed = false;

  EadMyAreaModel _model = const EadMyAreaModel(
    linkState: EadLinkState.disconnected,
    snapshotState: EadSnapshotState.unknown,
    environmentId: '',
    snapshotEnvironmentId: null,
  );

  EadMyAreaModel get model => _model;

  /// Caller must supply a short-lived, independently authenticated proof.
  /// This does not magically verify a token on the client. No data is read
  /// until refresh() is explicitly requested.
  void acceptSession(EadSessionProof? proof) {
    _generation++;
    _session = null;
    _lastVerified = null;
    if (proof == null) {
      _publish(_disconnected());
      return;
    }
    if (!_usable(proof, _clock())) {
      _publish(_loginRequired(proof));
      return;
    }
    _session = proof;
    _publish(_forSession(proof, EadSnapshotState.unknown));
  }

  /// Clears all private learner state immediately and invalidates in-flight
  /// reads. Does not imply remote JWT revocation, which requires a broker.
  void signOutLocally() => acceptSession(null);

  Future<void> refresh() async {
    final proof = _session;
    if (proof == null) {
      return;
    }
    if (!_usable(proof, _clock())) {
      _requireLogin(proof);
      return;
    }
    final requestGeneration = ++_generation;
    // Never show cached personal data while a new read is in flight.
    _publish(_forSession(proof, EadSnapshotState.loading));
    try {
      final result = await reader.read(proof);
      if (!_current(requestGeneration)) return;
      if (!_usable(proof, _clock())) {
        _requireLogin(proof);
        return;
      }
      if (!_validResult(result, proof, _clock())) {
        // Unverifiable provenance is a security error: fail closed and do not
        // display the previous user's data even if the server is healthy.
        _requireLogin(proof);
        return;
      }

      final now = _clock();
      final age = now.difference(result.observedAt);
      if (age > maxOfflineAge) {
        _lastVerified = null;
        _publish(_forSession(proof, EadSnapshotState.error));
        return;
      }
      _lastVerified = result;
      _publish(
        _fromResult(
          proof,
          result,
          age <= maxFreshAge
              ? EadSnapshotState.current
              : EadSnapshotState.stale,
        ),
      );
    } on EadAccountReadException catch (error) {
      if (!_current(requestGeneration)) return;
      if (error.reason == EadAccountReadFailure.loginRequired ||
          error.reason == EadAccountReadFailure.forbidden) {
        _requireLogin(proof);
      } else {
        _lastVerified = null;
        _publish(_forSession(proof, EadSnapshotState.error));
      }
    } on Object {
      if (!_current(requestGeneration)) return;
      _lastVerified = null;
      _publish(_forSession(proof, EadSnapshotState.error));
    }
  }

  /// Offline access is limited to an in-memory verified snapshot for the
  /// same current user and environment. Never queue a LearnPress mutation.
  void setOffline() {
    _generation++;
    final proof = _session;
    if (proof == null) {
      _publish(_disconnected());
      return;
    }
    final now = _clock();
    if (!_usable(proof, now)) {
      _requireLogin(proof);
      return;
    }
    final cached = _lastVerified;
    if (cached != null &&
        _validResult(cached, proof, now) &&
        now.difference(cached.observedAt) <= maxOfflineAge) {
      _publish(_fromResult(proof, cached, EadSnapshotState.offline));
      return;
    }
    _lastVerified = null;
    _publish(_forSession(proof, EadSnapshotState.offline));
  }

  bool _usable(EadSessionProof proof, DateTime now) =>
      proof.brokerVerified &&
      proof.wpUserId > 0 &&
      proof.environmentId.trim().isNotEmpty &&
      proof.verifiedAt.isBefore(proof.expiresAt) &&
      !proof.verifiedAt.isAfter(now.add(const Duration(seconds: 5))) &&
      now.isBefore(proof.expiresAt) &&
      proof.expiresAt.difference(proof.verifiedAt) <=
          const Duration(minutes: 15);

  bool _validResult(
    EadAccountReadSnapshot response,
    EadSessionProof proof,
    DateTime now,
  ) {
    if (!response.authenticatedLearnPressOrigin ||
        response.wpUserId != proof.wpUserId ||
        response.environmentId != proof.environmentId ||
        response.observedAt.isAfter(now.add(const Duration(seconds: 5))) ||
        response.observedAt.isBefore(proof.verifiedAt) ||
        response.courses.length > 100) {
      return false;
    }
    final courseIds = <int>{};
    for (final course in response.courses) {
      if (course.wpCourseId <= 0 ||
          !courseIds.add(course.wpCourseId) ||
          course.title.trim().isEmpty ||
          course.title.length > 200 ||
          (course.progressPercent != null &&
              (course.progressPercent! < 0 || course.progressPercent! > 100))) {
        return false;
      }
    }
    return true;
  }

  EadMyAreaModel _disconnected() => const EadMyAreaModel(
    linkState: EadLinkState.disconnected,
    snapshotState: EadSnapshotState.unknown,
    environmentId: '',
    snapshotEnvironmentId: null,
  );

  EadMyAreaModel _forSession(EadSessionProof proof, EadSnapshotState state) =>
      EadMyAreaModel(
        linkState: EadLinkState.linked,
        snapshotState: state,
        environmentId: proof.environmentId,
        snapshotEnvironmentId: null,
        viewerWpUserId: proof.wpUserId,
      );

  EadMyAreaModel _loginRequired(EadSessionProof proof) => EadMyAreaModel(
    linkState: EadLinkState.loginRequired,
    snapshotState: EadSnapshotState.unknown,
    environmentId: proof.environmentId,
    snapshotEnvironmentId: null,
  );

  EadMyAreaModel _fromResult(
    EadSessionProof proof,
    EadAccountReadSnapshot result,
    EadSnapshotState state,
  ) => EadMyAreaModel(
    linkState: EadLinkState.linked,
    snapshotState: state,
    environmentId: proof.environmentId,
    snapshotEnvironmentId: result.environmentId,
    viewerWpUserId: proof.wpUserId,
    snapshotWpUserId: result.wpUserId,
    authenticatedSourceVerified: true,
    courses: List<EadAreaCourse>.unmodifiable(result.courses),
  );

  void _requireLogin(EadSessionProof proof) {
    _generation++;
    _lastVerified = null;
    _session = null;
    _publish(_loginRequired(proof));
  }

  bool _current(int generation) => !_disposed && _generation == generation;

  void _publish(EadMyAreaModel newModel) {
    if (_disposed) return;
    _model = newModel;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _session = null;
    _lastVerified = null;
    _disposed = true;
    super.dispose();
  }
}
