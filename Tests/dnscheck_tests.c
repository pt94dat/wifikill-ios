#include "Network/LGDNSCheck.h"
#include "Network/LGIdentity.h"
#include "dnscheck_shim.h"
#include <assert.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
static int mode,fds[2],freed,removed;static char expected[256];static DNSServiceRegisterRecordReply registered;static void *ctx;
int DNSServiceCreateConnection(DNSServiceRef *ref){if(mode==1)return -1;assert(!pipe(fds));*ref=(void*)1;return 0;}
int DNSServiceRegisterRecord(DNSServiceRef ref,DNSRecordRef *record,DNSServiceFlags flags,uint32_t iface,const char *name,uint16_t type,uint16_t cls,uint16_t length,const void *data,uint32_t ttl,DNSServiceRegisterRecordReply cb,void *context){(void)ref;assert(flags==1&&iface==UINT32_MAX&&type==12&&cls==1&&ttl==10);unsigned a,b,c,d;assert(sscanf(name,"%u.%u.%u.%u.in-addr.arpa.",&a,&b,&c,&d)==4&&d==127&&c>=128);assert(lg_ptr_name(data,length,expected,sizeof(expected)));if(mode==2)return -2;*record=(void*)2;registered=cb;ctx=context;assert(write(fds[1],"x",1)==1);return 0;}
int DNSServiceRefSockFD(DNSServiceRef ref){(void)ref;return mode==3?-1:fds[0];}
int DNSServiceProcessResult(DNSServiceRef ref){char byte;assert(read(fds[0],&byte,1)==1);registered(ref,(void*)2,0,mode==4?-3:0,ctx);return 0;}
int DNSServiceRemoveRecord(DNSServiceRef ref,DNSRecordRef record,DNSServiceFlags flags){(void)ref;(void)record;(void)flags;removed++;return mode==7?-4:0;}
void DNSServiceRefDeallocate(DNSServiceRef ref){(void)ref;close(fds[0]);close(fds[1]);freed++;}
void lg_hostnames_controlled(LGDNSRequest *requests,size_t count,unsigned iface,const LGDNSControl *control){assert(count==1&&iface==UINT32_MAX&&control->hard_ms==800);requests[0].outcome=mode==5?LGDNSNoRecord:LGDNSResolved;requests[0].metrics.cleaned=1;snprintf(requests[0].name,sizeof(requests[0].name),"%s",mode==6?"old-fixture.invalid":expected);}
int main(void){for(mode=0;mode<9;mode++){freed=removed=0;LGDNSCheck check=lg_dns_positive_check();assert(freed==(mode==1?0:1));assert(removed==(mode==1||mode==2?0:1));assert(check.matched==(mode==0||mode==7||mode==8));if(mode==1||mode==2||mode==3||mode==4)assert(check.setup_code&&!check.registered);if(mode==7)assert(!check.removed);printf("LocalOnly check fixture mode=%d matched=%d connectionCleanup=%d recordRemoval=%d\n",mode,check.matched,freed,removed);}puts("Production positive-control setup/query/mismatch/failure cleanup passed; API fixture only");}
