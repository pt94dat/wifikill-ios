#import <Foundation/Foundation.h>
#import "Devices/LGDevice.h"
@interface LGScanSnapshot:NSObject
+ (NSDictionary*)counts:(NSArray<LGDevice*>*)devices;
+ (NSArray<NSDictionary*>*)history:(NSArray*)records now:(NSTimeInterval)now address:(uint32_t)address mask:(uint32_t)mask;
@end
