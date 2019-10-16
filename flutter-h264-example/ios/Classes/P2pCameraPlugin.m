#import "P2pCameraPlugin.h"
#import "HWDecoder.h"

static P2pCameraPlugin *sharedInstance;

@interface P2pCameraPlugin () {
    FlutterBasicMessageChannel *messageChannel;
    NSInteger _textureId;
    HWDecoder *_decoder;
}

@property (nonatomic, strong) NSObject<FlutterTextureRegistry> *textures;
@property (nonatomic, strong) CADisplayLink* displayLink;

@end

@implementation P2pCameraPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    if (! sharedInstance) {
        sharedInstance = [[P2pCameraPlugin alloc] init];
        [sharedInstance registerPlugin:registrar];
    }
}

- (void) registerPlugin:(NSObject<FlutterPluginRegistrar>*)registrar {
    _decoder = [[HWDecoder alloc] init];
    _textures = [registrar textures];
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"p2p-camera" binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:self channel:channel];
    messageChannel = [FlutterBasicMessageChannel messageChannelWithName:@"p2p-camera/buffers" binaryMessenger:[registrar messenger] codec:[FlutterBinaryCodec sharedInstance]];
    _displayLink = [CADisplayLink displayLinkWithTarget:self
                                               selector:@selector(onDisplayLink:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    _displayLink.paused = YES;

}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"%@ %@", call.method, call.arguments);
    
    if ([call.method isEqualToString:@"setMediaFormat"]) {
        FlutterStandardTypedData *pps = [call.arguments objectForKey:@"csd0"];
        FlutterStandardTypedData *sps = [call.arguments objectForKey:@"csd1"];
        if (! sps || ! pps) {
            result(@"Incomplete Data");
            return;
        }
        [_decoder setVideoFormaWithPps:pps.data withSps:sps.data];
        result(@"OK");
    } else if ([call.method isEqualToString:@"getTexture"]) {

        CGFloat width = [call.arguments[@"width"] floatValue];
        CGFloat height = [call.arguments[@"height"] floatValue];
        __weak P2pCameraPlugin* weakSelf = self;

        [messageChannel setMessageHandler:^(id  _Nullable message, FlutterReply  _Nonnull callback) {
            [_decoder decodeFrame:message withCallBack:^(CVImageBufferRef  _Nonnull frame) {
                            [self.textures textureFrameAvailable:_textureId];
                callback(nil);
            }];
        }];
        
        _textureId = [self.textures registerTexture:_decoder];
        result(@(_textureId));
    } else {
        result(nil);
    }
}


- (void)onDisplayLink:(CADisplayLink*)link {
    [self.textures textureFrameAvailable:_textureId];
}

@end
