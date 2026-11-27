#import <Foundation/Foundation.h>
@interface LGDevice : NSObject
@property(nonatomic,copy) NSString *ip,*mac,*name,*status;
@property(nonatomic) BOOL protectedDevice, favorite, restricted;
@property(nonatomic,strong) NSDate *lastSeen;
@end
