#import "LGDevice.h"
@implementation LGDevice
- (instancetype)init{if((self=[super init])){_ip=@"";_mac=@"";_name=@"";_hostname=@"";_identityKey=@"";_identitySource=@"Unavailable";_operationError=@"";_bonjourName=@"";_serviceEvidence=@"";_typeHint=@"Device type unknown";_dnsOutcome=@"Not attempted";}return self;}
- (BOOL)restricted{return self.restrictionKnown&&self.routerRulePresent;}
- (BOOL)pending{return self.control==LGControlRestricting||self.control==LGControlRestoring;}
- (NSString*)displayName{return self.name.length?self.name:(self.bonjourName.length?self.bonjourName:(self.hostname.length?self.hostname:self.ip));}
- (NSString*)connectivityText{switch(self.reachability){case LGReachabilityHost:return @"This iPhone";case LGReachabilityResponded:return @"TCP response observed";case LGReachabilityCached:return @"Cached · reachability unknown";default:return self.previouslySeen?@"Previously seen · not verified now":@"Reachability unknown";}}
- (NSString*)controlText{switch(self.control){case LGControlRestricting:return @"Requesting restriction…";case LGControlRestricted:return self.restrictionKnown?@"Router rule confirmed · Internet unverified":@"Previous restriction · status unknown";case LGControlRestoring:return @"Requesting restoration…";case LGControlRestored:return self.restrictionKnown?@"Router rule removed · Internet unverified":@"Restoration unverified";case LGControlUnverified:return @"Operation unverified · see details";default:return @"No management operation requested";}}
- (NSString*)status{return self.control==LGControlNone?self.connectivityText:self.controlText;}
- (void)applyRulePresence:(BOOL)present{
 BOOL previous=self.routerRulePresent;self.restrictionKnown=self.mac.length>0;self.ruleCheckedAt=NSDate.date;self.routerRulePresent=present&&self.mac.length>0;
 if(self.hasIntent){if(self.routerRulePresent==self.desiredRestricted){self.control=self.routerRulePresent?LGControlRestricted:LGControlRestored;self.hasIntent=NO;self.operationError=@"Router readback matched the request. Internet access is unverified.";}else{self.control=LGControlUnverified;self.operationError=self.desiredRestricted?@"Router readback: requested restriction is absent":@"Router readback: rule remains; restoration is unverified";}}
 else if(self.routerRulePresent)self.control=LGControlRestricted;else if(previous)self.control=LGControlRestored;
}
@end
