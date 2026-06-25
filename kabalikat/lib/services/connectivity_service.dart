import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has a network path. The UI also
/// allows a manual override so you can SIMULATE offline during a demo
/// without touching airplane mode.
class ConnectivityService {
  final Connectivity _conn = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _online = true;
  bool? _forced; // demo override

  Stream<bool> get onChange => _controller.stream;
  bool get isOnline => _forced ?? _online;

  Future<void> init() async {
    final result = await _conn.checkConnectivity();
    _online = _isConnected(result);
    _conn.onConnectivityChanged.listen((r) {
      _online = _isConnected(r);
      _controller.add(isOnline);
    });
  }

  // connectivity_plus 6.x returns a List<ConnectivityResult>.
  bool _isConnected(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);

  /// Demo toggle. Pass null to return to real network state.
  void forceOffline(bool? offline) {
    _forced = offline == null ? null : !offline;
    _controller.add(isOnline);
  }
}
