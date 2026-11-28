#ifndef LG_HOST_PROBE_H
#define LG_HOST_PROBE_H
/* Combined evidence: TCP first-class result, independent ICMP response fallback.
 * Uses public datagram ICMP through Apple's licensed SimplePing implementation. */
int lg_discover_detail(const char *ip,unsigned timeout_ms,double *latency_ms,int *evidence,int *icmp_error);
#endif
