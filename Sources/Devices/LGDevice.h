#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,LGReachability){LGReachabilityUnknown,LGReachabilityCached,LGReachabilityResponded,LGReachabilityHost};
typedef NS_ENUM(NSInteger,LGControlState){LGControlNone,LGControlRestricting,LGControlRestricted,LGControlRestoring,LGControlRestored,LGControlUnverified};
@interface LGDevice:NSObject<NSCopying>
@property(nonatomic,copy) NSString *ip,*mac,*name,*hostname,*identityKey,*identitySource,*operationError,*bonjourName,*serviceEvidence,*typeHint,*dnsOutcome;
@property(nonatomic,readonly) NSString *identityConfidence;
@property(nonatomic,copy) NSArray<NSDictionary*> *identityEvidence;
- (void)recordAttribute:(NSString*)attribute value:(NSString*)value source:(NSString*)source confidence:(NSString*)confidence scope:(NSString*)scope limitations:(NSString*)limitations;
- (void)scopeIdentityToNetwork:(NSString*)network;
@property(nonatomic) BOOL protectedDevice,systemProtected,favorite,neighborCached,previouslySeen,restrictionKnown,routerRulePresent,desiredRestricted,hasIntent,macSelfReported;
@property(nonatomic) LGReachability reachability;
@property(nonatomic) NSInteger probeEvidence;
@property(nonatomic) double latencyMS;
@property(nonatomic) LGControlState control;
@property(nonatomic,strong) NSDate *lastSeen,*ruleCheckedAt;
@property(nonatomic,readonly) BOOL restricted,pending;
@property(nonatomic,readonly) NSString *displayName,*connectivityText,*status,*controlText;
- (void)applyRulePresence:(BOOL)present;
@end
