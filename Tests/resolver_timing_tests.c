#include "Network/LGNetwork.h"
#include "resolver_shim.h"
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <time.h>
#include <string.h>
static int fds[2],deallocated,events;static unsigned delay;static pthread_t writer;static void *ctx;static DNSServiceQueryRecordReply callback;
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1e6;}
static void *write_later(void *arg){int fd=*(int*)arg;struct timespec t={delay/1000,(delay%1000)*1000000};nanosleep(&t,NULL);ssize_t ignored=write(fd,"x",1);(void)ignored;return NULL;}
int DNSServiceQueryRecord(DNSServiceRef *ref,uint32_t flags,uint32_t iface,const char *name,uint16_t type,uint16_t cls,DNSServiceQueryRecordReply cb,void *context){(void)iface;(void)name;assert(flags&4096);assert(type==12&&cls==1);assert(!pipe(fds));callback=cb;ctx=context;*ref=(void*)1;events=0;assert(write(fds[1],"n",1)==1);assert(!pthread_create(&writer,NULL,write_later,&fds[1]));return 0;}
int DNSServiceRefSockFD(DNSServiceRef ref){(void)ref;return fds[0];}
int DNSServiceProcessResult(DNSServiceRef ref){char event;assert(read(fds[0],&event,1)==1);events++;if(events==1){callback(ref,2,4,-65554,"",12,1,0,NULL,0,ctx);return 0;}unsigned char name[]={4,'l','a','t','e',5,'l','o','c','a','l',0};callback(ref,2,4,0,"",12,1,sizeof(name),name,60,ctx);return 0;}
void DNSServiceRefDeallocate(DNSServiceRef ref){(void)ref;close(fds[0]);deallocated++;}
static int cancelled(void *context){return now()-*(double*)context>=120;}
int main(void){signal(SIGPIPE,SIG_IGN);unsigned budgets[]={400,800,1500,3000};for(unsigned i=0;i<4;i++){delay=650;deallocated=0;LGDNSControl control={400,budgets[i],NULL,NULL};LGDNSMetrics metrics;char name[256];LGDNSOutcome result=lg_hostname_controlled("192.0.2.20",0,name,sizeof(name),&control,&metrics);printf("Synthetic daemon delay=650ms hard=%u outcome=%d elapsed=%.1f late=%d cleanup=%d\n",budgets[i],result,metrics.elapsed_ms,metrics.soft_exceeded,metrics.cleaned);assert(deallocated==1&&metrics.cleaned);assert(result==(budgets[i]<650?LGDNSNoRecord:LGDNSResolved));if(result==LGDNSResolved)assert(!strcmp(name,"late.local")&&metrics.soft_exceeded);pthread_join(writer,NULL);close(fds[1]);}
 delay=650;double start=now();LGDNSControl control={400,3000,cancelled,&start};LGDNSMetrics metrics;char name[256];assert(lg_hostname_controlled("192.0.2.20",0,name,sizeof(name),&control,&metrics)==LGDNSCancelled);assert(metrics.elapsed_ms<500&&metrics.cleaned);pthread_join(writer,NULL);close(fds[1]);puts("Production soft/hard deadlines, useful late result and cancellation cleanup passed; synthetic transport, not physical network");return 0;}
