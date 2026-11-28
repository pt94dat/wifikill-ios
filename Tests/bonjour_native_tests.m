#import <Foundation/Foundation.h>
#import "Network/LGBonjourInventory.h"
#include <assert.h>
@interface Publisher:NSObject<NSNetServiceDelegate>
@property(nonatomic) BOOL published;
@property(nonatomic) NSInteger error;
@end
@implementation Publisher
- (void)netServiceDidPublish:(NSNetService*)service{(void)service;self.published=YES;}
- (void)netService:(NSNetService*)service didNotPublish:(NSDictionary*)error{(void)service;self.error=[error[NSNetServicesErrorCode] integerValue];}
@end
static void spin(double seconds){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:seconds];while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];}
int main(void){@autoreleasepool{
 Publisher *delegate=[Publisher new];NSString *name=[@"LanGuard-controlled-" stringByAppendingString:NSUUID.UUID.UUIDString];NSNetService *service=[[NSNetService alloc]initWithDomain:@"local." type:@"_languard-test._tcp." name:name port:53531];service.delegate=delegate;[service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:@{@"model":[@"Owned test model" dataUsingEncoding:NSUTF8StringEncoding],@"manufacturer":[@"Owned test publisher" dataUsingEncoding:NSUTF8StringEncoding]}]];[service publish];for(int i=0;i<100&&!delegate.published&&!delegate.error;i++)spin(.02);assert(delegate.published&&!delegate.error);
 for(NSNumber *window in @[@1500,@3000,@5000]){LGBonjourInventory *b=[LGBonjourInventory new];__block BOOL done=NO,matched=NO;double began=NSProcessInfo.processInfo.systemUptime;[b collectWithWindowMS:window.unsignedIntegerValue completion:^(NSDictionary<NSString*,NSDictionary*> *evidence){for(NSDictionary *address in evidence.allValues)for(NSDictionary *row in address[@"observations"])if([row[@"name"] isEqual:name]&&[row[@"service"] isEqual:@"_languard-test._tcp."]){assert(([row[@"model"] isEqual:@"Owned test model"]&&[row[@"manufacturer"] isEqual:@"Owned test publisher"]));matched=YES;}done=YES;}];for(int i=0;i<350&&!done;i++)spin(.02);printf("Controlled Bonjour window=%ld elapsedMS=%.1f matched=%d\n",(long)window.integerValue,(NSProcessInfo.processInfo.systemUptime-began)*1000,matched);printf("Bonjour module stats: %s\n",b.diagnostics.description.UTF8String);assert(done);if(window.integerValue>=3000)assert(matched);[b cancel];}
 [service stop];puts("Actual host Bonjour publish/browse/resolve: 1.5s/3s/5s and dynamically enumerated type outside six defaults, not a physical iPhone or battery measurement");
}return 0;}
