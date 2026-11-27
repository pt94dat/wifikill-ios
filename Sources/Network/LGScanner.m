#import "LGScanner.h"
#import <arpa/inet.h>
@implementation LGScanner
- (void)cancel { self.generation++; }
- (void)scan:(void(^)(NSArray<LGDevice*> *, NSString *))completion {
 [self cancel];NSUInteger generation=self.generation;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  LGNetwork net;if(lg_network(&net)){dispatch_async(dispatch_get_main_queue(),^{if(generation==self.generation)completion(@[],@"Wi-Fi IPv4 interface unavailable");});return;}
  uint32_t hosts=~net.netmask;if(hosts>1023||hosts<3){dispatch_async(dispatch_get_main_queue(),^{if(generation==self.generation)completion(@[],@"Subnet outside supported /22–/30 scan range");});return;}
  NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=12;
  NSMutableArray *found=[NSMutableArray new];uint32_t base=net.address&net.netmask;
  for(uint32_t h=1;h<hosts;h++){
   if(self.generation!=generation)break;
   [queue addOperationWithBlock:^{
    if(self.generation!=generation)return;
    struct in_addr a={htonl(base+h)};char ip[16],mac[32];inet_ntop(AF_INET,&a,ip,sizeof(ip));
    BOOL local=base+h==net.address;double latency=0;BOOL live=local||lg_probe(ip,250,&latency);
    int known=lg_mac(ip,mac,sizeof(mac));if(!live&&known)return;
    LGDevice *d=[LGDevice new];d.ip=@(ip);d.mac=@(mac);d.name=local?@"This iPhone":([d.ip isEqualToString:@(net.gateway)]?@"Gateway":d.ip);
    d.protectedDevice=local||[d.ip isEqualToString:@(net.gateway)];d.status=live?@"Local reachability verified":@"Neighbor cached · reachability unknown";if(live)d.lastSeen=[NSDate date];
    @synchronized(found){[found addObject:d];}
   }];
  }
  [queue waitUntilAllOperationsAreFinished];LGNetwork current;
  BOOL changed=lg_network(&current)||current.address!=net.address||current.netmask!=net.netmask||strcmp(current.gateway,net.gateway);
  dispatch_async(dispatch_get_main_queue(),^{if(self.generation==generation)completion(changed?@[]:found,changed?@"Network changed — scan discarded":[NSString stringWithFormat:@"%s · %s/%s · gateway %s",net.interface,net.ip,net.mask,net.gateway[0]?net.gateway:"unavailable"]);});
 });
}
@end
