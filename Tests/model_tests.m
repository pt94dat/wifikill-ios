#import <Foundation/Foundation.h>
#import "Devices/LGDevice.h"
#include <assert.h>
int main(void){@autoreleasepool{
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
