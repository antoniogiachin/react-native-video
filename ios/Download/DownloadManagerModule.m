//
//  DownloadManagerModule.m
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTBridge.h>

@interface RCT_EXTERN_MODULE(DownloadManagerModule, NSObject)

RCT_EXTERN_METHOD(start:(NSDictionary *)item)
RCT_EXTERN_METHOD(prepare)
RCT_EXTERN_METHOD(resume:(NSDictionary* )item)
RCT_EXTERN_METHOD(pause:(NSDictionary *)item)
RCT_EXTERN_METHOD(delete:(NSDictionary *)item)
//RCT_EXTERN_METHOD(renewDrmLicense:(NSDictionary)item)
RCT_EXTERN_METHOD(setQuality:(NSString *)quality)
RCT_EXTERN_METHOD(getDownloadList:(NSString *)ua
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
