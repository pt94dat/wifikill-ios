#import "LGServiceEvidence.h"
#import <arpa/inet.h>
@implementation LGServiceEvidence
+ (NSString*)serviceType:(NSString*)record{
 if([record hasSuffix:@".local"]){record=[record substringToIndex:record.length-6];}if(![record hasSuffix:@"."])record=[record stringByAppendingString:@"."];
 static NSRegularExpression *pattern;static dispatch_once_t once;dispatch_once(&once,^{pattern=[NSRegularExpression regularExpressionWithPattern:@"^_[A-Za-z0-9-]{1,63}\\._(tcp|udp)\\.$" options:0 error:nil];});
 return record.length<80&&[pattern numberOfMatchesInString:record options:0 range:NSMakeRange(0,record.length)]==1?record:nil;
}
+ (NSUInteger)merge:(NSDictionary<NSString*,NSDictionary*>*)evidence into:(NSMutableDictionary<NSString*,LGDevice*>*)devices network:(LGNetwork)network{
 NSUInteger matched=0;uint32_t base=network.address&network.netmask;
 for(NSString *ip in evidence){struct in_addr address;if(inet_pton(AF_INET,ip.UTF8String,&address)!=1)continue;uint32_t host=ntohl(address.s_addr);if((host&network.netmask)!=base||host==base||host==(base|~network.netmask))continue;
  NSDictionary *row=evidence[ip];if(![row isKindOfClass:NSDictionary.class]||![row[@"name"] isKindOfClass:NSString.class]||![row[@"service"] isKindOfClass:NSString.class]||![self serviceType:row[@"service"]])continue;
  NSString *name=row[@"name"];if(!name.length||name.length>128)continue;LGDevice *d=devices[ip];if(!d){d=[LGDevice new];d.ip=ip;d.reachability=LGReachabilityUnknown;d.systemProtected=host==network.address||[ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;devices[ip]=d;}
  d.bonjourName=name;d.serviceEvidence=row[@"service"];d.typeHint=[row[@"typeHint"] isKindOfClass:NSString.class]?row[@"typeHint"]:@"Device type unknown";if(!d.hostname.length&&[row[@"host"] isKindOfClass:NSString.class])d.hostname=row[@"host"];matched++;
 }
 return matched;
}
@end
