#import "LGScanSnapshot.h"
#import <arpa/inet.h>
@implementation LGScanSnapshot
+ (NSDictionary*)counts:(NSArray<LGDevice*>*)devices{
 NSMutableDictionary *unique=[NSMutableDictionary new];NSUInteger duplicates=0;
 for(LGDevice *d in devices){if(unique[d.ip]){duplicates++;continue;}unique[d.ip]=d;}
 NSUInteger responded=0,cached=0,unknown=0,accepted=0,refused=0,local=0,other=0;
 for(LGDevice *d in unique.allValues){if(d.reachability>=LGReachabilityResponded){responded++;if(d.probeEvidence==1)accepted++;else if(d.probeEvidence==2)refused++;else if(d.probeEvidence==3)local++;else other++;}else if(d.reachability==LGReachabilityCached)cached++;else unknown++;}
 return @{@"discovered":@(unique.count),@"reachable":@(responded),@"cached":@(cached),@"unknown":@(unknown),@"tcpAccepted":@(accepted),@"tcpRefused":@(refused),@"local":@(local),@"otherResponseEvidence":@(other),@"duplicateRows":@(duplicates),@"reconciled":@(unique.count==responded+cached+unknown&&responded==accepted+refused+local&&duplicates==0)};
}
+ (NSArray<NSDictionary*>*)history:(NSArray*)records now:(NSTimeInterval)now address:(uint32_t)address mask:(uint32_t)mask{
 NSMutableDictionary *latest=[NSMutableDictionary new];uint32_t base=address&mask;
 for(id raw in records){if(![raw isKindOfClass:NSDictionary.class])continue;NSDictionary *r=raw;NSString *ip=r[@"ip"];NSNumber *seen=r[@"seen"];if(![ip isKindOfClass:NSString.class]||![seen isKindOfClass:NSNumber.class])continue;
  struct in_addr a;if(inet_pton(AF_INET,ip.UTF8String,&a)!=1)continue;uint32_t host=ntohl(a.s_addr);double time=seen.doubleValue;
  if((host&mask)!=base||host<=base||host==(base|~mask)||time<=0||time>now+60||now-time>7*86400)continue;
  if(!latest[ip]||[latest[ip][@"seen"] doubleValue]<time)latest[ip]=@{@"ip":ip,@"seen":seen};
 }
 NSArray *sorted=[latest.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){NSComparisonResult result=[b[@"seen"] compare:a[@"seen"]];return result==NSOrderedSame?[a[@"ip"] compare:b[@"ip"] options:NSNumericSearch]:result;}];return sorted.count>1022?[sorted subarrayWithRange:NSMakeRange(0,1022)]:sorted;
}
@end
