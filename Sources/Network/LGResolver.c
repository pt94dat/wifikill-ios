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
 (void)ref;(void)index;(void)name;(void)ttl;LGNameResult *r=context;
 if(r->finished)return;
 /* ReturnIntermediates delivers observations, not end-of-query markers.
  * Keep the subscription alive until a usable PTR, terminal failure, cancel or deadline. */
 if(error==kDNSServiceErr_NoSuchRecord){r->error=error;r->outcome=LGDNSNoRecord;return;}
 if(error){r->error=error;r->outcome=LGDNSFailure;r->finished=1;return;}
 if((flags&kDNSServiceFlagsAdd)&&type==kDNSServiceType_PTR&&cls==kDNSServiceClass_IN&&data){
  if(lg_ptr_name(data,length,r->out,r->capacity)){r->outcome=LGDNSResolved;r->error=0;r->finished=1;}
  else{r->outcome=LGDNSMalformed;r->error=0;}
 }
}
LGDNSOutcome lg_hostname_controlled(const char *ip,unsigned interface_index,char *out,size_t capacity,const LGDNSControl *control,LGDNSMetrics *metrics){
 LGDNSMetrics local={0};if(!metrics)metrics=&local;memset(metrics,0,sizeof(*metrics));double began=clock_ms();
 unsigned timeout_ms=control?control->hard_ms:400;if(timeout_ms>3000)timeout_ms=3000;
 if(!out||!capacity)return LGDNSFailure;
 out[0]=0;
 if(control&&control->cancelled&&control->cancelled(control->context))return LGDNSCancelled;
 struct in_addr addr;if(inet_pton(AF_INET,ip,&addr)!=1)return LGDNSFailure;unsigned char *bytes=(void*)&addr;
 char reverse[80];snprintf(reverse,sizeof(reverse),"%u.%u.%u.%u.in-addr.arpa.",bytes[3],bytes[2],bytes[1],bytes[0]);
 DNSServiceRef ref=NULL;LGNameResult result={out,capacity,0,0,LGDNSDeadline};
 int error=DNSServiceQueryRecord(&ref,kDNSServiceFlagsReturnIntermediates,interface_index,reverse,kDNSServiceType_PTR,kDNSServiceClass_IN,name_reply,&result);
 if(error){metrics->api_error=error;return LGDNSFailure;}
 int fd=DNSServiceRefSockFD(ref);double deadline=clock_ms()+timeout_ms;
 if(fd<0){result.outcome=LGDNSFailure;result.error=fd;}
 while(fd>=0&&!result.finished&&clock_ms()<deadline){struct pollfd p={fd,POLLIN,0};if(control&&control->cancelled&&control->cancelled(control->context)){result.outcome=LGDNSCancelled;break;}int remain=(int)(deadline-clock_ms());if(remain<1)break;if(remain>50)remain=50;int ready=poll(&p,1,remain);if(ready<0&&errno==EINTR)continue;if(ready<0){result.outcome=LGDNSFailure;result.error=errno;break;}if(!ready)continue;
  if(!(p.revents&POLLIN)){result.outcome=LGDNSFailure;result.error=EIO;break;}
  error=DNSServiceProcessResult(ref);if(error){result.outcome=LGDNSFailure;result.error=error;break;}}
 if(result.outcome!=LGDNSResolved)out[0]=0;
 DNSServiceRefDeallocate(ref);metrics->cleaned=1;metrics->elapsed_ms=clock_ms()-began;metrics->api_error=result.error;metrics->soft_exceeded=control&&metrics->elapsed_ms>control->soft_ms;return result.outcome;
}
LGDNSOutcome lg_hostname_detail(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms,int *api_error){
 LGDNSControl control={timeout_ms,timeout_ms,NULL,NULL};LGDNSMetrics metrics;LGDNSOutcome result=lg_hostname_controlled(ip,interface_index,out,capacity,&control,&metrics);if(api_error)*api_error=metrics.api_error;return result;
}
int lg_hostname(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms){return lg_hostname_detail(ip,interface_index,out,capacity,timeout_ms,NULL)==LGDNSResolved;}

/* A bounded DNS-SD event loop avoids parking one worker for every negative reply.
 * Queries retain their own state; all published results still belong to one scan generation. */
void lg_hostnames_controlled(LGDNSRequest *requests,size_t count,unsigned interface_index,const LGDNSControl *control){
 enum{slots=64};
 DNSServiceRef refs[slots]={0};LGNameResult results[slots];struct pollfd fds[slots];
 size_t indices[slots]={0},next=0;double started[slots]={0};unsigned active=0;
 unsigned budget=control?control->hard_ms:400;if(budget>3000)budget=3000;
 double deadline=clock_ms()+budget;if(count>1024)count=1024;
 for(size_t i=0;i<count;i++){requests[i].name[0]=0;requests[i].outcome=LGDNSNotAttempted;memset(&requests[i].metrics,0,sizeof(requests[i].metrics));}
 while(next<count||active){
  int cancelled=control&&control->cancelled&&control->cancelled(control->context);
  int stopped=cancelled||clock_ms()>=deadline;
  if(stopped){
   for(unsigned s=0;s<slots;s++)if(refs[s]){if(cancelled)results[s].outcome=LGDNSCancelled;results[s].finished=1;}
   if(cancelled)for(size_t i=next;i<count;i++)requests[i].outcome=LGDNSCancelled;
  }
  for(unsigned s=0;s<slots;s++)if(refs[s]&&results[s].finished){
   LGDNSRequest *request=&requests[indices[s]];request->outcome=results[s].outcome;request->metrics.api_error=results[s].error;
   request->metrics.elapsed_ms=clock_ms()-started[s];request->metrics.soft_exceeded=control&&request->metrics.elapsed_ms>control->soft_ms;
   if(request->outcome!=LGDNSResolved)request->name[0]=0;
   DNSServiceRefDeallocate(refs[s]);refs[s]=NULL;request->metrics.cleaned=1;active--;
  }
  if(stopped)break;
  if(clock_ms()>=deadline)continue;
  for(unsigned s=0;s<slots&&next<count;s++)if(!refs[s]){
   size_t i=next++;LGDNSRequest *request=&requests[i];struct in_addr addr;
   if(!request->ip||inet_pton(AF_INET,request->ip,&addr)!=1){request->outcome=LGDNSFailure;continue;}
   unsigned char *b=(void*)&addr;char reverse[80];snprintf(reverse,sizeof(reverse),"%u.%u.%u.%u.in-addr.arpa.",b[3],b[2],b[1],b[0]);
   results[s]=(LGNameResult){request->name,sizeof(request->name),0,0,LGDNSDeadline};indices[s]=i;started[s]=clock_ms();
   int error=DNSServiceQueryRecord(&refs[s],kDNSServiceFlagsReturnIntermediates,interface_index,reverse,kDNSServiceType_PTR,kDNSServiceClass_IN,name_reply,&results[s]);
   if(error){refs[s]=NULL;request->outcome=LGDNSFailure;request->metrics.api_error=error;continue;}
   active++;fds[s]=(struct pollfd){DNSServiceRefSockFD(refs[s]),POLLIN,0};
   if(fds[s].fd<0){results[s].finished=1;results[s].outcome=LGDNSFailure;results[s].error=EIO;}
  }
  if(!active)continue;
  int remain=(int)(deadline-clock_ms());if(remain<1)continue;if(remain>50)remain=50;
  for(unsigned s=0;s<slots;s++){fds[s].revents=0;if(!refs[s])fds[s].fd=-1;}
  int ready=poll(fds,slots,remain);if(ready<0&&errno==EINTR)continue;
  for(unsigned s=0;s<slots;s++)if(refs[s]&&(ready<0||fds[s].revents)){
   int error=ready<0?errno:(!(fds[s].revents&POLLIN)?EIO:DNSServiceProcessResult(refs[s]));
   if(error){results[s].finished=1;results[s].outcome=LGDNSFailure;results[s].error=error;}
  }
 }
}
