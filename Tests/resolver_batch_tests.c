#include "Network/LGNetwork.h"
#include "resolver_shim.h"
#include <assert.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef struct{int fd[2],events;unsigned suffix;void *context;DNSServiceQueryRecordReply reply;} Query;
static int negative_only,live,peak,cleaned,cancel;
int DNSServiceQueryRecord(DNSServiceRef *ref,uint32_t flags,uint32_t iface,const char *name,uint16_t type,uint16_t cls,DNSServiceQueryRecordReply cb,void *context){
 (void)iface;assert(flags==4096&&type==12&&cls==1);Query *q=calloc(1,sizeof(*q));assert(q&&!pipe(q->fd));assert(sscanf(name,"%u.2.0.192.in-addr.arpa.",&q->suffix)==1);q->context=context;q->reply=cb;*ref=q;assert(write(q->fd[1],"n",1)==1);live++;if(live>peak)peak=live;return 0;
}
int DNSServiceRefSockFD(DNSServiceRef ref){return ((Query*)ref)->fd[0];}
int DNSServiceProcessResult(DNSServiceRef ref){Query *q=ref;char event;assert(read(q->fd[0],&event,1)==1);q->events++;unsigned char name[64];char label[32];int length=snprintf(label,sizeof(label),"owned-%u",q->suffix);name[0]=(unsigned char)length;memcpy(name+1,label,(size_t)length);name[length+1]=5;memcpy(name+length+2,"local",5);name[length+7]=0;q->reply(ref,2,0,q->events==1?-65554:0,"",12,1,(uint16_t)(length+8),name,60,q->context);if(q->events==1&&!negative_only)assert(write(q->fd[1],"p",1)==1);return 0;}
void DNSServiceRefDeallocate(DNSServiceRef ref){Query *q=ref;close(q->fd[0]);close(q->fd[1]);free(q);live--;cleaned++;}
static int cancelled(void *context){(void)context;return cancel&&peak>0;}
int main(void){
 LGDNSRequest requests[130];char ips[130][16];for(unsigned i=0;i<130;i++)snprintf(ips[i],sizeof(ips[i]),"192.0.2.%u",i+1);LGDNSControl control={10,80,cancelled,NULL};
 for(int pass=0;pass<4;pass++){
  size_t count=pass?130:17;negative_only=pass==1;cancel=pass==2;peak=cleaned=0;
  for(size_t i=0;i<count;i++)requests[i].ip=ips[i];
  lg_hostnames_controlled(requests,count,0,&control);size_t resolved=0,negative=0,not_started=0,cancelled_count=0;
  for(size_t i=0;i<count;i++){resolved+=requests[i].outcome==LGDNSResolved;negative+=requests[i].outcome==LGDNSNoRecord;not_started+=requests[i].outcome==LGDNSNotAttempted;cancelled_count+=requests[i].outcome==LGDNSCancelled;if(requests[i].outcome==LGDNSResolved){char expected[64];snprintf(expected,sizeof(expected),"owned-%zu.local",i+1);assert(!strcmp(requests[i].name,expected)&&requests[i].metrics.api_error==0);}}
  assert(!live&&peak<=64);if(!pass)assert(resolved==17&&cleaned==17&&peak==17);if(pass==1)assert(negative==64&&not_started==66&&cleaned==64);if(pass==2)assert(cancelled_count==130&&cleaned==64);if(pass==3)assert(resolved==130&&cleaned==130&&peak==64);
  printf("Owned batch: n=%zu resolved=%zu negative=%zu notStarted=%zu cancelled=%zu peakRefs=%d cleaned=%d\n",count,resolved,negative,not_started,cancelled_count,peak,cleaned);
 }
 /* Force frequent deadline crossings while slots are opening/closing. */
 control.hard_ms=1;cancel=0;
 for(int repeat=0;repeat<200;repeat++){peak=cleaned=0;negative_only=repeat%2;for(size_t i=0;i<130;i++)requests[i].ip=ips[i];lg_hostnames_controlled(requests,130,0,&control);assert(!live&&peak<=64);}
 puts("200 short-deadline batch cycles: no retained references");
 puts("Production DNS event-loop coverage and active-reference bounds passed; callback fixture only");
}
