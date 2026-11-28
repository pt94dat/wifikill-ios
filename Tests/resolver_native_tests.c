#include "Network/LGNetwork.h"
#include "Network/LGDNSCheck.h"
#include <dns_sd.h>
#include <poll.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
static int registered;
static void reply(DNSServiceRef ref,DNSRecordRef record,DNSServiceFlags flags,DNSServiceErrorType error,void *context){(void)ref;(void)record;(void)flags;(void)context;registered=error?error:1;}
int main(void){DNSServiceRef ref=NULL;DNSRecordRef record=NULL;assert(!DNSServiceCreateConnection(&ref));const char *q="77.113.0.203.in-addr.arpa.";unsigned char data[64];const char *label="languard-fixture";size_t n=strlen(label);data[0]=(unsigned char)n;memcpy(data+1,label,n);data[n+1]=5;memcpy(data+n+2,"local",5);data[n+7]=0;
 int result=DNSServiceRegisterRecord(ref,&record,kDNSServiceFlagsUnique,kDNSServiceInterfaceIndexLocalOnly,q,kDNSServiceType_PTR,kDNSServiceClass_IN,(uint16_t)(n+8),data,60,reply,NULL);assert(!result);
 for(int i=0;i<20&&!registered;i++){struct pollfd p={DNSServiceRefSockFD(ref),POLLIN,0};if(poll(&p,1,50)>0)assert(!DNSServiceProcessResult(ref));}assert(registered==1);
 unsigned budgets[]={400,800,1500,3000};for(unsigned i=0;i<4;i++){char name[256];LGDNSMetrics metrics;LGDNSControl control={400,budgets[i],NULL,NULL};LGDNSOutcome outcome=lg_hostname_controlled("203.0.113.77",kDNSServiceInterfaceIndexLocalOnly,name,sizeof(name),&control,&metrics);printf("Actual controlled PTR hard=%u outcome=%d code=%d elapsedMS=%.1f cleaned=%d\n",budgets[i],outcome,metrics.api_error,metrics.elapsed_ms,metrics.cleaned);assert(outcome==LGDNSResolved&&!strcmp(name,"languard-fixture.local")&&metrics.cleaned);}
 LGDNSRequest batch[17]={0};for(unsigned i=0;i<17;i++)batch[i].ip="203.0.113.77";LGDNSControl control={400,3000,NULL,NULL};lg_hostnames_controlled(batch,17,kDNSServiceInterfaceIndexLocalOnly,&control);for(unsigned i=0;i<17;i++)assert(batch[i].outcome==LGDNSResolved&&!strcmp(batch[i].name,"languard-fixture.local")&&batch[i].metrics.cleaned);puts("Actual host DNS-SD batch: 17 subscriptions to one owned PTR resolved and cleaned; not 17 devices");
 assert(!DNSServiceRemoveRecord(ref,record,0));DNSServiceRefDeallocate(ref);puts("Actual macOS DNS-SD registration/query/deallocation passed; not an iPhone runtime test");for(int run=0;run<10;run++){LGDNSCheck check=lg_dns_positive_check();printf("Production LocalOnly positive check run=%d setup=%d registered=%d outcome=%d matched=%d removed=%d cleaned=%d elapsed=%.1f\n",run,check.setup_code,check.registered,check.outcome,check.matched,check.removed,check.cleaned,check.elapsed_ms);fflush(stdout);assert(!check.setup_code&&check.registered&&check.matched&&check.removed&&check.cleaned);}return 0;}
