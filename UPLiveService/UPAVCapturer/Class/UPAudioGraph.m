//
//  UPAudioGraph.m
//  UPLiveSDKDemo
//
//  Created by DING FENG on 9/10/16.
//  Copyright © 2016 upyun.com. All rights reserved.
//

#import "UPAudioGraph.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <UPLiveSDK/AudioProcessor.h>


//https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/AudioUnitHostingFundamentals/AudioUnitHostingFundamentals.html#//apple_ref/doc/uid/TP40009492-CH3-SW43
#define kAUBus_0    0
#define kAUBus_1    1
#define kAUChannelsNum 1



//static OSStatus mixerCallBack(void *inRefCon,
//                              AudioUnitRenderActionFlags *ioActionFlags,
//                              const AudioTimeStamp * inTimeStamp,
//                              UInt32 inBusNumber,
//                              UInt32 inNumberFrames,
//                              AudioBufferList *ioData) {
//    
////    if ((*ioActionFlags) & kAudioUnitRenderAction_PostRender)
////        return (ExtAudioFileWrite(extAudioFile, inNumberFrames, ioData));
////
//    NSLog(@"mixerCallBack");
//    return noErr;
//}
//

@interface UPAudioGraph()
{
    AUGraph _audioGraph;
    AudioUnit _mixerUnit;//混合器
    AudioUnit _ioUnit;//录音，播放
    AudioUnit _outputUnit;//
    AudioStreamBasicDescription _audioFormat;
    AudioStreamBasicDescription _audioFormat2;
    AURenderCallbackStruct _mixerInputCallbackStruct;
    dispatch_queue_t _audioOutPutQueue;
    BOOL _audioGraphIsRunning;
}

@end


@implementation UPAudioGraph


- (id)init {
    self = [super init];
    if (self) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *error = nil;
        [session setCategory:AVAudioSessionCategoryPlayAndRecord
                 withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker
                       error:&error];
        _audioOutPutQueue = dispatch_queue_create("UPAudioGraph_audioOutPutQueue", DISPATCH_QUEUE_SERIAL);

    }
    return self;
}


- (void)setMixerInputCallbackStruct:(AURenderCallbackStruct)callbackStruct {
    _mixerInputCallbackStruct = callbackStruct;
}

- (void)setMixerInputVolume:(UInt32)inputIndex value:(Float32)value {

}
- (Float32)getMixerInputVolume:(UInt32)inputIndex {

    return 0;
}
- (void)setMixertOutputVolume:(Float32)value {

}
- (Float32)getMixertOutputVolume {
    return 0;
}


- (void)start {
    dispatch_sync(_audioOutPutQueue, ^{
        NSLog (@"_audioGraph will start");
        [self setup];
        OSStatus startStatus = AUGraphStart(_audioGraph);
        NSAssert(startStatus == noErr, @"AUGraphStart _audioGraph failed %d",  (int)startStatus);
        NSLog (@"_audioGraph did start");
        _audioGraphIsRunning = YES;
    });
}

- (void)stop {
    dispatch_sync(_audioOutPutQueue, ^{
        _audioGraphIsRunning = NO;
        NSLog (@"_audioGraph will stop");
        Boolean isRunning = false;
        OSStatus result = AUGraphIsRunning(_audioGraph, &isRunning);
        
        if (result == noErr) {
            isRunning = YES;
        } else {
            return;
            
        }
        if (isRunning) {
            result = AUGraphStop(_audioGraph);
            NSAssert(result == noErr, @"AUGraphStop %d",  (int)result);
        }
        NSLog (@"_audioGraph did stop");
    });

}

- (void)setup {
    //通用格式
    _audioFormat.mSampleRate		= 44100.00;
    _audioFormat.mFormatID			= kAudioFormatLinearPCM;
    _audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _audioFormat.mFramesPerPacket	= 1;
    _audioFormat.mChannelsPerFrame	= kAUChannelsNum;
    _audioFormat.mBitsPerChannel		= 16;
    _audioFormat.mBytesPerPacket		= 2 * kAUChannelsNum;
    _audioFormat.mBytesPerFrame		= 2 * kAUChannelsNum;
    
    _audioFormat2 = _audioFormat;
//    //mixerUnit 的输出只能是双声道
//    _audioFormat2.mSampleRate		= 44100.00;
//    _audioFormat2.mFormatID			= kAudioFormatLinearPCM;
//    _audioFormat2.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//    _audioFormat2.mFramesPerPacket	= 1;
//    _audioFormat2.mChannelsPerFrame	= 2;
//    _audioFormat2.mBitsPerChannel		= 16;
//    _audioFormat2.mBytesPerPacket		= 2 * 2;
//    _audioFormat2.mBytesPerFrame		= 2 * 2;
//

    OSStatus setupStatus;
    
    //创建和打开 _audioGraph
    setupStatus = NewAUGraph(&_audioGraph);
    NSAssert(setupStatus == noErr, @"NewAUGraph failed %d",  (int)setupStatus);
    
    AUNode ioNode;
    AUNode mixerNode;
    AUNode outputNode;
    
    AudioComponentDescription ioUnitDescription;
    AudioComponentDescription mixerUnitDescription;
    AudioComponentDescription outputUnitDescription;

    int ioNodeFlag = 0;
    int mixerNodeFlag = 0;
    int outputNodeFlag = 0;

    
    
//    //创建 ioNode，获取_ioUnit 用于麦克风录音（或者扬声器播放）
//    bzero(&ioUnitDescription, sizeof(AudioComponentDescription));
//    ioUnitDescription.componentType = kAudioUnitType_Output;
//    ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
//    ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
//    ioUnitDescription.componentFlags = 0;
//    ioUnitDescription.componentFlagsMask = 0;
//    setupStatus = AUGraphAddNode(_audioGraph, &ioUnitDescription, &ioNode);
//    ioNodeFlag = 1;
//    NSAssert(setupStatus == noErr, @"AUGraphAddNode ioNode failed %d",  (int)setupStatus);
    
    //创建 mixerNode，获取_mixerUnit 用于混音
    mixerUnitDescription.componentType= kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags = 0;
    mixerUnitDescription.componentFlagsMask = 0;
    mixerNodeFlag = 1;
    setupStatus = AUGraphAddNode(_audioGraph, &mixerUnitDescription, &mixerNode);
    NSAssert(setupStatus == noErr, @"AUGraphAddNode mixerNode failed %d",  (int)setupStatus);
    
    //创建 outputNode
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_GenericOutput;
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputNodeFlag = 1;
    setupStatus = AUGraphAddNode(_audioGraph, &outputUnitDescription, &outputNode);
    NSAssert(setupStatus == noErr, @"AUGraphAddNode outputNode failed %d",  (int)setupStatus);
    
    
    
    setupStatus = AUGraphConnectNodeInput(_audioGraph, mixerNode, 0, outputNode, 0);
    NSAssert(setupStatus == noErr, @"AUGraphConnectNodeInput ioNode-mixerNode failed %d",  (int)setupStatus);

    setupStatus = AUGraphOpen(_audioGraph);
    NSAssert(setupStatus == noErr, @"AUGraphOpen failed %d",  (int)setupStatus);
    
    if (mixerNodeFlag) {
        setupStatus = AUGraphNodeInfo(_audioGraph, mixerNode, &mixerUnitDescription, &_mixerUnit);
        NSAssert(setupStatus == noErr, @"AUGraphNodeInfo get mixerUnit failed %d",  (int)setupStatus);
    }
    
    if (ioNodeFlag) {
        setupStatus = AUGraphNodeInfo(_audioGraph, ioNode, &ioUnitDescription, &_ioUnit);
        NSAssert(setupStatus == noErr, @"AUGraphNodeInfo get ioUnit failed %d",  (int)setupStatus);
    }

    if (outputNodeFlag) {
        setupStatus = AUGraphNodeInfo(_audioGraph, outputNode, &outputUnitDescription, &_outputUnit);
        NSAssert(setupStatus == noErr, @"AUGraphNodeInfo get ioUnit failed %d",  (int)setupStatus);
        
        
    }
    
    
    if (_mixerUnit) {
        //为 mixerNode 设置两条输入通道
        UInt32 numbuses = 2;
        setupStatus = AudioUnitSetProperty(_mixerUnit,
                                           kAudioUnitProperty_ElementCount,
                                           kAudioUnitScope_Input,
                                           0,
                                           &numbuses,
                                           sizeof(numbuses));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_ElementCount _mixerUnit set numbuses failed %d",  (int)setupStatus);
        
        setupStatus = AudioUnitSetProperty(_mixerUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Input,
                                           kAUBus_1,
                                           &_audioFormat,
                                           sizeof(_audioFormat));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat _mixerUnit kAudioUnitScope_Input kAUBus_1 failed %d",  (int)setupStatus);
        
        setupStatus = AudioUnitSetProperty(_mixerUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Input,
                                           kAUBus_0,
                                           &_audioFormat,
                                           sizeof(_audioFormat));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat _mixerUnit kAudioUnitScope_Input kAUBus_0 failed %d",  (int)setupStatus);
        
        setupStatus = AudioUnitSetProperty(_mixerUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output,
                                           kAUBus_0,
                                           &_audioFormat2,
                                           sizeof(_audioFormat2));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat kAudioUnitScope_Output _mixerUnit  kAUBus_0 failed %d",  (int)setupStatus);
        
        
        // 混音器的输入回调
        AURenderCallbackStruct mixerInputCallbackStruct;
        mixerInputCallbackStruct = _mixerInputCallbackStruct;
        setupStatus = AUGraphSetNodeInputCallback(_audioGraph, mixerNode, 0, &mixerInputCallbackStruct);
        setupStatus = AUGraphSetNodeInputCallback(_audioGraph, mixerNode, 1, &mixerInputCallbackStruct);
        NSAssert(setupStatus == noErr, @"AUGraphSetNodeInputCallback _mixerUnit  failed %d",  (int)setupStatus);
    }
    
    
    if (_outputUnit) {
        setupStatus = AudioUnitSetProperty(_outputUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Input,
                                           kAUBus_0,
                                           &_audioFormat2,
                                           sizeof(_audioFormat2));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat _outputUnit kAudioUnitScope_Input kAUBus_0 failed %d",  (int)setupStatus);
        
        
        setupStatus = AudioUnitSetProperty(_outputUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output,
                                           kAUBus_0,
                                           &_audioFormat,
                                           sizeof(_audioFormat));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat  _outputUnit kAudioUnitScope_Output  kAUBus_0 failed %d",  (int)setupStatus);
        
    }

    
    if (_ioUnit) {
        //录音和播放功能 开关
        UInt32 flag_recording = 1;
        UInt32 flag_playback = 1;
        //设置麦克风启动
        setupStatus = AudioUnitSetProperty(_ioUnit,
                                           kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Input,
                                           kAUBus_1,
                                           &flag_recording,
                                           sizeof(flag_recording));
        NSAssert(setupStatus == noErr, @"kAudioOutputUnitProperty_EnableIO _ioUnit  kAUBus_1 failed %d",  (int)setupStatus);
        
        
        //设置扬声器启动
        setupStatus = AudioUnitSetProperty(_ioUnit,
                                           kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output,
                                           kAUBus_0,
                                           &flag_playback,
                                           sizeof(flag_playback));
        NSAssert(setupStatus == noErr, @"kAudioOutputUnitProperty_EnableIO _ioUnit  kAUBus_0 failed %d",  (int)setupStatus);
        
        
        setupStatus = AudioUnitSetProperty(_ioUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output,
                                           kAUBus_1,
                                           &_audioFormat,
                                           sizeof(_audioFormat));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat _ioUnit  kAUBus_1 failed %d",  (int)setupStatus);
        
        
        setupStatus = AudioUnitSetProperty(_ioUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Input,
                                           kAUBus_0,
                                           &_audioFormat,
                                           sizeof(_audioFormat));
        NSAssert(setupStatus == noErr, @"kAudioUnitProperty_StreamFormat _ioUnit  kAUBus_0 failed %d",  (int)setupStatus);
    }
    
    setupStatus = AUGraphInitialize(_audioGraph);
    NSAssert(setupStatus == noErr, @"AUGraphInitialize _audioGraph  failed %d",  (int)setupStatus);
    CAShow(_audioGraph);
}

- (void)needRenderFramesNum:(UInt32)framesNum
                  timeStamp:(AudioTimeStamp *)inTimeStamp
                       flag:(AudioUnitRenderActionFlags *)ioActionFlags {

    dispatch_async(_audioOutPutQueue, ^{
        if (!_audioGraphIsRunning) {
            return ;
        }
        AudioBuffer buffer;
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = framesNum * 2 * 1;
        buffer.mData = malloc( framesNum * 2 * 1);
        
        // Put buffer in a AudioBufferList
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0] = buffer;
        
        OSStatus error = AudioUnitRender(_outputUnit,
                                         ioActionFlags,
                                         inTimeStamp,
                                         0,
                                         framesNum,
                                         &bufferList);
        
        NSAssert(error == noErr, @"UPAudioGraph AudioUnitRender failed %d",  (int)error);
        if (self.delegate) {
            [self.delegate audioGraph:self didOutputBuffer:buffer info:_audioFormat];
        }
        free(buffer.mData);
    });
}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
}

@end
