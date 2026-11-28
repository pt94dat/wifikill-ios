#include "resolver_shim.h"
typedef void *DNSRecordRef;
enum{kDNSServiceFlagsUnique=1};
#define kDNSServiceInterfaceIndexLocalOnly UINT32_MAX
typedef void(*DNSServiceRegisterRecordReply)(DNSServiceRef,DNSRecordRef,DNSServiceFlags,DNSServiceErrorType,void*);
int DNSServiceCreateConnection(DNSServiceRef*);
int DNSServiceRegisterRecord(DNSServiceRef,DNSRecordRef*,DNSServiceFlags,uint32_t,const char*,uint16_t,uint16_t,uint16_t,const void*,uint32_t,DNSServiceRegisterRecordReply,void*);
int DNSServiceRemoveRecord(DNSServiceRef,DNSRecordRef,DNSServiceFlags);
