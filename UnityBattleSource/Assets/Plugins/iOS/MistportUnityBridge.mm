#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

extern "C" void UnitySetExecuteMachHeader(const struct mach_header_64 *header);

extern "C" __attribute__((visibility("default"))) void MistportConfigureUnityExecuteHeader()
{
    const struct mach_header *mainHeader = _dyld_get_image_header(0);
    UnitySetExecuteMachHeader(reinterpret_cast<const struct mach_header_64 *>(mainHeader));
}

extern "C" void MistportUnityBattleEvent(const char *json)
{
    if (json == nullptr) {
        return;
    }

    NSString *payload = [NSString stringWithUTF8String:json];
    if (payload == nil) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"MistportUnityBattleEvent"
                          object:nil
                        userInfo:@{@"json": payload}];
    });
}
