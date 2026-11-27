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

static int neighbor_view=0;
int lg_neighbor_view_status(void){return neighbor_view;}
static size_t neighbor_snapshot(const LGNetwork *net,LGNeighbor *out,size_t capacity,unsigned *rejected,int mode){
 if(rejected)*rejected=0;int mib[]={CTL_NET,PF_ROUTE,0,AF_INET,mode,mode==10?0x400:0};size_t length=0,count=0;
 if(sysctl(mib,6,NULL,&length,NULL,0)||!length||length>16*1024*1024)return 0;
 unsigned char *buffer=malloc(length);if(!buffer)return 0;
 if(sysctl(mib,6,buffer,&length,NULL,0)){free(buffer);return 0;}
 unsigned iface=if_nametoindex(net->interface);
 for(size_t p=0;p+sizeof(LGRouteHeader)<=length;){
  LGRouteHeader header;memcpy(&header,buffer+p,sizeof(header));if(header.length<sizeof(header)||header.length>length-p)break;
  struct sockaddr *a[LGRouteAddressCount]={0};size_t offset=p+sizeof(header);int valid=1;
  for(int i=0;i<LGRouteAddressCount;i++)if(header.addresses&(1<<i)){
   if(offset+2>p+header.length){valid=0;break;}struct sockaddr *sa=(void*)(buffer+offset);size_t n=aligned(sa->sa_len);
   if(sa->sa_len<2||n>p+header.length-offset){valid=0;break;}a[i]=sa;offset+=n;
  }
  if(valid&&header.index==iface&&a[0]&&a[1]&&a[0]->sa_family==AF_INET&&a[0]->sa_len>=sizeof(struct sockaddr_in)&&a[1]->sa_family==AF_LINK){
   struct sockaddr_in *address=(void*)a[0];struct sockaddr_dl *link=(void*)a[1];uint32_t host=ntohl(address->sin_addr.s_addr);
   if((host&net->netmask)==(net->address&net->netmask)&&link->sdl_len>=offsetof(struct sockaddr_dl,sdl_data)&&link->sdl_alen==6&&offsetof(struct sockaddr_dl,sdl_data)+link->sdl_nlen+6<=link->sdl_len){
    unsigned char *bytes=(void*)LLADDR(link);char raw[18],mac[18];snprintf(raw,18,"%02x:%02x:%02x:%02x:%02x:%02x",bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5]);
    if(lg_normalize_mac(raw,mac)){if(count<capacity){inet_ntop(AF_INET,&address->sin_addr,out[count].ip,16);memcpy(out[count].mac,mac,18);count++;}}else if(rejected)(*rejected)++;
   }
  }p+=header.length;
 }free(buffer);return count;
}
size_t lg_neighbors(const LGNetwork *net,LGNeighbor *out,size_t capacity,unsigned *rejected){
 // XNU exposes NET_RT_FLAGS_PRIV=10 for already-authorized neighbor-cache readers.
 // This requests a read-only view; it neither grants an entitlement nor changes OS policy.
 unsigned hidden=0;size_t count=neighbor_snapshot(net,out,capacity,&hidden,10);
 if(count){neighbor_view=1;if(rejected)*rejected=hidden;return count;}
 count=neighbor_snapshot(net,out,capacity,&hidden,NET_RT_DUMP);neighbor_view=count?0:(hidden?2:3);if(rejected)*rejected=hidden;return count;
}
typedef struct{char *out;size_t capacity;int finished;} LGNameResult;
static void name_reply(DNSServiceRef ref,DNSServiceFlags flags,uint32_t index,DNSServiceErrorType error,const char *name,uint16_t type,uint16_t cls,uint16_t length,const void *data,uint32_t ttl,void *context){
 (void)ref;(void)index;(void)name;(void)cls;(void)ttl;LGNameResult *r=context;
 if(!error&&(flags&kDNSServiceFlagsAdd)&&type==kDNSServiceType_PTR&&data)r->finished=lg_ptr_name(data,length,r->out,r->capacity);
}
int lg_hostname(const char *ip,unsigned interface_index,char *out,size_t capacity,unsigned timeout_ms){
 if(!capacity)return 0;out[0]=0;struct in_addr addr;if(inet_pton(AF_INET,ip,&addr)!=1)return 0;unsigned char *bytes=(void*)&addr;
 char reverse[80];snprintf(reverse,sizeof(reverse),"%u.%u.%u.%u.in-addr.arpa.",bytes[3],bytes[2],bytes[1],bytes[0]);
 DNSServiceRef ref=NULL;LGNameResult result={out,capacity,0};
 if(DNSServiceQueryRecord(&ref,0,interface_index,reverse,kDNSServiceType_PTR,kDNSServiceClass_IN,name_reply,&result))return 0;
 int fd=DNSServiceRefSockFD(ref);double deadline=clock_ms()+timeout_ms;
 while(fd>=0&&!result.finished&&clock_ms()<deadline){struct pollfd p={fd,POLLIN,0};int remain=(int)(deadline-clock_ms());if(remain<1)break;if(poll(&p,1,remain)<=0)break;if(DNSServiceProcessResult(ref))break;}
 DNSServiceRefDeallocate(ref);return result.finished;
}
