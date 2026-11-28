#import <Foundation/Foundation.h>
#import "Network/LGHostProbe.h"
#import "ThirdParty/SimplePing.h"
#import <arpa/inet.h>
@interface LGHostEcho:NSObject<SimplePingDelegate>
@property(nonatomic) BOOL replied;
@property(nonatomic,strong) NSData *payload,*targetAddress;
@end
#include <assert.h>
#include <string.h>
#include <time.h>
/* TCP transport is intentionally silent; the ICMP responder is real host loopback. */
static int tcpMode;
int lg_probe_detail(const char *ip,unsigned timeout,double *latency,int *evidence){(void)ip;(void)timeout;struct timespec wait={0,50000000};nanosleep(&wait,NULL);*latency=50;*evidence=tcpMode;return tcpMode!=0;}
int main(void){@autoreleasepool{
 struct in_addr target;assert(inet_pton(AF_INET,"192.0.2.20",&target)==1);LGHostEcho *echo=[LGHostEcho new];echo.targetAddress=[NSData dataWithBytes:&target length:4];echo.payload=[@"owned-payload" dataUsingEncoding:NSUTF8StringEncoding];NSMutableData *packet=[NSMutableData dataWithLength:sizeof(IPHeader)+sizeof(ICMPHeader)+echo.payload.length];IPHeader *header=packet.mutableBytes;header->versionAndHeaderLength=0x45;header->protocol=1;memcpy(header->sourceAddress,&target,4);memcpy((uint8_t*)packet.mutableBytes+sizeof(IPHeader)+sizeof(ICMPHeader),echo.payload.bytes,echo.payload.length);
 header->sourceAddress[3]=21;[echo simplePing:nil didReceivePingResponsePacket:packet];assert(!echo.replied);header->sourceAddress[3]=20;((uint8_t*)packet.mutableBytes)[packet.length-1]^=1;[echo simplePing:nil didReceivePingResponsePacket:packet];assert(!echo.replied);((uint8_t*)packet.mutableBytes)[packet.length-1]^=1;[echo simplePing:nil didReceivePingResponsePacket:packet];assert(echo.replied);puts("Production echo association rejects wrong source and wrong per-probe payload in owned callback fixtures");
 for(int i=0;i<20;i++){int evidence=0;double ms=0;tcpMode=0;assert(lg_discover_detail("127.0.0.1",150,&ms,&evidence,NULL)&&evidence==4);assert(ms>=0);}
 for(tcpMode=1;tcpMode<=2;tcpMode++){int evidence=0;double ms=0;assert(lg_discover_detail("127.0.0.1",150,&ms,&evidence,NULL)&&evidence==tcpMode);}
 int evidence=99;double ms=1;assert(!lg_discover_detail("invalid",150,&ms,&evidence,NULL)&&evidence==0);
 puts("Reused Apple SimplePing: 20 actual loopback echoes detected with synthetic silent TCP; TCP acceptance/refusal precedence retained. Not an iPhone or LAN completeness test.");
}return 0;}
