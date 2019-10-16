import Flutter
import UIKit
import Foundation

public class SwiftP2pCameraPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var decoder: HWDecoder?
    
    public var registrar:FlutterPluginRegistrar?
    
    public var messageChannel:FlutterBasicMessageChannel?
    
    private var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "p2p-camera", binaryMessenger: registrar.messenger())
        let instance = SwiftP2pCameraPlugin()
        instance.decoder = HWDecoder()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.registrar = registrar
        instance.messageChannel = FlutterBasicMessageChannel(name: "p2p-camera/buffers", binaryMessenger: registrar.messenger(), codec: FlutterBinaryCodec.sharedInstance())
        instance.messageChannel?.setMessageHandler { (message, callback) in
            instance.frameRecieved(message: message as! NSData, reply: callback)
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if(call.method == "initCodec") {
            print("initCodec")
            result(nil)
        } else if (call.method == "setMediaFormat") {
            let dict:NSDictionary = call.arguments as! NSDictionary;
            let val1 = dict.object(forKey: "csd0")
            let val2 = dict.object(forKey: "csd1")
            self.setMediaFormat(pps: val2, sps:val1)
            result(nil)
        } else if(call.method == "start") {
            print("start")
            result(nil)
        } else if (call.method == "getPlatformCodecs") {
            print("getPlatformCodecs")
            result(nil)
        }  else if (call.method == "getPlatformVersion") {
            result("iOS " + UIDevice.current.systemVersion)
        }  else if (call.method == "registerAvailableBufferEventStream") {
            let eChannel = FlutterEventChannel.init(name: "p2p-camera/codec-stream", binaryMessenger: (registrar?.messenger())!)
            eChannel.setStreamHandler(self)
            result("registerAvailableBufferEventStream:OK")
        } else if (call.method == "getTexture") {
            print(call.method)
            result(nil)
        } else {
            print(call.method)
            result(nil)
        }
    }

    private func setMediaFormat(pps:Any?, sps:Any?) {
        self.decoder?.setVideoFormaWithPps(pps , withSps: sps)
    }
    
    private func initCodec() {
        
    }
    
    private func platformCodecs () {
        
    }
    
    private func texture() {
        
    }
    
    private func start() {
        
    }
    
    private func platformVersion() {
        
    }
    
    private func frameRecieved (message: NSData, reply: @escaping FlutterReply) {
        decoder?.decodeFrame(message as Data, withCallBack: {(decodedFrame:CVImageBuffer ) -> Void in
            reply(decodedFrame)
        })
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
    
}
