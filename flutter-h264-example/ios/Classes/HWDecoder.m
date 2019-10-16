#import <VideoToolbox/VideoToolbox.h>
#import <Flutter/Flutter.h>

#import "HWDecoder.h"

CVPixelBufferRef outBuffer = NULL;

@interface HWDecoder()

@property (nonatomic, strong) NSString * _Nonnull path;

//VideoToolbox
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) int spsSize;
@property (nonatomic, assign) int ppsSize;
//@property (nonatomic, assign) CVPixelBufferRef outBuffer;


@end

@implementation HWDecoder

- (CVPixelBufferRef)copyPixelBuffer {
    CVBufferRetain(outBuffer);
    return outBuffer;
}

- (BOOL) haveStartCode:(NSData*) frame {
    uint32_t start = 0;
    [frame getBytes:&start length:sizeof(start)];
    return CFSwapInt32BigToHost(start) == 1;
}

- (NSData*) correctFrame:(NSData*) frame {
    NSData *correctedFrame = frame;
    uint32_t start = 0;
    [frame getBytes:&start length:sizeof(start)];
    if (CFSwapInt32BigToHost(start) != 1) {
        size_t newSize = frame.length + 4;
        void * newData = malloc(newSize);
        memcpy(newData + 4, frame.bytes, frame.length);
        start = htonl (0x00000001);
        memcpy (newData, &start, sizeof (uint32_t));
        correctedFrame = [NSData dataWithBytes:newData length:newSize];
    }
    return correctedFrame;
}


- (void) decodeFrame:(NSData*) frame withCallBack:(frameReady)ready {
    _ready = ready;
    if (! [self haveStartCode:frame]) {
        ready(nil);
        return;
    }
    CMSampleBufferRef sampleBuffer = [self rawDataToSampleBuffer:(uint8_t*)frame.bytes withSize:frame.length];
    [self decode:sampleBuffer];
}

- (CMSampleBufferRef) createSampleBufferWithData:(uint8_t*) data withSize:(size_t) size andOffset:(size_t) offset {
    OSStatus status = 0;
    CMBlockBufferRef blockBuffer = NULL;
    CMSampleBufferRef sampleBuffer = NULL;

    status = CMBlockBufferCreateWithMemoryBlock(NULL, data + offset,  // memoryBlock to hold buffered data
                                                size,  // block length of the mem block in bytes.
                                                kCFAllocatorNull, NULL,
                                                0, // offsetToData
                                                size,   // dataLength of relevant bytes, starting at offsetToData
                                                0, &blockBuffer);
    
    
    uint32_t dataLength32 = htonl (size - 4);
    uint8_t *sourceBytes = malloc(sizeof(uint32_t));
    memcpy (sourceBytes, &dataLength32, sizeof (uint32_t));
    
    status = CMBlockBufferReplaceDataBytes(sourceBytes, blockBuffer, 0, sizeof (uint32_t));
    free(sourceBytes);
    if(status == noErr)
    {
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      blockBuffer, true, NULL, NULL,
                                      _formatDesc, 1, 0, NULL, 1,
                                      &size, &sampleBuffer);
        
    }
    
    if(status == noErr)
    {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }
    
    return sampleBuffer;
}

- (void) setVideoFormaWithPps:(NSData*) pps withSps:(NSData*) sps {
    OSStatus status;
    
    if([self haveStartCode:pps]) {
        pps = [pps subdataWithRange:NSMakeRange(4, pps.length -4)];
    }
    
    if([self haveStartCode:sps]) {
        sps = [sps subdataWithRange:NSMakeRange(4, sps.length -4)];
    }

    const uint8_t*  parameterSetPointers[2] = {sps.bytes, pps.bytes};
    size_t parameterSetSizes[2] = {sps.length, pps.length};
    if (_formatDesc)
    {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }
    
    status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2,
                                                                 parameterSetPointers,
                                                                 parameterSetSizes, 4,
                                                                 &_formatDesc);
    
    BOOL needNewDecompSession = (VTDecompressionSessionCanAcceptFormatDescription(_decompressionSession, _formatDesc) == NO);
    if(needNewDecompSession)
    {
        [self initCodec];
    }

    NSLog(@"%d %@", status, _formatDesc);
}

- (void) initCodec
{
    _decompressionSession = NULL;
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decompressionSessionDecodeFrameCallback;
    
    callBackRecord.decompressionOutputRefCon = (__bridge_retained void *)self;
    NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:YES],
                                                      (id)kCVPixelBufferOpenGLESCompatibilityKey,
                                                      nil];
    
    OSStatus status =  VTDecompressionSessionCreate(NULL, _formatDesc, NULL,
                                                    (__bridge CFDictionaryRef)(destinationImageBufferAttributes),
                                                    &callBackRecord, &_decompressionSession);
    if (status != noErr) {
        NSLog(@"VTDecompressionSessionCreate : Failed with status code %d", status);
    }
    
}

- (void) invalidateCodec
{
    if (_decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = nil;
    }
    if (_formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = nil;
    }
}

void decompressionSessionDecodeFrameCallback(void *decompressionOutputRefCon,
                                             void *sourceFrameRefCon,
                                             OSStatus status,
                                             VTDecodeInfoFlags infoFlags,
                                             CVImageBufferRef imageBuffer,
                                             CMTime presentationTimeStamp,
                                             CMTime presentationDuration)
{
    HWDecoder *streamManager = (__bridge HWDecoder *)decompressionOutputRefCon;
    if (status != noErr)
    {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Decompressed error: %@", error);
        streamManager.ready(imageBuffer);
    } else {
        NSLog(@"Decompressed sucessfully");
        
        CFBridgingRetain((__bridge id _Nullable)(imageBuffer));
    
        streamManager.ready(imageBuffer);
    }
}

- (void) decode:(CMSampleBufferRef)sampleBuffer
{
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags flagOut;
    NSDate* currentTime = [NSDate date];
    VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBuffer, flags,
                                      (void*)CFBridgingRetain(currentTime), &flagOut);
    
    CFRelease(sampleBuffer);
}

- (BOOL) stop {
    [self invalidateCodec];
    return YES;
}


-(CMSampleBufferRef) rawDataToSampleBuffer:(uint8_t *)frame withSize:(NSUInteger)frameSize
{
    OSStatus status = 0;
    
    uint8_t *pps = NULL;
    uint8_t *sps = NULL;
    
    int startCodeIndex = 0;
    int secondStartCodeIndex = 0;
    int thirdStartCodeIndex = 0;
    
    long blockLength = 0;
    
    CMSampleBufferRef sampleBuffer = NULL;
    
    
    
    int nalu_type = (frame[startCodeIndex + 4] & 0x1F);
    
    if (nalu_type != 7 && _formatDesc == NULL)
    {
        return nil;
    }
    
    if (nalu_type == 7)
    {
        for (int i = startCodeIndex + 4; i < startCodeIndex + 40; i++)
        {
            if (frame[i] == 0x00 && frame[i+1] == 0x00 && frame[i+2] == 0x00 && frame[i+3] == 0x01)
            {
                secondStartCodeIndex = i;
                _spsSize = secondStartCodeIndex;   // includes the header in the size
                break;
            }
        }
        nalu_type = (frame[secondStartCodeIndex + 4] & 0x1F);
    }
    
    if(nalu_type == 8)
    {
        for (int i = _spsSize + 4; i < _spsSize + 30; i++)
        {
            if (frame[i] == 0x00 && frame[i+1] == 0x00 && frame[i+2] == 0x00 && frame[i+3] == 0x01)
            {
                thirdStartCodeIndex = i;
                _ppsSize = thirdStartCodeIndex - _spsSize;
                break;
            }
        }
        
        sps = malloc(_spsSize - 4);
        pps = malloc(_ppsSize - 4);
        
        memcpy (sps, &frame[4], _spsSize-4);
        memcpy (pps, &frame[_spsSize+4], _ppsSize-4);
        
        NSData* ppsData = [NSData dataWithBytes:pps length:_ppsSize - 4];
        NSData* spsData = [NSData dataWithBytes:sps length:_spsSize - 4];

        free(sps);
        free(pps);

        [self setVideoFormaWithPps:ppsData withSps:spsData];
        
        nalu_type = (frame[thirdStartCodeIndex + 4] & 0x1F);
    }
    
    if((status == noErr) && (_decompressionSession == NULL))
    {
        [self initCodec];
    }
    
    int offset = 0;
    if(nalu_type == 5)
    {
        offset = _spsSize + _ppsSize;
        blockLength = frameSize - offset;
        
    } else if(1 == nalu_type) {
        blockLength = frameSize;
    }
    
    sampleBuffer =  [self createSampleBufferWithData:frame withSize:blockLength andOffset:offset];
    return sampleBuffer;
}

@end
