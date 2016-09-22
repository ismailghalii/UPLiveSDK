//
//  UPAVPlayer.h
//  UPAVPlayerDemo
//
//  Created by DING FENG on 2/16/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "UPLiveSDKConfig.h"



typedef NS_ENUM(NSInteger, UPAVPlayerStatus) {
    UPAVPlayerStatusIdle,
    UPAVPlayerStatusPlaying_buffering,
    UPAVPlayerStatusPlaying,
    UPAVPlayerStatusPause,
    UPAVPlayerStatusFailed
};

typedef NS_ENUM(NSInteger, UPAVStreamStatus) {
    UPAVStreamStatusIdle,
    UPAVStreamStatusConnecting,
    UPAVStreamStatusReady,
};

typedef void(^PlayerStadusBlock)(UPAVPlayerStatus playerStatus, NSError *error);
typedef void(^BufferingProgressBlock)(float progress);
typedef void(^AudioBufferListReleaseBlock)(AudioBufferList *audioBufferListe);



@interface UPAVPlayerStreamInfo : NSObject
@property (nonatomic) float duration;
@property (nonatomic) BOOL canPause;
@property (nonatomic) BOOL canSeek;
@property (nonatomic, strong) NSDictionary *descriptionInfo;
@end

@interface UPAVPlayerDashboard: NSObject
@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *serverIp;
@property (nonatomic, readonly) NSString *serverName;
@property (nonatomic, readonly) int cid;
@property (nonatomic, readonly) int pid;
@property (nonatomic, readonly) float fps;
@property (nonatomic, readonly) float bps;
@property (nonatomic, readonly) int vCachedFrames;
@property (nonatomic, readonly) int aCachedFrames;

@property (readonly, nonatomic) int decodedVFrameNum;//解码的视频包数量
@property (readonly, nonatomic) int decodedVKeyFrameNum;//解码的关键帧
@property (readonly, nonatomic) int decodedAFrameNum;//解码的音频包数量

@end


@class UPAVPlayer;

@protocol UPAVPlayerDelegate <NSObject>
//播放器状态
- (void)UPAVPlayer:(UPAVPlayer *)player playerStatusDidChange:(UPAVPlayerStatus)playerStatus;
- (void)UPAVPlayer:(UPAVPlayer *)player playerError:(NSError *)error;
- (void)UPAVPlayer:(UPAVPlayer *)player displayPositionDidChange:(float)position;
- (void)UPAVPlayer:(UPAVPlayer *)player bufferingProgressDidChange:(float)progress;

//视频流状态
- (void)UPAVPlayer:(UPAVPlayer *)player streamStatusDidChange:(UPAVStreamStatus)streamStatus;
- (void)UPAVPlayer:(UPAVPlayer *)player streamInfoDidReceive:(UPAVPlayerStreamInfo *)streamInfo;



/*
 播放音频数据的回调.
 用途如：读取并播放音频文件，同时将音频数据送入混音器来当作背景音乐。
 */
- (void)UPAVPlayer:(UPAVPlayer *)audioManager
      willRenderBuffer:(AudioBufferList *)audioBufferList
             timeStamp:(const AudioTimeStamp *)inTimeStamp
                frames:(UInt32)inNumberFrames
              info:(AudioStreamBasicDescription)asbd
             block:(AudioBufferListReleaseBlock)release;

@end



@interface UPAVPlayer : NSObject

@property (nonatomic, strong, readonly) UIView *playView;
@property (nonatomic, strong, readonly) UPAVPlayerDashboard *dashboard;
@property (nonatomic, strong, readonly) UPAVPlayerStreamInfo *streamInfo;
@property (nonatomic, assign, readonly) UPAVPlayerStatus playerStatus;
@property (nonatomic, assign, readonly) UPAVStreamStatus streamStatus;

@property (nonatomic, assign) NSTimeInterval bufferingTime;//(0.1s -- 10s)
@property (nonatomic, assign) CGFloat volume;
@property (nonatomic, assign) CGFloat bright;
@property (nonatomic, assign) BOOL mute;
@property (nonatomic, assign) NSUInteger bitrateLevel;
@property (nonatomic, assign) NSTimeInterval bufferingTimeOutLimit;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign, readonly) float displayPosition;//视频播放到的时间点
@property (nonatomic, assign, readonly) float streamPosition;//视频流读取到的时间点
@property (nonatomic, weak) id<UPAVPlayerDelegate> delegate;
@property (nonatomic) BOOL lipSynchOn;//音画同步，默认值 YES


- (instancetype)initWithURL:(NSString *)url;
- (void)setFrame:(CGRect)frame;
- (void)connect;
- (void)play;
- (void)pause;
- (void)stop;
- (void)seekToTime:(CGFloat)position;

@end
