
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class P2pCameraPlugin {
  static const MethodChannel _channel =
      const MethodChannel('p2p-camera');

  static const _binaryChannel = const BasicMessageChannel('p2p-camera/buffers', const BinaryCodec());

  static Future<ByteData> sendBuffer(ByteData buffer) async {
    final ByteData result = await _binaryChannel.send(buffer);
    return result;
  }
  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<List<String>> get platformCodecs async {
    List<dynamic> result = await _channel.invokeMethod('getPlatformCodecs');
    var codecs = result.cast<String>();
    return codecs;
  }

  static Future<bool> initCodec(codecType) async {
    final bool result = await _channel.invokeMethod('initCodec', {'codecType':codecType});
    return result;
  }

  static Future<int> getTexture() async {
    final int result = await _channel.invokeMethod('getTexture');
    return result;
  }

  static Future<void> setMediaFormat({Uint8List csd0, Uint8List csd1}) async {
    final int result = await _channel.invokeMethod('setMediaFormat', {'csd0' : csd0, 'csd1' : csd1});
    return result;
  }

  static Future<void> start() async {
    final int result = await _channel.invokeMethod('start');
    return result;
  }

  static Future<void> registerAvailableBufferEventStream() async {
    final int result = await _channel.invokeMethod('registerAvailableBufferEventStream');
    return result;
  }

}
