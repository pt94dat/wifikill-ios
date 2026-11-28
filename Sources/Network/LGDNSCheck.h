#ifndef LG_DNS_CHECK_H
#define LG_DNS_CHECK_H
#include "LGNetwork.h"
typedef struct {int setup_code,registered,query_code,removed,matched,cleaned;LGDNSOutcome outcome;double elapsed_ms;} LGDNSCheck;
/* Own LocalOnly fixture only. Does not discover or identify any LAN device. */
LGDNSCheck lg_dns_positive_check(void);
#endif
