#import <Foundation/Foundation.h>
@interface LGBonjourInventory : NSObject <NSNetServiceBrowserDelegate,NSNetServiceDelegate>
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (void)collect:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion;
- (void)collectWithWindowMS:(NSUInteger)window completion:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion;
- (void)cancel;
@end
