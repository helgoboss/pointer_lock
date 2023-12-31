import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_lock/src/pointer_lock_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ChannelPointerLock platform = ChannelPointerLock();
  const MethodChannel channel = MethodChannel('pointer_lock');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  // test('getPlatformVersion', () async {
  //   expect(await platform.getPlatformVersion(), '42');
  // });
}
