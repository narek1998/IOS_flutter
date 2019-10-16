#import <Foundation/Foundation.h>

#import <Flutter/Flutter.h>
/**
 *
 *
 *
 **/
typedef void (^frameReady)(CVImageBufferRef _Nonnull frame);

@interface HWDecoder : NSObject <FlutterTexture>

// CallBack
@property (nonatomic, strong) frameReady _Nonnull ready;

- (void) setVideoFormaWithPps:(NSData*) pps withSps:(NSData*) sps;

- (void) initCodec;

- (void) decodeFrame:( NSData* _Nonnull ) frame withCallBack:(frameReady) ready;

@end
