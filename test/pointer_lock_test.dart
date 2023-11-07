import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock/pointer_lock_platform_interface.dart';
import 'package:pointer_lock/pointer_lock_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPointerLockPlatform
    with MockPlatformInterfaceMixin
    implements PointerLockPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PointerLockPlatform initialPlatform = PointerLockPlatform.instance;

  test('$MethodChannelPointerLock is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPointerLock>());
  });

  test('getPlatformVersion', () async {
    PointerLock pointerLockPlugin = PointerLock();
    MockPointerLockPlatform fakePlatform = MockPointerLockPlatform();
    PointerLockPlatform.instance = fakePlatform;

    expect(await pointerLockPlugin.getPlatformVersion(), '42');
  });
}
