import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// ─── CONNECTIVITY MANAGER ────────────────────────────────────────────
/// Detects online/offline state using connectivity_plus and exposes a
/// reactive stream.
///
/// KEY FEATURES:
/// • Real connectivity check via DNS lookup (not just WiFi-connected).
/// • Demo override for hackathon presentations (simulate offline without
///   touching airplane mode).
/// • Debounced stream to avoid rapid toggle noise on flaky networks.
///
/// OFFLINE-FALLBACK MECHANIC:
///   ConnectivityManager.isOnline → true  → route to Gemini API
///   ConnectivityManager.isOnline → false → route to local Ollama
class ConnectivityManager {
  final Connectivity _conn = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _online = true;
  bool? _forced; // Demo override for presentations.

  /// Reactive stream of connectivity changes.
  Stream<bool> get onChange => _controller.stream;

  /// Current effective online status (respects demo override).
  bool get isOnline => _forced ?? _online;

  /// Human-readable status for the UI badge.
  String get statusLabel {
    if (_forced != null && !_forced!) return '🔧 Demo Offline Mode';
    if (!_online) return '📴 Offline · Local AI';
    return '🌐 Online · Gemini AI';
  }

  /// Initialize: check current state and start listening.
  Future<void> init() async {
    final result = await _conn.checkConnectivity();
    _online = _isConnected(result);

    _conn.onConnectivityChanged.listen((r) {
      final wasOnline = _online;
      _online = _isConnected(r);

      // Only emit if actual state changed to avoid UI thrash.
      if (wasOnline != _online) {
        _controller.add(isOnline);
      }
    });
  }

  /// Performs a live network re-check and returns the authoritative status.
  ///
  /// Always call this before routing AI traffic — the cached [isOnline]
  /// getter may lag by seconds on rapid toggle (airplane mode, handoff).
  /// Equivalent to [recheckNow] but named for the repository contract.
  Future<bool> isDeviceOnline() => recheckNow();

  /// Force a re-check (useful before critical operations like deck gen).
  Future<bool> recheckNow() async {
    final result = await _conn.checkConnectivity();
    if (_isConnected(result)) {
      _online = await _checkActualInternet();
    } else {
      _online = false;
    }
    return isOnline;
  }

  /// Verifies actual internet reachability using a DNS lookup.
  /// Prevents false positives when connected to a router with no internet.
  Future<bool> _checkActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
    return false;
  }

  /// connectivity_plus 6.x returns List<ConnectivityResult>.
  bool _isConnected(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);

  /// Demo toggle. Pass `true` to force offline, `null` to return to real.
  void forceOffline(bool? offline) {
    _forced = offline == null ? null : !offline;
    _controller.add(isOnline);
  }

  /// Clean up.
  void dispose() {
    _controller.close();
  }
}
