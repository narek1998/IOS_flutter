import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:p2p_camera_plugin/p2p_camera_plugin.dart';


void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  int textureId;
  ListQueue<int> availableBuffers = ListQueue<int>();

  Uint8List sps = Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x01,
    0x67,
    0x42,
    0xc0,
    0x1f,
    0x9d,
    0xa8,
    0x14,
    0x01,
    0x6e,
    0x84,
    0x00,
    0x00,
    0x03,
    0x00,
    0x04,
    0x00,
    0x00,
    0x03,
    0x00,
    0x50,
    0x10
  ]);

  Uint8List pps = Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x01,
    0x68,
    0xee,
    0x3c,
    0x80,
  ]);

  static const availableCodecInputBufferStream = const EventChannel('p2p-camera/codec-stream');
  StreamSubscription _codecStreamSubscription = null;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }


  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await P2pCameraPlugin.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });

    await P2pCameraPlugin.registerAvailableBufferEventStream();

    if (_codecStreamSubscription == null) {
      _codecStreamSubscription = availableCodecInputBufferStream.receiveBroadcastStream().listen((data) {
        availableBuffers.add(data as int);
      });
    }

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Text('Running on: $_platformVersion\n'),
              RaisedButton(
                onPressed: () async {
                  var codecs = await P2pCameraPlugin.platformCodecs;
                  print(codecs);
                },
                child: Text('Get codecs'),
              ),
              RaisedButton(
                onPressed: () async {
                  var result = await P2pCameraPlugin.initCodec('video/avc');
                  print('InitCodec: $result');
                  textureId = await P2pCameraPlugin.getTexture();
                  print('InitTexture: $textureId');

                  await P2pCameraPlugin.setMediaFormat(csd0: sps, csd1: pps);
                  setState(() {

                  });
                },
                child: Text('Init codec'),
              ),
              RaisedButton(
                onPressed: () async {
                  await P2pCameraPlugin.start();
                  print('Started');
                },
                child: Text('Start'),
              ),

              RaisedButton(
                onPressed: () async {
                  AssetBundle bundle = DefaultAssetBundle.of(context);
                  var videoFile = await bundle.load('lib/assets/video.264');
                  print(videoFile);

                  /// Process file
                  var offset = 0;
                  var length = videoFile.lengthInBytes;
                  while (offset < length) {
                    List<int> nal = List();

                    // First we need to find magic number
                    if (videoFile.getUint32(offset) == 0x55aa15a8) {
                      // Get length of the block
                      var nalLen = videoFile.getUint16(offset + 16, Endian.little);
                      var byteData = videoFile.buffer.asByteData(offset + 32, nalLen);
                      await Future.delayed(Duration(milliseconds: 30));
                      await P2pCameraPlugin.sendBuffer(byteData);

                      //print("Found!!! Len=${nalLen.toRadixString(16)} Offset=${offset.toRadixString(16)}");
                      offset = offset + 32 + nalLen;
                    } else
                      offset++;
                  }
                  print('**********************************************************');
                  //var videoFile =  videoFile.buffer;
                },
                child: Text('Read video'),
              ),
              textureId == null ? Container(color: Colors.red) : Container(
                color: Colors.blue,
                width: 400,
                height: 250,
                child: Texture(textureId: textureId,),
              )
            ],
          ),
        ),
      ),
    );
  }
}
