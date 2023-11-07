import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pointer_lock_method_channel.dart';

abstract class PointerLockPlatform extends PlatformInterface {
  /// Constructs a PointerLockPlatform.
  PointerLockPlatform() : super(token: _token);

  static final Object _token = Object();

  static PointerLockPlatform _instance = MethodChannelPointerLock();

  /// The default instance of [PointerLockPlatform] to use.
  ///
  /// Defaults to [MethodChannelPointerLock].
  static PointerLockPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PointerLockPlatform] when
  /// they register themselves.
  static set instance(PointerLockPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> lockPointer() {
    throw UnimplementedError('lockPointer() has not been implemented.');
  }

  Future<void> unlockPointer() {
    throw UnimplementedError('unlockPointer() has not been implemented.');
  }

  Future<Offset> lastPointerDelta() {
    throw UnimplementedError('lastPointerDelta() has not been implemented.');
  }

  Future<void> hidePointer() {
    throw UnimplementedError('hidePointer() has not been implemented.');
  }

  Future<void> showPointer() {
    throw UnimplementedError('showPointer() has not been implemented.');
  }
}
