//
//  UPAVCapturer.m
//  UPAVCaptureDemo
//
//  Created by DING FENG on 3/31/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

#import "UPAVCapturer.h"
#import <CommonCrypto/CommonDigest.h>
#import <UPLiveSDK/UPAVStreamer.h>
#import "GPUImage.h"
#import "GPUImageFramebuffer.h"
#import "LFGPUImageBeautyFilter.h"

//连麦模块可先择集成
#ifdef _UPRTCSDK_

@interface UPAVCapturer()<RtcManagerDataOutProtocol>
@property (nonatomic, strong) RtcManager *rtc;
@end
#endif


@import  Accelerate;


@interface UPAVCapturer()<UPAVStreamerDelegate, UPAudioCaptureProtocol, UPVideoCaptureProtocol> {
    NSError *_capturerError;
    //backgroud push
    BOOL _applicationActive;
    CVPixelBufferRef _backGroundPixBuffer;
    int _backGroundFrameSendloopid;
    BOOL _backGroundFrameSendloopOn;
    
    //video size, capture size
    CGSize _capturerPresetLevelFrameCropSize;
    dispatch_queue_t _pushFrameQueue;
    UIView *_preview;
    NSString *_outStreamPath;
    
}

@property (nonatomic, assign) int pushStreamReconnectCount;

@property (nonatomic, strong) UPAVStreamer *rtmpStreamer; // rtmp 推流器
@property (nonatomic, strong) UPVideoCapture *upVideoCapture; // 视频采集器
@property (nonatomic, strong) UPAudioCapture *audioUnitRecorder; // 音频采集器


@property (nonatomic, assign) NSTimeInterval startReconnectTimeInterval;
@property (nonatomic, strong) NSTimer *delayTimer;
@property (nonatomic, assign) int timeSec;
@property (nonatomic, assign) int reconnectCount;
@end



#pragma mark capturer dashboard

@interface UPAVCapturerDashboard()

@property(nonatomic, weak) UPAVCapturer *infoSource_Capturer;

@end

@class UPAVCapturer;

@implementation UPAVCapturerDashboard

- (float)fps_capturer {
    return self.infoSource_Capturer.rtmpStreamer.fps_capturer;
}

- (float)fps_streaming {
    return self.infoSource_Capturer.rtmpStreamer.fps_streaming;
}

- (float)bps {
    return self.infoSource_Capturer.rtmpStreamer.bps;
}

- (int64_t)vFrames_didSend {
    return self.infoSource_Capturer.rtmpStreamer.vFrames_didSend;
}
- (int64_t)aFrames_didSend {
    return self.infoSource_Capturer.rtmpStreamer.aFrames_didSend;
}

- (int64_t)streamSize_didSend {
    return self.infoSource_Capturer.rtmpStreamer.streamSize_didSend;
}

- (int64_t)streamTime_lasting {
    return self.infoSource_Capturer.rtmpStreamer.streamTime_lasting;
}

- (int64_t)cachedFrames {
    return self.infoSource_Capturer.rtmpStreamer.cachedFrames;
}

- (int64_t)dropedFrames {
    return self.infoSource_Capturer.rtmpStreamer.dropedFrames;
}

- (NSString *)description {
    NSString *descriptionString = [NSString stringWithFormat:@"fps_capturer: %f \nfps_streaming: %f \nbps: %f \nvFrames_didSend: %lld \naFrames_didSend:%lld \nstreamSize_didSend: %lld \nstreamTime_lasting: %lld \ncachedFrames: %lld \ndropedFrames:%lld",
                                   self.fps_capturer,
                                   self.fps_streaming,
                                   self.bps,
                                   self.vFrames_didSend,
                                   self.aFrames_didSend,
                                   self.streamSize_didSend,
                                   self.streamTime_lasting,
                                   self.cachedFrames,
                                   self.dropedFrames];
    return descriptionString;
}

@end

@implementation UPAVCapturer

+ (UPAVCapturer *)sharedInstance {
    static UPAVCapturer *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[UPAVCapturer alloc] init];
    });
    return _sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        self.capturerPresetLevel = UPAVCapturerPreset_640x480;
        _capturerPresetLevelFrameCropSize = CGSizeZero;
        _fps = 24;
        _viewZoomScale = 1;
        _applicationActive = YES;
        _streamingOn = YES;
        _filterOn = NO;
        _increaserRate = 100;//原声
        _pushFrameQueue = dispatch_queue_create("UPAVCapturer.pushFrameQueue", DISPATCH_QUEUE_SERIAL);
        
        _dashboard = [UPAVCapturerDashboard new];
        _dashboard.infoSource_Capturer = self;
        
        //注意:为了与 rtc 系统衔接这里的 samplerate 需要与 rtc 保持一致 32Khz。
        _audioUnitRecorder = [[UPAudioCapture alloc] initWith:UPAudioUnitCategory_recorder
                                                   samplerate:32000];
        _audioUnitRecorder.delegate = self;
        
        _upVideoCapture = [[UPVideoCapture alloc]init];
        _upVideoCapture.delegate = self;
        
        [self addNotifications];
        _timeSec = 30;
        _reconnectCount = 0;
    }
    return self;
}

- (void)rtcInitWithAppId:(NSString *)aapid {
#ifdef _UPRTCSDK_
    self.rtc = [RtcManager sharedInstance];
    self.rtc.delegate = self;
    [self.rtc setAppId:aapid];
    NSLog(@"连麦模块");
#endif
}


- (void)addNotifications {
#ifndef UPYUN_APP_EXTENSIONS
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidResignActive:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:[UIApplication sharedApplication]];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:[UIApplication sharedApplication]];

#endif
}

- (void)removeNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)setFilterOn:(BOOL)filterOn {
    _filterOn = filterOn;
    _upVideoCapture.filterOn = filterOn;
}

- (void)setCapturerStatus:(UPAVCapturerStatus)capturerStatus {
    if (_capturerStatus == capturerStatus) {
        return;
    }
    _capturerStatus = capturerStatus;
    //代理方式回调采集器状态
    dispatch_async(dispatch_get_main_queue(), ^(){
        if ([self.delegate respondsToSelector:@selector(capturer:capturerStatusDidChange:)]) {
            [self.delegate capturer:self capturerStatusDidChange:_capturerStatus];
        }
        
        switch (_capturerStatus) {
            case UPAVCapturerStatusStopped:
                break;
            case UPAVCapturerStatusLiving:
                break;
            case UPAVCapturerStatusError: {
                [self stop];
                if ([self.delegate respondsToSelector:@selector(capturer:capturerError:)]) {
                    [self.delegate capturer:self capturerError:_capturerError];
                }
            }
                break;
            default:
                break;
        }
    });
}

- (void)setPushStreamStatus:(UPPushAVStreamStatus)pushStreamStatus {
    
    if (_pushStreamStatus == pushStreamStatus) {
        return;
    }
    _pushStreamStatus = pushStreamStatus;
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        if ([self.delegate respondsToSelector:@selector(capturer:pushStreamStatusDidChange:)]) {
            [self.delegate capturer:self pushStreamStatusDidChange:_pushStreamStatus];
        }
        
        switch (_pushStreamStatus) {
            case UPPushAVStreamStatusClosed:
                break;
            case UPPushAVStreamStatusConnecting:
                break;
            case UPPushAVStreamStatusReady:
                break;
            case UPPushAVStreamStatusPushing:
                break;
            case UPPushAVStreamStatusError: {
                //失败重连尝试三次
                if (_reconnectCount == 0) {
                    [self reconnectTimes];
                }
                self.pushStreamReconnectCount = self.pushStreamReconnectCount + 1;
                NSString *message = [NSString stringWithFormat:@"UPAVPacketManagerStatusStreamWriteError %@, reconnect %d times", _capturerError, self.pushStreamReconnectCount];
                
//                NSLog(@"reconnect --%@",message);
                
                if (self.pushStreamReconnectCount < 3 && _reconnectCount < 20) {
                    _reconnectCount++;
                    [_rtmpStreamer reconnect];
                    return ;
                } else {
                    self.capturerStatus = UPAVCapturerStatusError;
                }
                break;
            }
        }
    });
}

- (void)setStreamingOn:(BOOL)streamingOn {
    _streamingOn = streamingOn;
    _rtmpStreamer.streamingOn = _streamingOn;
}

- (NSString *)outStreamPath{
    return _outStreamPath;
}

- (void)setOutStreamPath:(NSString *)outStreamPath {
    _outStreamPath = outStreamPath;
}

- (void)setCamaraPosition:(AVCaptureDevicePosition)camaraPosition {
    
    if (self.audioOnly) {
        return;
    }
    
    if (AVCaptureDevicePositionUnspecified == camaraPosition) {
        return;
    }
    if (_camaraPosition == camaraPosition) {
        return;
    }
    _camaraPosition = camaraPosition;

    [_upVideoCapture setCamaraPosition:camaraPosition];
    
}

- (void)setCapturerPresetLevelFrameCropSize:(CGSize)capturerPresetLevelFrameCropSize {
    [_upVideoCapture resetCapturerPresetLevelFrameSizeWithCropRect:capturerPresetLevelFrameCropSize];
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    _videoOrientation = videoOrientation;
    [_upVideoCapture setVideoOrientation:videoOrientation];
}

- (void)setCapturerPresetLevel:(UPAVCapturerPresetLevel)capturerPresetLevel {
    _capturerPresetLevel = capturerPresetLevel;
    [_upVideoCapture setCapturerPresetLevel:capturerPresetLevel];
    
    switch (_capturerPresetLevel) {
        case UPAVCapturerPreset_480x360:{
            _bitrate = 400000;
            break;
        }
        case UPAVCapturerPreset_640x480:{
            _bitrate = 600000;
            break;
        }
        case UPAVCapturerPreset_960x540:{
            _bitrate = 900000;
            break;
        }
        case UPAVCapturerPreset_1280x720:{
            _bitrate = 1200000;
            break;
        }
        default:{
            _bitrate = 600000;
            break;
        }
    }
    [self setBitrate:_bitrate];
}

- (void)setFps:(int32_t)fps{
    _fps = fps;
    _upVideoCapture.fps = fps;
}


- (NSString *)backgroudMusicUrl{
    return self.audioUnitRecorder.backgroudMusicUrl;
}

- (void)setBackgroudMusicUrl:(NSString *)backgroudMusicUrl {
    self.audioUnitRecorder.backgroudMusicUrl = backgroudMusicUrl;
}

- (void)setBackgroudMusicOn:(BOOL)backgroudMusicOn {
    self.audioUnitRecorder.backgroudMusicOn = backgroudMusicOn;
}

- (BOOL)backgroudMusicOn {
    return  self.audioUnitRecorder.backgroudMusicOn;
}

- (CGFloat)fpsCapture {
    return _rtmpStreamer.fps_capturer;
}

- (void)setIncreaserRate:(int)increaserRate {
    _increaserRate = increaserRate;
    _audioUnitRecorder.increaserRate = increaserRate;
}

- (void)setDeNoise:(BOOL)deNoise {
    _deNoise = deNoise;
    _audioUnitRecorder.deNoise = deNoise;
}

- (void)setBackgroudMusicVolume:(Float32)backgroudMusicVolume {
    _audioUnitRecorder.backgroudMusicVolume = backgroudMusicVolume;
}

- (Float32)backgroudMusicVolume {
    return _audioUnitRecorder.backgroudMusicVolume;
}

- (UIView *)previewWithFrame:(CGRect)frame contentMode:(UIViewContentMode)mode {
    _preview = [_upVideoCapture previewWithFrame:frame contentMode:mode];
    return _preview;
}

- (void)setWatermarkView:(UIView *)watermarkView Block:(WatermarkBlock)block {
    [_upVideoCapture setWatermarkView:watermarkView Block:block];
}

- (void)start {
    //实例化推流器 _rtmpStreamer
    dispatch_async(_pushFrameQueue, ^{
        _rtmpStreamer = [[UPAVStreamer alloc] initWithUrl:_outStreamPath];
        if (!_rtmpStreamer) {
            NSError *error = [NSError errorWithDomain:@"UPAVCapturer_error"
                                                 code:100
                                             userInfo:@{NSLocalizedDescriptionKey:@"_rtmpStreamer init failed, please check the push url"}];
            
            _capturerError = error;

            if (_streamingOn && [self.delegate respondsToSelector:@selector(capturer:capturerError:)]) {
                
                /*抛出推流器实例失败错误
                 在只拍摄不推流的情况下，例如观众端连麦时候 outStreamPath 是 nil 或者无效地址，这个错误不必抛出。
                 除此之外的大多数正常推流、主播连麦都需要推流器，所以这里默认初始化一个 _rtmpStreamer 备用。
                 */
                
                [self.delegate capturer:self capturerError:_capturerError];
            }
        }
        _rtmpStreamer.audioOnly = self.audioOnly;
        _rtmpStreamer.bitrate = _bitrate;
        _rtmpStreamer.delegate = self;
        _rtmpStreamer.streamingOn = _streamingOn;
        if (_openDynamicBitrate) {
            [self openStreamDynamicBitrate:YES];
        }
        
    });

    _rtmpStreamer.audioOnly = self.audioOnly;
    if (!self.audioOnly) {
        [_upVideoCapture start];
    }
    [_audioUnitRecorder start];
    self.capturerStatus = UPAVCapturerStatusLiving;
    
#ifndef UPYUN_APP_EXTENSIONS
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
#endif
    
}

- (void)stop {
    //关闭背景音播放器
    if([UPAVCapturer sharedInstance].backgroudMusicOn) {
        [UPAVCapturer sharedInstance].backgroudMusicOn = NO;
    }
    
    //关闭连麦模块
#ifdef _UPRTCSDK_
    if (self.rtc.channelConnected) {
        [self.rtc stop];
    }
#endif
    //关闭视频采集
    [_upVideoCapture stop];
    
    //关闭音频采集
    [_audioUnitRecorder stop];
    
    self.capturerStatus = UPAVCapturerStatusStopped;
    
    //关闭推流器
    dispatch_async(_pushFrameQueue, ^{
        [_rtmpStreamer stop];
        _rtmpStreamer = nil;
    });
#ifndef UPYUN_APP_EXTENSIONS
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
#endif
    _reconnectCount = 0;
    if (_backGroundPixBuffer) {
        CFRelease(_backGroundPixBuffer);
        _backGroundPixBuffer = nil;
    }
    if (_delayTimer) {
        [_delayTimer invalidate];
        _delayTimer = nil;
    }
    
}

- (void)dealloc {
    [self removeNotifications];
    NSString *message = [NSString stringWithFormat:@"dealloc %@", self];
    NSLog(@"%@",message);
}


- (void)setCamaraTorchOn:(BOOL)camaraTorchOn {
    _camaraTorchOn = camaraTorchOn;
    [_upVideoCapture setCamaraTorchOn:camaraTorchOn];
}

- (void)setBitrate:(int64_t)bitrate {
    if (bitrate < 0) {
        return;
    }
    _bitrate = bitrate;
    _rtmpStreamer.bitrate = _bitrate;
}

- (void)setViewZoomScale:(CGFloat)viewZoomScale {
    _upVideoCapture.viewZoomScale = viewZoomScale;
}

- (void)setOpenDynamicBitrate:(BOOL)openDynamicBitrate {
    _openDynamicBitrate = openDynamicBitrate;
    if (_rtmpStreamer) {
        [self openStreamDynamicBitrate:_openDynamicBitrate];
    }
}


#pragma mark 动态码率


- (void)openStreamDynamicBitrate:(BOOL)open {
    int max = -1;
    int min = -1;
    switch (_capturerPresetLevel) {
        case UPAVCapturerPreset_480x360:{
            max = 600;
            min = 200;
            break;
        }
        case UPAVCapturerPreset_640x480:{
            max = 720;
            min = 400;
            break;
        }
        case UPAVCapturerPreset_960x540:{
            max = 960;
            min = 500;
            break;
        }
        case UPAVCapturerPreset_1280x720:{
            max = 1440;
            min = 800;
            break;
        }
    }
    [_rtmpStreamer dynamicBitrate:open Max:max * 1000 Min:min * 1000];
}

#pragma mark-- filter 滤镜
- (void)setFilter:(GPUImageOutput<GPUImageInput> *)filter {
    [_upVideoCapture setFilter:filter];
}

- (void)setFilterName:(UPCustomFilter)filterName {
    [_upVideoCapture setFilterName:filterName];
}

- (void)setFilters:(NSArray *)filters {
    [_upVideoCapture setFilters:filters];
}

- (void)setFilterNames:(NSArray *)filterNames {
    [_upVideoCapture setFilterNames:filterNames];
}

#pragma mark UPAVStreamerDelegate

-(void)streamer:(UPAVStreamer *)streamer networkSates:(UPAVStreamerNetworkState)status {
    if (_networkSateBlock) {
        _networkSateBlock(status);
    }
}


- (void)streamer:(UPAVStreamer *)streamer statusDidChange:(UPAVStreamerStatus)status error:(NSError *)error {
    
    switch (status) {
        case UPAVStreamerStatusConnecting: {
            self.pushStreamStatus = UPPushAVStreamStatusConnecting;
        }
            break;
        case UPAVStreamerStatusWriting: {
            self.pushStreamStatus = UPPushAVStreamStatusPushing;
            self.pushStreamReconnectCount = 0;
        }
            break;
        case UPAVStreamerStatusConnected: {
            self.pushStreamStatus = UPPushAVStreamStatusReady;
        }
            break;
        case UPAVStreamerStatusWriteError: {
            _capturerError = error;
            self.pushStreamStatus = UPPushAVStreamStatusError;
        }
            break;
        case UPAVStreamerStatusOpenError: {
            _capturerError = error;
            self.pushStreamStatus = UPPushAVStreamStatusError;
        }
            break;
        case UPAVStreamerStatusClosed: {
            self.pushStreamStatus = UPPushAVStreamStatusClosed;
        }
            break;
            
        case UPAVStreamerStatusIdle: {
        }
            break;
    }
}

#pragma mark UPAudioCaptureProtocol

- (void)didReceiveBuffer:(AudioBuffer)audioBuffer info:(AudioStreamBasicDescription)asbd {
    [self didCaptureAudioBuffer:audioBuffer withInfo:asbd];
    if(!_applicationActive) {
        [self startFrameSendLoopWith:_backGroundFrameSendloopid];
    } else {
        [self stopFrameSendLoop];
    }
}

#pragma mark applicationActiveSwitch

- (void)applicationDidResignActive:(NSNotification *)notification {
    _applicationActive = NO;
    [_upVideoCapture.videoCamera pauseCameraCapture];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    _applicationActive = YES;
    [_upVideoCapture.videoCamera resumeCameraCapture];
}

#pragma mark backgroud push frame loop

- (void)stopFrameSendLoop {
    _backGroundFrameSendloopOn = NO;
    _backGroundFrameSendloopid = _backGroundFrameSendloopid + 1;
}

- (void)startFrameSendLoopWith:(int)loopid {
    if (_backGroundFrameSendloopOn) {
        return;
    }
    _backGroundFrameSendloopOn = YES;
    [self backGroundFrameSendLoopStart:loopid];
}

- (void)backGroundFrameSendLoopStart:(int)loopid {
    if (_backGroundFrameSendloopid != loopid) {
        return;
    }
    double delayInSeconds = 1.0 / _fps;
    __weak UPAVCapturer *weakself = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (_streamingOn) {
            [_rtmpStreamer pushPixelBuffer:_backGroundPixBuffer];
        }
        [weakself backGroundFrameSendLoopStart:loopid];
    });
}

#pragma mark push Capture audio/video buffer

- (void)didCapturePixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!_backGroundPixBuffer) {
        size_t width_o = CVPixelBufferGetWidth(pixelBuffer);
        size_t height_o = CVPixelBufferGetHeight(pixelBuffer);
        OSType format_o = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CVPixelBufferRef pixelBuffer_c;
        CVPixelBufferCreate(nil, width_o, height_o, format_o, nil, &pixelBuffer_c);
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(pixelBuffer_c, 0);
        size_t dataSize_o = CVPixelBufferGetDataSize(pixelBuffer);
        void *target = CVPixelBufferGetBaseAddress(pixelBuffer_c);
        bzero(target, dataSize_o);
        _backGroundPixBuffer = pixelBuffer_c;
    }
    
#ifdef _UPRTCSDK_
    if (self.rtc.channelConnected) {
        // rtc 已经连接视频切换到 rtc 系统
        [[RtcManager sharedInstance] deliverVideoFrame:pixelBuffer];
        return;
    }
#endif
    
    //视频数据压缩入列发送队列
    dispatch_sync(_pushFrameQueue, ^{
        if (_streamingOn) {
            [_rtmpStreamer pushPixelBuffer:pixelBuffer];
        }
        if (pixelBuffer) {
            CFRelease(pixelBuffer);
        }
    });
}

- (void)didCaptureAudioBuffer:(AudioBuffer)audioBuffer withInfo:(AudioStreamBasicDescription)asbd{
    
#ifdef _UPRTCSDK_
    if (self.rtc.channelConnected) {
        // rtc 已经连接音频切换到 rtc 系统
        return;
    }
#endif
    //音频数据压缩入列发送队列
    dispatch_sync(_pushFrameQueue, ^{
        typedef struct AudioBuffer  AudioBuffer;
        if (self.audioMute) {
            if (audioBuffer.mData) {
                memset(audioBuffer.mData, 0, audioBuffer.mDataByteSize);
            }
        }
        
        if (_streamingOn) {
            [_rtmpStreamer pushAudioBuffer:audioBuffer info:asbd];
        }
        
    });
}

- (int)rtcConnect:(NSString *)channelId {
#ifdef _UPRTCSDK_
    if (![self trySetRtcInputVideoSize]) {
        NSLog(@"连麦错误：请检查 appID 及 采集视频尺寸");
        return -2;
    }
    
    [self.rtc stop];
    [self.rtc startWithRtcChannel:channelId];
    CGFloat w = [UIScreen mainScreen].bounds.size.width / 4;
    CGFloat h = [UIScreen mainScreen].bounds.size.height / 4;
    NSLog(@"%f", [UIScreen mainScreen].bounds.size.width);
    NSLog(@"%f", [UIScreen mainScreen].bounds.size.height);
    
    [self.rtc setRemoteViewFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - w - 10, 10, w, h)];
    [self.rtc.remoteView removeFromSuperview];
    [_preview addSubview:self.rtc.remoteView]; //预览视图上添加rtc小窗口
    return 0;
#else
    NSLog(@"连麦需要安装连麦模块：UPRtcSDK.framework");
    return -1;
#endif

    
}

- (void)rtcClose {
#ifdef _UPRTCSDK_
    [self.rtc stop];
    //rtc _audioUnitRecorder
    double delayInSeconds = 1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (self.capturerStatus == UPAVCapturerStatusLiving) {
            [_audioUnitRecorder stop];
            [_audioUnitRecorder start];
        }
    });
    
    [self.rtc.remoteView removeFromSuperview];
#endif
}


#ifdef _UPRTCSDK_

- (BOOL)trySetRtcInputVideoSize{
    int w = _upVideoCapture.capturerPresetLevelFrameCropSize.width;
    int h = _upVideoCapture.capturerPresetLevelFrameCropSize.height;
    return  [self.rtc setInputVideoWidth:w height:h];
}


// rtc 开启，rtc 音视频数据回调接口
-(void)rtc:(RtcManager *)manager didReceiveAudioBuffer:(AudioBuffer)audioBuffer info:(AudioStreamBasicDescription)asbd {
    if (_streamingOn) {
        [_rtmpStreamer pushAudioBuffer:audioBuffer info:asbd];
    }
}

-(void)rtc:(RtcManager *)manager didReceiveVideoBuffer:(CVPixelBufferRef)pixelBuffer {
    dispatch_sync(_pushFrameQueue, ^{
        if (_streamingOn) {
            [_rtmpStreamer pushPixelBuffer:pixelBuffer];
        }
    });
}

#endif


- (void)reconnectTimes {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delayTimer) {
            [_delayTimer invalidate];
            _delayTimer = nil;
        }
        _delayTimer = [NSTimer scheduledTimerWithTimeInterval:_timeSec target:self selector:@selector(afterTimes) userInfo:nil repeats:NO];
    });
}

- (void)afterTimes {
//    NSLog(@"重置 重连次数 %d", _reconnectCount);
    _reconnectCount = 0;
}

#pragma mark upyun token
+ (NSString *)tokenWithKey:(NSString *)key
                    bucket:(NSString *)bucket
                expiration:(int)expiration
           applicationName:(NSString *)appName
                streamName:(NSString *)streamName {
    NSTimeInterval expiration_ = [[NSDate date] timeIntervalSince1970];
    NSString *input = [NSString stringWithFormat:@"%@&%d&/%@/%@", key, (int)expiration_ + expiration, appName, streamName];
    NSString *md5string = [UPAVCapturer md5:input];
    if (md5string.length != 32) {
        return nil;
    }
    NSString *token = [NSString stringWithFormat:@"%@%d", [md5string substringWithRange:NSMakeRange(12, 8)], (int)expiration_ + expiration];
    return token;
}

+ (NSString *)md5:(NSString *)input {
    const char *cStr = [input UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int)strlen(cStr), digest ); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return  output;
}

@end
