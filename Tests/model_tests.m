#import <Foundation/Foundation.h>
#import "Devices/LGDevice.h"
#include <assert.h>
int main(void){@autoreleasepool{
 LGDevice *evidenceDevice=[LGDevice new];[evidenceDevice recordAttribute:@"MAC" value:@"02:11:22:33:44:55" source:@"Owned fixture" confidence:@"Reported" scope:@"network-A" limitations:@"Private address; not a manufacturer"];
 assert(evidenceDevice.identityEvidence.count==1);NSDictionary *observation=evidenceDevice.identityEvidence[0];for(NSString *key in @[@"attribute",@"value",@"source",@"confidence",@"observedAt",@"validity",@"networkScope",@"limitations"])assert(observation[key]);
 LGDevice *evidenceCopy=[evidenceDevice copy];[evidenceDevice recordAttribute:@"MAC" value:@"06:11:22:33:44:55" source:@"Owned fixture" confidence:@"Reported" scope:@"network-A" limitations:@"Unverified"];
 assert(evidenceDevice.identityEvidence.count==1&&[evidenceCopy.identityEvidence[0][@"value"] isEqual:@"02:11:22:33:44:55"]);[evidenceDevice scopeIdentityToNetwork:@"network-B"];assert([evidenceDevice.identityEvidence[0][@"networkScope"] isEqual:@"network-B"]);[evidenceDevice recordAttribute:@"MAC" value:@"" source:@"Owned fixture" confidence:@"Reported" scope:@"network-B" limitations:@""];assert(!evidenceDevice.identityEvidence.count);

 LGDevice *d=[LGDevice new];d.ip=@"192.0.2.10";assert([d.displayName isEqual:d.ip]);assert(!d.restricted&&!d.restrictionKnown);assert([d.controlText isEqual:@"No management operation requested"]);assert(![d.controlText containsString:@"TCP"]);
 d.bonjourName=@"Bonjour device";assert([d.displayName isEqual:@"Bonjour device"]);d.bonjourName=@"";d.hostname=@"client.local";assert([d.displayName isEqual:@"client.local"]);d.name=@"My device";assert([d.displayName isEqual:@"My device"]);
 d.mac=@"02:00:00:00:00:01";d.hasIntent=YES;d.desiredRestricted=YES;[d applyRulePresence:NO];assert(d.control==LGControlUnverified&&d.hasIntent&&!d.restricted);
 [d applyRulePresence:YES];assert(d.control==LGControlRestricted&&!d.hasIntent&&d.restricted);
 d.hasIntent=YES;d.desiredRestricted=NO;[d applyRulePresence:YES];assert(d.control==LGControlUnverified&&d.restricted&&d.hasIntent);
 [d applyRulePresence:NO];assert(d.control==LGControlRestored&&!d.restricted&&!d.hasIntent);
 d.control=LGControlRestricting;assert(d.pending);d.control=LGControlRestoring;assert(d.pending);
 d.reachability=LGReachabilityCached;assert([d.connectivityText containsString:@"unknown"]);d.reachability=LGReachabilityUnknown;d.previouslySeen=YES;assert([d.connectivityText containsString:@"not verified now"]);
 puts("Native device-state regression assertions passed");
}return 0;}
