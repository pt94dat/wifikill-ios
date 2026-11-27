#ifndef LGNetwork_h
#define LGNetwork_h
#include <stdint.h>
#include <stddef.h>
typedef struct { char interface[32], ip[16], mask[16], gateway[16]; uint32_t address, netmask; } LGNetwork;
int lg_network(LGNetwork *out);
int lg_probe_detail(const char *ip,unsigned timeout_ms,double *latency_ms,int *evidence);
int lg_probe(const char *ip, unsigned timeout_ms, double *latency_ms);
#include "LGNeighborParser.h"
LGNeighborStats lg_neighbor_stats(void);
int lg_neighbor_view_status(void);
size_t lg_neighbors(const LGNetwork *net,LGNeighbor *out,size_t capacity,unsigned *rejected);
typedef enum { LGDNSNotAttempted,LGDNSResolved,LGDNSDeadline,LGDNSNoRecord,LGDNSFailure,LGDNSMalformed,LGDNSCancelled } LGDNSOutcome;
typedef struct {unsigned soft_ms,hard_ms;int (*cancelled)(void*);void *context;} LGDNSControl;
typedef struct {int api_error,soft_exceeded,cleaned;double elapsed_ms;} LGDNSMetrics;
LGDNSOutcome lg_hostname_controlled(const char *ip,unsigned interface_index,char *out,size_t capacity,const LGDNSControl *control,LGDNSMetrics *metrics);
LGDNSOutcome lg_hostname_detail(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms,int *api_error);
int lg_hostname(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms);
#endif
