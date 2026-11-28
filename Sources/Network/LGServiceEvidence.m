#import "LGServiceEvidence.h"
#import <arpa/inet.h>
@implementation LGServiceEvidence
+ (NSDictionary*)mergeObservation:(NSDictionary*)row previous:(NSDictionary*)previous{
 if(![row[@"name"] isKindOfClass:NSString.class]||![row[@"service"] isKindOfClass:NSString.class]||![self serviceType:row[@"service"]]||![row[@"name"] length]||[row[@"name"] length]>128)return previous;
 NSMutableArray *observations=[NSMutableArray new];if([previous[@"observations"] isKindOfClass:NSArray.class])[observations addObjectsFromArray:previous[@"observations"]];else if(previous[@"name"])[observations addObject:previous];
 BOOL duplicate=NO;for(NSDictionary *old in observations)if([old[@"name"] isEqual:row[@"name"]]&&[old[@"service"] isEqual:row[@"service"]])duplicate=YES;
 if(!duplicate&&observations.count<64)[observations addObject:row];
 [observations sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){BOOL knownA=[a[@"typeHint"] length]&&![a[@"typeHint"] isEqual:@"Device type unknown"],knownB=[b[@"typeHint"] length]&&![b[@"typeHint"] isEqual:@"Device type unknown"];if(knownA!=knownB)return knownA?NSOrderedAscending:NSOrderedDescending;NSComparisonResult type=[a[@"service"] compare:b[@"service"]];return type==NSOrderedSame?[a[@"name"] compare:b[@"name"]]:type;}];
 NSMutableDictionary *result=[observations.firstObject mutableCopy];result[@"observations"]=observations.copy;return result.copy;
}
+ (NSDictionary*)removeName:(NSString*)name type:(NSString*)type previous:(NSDictionary*)previous{
 NSDictionary *result=nil;for(NSDictionary *row in previous[@"observations"])if(!([row[@"name"] isEqual:name]&&[row[@"service"] isEqual:type]))result=[self mergeObservation:row previous:result];return result;
}

+ (NSString*)serviceType:(NSString*)record{
 record=record.lowercaseString;if([record hasSuffix:@"."])record=[record substringToIndex:record.length-1];
 if([record hasSuffix:@".local"]){record=[record substringToIndex:record.length-6];}if(![record hasSuffix:@"."])record=[record stringByAppendingString:@"."];
 static NSRegularExpression *pattern;static dispatch_once_t once;dispatch_once(&once,^{pattern=[NSRegularExpression regularExpressionWithPattern:@"^_[A-Za-z0-9-]{1,63}\\._(tcp|udp)\\.$" options:0 error:nil];});
 return record.length<80&&[pattern numberOfMatchesInString:record options:0 range:NSMakeRange(0,record.length)]==1?record:nil;
}
+ (NSUInteger)merge:(NSDictionary<NSString*,NSDictionary*>*)evidence into:(NSMutableDictionary<NSString*,LGDevice*>*)devices network:(LGNetwork)network{
 NSUInteger matched=0;uint32_t base=network.address&network.netmask;
 for(NSString *ip in evidence){struct in_addr address;if(inet_pton(AF_INET,ip.UTF8String,&address)!=1)continue;uint32_t host=ntohl(address.s_addr);if((host&network.netmask)!=base||host==base||host==(base|~network.netmask))continue;
  NSDictionary *row=evidence[ip];if(![row isKindOfClass:NSDictionary.class]||![row[@"name"] isKindOfClass:NSString.class]||![row[@"service"] isKindOfClass:NSString.class]||![self serviceType:row[@"service"]])continue;
  NSString *name=row[@"name"];if(!name.length||name.length>128)continue;LGDevice *d=devices[ip];if(!d){d=[LGDevice new];d.ip=ip;d.reachability=LGReachabilityUnknown;d.systemProtected=host==network.address||[ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;devices[ip]=d;}
  NSString *scope=[NSString stringWithFormat:@"IPv4 subnet %08x/%08x",base,network.netmask];[d recordAttribute:@"Bonjour name" value:name source:@"DNS-SD service advertisement" confidence:@"Device-reported · unverified" scope:scope limitations:@"Service instance name; does not authenticate model, owner or manufacturer"];
  d.bonjourName=name;NSMutableSet *types=[NSMutableSet setWithObject:row[@"service"]];for(NSDictionary *observation in row[@"observations"])if([observation[@"service"] isKindOfClass:NSString.class]&&[self serviceType:observation[@"service"]])[types addObject:observation[@"service"]];d.serviceEvidence=[[types.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "];d.typeHint=[row[@"typeHint"] isKindOfClass:NSString.class]?row[@"typeHint"]:@"Device type unknown";if(!d.hostname.length&&[row[@"host"] isKindOfClass:NSString.class]){d.hostname=row[@"host"];[d recordAttribute:@"Network name" value:d.hostname source:@"DNS-SD service host" confidence:@"Device-reported · unverified" scope:scope limitations:@"Host associated by service resolution; not authenticated"];}if(![d.typeHint isEqual:@"Device type unknown"])[d recordAttribute:@"Category" value:d.typeHint source:@"DNS-SD service type" confidence:@"Inferred service category" scope:scope limitations:@"A service type does not establish an exact device type or model"];matched++;
 }
 return matched;
}
@end
