Pod::Spec.new do |s|
s.name = 'UPLiveSDK'
s.version = '2.6'
s.license = 'MIT'
s.summary = 'UPLive SDK For iOS. 杭州又拍云科技有限公司'
s.homepage = 'https://github.com/linKnowEasy/UPLiveSDK'
s.authors = { 'UPYUN' => 'iOSTeam@upyun.com' }
s.source = { :git => 'https://github.com/linKnowEasy/UPLiveSDK.git', :tag => "v2.6" }
s.requires_arc = true
s.ios.deployment_target = '8.0'
# s.source_files = ['UPLiveService/**/*.{h,m}', 'UpYunSDK/Utils/**/*.{h,m}']
s.resources = [ 'UPLiveService/UPAVCapturer/Class/*.{jpg,png,xib}', 'UPLiveService/UPAVCapturer/ImageProcessor/**/**/*.{jpg,png,xib}']

s.source_files = ['UPLiveService/**/*.{h,m}', 'UPLiveService/**/**/*.{h,m}', 'UPLiveService/**/**/**/*.{h,m}', 'UPLiveService/**/**/**/**/*.{h,m}']
s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-read_only_relocs suppress' }
s.frameworks = 'AVFoundation', 'QuartzCore', 'OpenGLES', 'AudioToolbox', 'VideoToolbox', 'Accelerate'
s.libraries  = 'bz2.1.0', 'iconv', 'z'
s.vendored_frameworks = 'UPLiveService/UPLiveSDK.framework'
#s.dependency 'GPUImage'

end