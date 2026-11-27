#import <Foundation/Foundation.h>
@interface LGStore : NSObject
+ (NSString*)token;
+ (BOOL)setToken:(NSString*)token;
+ (void)record:(NSString*)event;
+ (NSArray*)history;
@end
