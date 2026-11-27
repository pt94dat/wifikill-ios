#import <Foundation/Foundation.h>
#import "LGNetworkContext.h"
#import "LGBonjourInventory.h"
#import "Devices/LGDevice.h"
@interface LGScanner:NSObject
@property(atomic) NSUInteger generation;
@property(nonatomic,strong) NSDictionary *metrics;
@property(nonatomic,strong) LGNetworkContext *context;
@property(nonatomic,strong) NSDictionary *diagnostics;
@property(atomic,strong) NSOperationQueue *workQueue;
@property(nonatomic,strong) LGBonjourInventory *bonjour;
@property(nonatomic,strong) dispatch_queue_t engineQueue;
- (void)cancel;
- (void)scan:(void(^)(NSArray<LGDevice*>*,NSString*))completion;
@end
