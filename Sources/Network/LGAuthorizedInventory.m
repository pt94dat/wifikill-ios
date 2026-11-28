#import "LGAuthorizedInventory.h"
#import "LGIdentity.h"
#import <arpa/inet.h>
@implementation LGAuthorizedInventory
+ (NSArray<LGDevice*>*)mergeRows:(NSArray*)rows devices:(NSArray<LGDevice*>*)devices network:(LGNetwork)network scope:(NSString*)scope now:(NSTimeInterval)now{
 if(![rows isKindOfClass:NSArray.class]||rows.count>2048||!scope.length)return devices;
 NSMutableDictionary *mapping=[NSMutableDictionary new],*valid=[NSMutableDictionary new];NSMutableSet *conflicts=[NSMutableSet new];uint32_t base=network.address&network.netmask;
 for(id raw in rows){if(![raw isKindOfClass:NSDictionary.class])continue;NSString *ip=raw[@"dst"],*mac=raw[@"lladdr"];char normalized[18];struct in_addr address;
  if(![ip isKindOfClass:NSString.class]||inet_pton(AF_INET,ip.UTF8String,&address)!=1||![mac isKindOfClass:NSString.class]||!lg_normalize_mac(mac.UTF8String,normalized))continue;
  uint32_t host=ntohl(address.s_addr);if((host&network.netmask)!=base||host==base||host==(base|~network.netmask))continue;
  id expiry=raw[@"expires_at"];if(expiry&&(![expiry isKindOfClass:NSNumber.class]||[expiry doubleValue]<0||([expiry doubleValue]>0&&[expiry doubleValue]<=now)))continue;
  NSString *canonical=@(normalized);if(mapping[ip]&&![mapping[ip] isEqual:canonical])[conflicts addObject:ip];mapping[ip]=canonical;valid[ip]=raw;
 }
 NSMutableDictionary *found=[NSMutableDictionary new];for(LGDevice *d in devices)found[d.ip]=[d copy];
 for(NSString *ip in valid){if([conflicts containsObject:ip])continue;NSDictionary *row=valid[ip];NSString *mac=mapping[ip];LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;d.identityKey=[NSString stringWithFormat:@"%@:%@",scope,ip];d.systemProtected=[ip isEqual:@(network.ip)]||[ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;found[ip]=d;}
  d.mac=mac;d.macSelfReported=NO;BOOL dhcp=[row[@"source"] isEqual:@"dnsmasq"];d.inventoryAllocationOnly=dhcp;d.identitySource=dhcp?@"Authorized DHCP lease · online state unverified":@"Authenticated gateway neighbor cache";
  [d recordAttribute:@"MAC" value:mac source:d.identitySource confidence:@"Authorized inventory · identity unverified" scope:scope limitations:@"Current inventory snapshot; lease allocation is not proof of online status. Management still requires a current neighbor mapping."];
  NSString *name=row[@"hostname"];if([name isKindOfClass:NSString.class]&&name.length&&name.length<=128&&[name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound){if(!d.hostname.length)d.hostname=name;[d recordAttribute:@"Network name" value:name source:@"Authorized DHCP inventory" confidence:@"Client-supplied name · unverified" scope:scope limitations:@"Lease hostname is not authenticated physical identity"];
  }
 }
 return found.allValues;
}
@end
