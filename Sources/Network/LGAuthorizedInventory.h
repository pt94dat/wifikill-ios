#import <Foundation/Foundation.h>
#import "Devices/LGDevice.h"
#import "LGNetwork.h"
@interface LGAuthorizedInventory:NSObject
/* Call only after authenticated, explicitly enrolled gateway response. */
+ (NSArray<LGDevice*>*)mergeRows:(NSArray*)rows devices:(NSArray<LGDevice*>*)devices network:(LGNetwork)network scope:(NSString*)scope now:(NSTimeInterval)now;
@end
