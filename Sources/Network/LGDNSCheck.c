#include "LGDNSCheck.h"
#ifdef LG_DNS_CHECK_TEST
#include "dnscheck_shim.h"
#define arc4random() 0x12345678u
#else
#include <dns_sd.h>
#endif
#include <poll.h>
#include <time.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
static double now_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1e6;}
static void registered_reply(DNSServiceRef ref,DNSRecordRef record,DNSServiceFlags flags,DNSServiceErrorType error,void *context){(void)ref;(void)record;(void)flags;int *state=context;*state=error?error:1;}
LGDNSCheck lg_dns_positive_check(void){
 LGDNSCheck result={0};double began=now_ms();DNSServiceRef connection=NULL;DNSRecordRef record=NULL;int registered=0,owns_record=0;
 result.setup_code=DNSServiceCreateConnection(&connection);if(result.setup_code)goto done;
 /* Unique label prevents a cached earlier run being mistaken for this run's registration. */
 char label[64],expected[80];snprintf(label,sizeof(label),"languard-check-%08x",arc4random());snprintf(expected,sizeof(expected),"%s.invalid",label);
 size_t n=strlen(label);unsigned char data[96];data[0]=(unsigned char)n;memcpy(data+1,label,n);data[n+1]=7;memcpy(data+n+2,"invalid",7);data[n+9]=0;
 result.setup_code=DNSServiceRegisterRecord(connection,&record,kDNSServiceFlagsUnique,kDNSServiceInterfaceIndexLocalOnly,"77.113.0.203.in-addr.arpa.",kDNSServiceType_PTR,kDNSServiceClass_IN,(uint16_t)(n+10),data,10,registered_reply,&registered);
 if(result.setup_code)goto cleanup;
 owns_record=1;
 double deadline=now_ms()+1000;int fd=DNSServiceRefSockFD(connection);if(fd<0){result.setup_code=EIO;goto cleanup;}
 while(!registered&&fd>=0&&now_ms()<deadline){struct pollfd p={fd,POLLIN,0};int ready=poll(&p,1,25);if(ready<0&&errno==EINTR)continue;if(ready<0){result.setup_code=errno;break;}if(ready>0){if(!(p.revents&POLLIN)){result.setup_code=EIO;break;}result.setup_code=DNSServiceProcessResult(connection);if(result.setup_code)break;}}
 if(registered!=1){if(!result.setup_code)result.setup_code=registered?registered:ETIMEDOUT;goto cleanup;}
 result.registered=1;LGDNSRequest request={0};request.ip="203.0.113.77";LGDNSControl control={400,800,NULL,NULL};lg_hostnames_controlled(&request,1,kDNSServiceInterfaceIndexLocalOnly,&control);result.outcome=request.outcome;result.query_code=request.metrics.api_error;result.matched=request.outcome==LGDNSResolved&&!strcmp(request.name,expected);result.cleaned=request.metrics.cleaned;
cleanup:
 if(owns_record)result.removed=DNSServiceRemoveRecord(connection,record,0)==0;
 DNSServiceRefDeallocate(connection);
done:
 result.elapsed_ms=now_ms()-began;return result;
}
