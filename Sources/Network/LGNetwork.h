#ifndef LGNetwork_h
#define LGNetwork_h
#include <stdint.h>
#include <stddef.h>
typedef struct { char interface[32], ip[16], mask[16], gateway[16]; uint32_t address, netmask; } LGNetwork;
int lg_network(LGNetwork *out);
int lg_probe(const char *ip, unsigned timeout_ms, double *latency_ms);
typedef struct {char ip[16],mac[18];} LGNeighbor;
size_t lg_neighbors(const LGNetwork *net,LGNeighbor *out,size_t capacity,unsigned *rejected);
int lg_hostname(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms);
int lg_mac(const char *ip, char *out, size_t size);
#endif
