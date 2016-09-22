//
//  GPUImageBeautifyFilter.h
//  UPLiveSDKDemo
//
//  Created by 林港 on 16/8/17.
//  Copyright © 2016年 upyun.com. All rights reserved.
//

//
//  GPUImageBeautifyFilter.h
//  BeautifyFaceDemo
//
//  Created by guikz on 16/4/28.
//  Copyright © 2016年 guikz. All rights reserved.
//

#import "GPUImage.h"

@class GPUImageCombinationFilter;
@class GPUImageSobelEdgeDetectionFilter;

@interface GPUImageBeautifyFilter : GPUImageFilterGroup {
    GPUImageBilateralFilter *bilateralFilter;
//    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
    /// 修改参考 http://www.jianshu.com/p/dde412cab8db
    GPUImageSobelEdgeDetectionFilter *sobelEdgeFilter;
    GPUImageCombinationFilter *combinationFilter;
    GPUImageHSBFilter *hsbFilter;
}

@property (nonatomic, assign)CGFloat level;
//- (void)setLevel:(CGFloat)level;

/// 磨皮等级调整
@property (nonatomic, assign)CGFloat bilateralLevel;

/// 边缘检测调整
@property (nonatomic, assign)CGFloat cannyEdgeLevel;

/// 饱和度调整
@property (nonatomic, assign)CGFloat saturationLevel;

/// 亮度调整
@property (nonatomic, assign)CGFloat brightnessLevel;
@end
