#include "LGNetwork.h"
#include "LGIdentity.h"
#include <arpa/inet.h>
#include <poll.h>
#include <errno.h>
#include <time.h>
#include <stdio.h>
#include <string.h>
#ifdef LG_RESOLVER_TEST
#include "resolver_shim.h"
#else
#include <dns_sd.h>
#endif
static double clock_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1e6;}
typedef struct{char *out;size_t capacity;int finished,error;LGDNSOutcome outcome;} LGNameResult;
static void name_reply(DNSServiceRef ref,DNSServiceFlags flags,uint32_t index,DNSServiceErrorType error,const char *name,uint16_t type,uint16_t cls,uint16_t length,const void *data,uint32_t ttl,void *context){
 (void)ref;(void)index;(void)name;(void)cls;(void)ttl;LGNameResult *r=context;
 if(error){r->error=error;r->outcome=error==kDNSServiceErr_NoSuchRecord?LGDNSNoRecord:LGDNSFailure;r->finished=1;return;}
 if((flags&kDNSServiceFlagsAdd)&&type==kDNSServiceType_PTR&&data){r->outcome=lg_ptr_name(data,length,r->out,r->capacity)?LGDNSResolved:LGDNSMalformed;r->finished=1;}
}
LGDNSOutcome lg_hostname_controlled(const char *ip,unsigned interface_index,char *out,size_t capacity,const LGDNSControl *control,LGDNSMetrics *metrics){
 LGDNSMetrics local={0};if(!metrics)metrics=&local;memset(metrics,0,sizeof(*metrics));double began=clock_ms();
 unsigned timeout_ms=control?control->hard_ms:400;if(timeout_ms>3000)timeout_ms=3000;
 if(control&&control->cancelled&&control->cancelled(control->context))return LGDNSCancelled;
 if(!capacity)return LGDNSFailure;
 out[0]=0;struct in_addr addr;if(inet_pton(AF_INET,ip,&addr)!=1)return LGDNSFailure;unsigned char *bytes=(void*)&addr;
 char reverse[80];snprintf(reverse,sizeof(reverse),"%u.%u.%u.%u.in-addr.arpa.",bytes[3],bytes[2],bytes[1],bytes[0]);
 DNSServiceRef ref=NULL;LGNameResult result={out,capacity,0,0,LGDNSDeadline};
 int error=DNSServiceQueryRecord(&ref,kDNSServiceFlagsReturnIntermediates,interface_index,reverse,kDNSServiceType_PTR,kDNSServiceClass_IN,name_reply,&result);
 if(error){metrics->api_error=error;return LGDNSFailure;}
 int fd=DNSServiceRefSockFD(ref);double deadline=clock_ms()+timeout_ms;
 if(fd<0){result.outcome=LGDNSFailure;result.error=fd;}
 while(fd>=0&&!result.finished&&clock_ms()<deadline){struct pollfd p={fd,POLLIN,0};if(control&&control->cancelled&&control->cancelled(control->context)){result.outcome=LGDNSCancelled;break;}int remain=(int)(deadline-clock_ms());if(remain<1)break;if(remain>50)remain=50;int ready=poll(&p,1,remain);if(ready<0&&errno==EINTR)continue;if(ready<0){result.outcome=LGDNSFailure;result.error=errno;break;}if(!ready)continue;
  error=DNSServiceProcessResult(ref);if(error){result.outcome=LGDNSFailure;result.error=error;break;}}
 DNSServiceRefDeallocate(ref);metrics->cleaned=1;metrics->elapsed_ms=clock_ms()-began;metrics->api_error=result.error;metrics->soft_exceeded=control&&metrics->elapsed_ms>control->soft_ms;return result.outcome;
}
LGDNSOutcome lg_hostname_detail(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms,int *api_error){
 LGDNSControl control={timeout_ms,timeout_ms,NULL,NULL};LGDNSMetrics metrics;LGDNSOutcome result=lg_hostname_controlled(ip,interface_index,out,capacity,&control,&metrics);if(api_error)*api_error=metrics.api_error;return result;
}
int lg_hostname(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms){return lg_hostname_detail(ip,interface_index,out,capacity,timeout_ms,NULL)==LGDNSResolved;}
