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
static size_t aligned(size_t n) { return n ? (n+3)&~(size_t)3 : 4; }
static void routes(LGNetwork *net, const char *ip, char *mac, size_t cap) {
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
  if(net && a[LGRouteDestination] && a[LGRouteGateway] && a[LGRouteDestination]->sa_family==AF_INET && a[LGRouteGateway]->sa_family==AF_INET && (r->flags&LGRouteGatewayFlag) && r->index==if_nametoindex(net->interface)){
   struct sockaddr_in *dst=(void*)a[LGRouteDestination], *gw=(void*)a[LGRouteGateway];
   if(dst->sin_addr.s_addr==0)inet_ntop(AF_INET,&gw->sin_addr,net->gateway,sizeof(net->gateway));
  }
  if(ip && mac && a[LGRouteDestination] && a[LGRouteGateway] && a[LGRouteDestination]->sa_family==AF_INET && a[LGRouteGateway]->sa_family==AF_LINK){
   char addr[16];struct sockaddr_in *dst=(void*)a[LGRouteDestination];inet_ntop(AF_INET,&dst->sin_addr,addr,sizeof(addr));
   struct sockaddr_dl *dl=(void*)a[LGRouteGateway];
   if(!strcmp(addr,ip)&&dl->sdl_alen==6 && offsetof(struct sockaddr_dl,sdl_data)+dl->sdl_nlen+6<=dl->sdl_len){
    unsigned char *b=(void*)LLADDR(dl);snprintf(mac,cap,"%02x:%02x:%02x:%02x:%02x:%02x",b[0],b[1],b[2],b[3],b[4],b[5]);
   }
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
  routes(&candidate,NULL,NULL,0);if(!out->address||candidate.gateway[0])*out=candidate;
  if(candidate.gateway[0])break;
 }
 freeifaddrs(all);return out->address?0:-1;
}
int lg_mac(const char *ip,char *out,size_t size){if(!size)return -1;out[0]=0;routes(NULL,ip,out,size);return out[0]?0:-1;}
static double clock_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.0+t.tv_nsec/1e6;}
int lg_probe(const char *ip,unsigned timeout_ms,double *latency_ms){
 struct sockaddr_in a={0};a.sin_len=sizeof(a);a.sin_family=AF_INET;a.sin_port=htons(443);
 if(inet_pton(AF_INET,ip,&a.sin_addr)!=1)return 0;
 int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0)return 0;
 fcntl(fd,F_SETFL,O_NONBLOCK);double start=clock_ms();int rc=connect(fd,(void*)&a,sizeof(a));int reachable=rc==0;
 if(rc<0 && errno==EINPROGRESS){struct pollfd p={fd,POLLOUT,0};if(poll(&p,1,(int)timeout_ms)>0){int e=0;socklen_t len=sizeof(e);if(!getsockopt(fd,SOL_SOCKET,SO_ERROR,&e,&len))reachable=e==0||e==ECONNREFUSED;}}
 if(latency_ms)*latency_ms=clock_ms()-start;close(fd);return reachable;
}
