import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../pointer_lock.dart';
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

  Stream<Offset> createSession({
    required WindowsPointerLockMode windowsMode,
    required PointerLockCursor cursor,
  }) {
    throw UnimplementedError('createSession() has not been implemented.');
  }
}
