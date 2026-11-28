#import "LGDiagnostics.h"
#include <sys/utsname.h>
#include <unistd.h>
@implementation LGDiagnostics
+ (id)redact:(id)value key:(NSString*)key{
 if([value isKindOfClass:NSNumber.class])return value;
 if([value isKindOfClass:NSString.class]){
  if([key isEqual:@"scanID"]&&[NSUUID.alloc initWithUUIDString:value])return value;
  if([key isEqual:@"lifecycle"]&&[@[@"running",@"identifying",@"completed",@"cancelled",@"networkChanged",@"noNetwork",@"unsupportedSubnet"] containsObject:value])return value;
  return nil;
 }
 if(![value isKindOfClass:NSDictionary.class])return nil;
 static NSSet *keys;static dispatch_once_t once;dispatch_once(&once,^{keys=[NSSet setWithArray:[@"positiveControl localOnly runTime setupCode registered queryCode outcome matched removed elapsedMS scanID lifecycle generation revision snapshotCommitted advertisedOnly started cleaned softExceeded lateResolved budgetNotStarted ptrSoftMS enumeratedTypes typeEnumerationCode nonNeighbor rejectedRepeated completionMSMax initial counts discovered reachable cached unknown tcpAccepted tcpRefused local otherResponseEvidence duplicateRows reconciled neighbor view apiErrno records candidates usableUnique duplicate conflicting malformed unsupported incomplete placeholderPattern zero multicast uniqueRejectedAddresses capacityDropped dns outcomes apiCodes notAttempted resolved applicationDeadline noRecordReported resolverFailure malformedReply netbiosReplies bonjour windowMS browsersStarted found browserFailures resolveFailures removed lastBrowserCode lastResolveCode deadlineReached unresolvedAtDeadline bonjourMatchedAddresses history input retainedUnique filteredOrDuplicate timingMS probes identity total processCPU residentBytes memoryAPICode budgets workers dnsActiveLimit tcpMS ptrMS nbnsMS bonjourMS" componentsSeparatedByString:@" "]];});
 NSMutableDictionary *result=[NSMutableDictionary new];for(id k in value){if(![k isKindOfClass:NSString.class])continue;NSScanner *number=[NSScanner scannerWithString:k];int code=0;BOOL numeric=[key isEqual:@"apiCodes"]&&[number scanInt:&code]&&number.isAtEnd;if(![keys containsObject:k]&&!numeric)continue;id v=[self redact:value[k] key:k];if(v)result[k]=v;}return result.copy;
}
+ (NSString*)report:(NSDictionary*)scan{
 struct utsname runtime;BOOL available=uname(&runtime)==0;NSDictionary *bundle=NSBundle.mainBundle.infoDictionary;
 NSDictionary *report=@{@"schema":@1,@"redacted":@YES,@"application":@{@"version":bundle[@"CFBundleShortVersionString"]?:@"unbundled-test",@"build":bundle[@"CFBundleVersion"]?:@"unbundled-test",@"sourceCommit":bundle[@"LGSourceCommit"]?:@"not-recorded"},@"runtime":@{@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"machine":available?@(runtime.machine):@"unavailable",@"uid":@(getuid()),@"euid":@(geteuid())},@"scan":[self redact:scan?:@{} key:@"scan"]?:@{},@"limits":@[@"No credentials, network names, addresses, device names or traffic payloads exported",@"Application DNS deadline is not proof of NXDOMAIN or missing PTR",@"Neighbor placeholder pattern is an observation, not proof of a specific OS cause",@"CPU and resident memory are process measurements, not battery benchmarks",@"LocalOnly positive control checks this device DNS-SD API, not LAN device identity or multicast"]};
 NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil];return data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:@"Diagnostic serialization failed";
}
@end
