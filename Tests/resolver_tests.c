#include "Network/LGNetwork.h"
#include "resolver_shim.h"
#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
static int fds[2],mode,deallocated;static void *ctx;static DNSServiceQueryRecordReply callback;
int DNSServiceQueryRecord(DNSServiceRef *ref,uint32_t flags,uint32_t iface,const char *name,uint16_t type,uint16_t cls,DNSServiceQueryRecordReply cb,void *context){(void)flags;(void)iface;assert(!strcmp(name,"20.2.0.192.in-addr.arpa."));assert(type==12&&cls==1);if(mode==1)return -65563;assert(!pipe(fds));if(mode!=2)assert(write(fds[1],"x",1)==1);*ref=(void*)1;ctx=context;callback=cb;return 0;}
int DNSServiceRefSockFD(DNSServiceRef ref){(void)ref;return fds[0];}
int DNSServiceProcessResult(DNSServiceRef ref){if(mode==3)return -65563;unsigned char name[]={4,'t','e','s','t',5,'l','o','c','a','l',0};if(mode==5)name[0]=63;callback(ref,2,4,mode==4?-65554:0,"",12,1,sizeof(name),name,60,ctx);return 0;}
void DNSServiceRefDeallocate(DNSServiceRef ref){(void)ref;close(fds[0]);close(fds[1]);deallocated++;}
int main(void){char name[256];int error=0;LGDNSOutcome expected[]={LGDNSResolved,LGDNSFailure,LGDNSDeadline,LGDNSFailure,LGDNSNoRecord,LGDNSMalformed};for(mode=0;mode<6;mode++){deallocated=0;LGDNSOutcome got=lg_hostname_detail("192.0.2.20",4,name,sizeof(name),20,&error);assert(got==expected[mode]);assert(deallocated==(mode==1?0:1));if(mode==0)assert(!strcmp(name,"test.local"));if(mode==1||mode==3)assert(error==-65563);if(mode==4)assert(error==-65554);}puts("Production resolver: success, API failure, deadline, callback no-record, malformed response and cleanup passed");return 0;}
