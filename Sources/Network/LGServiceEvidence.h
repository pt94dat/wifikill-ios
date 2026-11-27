#import <Foundation/Foundation.h>
#import "LGNetwork.h"
#import "Devices/LGDevice.h"
@interface LGServiceEvidence:NSObject
+ (NSString*)serviceType:(NSString*)record;
+ (NSUInteger)merge:(NSDictionary<NSString*,NSDictionary*>*)evidence into:(NSMutableDictionary<NSString*,LGDevice*>*)devices network:(LGNetwork)network;
@end
