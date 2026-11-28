#include "Network/LGNetwork.h"
#include "resolver_shim.h"
#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <time.h>
/* Owned callback transport. No live network or phone behavior is simulated as evidence. */
static int fds[2],mode,event,deallocated;static void *ctx;static DNSServiceQueryRecordReply callback;
int DNSServiceQueryRecord(DNSServiceRef *ref,uint32_t flags,uint32_t iface,const char *name,uint16_t type,uint16_t cls,DNSServiceQueryRecordReply cb,void *context){
 assert(flags&kDNSServiceFlagsReturnIntermediates);(void)iface;assert(!strcmp(name,"20.2.0.192.in-addr.arpa."));assert(type==12&&cls==1);
 if(mode==1){return -65563;}
 assert(!pipe(fds));event=0;if(mode!=2)assert(write(fds[1],"x",1)==1);*ref=(void*)1;ctx=context;callback=cb;return 0;
}
int DNSServiceRefSockFD(DNSServiceRef ref){(void)ref;return mode==13?-1:fds[0];}
int DNSServiceProcessResult(DNSServiceRef ref){
 char byte;assert(read(fds[0],&byte,1)==1);if(mode==3)return -65563;
 unsigned char name[]={4,'t','e','s','t',5,'l','o','c','a','l',0};event++;
 int error=0;uint32_t flags=2;uint16_t type=12,cls=1;
 if(mode==4||(mode==6&&event==1)||(mode==7&&event<=3)||(mode==8&&event==1)||(mode==14&&event==1))error=-65554;
 if(mode==5||(mode==9&&event==1))name[0]=63;
 if(mode==10&&event==1)type=5;
 if(mode==11&&event==1)flags=0;
 if(mode==12&&event==1)cls=3;
 callback(ref,flags,4,error,"20.2.0.192.in-addr.arpa.",type,cls,sizeof(name),name,60,ctx);
 if((mode==6&&event==1)||(mode==7&&event<=3)||(mode==8&&event==1)||(mode>=9&&mode<=12&&event==1))assert(write(fds[1],"x",1)==1);
 if(mode==8&&event==2)return -65563;
 return 0;
}
void DNSServiceRefDeallocate(DNSServiceRef ref){(void)ref;close(fds[0]);close(fds[1]);deallocated++;}
static int cancel_after_negative(void *unused){(void)unused;return event>0;}
int main(void){
 char name[256];int error=0;
 LGDNSOutcome expected[]={LGDNSResolved,LGDNSFailure,LGDNSDeadline,LGDNSFailure,LGDNSNoRecord,LGDNSMalformed,LGDNSResolved,LGDNSResolved,LGDNSFailure,LGDNSResolved,LGDNSResolved,LGDNSResolved,LGDNSResolved,LGDNSFailure,LGDNSCancelled};
 int order[]={6,7,0,1,2,3,4,5,8,9,10,11,12,13,14};
 for(unsigned i=0;i<15;i++){mode=order[i];
  deallocated=0;event=0;strcpy(name,"stale");LGDNSControl control={5,25,mode==14?cancel_after_negative:NULL,NULL};LGDNSMetrics metrics;
  LGDNSOutcome got=lg_hostname_controlled("192.0.2.20",4,name,sizeof(name),&control,&metrics);error=metrics.api_error;
  printf("callback sequence mode=%d outcome=%d events=%d cleanup=%d\n",mode,got,event,deallocated);fflush(stdout);
  assert(got==expected[mode]);assert(deallocated==(mode==1?0:1));
  if(got==LGDNSResolved){assert(!strcmp(name,"test.local"));assert(error==0);}else assert(!name[0]);
  if(mode==1||mode==3||mode==8)assert(error==-65563);
  if(mode==4)assert(error==-65554&&metrics.elapsed_ms>=20);
 }
 puts("Production DNS multi-event regressions, class/type/removal validation, negative-window, cancellation and cleanup passed");return 0;
}
