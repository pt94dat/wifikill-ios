#import <Foundation/Foundation.h>
@interface LGBonjourInventory : NSObject <NSNetServiceBrowserDelegate,NSNetServiceDelegate>
- (void)collect:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion;
@end
