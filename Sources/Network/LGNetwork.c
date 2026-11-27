#include "LGNetwork.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include "LGRouteABI.h"
#include <net/if_dl.h>
#include <net/if_types.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <poll.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <dns_sd.h>
#include "LGIdentity.h"
static size_t aligned(size_t n) { return n ? (n+3)&~(size_t)3 : 4; }
static void routes(LGNetwork *net) {
 int mib[]={CTL_NET,PF_ROUTE,0,AF_INET,NET_RT_DUMP,0}; size_t size=0;
 if(sysctl(mib,6,NULL,&size,NULL,0)<0 || !size || size>16*1024*1024)return;
 char *buf=malloc(size); if(!buf)return;
 if(sysctl(mib,6,buf,&size,NULL,0)<0){free(buf);return;}
 for(char *p=buf;p+sizeof(LGRouteHeader)<=buf+size;){
  LGRouteHeader *r=(void*)p;
  if(r->length<sizeof(*r)||p+r->length>buf+size)break;
  struct sockaddr *a[LGRouteAddressCount]={0}; char *s=p+sizeof(*r);
  for(int i=0;i<LGRouteAddressCount;i++)if(r->addresses&(1<<i)){
   if(s+2>p+r->length)break;
   struct sockaddr *sa=(void*)s;size_t len=aligned(sa->sa_len);
   if(s+len>p+r->length)break;
   a[i]=sa;s+=len;
  }
  if(net && a[LGRouteDestination] && a[LGRouteGateway] && a[LGRouteDestination]->sa_family==AF_INET && a[LGRouteDestination]->sa_len>=sizeof(struct sockaddr_in) && a[LGRouteGateway]->sa_family==AF_INET && a[LGRouteGateway]->sa_len>=sizeof(struct sockaddr_in) && (r->flags&LGRouteGatewayFlag) && r->index==if_nametoindex(net->interface)){
   struct sockaddr_in *dst=(void*)a[LGRouteDestination], *gw=(void*)a[LGRouteGateway];
   if(dst->sin_addr.s_addr==0)inet_ntop(AF_INET,&gw->sin_addr,net->gateway,sizeof(net->gateway));
  }
  p+=r->length;
 }
 free(buf);
}
int lg_network(LGNetwork *out){
 memset(out,0,sizeof(*out));struct ifaddrs *all=NULL;
 if(getifaddrs(&all))return -1;
 for(struct ifaddrs *p=all;p;p=p->ifa_next){
  if(!p->ifa_addr||!p->ifa_netmask||p->ifa_addr->sa_family!=AF_INET||!(p->ifa_flags&IFF_UP)||(p->ifa_flags&IFF_LOOPBACK))continue;
  int ethernet=0;
  for(struct ifaddrs *link=all;link;link=link->ifa_next){
   if(link->ifa_addr&&link->ifa_addr->sa_family==AF_LINK&&!strcmp(link->ifa_name,p->ifa_name)){
    struct sockaddr_dl *dl=(void*)link->ifa_addr;ethernet=dl->sdl_type==IFT_ETHER;break;
   }
  }
  if(!ethernet)continue;
  LGNetwork candidate={0};struct sockaddr_in *a=(void*)p->ifa_addr,*m=(void*)p->ifa_netmask;
  strlcpy(candidate.interface,p->ifa_name,sizeof(candidate.interface));
  inet_ntop(AF_INET,&a->sin_addr,candidate.ip,sizeof(candidate.ip));inet_ntop(AF_INET,&m->sin_addr,candidate.mask,sizeof(candidate.mask));
  candidate.address=ntohl(a->sin_addr.s_addr);candidate.netmask=ntohl(m->sin_addr.s_addr);
  routes(&candidate);if(!out->address||candidate.gateway[0])*out=candidate;
  if(candidate.gateway[0])break;
 }
 freeifaddrs(all);return out->address?0:-1;
}

static double clock_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1e6;}
int lg_probe_detail(const char *ip,unsigned timeout_ms,double *latency_ms,int *evidence){
 if(evidence)*evidence=0;
 struct sockaddr_in a={0};a.sin_len=sizeof(a);a.sin_family=AF_INET;a.sin_port=htons(443);
 if(inet_pton(AF_INET,ip,&a.sin_addr)!=1)return 0;
 int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0)return 0;
 fcntl(fd,F_SETFL,O_NONBLOCK);double start=clock_ms();int rc=connect(fd,(void*)&a,sizeof(a));int reachable=rc==0;int kind=rc==0?1:0;if(rc<0&&errno==ECONNREFUSED){reachable=1;kind=2;}
 if(rc<0 && errno==EINPROGRESS){struct pollfd p={fd,POLLOUT,0};if(poll(&p,1,(int)timeout_ms)>0){int e=0;socklen_t len=sizeof(e);if(!getsockopt(fd,SOL_SOCKET,SO_ERROR,&e,&len))reachable=e==0||e==ECONNREFUSED;kind=e==0?1:(e==ECONNREFUSED?2:0);}}
 if(latency_ms)*latency_ms=clock_ms()-start;if(evidence)*evidence=kind;close(fd);return reachable;
}

int lg_probe(const char *ip,unsigned timeout_ms,double *latency_ms){return lg_probe_detail(ip,timeout_ms,latency_ms,NULL);}

static LGNeighborStats neighbor_stats;
LGNeighborStats lg_neighbor_stats(void){return neighbor_stats;}
int lg_neighbor_view_status(void){return neighbor_stats.view;}
size_t lg_neighbors(const LGNetwork *net,LGNeighbor *out,size_t capacity,unsigned *rejected){
 /* Ordinary read-only view only; no private mode/entitlement requested. */
 int mib[]={CTL_NET,PF_ROUTE,0,AF_INET,NET_RT_DUMP,0};size_t length=0;memset(&neighbor_stats,0,sizeof(neighbor_stats));
 if(sysctl(mib,6,NULL,&length,NULL,0)){neighbor_stats.apiError=errno;neighbor_stats.view=3;return 0;}
 if(!length||length>16*1024*1024){neighbor_stats.view=3;return 0;}
 unsigned char *buffer=malloc(length);if(!buffer){neighbor_stats.apiError=ENOMEM;neighbor_stats.view=3;return 0;}
 if(sysctl(mib,6,buffer,&length,NULL,0)){neighbor_stats.apiError=errno;neighbor_stats.view=3;free(buffer);return 0;}
 size_t count=lg_parse_neighbors(buffer,length,if_nametoindex(net->interface),net->address,net->netmask,out,capacity,&neighbor_stats);free(buffer);
 neighbor_stats.view=count?0:(neighbor_stats.placeholder||neighbor_stats.zero?2:3);
 if(rejected)*rejected=neighbor_stats.placeholder+neighbor_stats.zero+neighbor_stats.multicast;
 return count;
}
