#import "LGScanner.h"
#import "LGIdentity.h"
#import "LGNetBIOS.h"
#import "LGScanSnapshot.h"
#import "LGServiceEvidence.h"
#import "Storage/LGStore.h"
#import <arpa/inet.h>
#import <net/if.h>
#import <sys/resource.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <mach/mach.h>
#import <errno.h>
static int dns_cancelled(void *context){BOOL(^check)(void)=(__bridge id)context;return check();}
static double cpu_ms(void){struct rusage r;if(getrusage(RUSAGE_SELF,&r))return -1;return (r.ru_utime.tv_sec+r.ru_stime.tv_sec)*1000.0+(r.ru_utime.tv_usec+r.ru_stime.tv_usec)/1000.0;}
@implementation LGScanner
- (instancetype)init{if((self=[super init]))_engineQueue=dispatch_queue_create("com.pt94dat.languard.scanner",DISPATCH_QUEUE_SERIAL);return self;}
- (void)cancel{
 self.enriching=NO;self.generation++;[self.workQueue cancelAllOperations];[self.bonjour cancel];self.bonjour=nil;
 if([@[@"running",@"identifying"] containsObject:self.diagnostics[@"lifecycle"]]){NSMutableDictionary *d=[self.diagnostics mutableCopy];d[@"lifecycle"]=@"cancelled";d[@"snapshotCommitted"]=@NO;self.diagnostics=d.copy;}
}
- (void)scan:(void(^)(NSArray<LGDevice*>*,NSString*))completion{
 [self cancel];NSUInteger generation=self.generation;NSString *scanID=NSUUID.UUID.UUIDString;double began=NSProcessInfo.processInfo.systemUptime,cpu=cpu_ms();LGNetworkContext *start=[LGNetworkContext current];self.context=start;self.enriching=YES;
 self.diagnostics=@{@"scanID":scanID,@"lifecycle":@"running",@"snapshotCommitted":@NO,@"generation":@(generation)};
 dispatch_async(self.engineQueue,^{@autoreleasepool{
  unsigned base=0,hosts=0;
  if(!start||!lg_subnet_hosts(start.network.address,start.network.netmask,&base,&hosts)){dispatch_async(dispatch_get_main_queue(),^{if(self.generation==generation){self.enriching=NO;self.metrics=@{};self.diagnostics=@{@"scanID":scanID,@"lifecycle":start?@"unsupportedSubnet":@"noNetwork",@"snapshotCommitted":@NO};completion(@[],start?@"Unsupported subnet size":@"No local Wi-Fi IPv4 connection");}});return;}
  NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=12;self.workQueue=queue;NSMutableDictionary<NSString*,LGDevice*> *found=[NSMutableDictionary new];
  for(unsigned h=1;h<=hosts;h++){
   if(self.generation!=generation)break;
   [queue addOperationWithBlock:^{@autoreleasepool{
    if(self.generation!=generation)return;struct in_addr address={htonl(base+h)};char ip[16];inet_ntop(AF_INET,&address,ip,16);BOOL local=base+h==start.network.address;double ms=0;int evidence=local?3:0;
    if(!local&&!lg_probe_detail(ip,300,&ms,&evidence))return;LGDevice *d=[LGDevice new];d.ip=@(ip);d.reachability=local?LGReachabilityHost:LGReachabilityResponded;d.lastSeen=NSDate.date;d.probeEvidence=evidence;d.latencyMS=ms;if(local)d.name=@"This iPhone";
    @synchronized(found){found[d.ip]=d;}
   }}];
  }
  [queue waitUntilAllOperationsAreFinished];if(self.generation!=generation)return;double probesEnded=NSProcessInfo.processInfo.systemUptime;
  LGNetwork network=start.network;LGNeighbor *neighbors=calloc(1024,sizeof(*neighbors));unsigned rejected=0;size_t count=neighbors?lg_neighbors(&network,neighbors,1024,&rejected):0;LGNeighborStats ns={0};if(neighbors)ns=lg_neighbor_stats();else{ns.apiError=ENOMEM;ns.view=3;}
  for(size_t i=0;i<count;i++){
   NSString *ip=@(neighbors[i].ip);LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;d.reachability=LGReachabilityCached;found[ip]=d;}d.neighborCached=YES;d.mac=@(neighbors[i].mac);d.identitySource=@"Local neighbor cache · unauthenticated identity";
  }free(neighbors);
  NSArray *stored=[LGStore observations:start.networkKey];NSArray *history=[LGScanSnapshot history:stored now:NSDate.date.timeIntervalSince1970 address:network.address mask:network.netmask];
  for(NSDictionary *old in history){NSString *ip=old[@"ip"];LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;found[ip]=d;}d.previouslySeen=YES;if(!d.lastSeen)d.lastSeen=[NSDate dateWithTimeIntervalSince1970:[old[@"seen"] doubleValue]];}
  // Publish detached address observations before slower identity work; both revisions use the same scan ID.
  for(LGDevice *d in found.allValues){d.systemProtected=[d.ip isEqual:@(network.ip)]||[d.ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;d.identityKey=[NSString stringWithFormat:@"%@:%@",start.networkKey,d.ip];if(d.systemProtected&&!d.name.length)d.name=@"Gateway";}
  __block double initialPublishedMS=0;__block NSDictionary *serviceRows=@{};__block NSDictionary *bonjourStats=@{};dispatch_group_t serviceGroup=dispatch_group_create();dispatch_group_enter(serviceGroup);
  NSMutableArray *initial=[NSMutableArray new];for(LGDevice *d in found.allValues)[initial addObject:[d copy]];
  NSDictionary *initialCounts=[LGScanSnapshot counts:initial];
  dispatch_async(dispatch_get_main_queue(),^{
   LGNetworkContext *now=[LGNetworkContext current];if(self.generation!=generation||!now||![now.fingerprint isEqual:start.fingerprint]){dispatch_group_leave(serviceGroup);return;}
   NSMutableDictionary *initialMetrics=[initialCounts mutableCopy];initialMetrics[@"scanID"]=scanID;initialMetrics[@"revision"]=@1;self.metrics=initialMetrics.copy;self.diagnostics=@{@"scanID":scanID,@"generation":@(generation),@"lifecycle":@"identifying",@"revision":@1,@"snapshotCommitted":@YES,@"counts":initialCounts,@"timingMS":@{@"initial":@((NSProcessInfo.processInfo.systemUptime-began)*1000)}};
   initialPublishedMS=(NSProcessInfo.processInfo.systemUptime-began)*1000;completion(initial,@"Address snapshot ready; identifying advertised services and names…");if(self.generation!=generation){dispatch_group_leave(serviceGroup);return;}
   self.bonjour=[LGBonjourInventory new];LGBonjourInventory *collector=self.bonjour;[collector collectWithWindowMS:3000 completion:^(NSDictionary<NSString*,NSDictionary*> *evidence){serviceRows=evidence;bonjourStats=collector.diagnostics;dispatch_group_leave(serviceGroup);}];collector.onCancel=^{dispatch_group_leave(serviceGroup);};
  });
  double identityDeadline=NSProcessInfo.processInfo.systemUptime+3.0;
  NSMutableDictionary *dns=[NSMutableDictionary new];NSMutableDictionary *dnsLifecycle=[NSMutableDictionary new];NSMutableDictionary *dnsCodes=[NSMutableDictionary new];__block NSUInteger nbReplies=0;
  for(LGDevice *d in found.allValues)if(d.reachability==LGReachabilityResponded)[queue addOperationWithBlock:^{@autoreleasepool{
   if(self.generation!=generation)return;int remaining=(int)((identityDeadline-NSProcessInfo.processInfo.systemUptime)*1000);if(remaining<50){@synchronized(dns){dnsLifecycle[@"budgetNotStarted"]=@([dnsLifecycle[@"budgetNotStarted"] unsignedIntegerValue]+1);}return;}char name[256];BOOL(^cancelCheck)(void)=^BOOL(void){return self.generation!=generation;};LGDNSControl control={400,(unsigned)remaining,dns_cancelled,(__bridge void*)cancelCheck};LGDNSMetrics timing;LGDNSOutcome outcome=lg_hostname_controlled(d.ip.UTF8String,0,name,sizeof(name),&control,&timing);if(self.generation!=generation)return;int code=timing.api_error;NSString *category=@[@"notAttempted",@"resolved",@"applicationDeadline",@"noRecordReported",@"resolverFailure",@"malformedReply",@"cancelled"][outcome];
   @synchronized(dns){dnsLifecycle[@"started"]=@([dnsLifecycle[@"started"] unsignedIntegerValue]+1);dnsLifecycle[@"cleaned"]=@([dnsLifecycle[@"cleaned"] unsignedIntegerValue]+timing.cleaned);if(timing.soft_exceeded)dnsLifecycle[@"softExceeded"]=@([dnsLifecycle[@"softExceeded"] unsignedIntegerValue]+1);if(timing.soft_exceeded&&outcome==LGDNSResolved)dnsLifecycle[@"lateResolved"]=@([dnsLifecycle[@"lateResolved"] unsignedIntegerValue]+1);dnsLifecycle[@"completionMSMax"]=@(MAX([dnsLifecycle[@"completionMSMax"] doubleValue],timing.elapsed_ms));}d.dnsOutcome=category;if(outcome==LGDNSResolved)d.hostname=@(name);
   @synchronized(dns){dns[category]=@([dns[category] unsignedIntegerValue]+1);if(code)dnsCodes[[NSString stringWithFormat:@"%d",code]]=@([dnsCodes[[NSString stringWithFormat:@"%d",code]] unsignedIntegerValue]+1);}
   if(self.generation!=generation)return;char nbName[64],nbMac[18];if(lg_nbns_query(d.ip.UTF8String,150,nbName,nbMac)){@synchronized(dns){nbReplies++;}if(!d.hostname.length&&nbName[0])d.hostname=@(nbName);if(!d.mac.length&&nbMac[0]){d.mac=@(nbMac);d.identitySource=@"NetBIOS self-reported MAC · not authenticated";d.macSelfReported=YES;}}
  }}];
  [queue waitUntilAllOperationsAreFinished];if(self.generation!=generation)return;double namesEnded=NSProcessInfo.processInfo.systemUptime;
  for(LGDevice *d in found.allValues){d.systemProtected=[d.ip isEqual:@(network.ip)]||[d.ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;if(d.systemProtected&&!d.name.length)d.name=@"Gateway";d.identityKey=[NSString stringWithFormat:@"%@:%@",start.networkKey,d.ip];}
  NSDictionary *neighborReport=@{@"view":@(ns.view),@"nonNeighbor":@(ns.nonNeighbor),@"rejectedRepeated":@(ns.rejectedRepeated),@"apiErrno":@(ns.apiError),@"records":@(ns.records),@"candidates":@(ns.candidates),@"usableUnique":@(ns.accepted),@"duplicate":@(ns.duplicate),@"conflicting":@(ns.conflicting),@"malformed":@(ns.malformed),@"unsupported":@(ns.unsupported),@"incomplete":@(ns.incomplete),@"placeholderPattern":@(ns.placeholder),@"zero":@(ns.zero),@"multicast":@(ns.multicast),@"uniqueRejectedAddresses":@(ns.uniqueRejected),@"capacityDropped":@(ns.capacityDropped)};
  dispatch_group_notify(serviceGroup,dispatch_get_main_queue(),^{if(self.generation!=generation)return;
   LGNetworkContext *after=[LGNetworkContext current];if(!after||![after.fingerprint isEqual:start.fingerprint]){self.enriching=NO;self.context=after;self.metrics=@{};self.diagnostics=@{@"scanID":scanID,@"lifecycle":@"networkChanged",@"snapshotCommitted":@NO};completion(@[],@"Network changed; scan discarded");return;}
   NSUInteger matched=[LGServiceEvidence merge:serviceRows into:found network:network];
   for(LGDevice *d in found.allValues)if(!d.identityKey.length)d.identityKey=[NSString stringWithFormat:@"%@:%@",start.networkKey,d.ip];
   NSDictionary *finalCounts=[LGScanSnapshot counts:found.allValues];NSMutableDictionary *metrics=[finalCounts mutableCopy];metrics[@"rejectedNeighbors"]=@(rejected);metrics[@"probed"]=@(hosts);metrics[@"neighborView"]=@(ns.view);metrics[@"scanID"]=scanID;metrics[@"revision"]=@2;
    NSMutableArray *records=[NSMutableArray new];for(LGDevice *d in found.allValues)if(d.lastSeen)[records addObject:@{@"ip":d.ip,@"seen":@(d.lastSeen.timeIntervalSince1970)}];[LGStore saveObservations:[LGScanSnapshot history:records now:NSDate.date.timeIntervalSince1970 address:network.address mask:network.netmask] network:start.networkKey];
    mach_task_basic_info_data_t memory={0};mach_msg_type_number_t size=MACH_TASK_BASIC_INFO_COUNT;kern_return_t memoryCode=task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&memory,&size);
    NSMutableDictionary *dnsReport=[dnsLifecycle mutableCopy];dnsReport[@"outcomes"]=dns.copy;dnsReport[@"apiCodes"]=dnsCodes.copy;self.enriching=NO;self.context=start;self.metrics=metrics.copy;self.diagnostics=@{@"scanID":scanID,@"generation":@(generation),@"lifecycle":@"completed",@"revision":@2,@"snapshotCommitted":@YES,@"counts":finalCounts,@"neighbor":neighborReport,@"dns":dnsReport.copy,@"netbiosReplies":@(nbReplies),@"bonjour":bonjourStats,@"bonjourMatchedAddresses":@(matched),@"history":@{@"input":@(stored.count),@"retainedUnique":@(history.count),@"filteredOrDuplicate":@(stored.count-history.count)},@"timingMS":@{@"initial":@(initialPublishedMS),@"probes":@((probesEnded-began)*1000),@"identity":@((namesEnded-probesEnded)*1000),@"total":@((NSProcessInfo.processInfo.systemUptime-began)*1000),@"processCPU":@(cpu_ms()-cpu)},@"residentBytes":@(memoryCode==KERN_SUCCESS?memory.resident_size:0),@"memoryAPICode":@(memoryCode),@"budgets":@{@"workers":@12,@"tcpMS":@300,@"ptrMS":@3000,@"ptrSoftMS":@400,@"nbnsMS":@150,@"bonjourMS":@3000}};
    self.bonjour=nil;completion(found.allValues,@"One committed snapshot. Responded = accepted + refused + local. History is not current connectivity; network names are self-reported.");
  });
 }});
}
@end
