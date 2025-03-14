import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pointer_lock.dart';
import 'pointer_lock_channel.dart';

abstract class PointerLockPlatform extends PlatformInterface {
  /// Constructs a PointerLockPlatform.
  PointerLockPlatform() : super(token: _token);

  static final Object _token = Object();

  static PointerLockPlatform _instance = ChannelPointerLock();

  /// The default instance of [PointerLockPlatform] to use.
  ///
  /// Defaults to [ChannelPointerLock].
  static PointerLockPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PointerLockPlatform] when
  /// they register themselves.
  static set instance(PointerLockPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> ensureInitialized() {
    throw UnimplementedError('ensureInitialized() has not been implemented.');
  }

  Stream<PointerLockMoveEvent> createSession({
    required PointerLockWindowsMode windowsMode,
    required PointerLockCursor cursor,
    required bool unlockOnPointerUp,
  }) {
    throw UnimplementedError('createSession() has not been implemented.');
  }

  Future<void> hidePointer() {
    throw UnimplementedError('hidePointer() has not been implemented.');
  }

  Future<void> showPointer() {
    throw UnimplementedError('showPointer() has not been implemented.');
  }

  Future<Offset> pointerPositionOnScreen() {
    throw UnimplementedError(
        'pointerPositionOnScreen() has not been implemented.');
  }
}
