/// Monotonic foreground estimate; no academic credit. Stops after 60s idle.
class ScreenEngagementClock {
  ScreenEngagementClock(this.now);
  final Duration Function() now;
  Duration? _since;
  Duration? _lastTouch;
  bool foreground = true;

  void start() {
    _since = foreground ? now() : null;
    _lastTouch = _since;
  }

  int checkpoint() {
    final current = now();
    final since = _since;
    final touched = _lastTouch;
    if (!foreground || since == null || touched == null) return 0;
    final idleEnd = touched + const Duration(seconds: 60);
    final end = current < idleEnd ? current : idleEnd;
    final seconds = (end - since).inSeconds.clamp(0, 60);
    _since = end < current ? current : since + Duration(seconds: seconds);
    return seconds;
  }

  void touch() {
    _lastTouch = now();
  }

  void setForeground(bool value) {
    foreground = value;
    start();
  }

  void stop() {
    _since = null;
    _lastTouch = null;
  }
}
