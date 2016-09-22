//
//  UPAudioGraph.h
//  UPLiveSDKDemo
//
//  Created by DING FENG on 9/10/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class UPAudioGraph;
@protocol UPAudioGraphProtocol <NSObject>
- (void)audioGraph:(UPAudioGraph *)audioGraph didOutputBuffer:(AudioBuffer)audioBuffer info:(AudioStreamBasicDescription)asbd;
@end



@interface UPAudioGraph : NSObject
@property (nonatomic, weak) id<UPAudioGraphProtocol> delegate;



- (void)setMixerInputCallbackStruct:(AURenderCallbackStruct)callbackStruct;

- (void)start;
- (void)stop;

- (void)setMixerInputVolume:(UInt32)inputIndex value:(Float32)value;
- (Float32)getMixerInputVolume:(UInt32)inputIndex;
- (void)setMixertOutputVolume:(Float32)value;
- (Float32)getMixertOutputVolume;
- (void)needRenderFramesNum:(UInt32)framesNum;
- (void)needRenderFramesNum:(UInt32)framesNum timeStamp:(AudioTimeStamp *)inTimeStamp flag:(AudioUnitRenderActionFlags *)ioActionFlags;



@end
