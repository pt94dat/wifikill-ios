#import <Foundation/Foundation.h>
#import "LGNetwork.h"
#import "Devices/LGDevice.h"
@interface LGScanner : NSObject
@property(atomic) NSUInteger generation;
- (void)cancel;
- (void)scan:(void(^)(NSArray<LGDevice*> *, NSString *))completion;
@end
