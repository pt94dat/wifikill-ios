#import "LGDevice.h"
@implementation LGDevice
- (id)copyWithZone:(NSZone*)zone{(void)zone;LGDevice *d=[LGDevice new];NSArray *keys=@[@"ip",@"mac",@"name",@"hostname",@"identityKey",@"identitySource",@"operationError",@"bonjourName",@"serviceEvidence",@"typeHint",@"dnsOutcome",@"identityEvidence",@"reachability",@"probeEvidence",@"latencyMS",@"systemProtected",@"protectedDevice",@"favorite",@"neighborCached",@"previouslySeen",@"macSelfReported",@"control",@"restrictionKnown",@"routerRulePresent",@"lastSeen",@"ruleCheckedAt",@"desiredRestricted",@"hasIntent"];[d setValuesForKeysWithDictionary:[self dictionaryWithValuesForKeys:keys]];return d;}
- (void)recordAttribute:(NSString*)attribute value:(NSString*)value source:(NSString*)source confidence:(NSString*)confidence scope:(NSString*)scope limitations:(NSString*)limitations{
 if(!attribute.length||value.length>512||!source.length||!scope.length)return;
 NSMutableArray *records=[NSMutableArray new];for(NSDictionary *old in self.identityEvidence)if(!([old[@"attribute"] isEqual:attribute]&&[old[@"source"] isEqual:source]))[records addObject:old];
 if(!value.length){self.identityEvidence=records.copy;return;}
 if(records.count>=64)[records removeObjectAtIndex:0];
 [records addObject:@{@"attribute":attribute,@"value":value,@"source":source,@"confidence":confidence?:@"Unverified",@"observedAt":@(NSDate.date.timeIntervalSince1970),@"validity":@"Current snapshot; recheck on next scan",@"networkScope":scope,@"limitations":limitations?:@"Not an authenticated physical identity"}];self.identityEvidence=records.copy;
}
- (void)scopeIdentityToNetwork:(NSString*)network{if(!network.length)return;NSMutableArray *records=[NSMutableArray new];for(NSDictionary *old in self.identityEvidence){NSMutableDictionary *row=[old mutableCopy];row[@"networkScope"]=network;[records addObject:row.copy];}self.identityEvidence=records.copy;}
- (NSString*)identityConfidence{if(self.reachability==LGReachabilityHost)return @"Confirmed local interface";if(self.name.length&&!self.systemProtected)return @"User-defined label";if(self.bonjourName.length||self.hostname.length||self.mac.length)return @"Reported by network · unverified";return @"Unknown";}

- (instancetype)init{if((self=[super init])){_identityEvidence=@[];_ip=@"";_mac=@"";_name=@"";_hostname=@"";_identityKey=@"";_identitySource=@"Unavailable";_operationError=@"";_bonjourName=@"";_serviceEvidence=@"";_typeHint=@"Device type unknown";_dnsOutcome=@"Not attempted";}return self;}
- (BOOL)restricted{return self.restrictionKnown&&self.routerRulePresent;}
- (BOOL)pending{return self.control==LGControlRestricting||self.control==LGControlRestoring;}
- (NSString*)displayName{return self.name.length?self.name:(self.bonjourName.length?self.bonjourName:(self.hostname.length?self.hostname:self.ip));}
- (NSString*)connectivityText{if(self.reachability==LGReachabilityUnknown&&self.serviceEvidence.length)return @"Service advertised · TCP unverified";switch(self.reachability){case LGReachabilityHost:return @"This iPhone";case LGReachabilityResponded:return @"TCP response observed";case LGReachabilityCached:return @"Cached · reachability unknown";default:return self.previouslySeen?@"Previously seen · not verified now":@"Reachability unknown";}}
- (NSString*)controlText{switch(self.control){case LGControlRestricting:return @"Requesting restriction…";case LGControlRestricted:return self.restrictionKnown?@"Router rule confirmed · Internet unverified":@"Previous restriction · status unknown";case LGControlRestoring:return @"Requesting restoration…";case LGControlRestored:return self.restrictionKnown?@"Router rule removed · Internet unverified":@"Restoration unverified";case LGControlUnverified:return @"Operation unverified · see details";default:return @"No management operation requested";}}
- (NSString*)status{return self.control==LGControlNone?self.connectivityText:self.controlText;}
- (void)applyRulePresence:(BOOL)present{
 BOOL previous=self.routerRulePresent;self.restrictionKnown=self.mac.length>0;self.ruleCheckedAt=NSDate.date;self.routerRulePresent=present&&self.mac.length>0;
 if(self.hasIntent){if(self.routerRulePresent==self.desiredRestricted){self.control=self.routerRulePresent?LGControlRestricted:LGControlRestored;self.hasIntent=NO;self.operationError=@"Router readback matched the request. Internet access is unverified.";}else{self.control=LGControlUnverified;self.operationError=self.desiredRestricted?@"Router readback: requested restriction is absent":@"Router readback: rule remains; restoration is unverified";}}
 else if(self.routerRulePresent)self.control=LGControlRestricted;else if(previous)self.control=LGControlRestored;
}
@end
