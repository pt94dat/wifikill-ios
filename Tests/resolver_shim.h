#include <stdint.h>
typedef void *DNSServiceRef;
typedef uint32_t DNSServiceFlags;
typedef int32_t DNSServiceErrorType;
enum{kDNSServiceFlagsAdd=2,kDNSServiceType_PTR=12,kDNSServiceClass_IN=1,kDNSServiceErr_NoSuchRecord=-65554};
typedef void(*DNSServiceQueryRecordReply)(DNSServiceRef,DNSServiceFlags,uint32_t,DNSServiceErrorType,const char*,uint16_t,uint16_t,uint16_t,const void*,uint32_t,void*);
int DNSServiceQueryRecord(DNSServiceRef*,uint32_t,uint32_t,const char*,uint16_t,uint16_t,DNSServiceQueryRecordReply,void*);
int DNSServiceRefSockFD(DNSServiceRef);
int DNSServiceProcessResult(DNSServiceRef);
void DNSServiceRefDeallocate(DNSServiceRef);
