#import <Foundation/Foundation.h>
#import "Network/LGScanner.h"
#import "Network/LGScanSnapshot.h"
#import "Storage/LGStore.h"
#include <assert.h>
#include <stdio.h>
#include <arpa/inet.h>
#include <string.h>
#include <time.h>
#include <stdatomic.h>
static atomic_int nbnsActive,dnsSawNBNS;
static NSString *activeNetwork=@"controlled-A";
static double now(void){return NSProcessInfo.processInfo.systemUptime;}
@implementation LGNetworkContext
+ (instancetype)current{LGNetworkContext *c=[self new];LGNetwork n={0};n.address=0xc0000201;n.netmask=0xffffff00;strcpy(n.ip,"192.0.2.1");strcpy(n.gateway,"192.0.2.254");strcpy(n.interface,"lo0");c.network=n;c.networkKey=activeNetwork;c.fingerprint=activeNetwork;c.title=@"Owned synthetic transport";return c;}
@end
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation LGStore
+ (NSArray*)observations:(NSString*)network{(void)network;return @[];}
+ (void)saveObservations:(NSArray*)rows network:(NSString*)network{(void)rows;(void)network;}
@end
#pragma clang diagnostic pop
@interface LGBonjourInventory ()
@property(nonatomic) BOOL stopped;
@end
@implementation LGBonjourInventory
- (NSDictionary*)diagnostics{return @{@"found":@1,@"resolved":@1};}
- (void)collect:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion{[self collectWithWindowMS:3000 completion:completion];}
- (void)collectWithWindowMS:(NSUInteger)window completion:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion{(void)window;self.stopped=NO;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.stopped)return;self.onCancel=nil;completion(@{@"192.0.2.9":@{@"name":@"Owned service-only fixture",@"service":@"_languard-test._tcp."}});});}
- (void)cancel{self.stopped=YES;void(^done)(void)=self.onCancel;self.onCancel=nil;if(done)done();}
@end
int lg_probe_detail(const char *ip,unsigned timeout,double *latency,int *evidence){(void)timeout;*latency=1;*evidence=!strcmp(ip,"192.0.2.2")?1:0;return *evidence==1;}
size_t lg_neighbors(const LGNetwork *n,LGNeighbor *out,size_t capacity,unsigned *rejected){(void)n;(void)out;(void)capacity;*rejected=0;return 0;}
LGNeighborStats lg_neighbor_stats(void){LGNeighborStats s={0};s.view=3;return s;}
LGDNSOutcome lg_hostname_controlled(const char *ip,unsigned iface,char *out,size_t capacity,const LGDNSControl *control,LGDNSMetrics *metrics){(void)ip;(void)iface;memset(metrics,0,sizeof(*metrics));double began=now();while(now()-began<.65){if(atomic_load(&nbnsActive))atomic_store(&dnsSawNBNS,1);if(control->cancelled&&control->cancelled(control->context)){metrics->cleaned=1;return LGDNSCancelled;}struct timespec t={0,20000000};nanosleep(&t,NULL);}snprintf(out,capacity,"owned-ptr.local");metrics->elapsed_ms=(now()-began)*1000;metrics->soft_exceeded=1;metrics->cleaned=1;return LGDNSResolved;}
void lg_hostnames_controlled(LGDNSRequest *requests,size_t count,unsigned interface_index,const LGDNSControl *control){for(size_t i=0;i<count;i++)requests[i].outcome=lg_hostname_controlled(requests[i].ip,interface_index,requests[i].name,sizeof(requests[i].name),control,&requests[i].metrics);}

int lg_nbns_query(const char *ip,unsigned ms,char name[64],char mac[18]){(void)ip;(void)ms;atomic_store(&nbnsActive,1);struct timespec delay={0,250000000};nanosleep(&delay,NULL);atomic_store(&nbnsActive,0);name[0]=0;mac[0]=0;return 0;}
static void spin(double duration){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:duration];while(end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];}
int main(void){@autoreleasepool{
 LGScanner *scanner=[LGScanner new];__block BOOL done=NO;__block NSArray *initial=nil;__block NSString *identifier=nil;__block double initialTime=0,finalTime=0;double began=now();
 [scanner scan:^(NSArray<LGDevice*> *rows,NSString *explanation){(void)explanation;if(scanner.enriching){initial=rows;identifier=scanner.metrics[@"scanID"];initialTime=now()-began;assert((rows.count==2));for(LGDevice *d in rows)assert((!d.hostname.length));}else{finalTime=now()-began;assert(([identifier isEqual:scanner.metrics[@"scanID"]]));assert((rows.count==3&&[scanner.metrics[@"advertisedOnly"] intValue]==1));assert(([scanner.metrics[@"reconciled"] boolValue]));NSMutableSet *actual=[NSMutableSet new];for(LGDevice *d in rows){[actual addObject:d.ip];if([d.ip isEqual:@"192.0.2.2"])assert(([d.hostname isEqual:@"owned-ptr.local"]));if([d.ip isEqual:@"192.0.2.9"])assert(([d.bonjourName isEqual:@"Owned service-only fixture"]&&d.reachability==LGReachabilityUnknown));}NSSet *expected=[NSSet setWithArray:@[@"192.0.2.1",@"192.0.2.2",@"192.0.2.9"]];NSMutableSet *extra=actual.mutableCopy,*missing=expected.mutableCopy;[extra minusSet:expected];[missing minusSet:actual];assert((!extra.count&&!missing.count));printf("Owned synthetic observation inventory: expected=3 observed=%lu FP=%lu FN=%lu; identity association passed\n",(unsigned long)actual.count,(unsigned long)extra.count,(unsigned long)missing.count);for(LGDevice *d in initial)assert((!d.hostname.length));done=YES;}}];for(int i=0;i<300&&!done;i++)spin(.01);assert((done&&initialTime<finalTime&&finalTime>=.65&&atomic_load(&dnsSawNBNS)));printf("Actual scanner/synthetic transport initialMS=%.1f finalMS=%.1f detached revisions passed\n",initialTime*1000,finalTime*1000);
 __block int callbacks=0;[scanner scan:^(NSArray<LGDevice*> *rows,NSString *explanation){(void)rows;(void)explanation;callbacks++;[scanner cancel];}];spin(1);assert((callbacks==1&&[scanner.diagnostics[@"lifecycle"] isEqual:@"cancelled"]));
 activeNetwork=@"controlled-A";done=NO;[scanner scan:^(NSArray<LGDevice*> *rows,NSString *explanation){(void)explanation;if(scanner.enriching)activeNetwork=@"controlled-B";else{assert((rows.count==0&&[scanner.diagnostics[@"lifecycle"] isEqual:@"networkChanged"]));done=YES;}}];for(int i=0;i<300&&!done;i++)spin(.01);assert((done));
 for(int iteration=0;iteration<3;iteration++){done=NO;activeNetwork=@"controlled-A";[scanner scan:^(NSArray<LGDevice*> *rows,NSString *explanation){(void)rows;(void)explanation;if(!scanner.enriching)done=YES;}];for(int i=0;i<300&&!done;i++)spin(.01);assert((done&&[scanner.metrics[@"reconciled"] boolValue]));}
 [scanner cancel];puts("Production staged scanner, copied rows, cancellation, network-switch rejection and repeated completion passed; all transport is synthetic");
}return 0;}
