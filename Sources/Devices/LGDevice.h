#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,LGReachability){LGReachabilityUnknown,LGReachabilityCached,LGReachabilityResponded,LGReachabilityHost};
typedef NS_ENUM(NSInteger,LGControlState){LGControlNone,LGControlRestricting,LGControlRestricted,LGControlRestoring,LGControlRestored,LGControlUnverified};
@interface LGDevice:NSObject
@property(nonatomic,copy) NSString *ip,*mac,*name,*hostname,*identityKey,*identitySource,*operationError;
@property(nonatomic) BOOL protectedDevice,systemProtected,favorite,neighborCached,previouslySeen,restrictionKnown,routerRulePresent,desiredRestricted,hasIntent;
@property(nonatomic) LGReachability reachability;
@property(nonatomic) LGControlState control;
@property(nonatomic,strong) NSDate *lastSeen,*ruleCheckedAt;
@property(nonatomic,readonly) BOOL restricted,pending;
@property(nonatomic,readonly) NSString *displayName,*connectivityText,*status;
- (void)applyRulePresence:(BOOL)present;
@end
