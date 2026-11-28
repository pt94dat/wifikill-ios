#import <Foundation/Foundation.h>
#import "Network/LGHostProbe.h"
#include <assert.h>
#include <string.h>
#include <time.h>
/* TCP transport is intentionally silent; the ICMP responder is real host loopback. */
static int tcpMode;
int lg_probe_detail(const char *ip,unsigned timeout,double *latency,int *evidence){(void)ip;(void)timeout;struct timespec wait={0,50000000};nanosleep(&wait,NULL);*latency=50;*evidence=tcpMode;return tcpMode!=0;}
int main(void){@autoreleasepool{
 for(int i=0;i<20;i++){int evidence=0;double ms=0;tcpMode=0;assert(lg_discover_detail("127.0.0.1",150,&ms,&evidence,NULL)&&evidence==4);assert(ms>=0);}
 for(tcpMode=1;tcpMode<=2;tcpMode++){int evidence=0;double ms=0;assert(lg_discover_detail("127.0.0.1",150,&ms,&evidence,NULL)&&evidence==tcpMode);}
 int evidence=99;double ms=1;assert(!lg_discover_detail("invalid",150,&ms,&evidence,NULL)&&evidence==0);
 puts("Reused Apple SimplePing: 20 actual loopback echoes detected with synthetic silent TCP; TCP acceptance/refusal precedence retained. Not an iPhone or LAN completeness test.");
}return 0;}
