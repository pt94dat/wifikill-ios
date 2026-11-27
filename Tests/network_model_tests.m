#import <Foundation/Foundation.h>
#import "Network/LGScanSnapshot.h"
#import "Network/LGBonjourInventory.h"
#import "Diagnostics/LGDiagnostics.h"
#include <assert.h>
@interface LGBonjourInventory (TestCallbacks)
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindService:(NSNetService*)service moreComing:(BOOL)more;
- (void)netServiceDidResolveAddress:(NSNetService*)service;
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didNotSearch:(NSDictionary*)error;
- (void)netService:(NSNetService*)service didNotResolve:(NSDictionary*)error;
@end
int main(void){@autoreleasepool{
 LGDevice *host=[LGDevice new];host.ip=@"192.0.2.1";host.reachability=LGReachabilityHost;host.probeEvidence=3;
 LGDevice *accepted=[LGDevice new];accepted.ip=@"192.0.2.2";accepted.reachability=LGReachabilityResponded;accepted.probeEvidence=1;
 LGDevice *refused=[LGDevice new];refused.ip=@"192.0.2.3";refused.reachability=LGReachabilityResponded;refused.probeEvidence=2;
 LGDevice *unknown=[LGDevice new];unknown.ip=@"192.0.2.4";
 LGDevice *cached=[LGDevice new];cached.ip=@"192.0.2.5";cached.reachability=LGReachabilityCached;
 NSDictionary *counts=[LGScanSnapshot counts:@[host,accepted,refused,unknown,cached]];assert(([counts[@"reconciled"] boolValue]));assert(([counts[@"discovered"] intValue]==5&&[counts[@"reachable"] intValue]==3&&[counts[@"unknown"] intValue]==1&&[counts[@"cached"] intValue]==1));assert((![[LGScanSnapshot counts:@[host,host]][@"reconciled"] boolValue]));
 accepted.probeEvidence=0;assert((![[LGScanSnapshot counts:@[host,accepted]][@"reconciled"] boolValue]));accepted.probeEvidence=1;
 NSArray *raw=@[@{@"ip":@"192.0.2.2",@"seen":@900000},@{@"ip":@"192.0.2.2",@"seen":@900001},@{@"ip":@"192.0.2.3",@"seen":@1},@{@"ip":@"192.0.3.2",@"seen":@900000},@{@"ip":@"192.0.2.4",@"seen":@9999999},@{@"ip":@"garbage",@"seen":@900000}];
 NSArray *h=[LGScanSnapshot history:raw now:900002 address:0xc0000201 mask:0xffffff00];assert((h.count==1&&[h[0][@"seen"] intValue]==900001));assert(([LGScanSnapshot history:h now:1600000 address:0xc0000201 mask:0xffffff00].count==0));assert(([LGScanSnapshot history:h now:900002 address:0xc0000301 mask:0xffffff00].count==0));
 NSString *text=[LGDiagnostics report:@{@"scanID":@"11111111-1111-1111-1111-111111111111",@"lifecycle":@"completed",@"counts":counts,@"token":@"sensitive-fixture",@"endpoint":@"https://secret.invalid",@"neighbor":@{@"zero":@3,@"mac":@"11:22:33:44:55:66"},@"dns":@{@"apiCodes":@{@"-65554":@1,@"secret-key":@2}}}];assert((![text containsString:@"sensitive-fixture"]&&![text containsString:@"secret.invalid"]&&![text containsString:@"11:22:33:44:55:66"]&&![text containsString:@"secret-key"]));NSDictionary *report=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];assert(([report[@"redacted"] boolValue]&&[report[@"scan"][@"neighbor"][@"zero"] intValue]==3));
 LGBonjourInventory *b=[LGBonjourInventory new];__block BOOL delivered=NO;[b collect:^(NSDictionary<NSString*,NSDictionary*> *evidence){(void)evidence;delivered=YES;}];[b netServiceBrowser:nil didNotSearch:@{NSNetServicesErrorCode:@(-72000)}];[b netService:nil didNotResolve:@{NSNetServicesErrorCode:@(-72007)}];assert(([b.diagnostics[@"browserFailures"] intValue]==1&&[b.diagnostics[@"resolveFailures"] intValue]==1));[b cancel];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:1.6];while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];assert((!delivered));
 puts("Native snapshot, reconciliation, history expiry/network boundaries, redacted export and Bonjour cancellation/error fixtures passed");
}return 0;}
