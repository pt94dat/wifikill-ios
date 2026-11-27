#import <Foundation/Foundation.h>
#import "LGNetworkContext.h"
#import "Devices/LGDevice.h"
@interface LGScanner:NSObject
@property(atomic) NSUInteger generation;
@property(nonatomic,strong) NSDictionary *metrics;
@property(nonatomic,strong) LGNetworkContext *context;
- (void)cancel;
- (void)scan:(void(^)(NSArray<LGDevice*>*,NSString*))completion;
@end
