#include "LGNeighborParser.h"
#include "LGRouteABI.h"
#include "LGIdentity.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
/* Decode Darwin wire bytes, never host sockaddr layouts. No raw values in stats. */
size_t lg_parse_neighbors(const unsigned char *bytes,size_t size,unsigned iface,uint32_t address,uint32_t mask,LGNeighbor *out,size_t capacity,LGNeighborStats *s){
 memset(s,0,sizeof(*s));uint32_t rejected[1024],conflicts[1024];size_t nr=0,nc=0,count=0;
 for(size_t pos=0;pos<size;){
  if(size-pos<sizeof(LGRouteHeader)){s->malformed++;break;}
  LGRouteHeader h;memcpy(&h,bytes+pos,sizeof(h));s->records++;
  if(h.length<sizeof(h)||h.length>size-pos){s->malformed++;break;}
  size_t end=pos+h.length,offset=pos+sizeof(h);const unsigned char *a[8]={0};int bad=0;
  if(h.version!=5||(h.addresses&~255)){s->unsupported++;pos=end;continue;}
  for(unsigned i=0;i<8;i++)if(h.addresses&(1u<<i)){
   if(end-offset<2){bad=1;break;}unsigned length=bytes[offset];size_t padded=length?(length+3u)&~3u:4;
   if(padded>end-offset){bad=1;break;}
   /* Zero length netmasks are a valid Darwin default-route encoding. */
   if(length>=2)a[i]=bytes+offset;else if(i<2){bad=1;break;}offset+=padded;
  }
  pos=end;if(bad){s->malformed++;continue;}
  if(h.index!=iface||!a[0]||!a[1]||a[0][1]!=2||a[1][1]!=18)continue;
  if(a[0][0]<8||a[1][0]<8){s->malformed++;continue;}
  uint32_t ip;memcpy(&ip,a[0]+4,4);uint32_t host=ntohl(ip),base=address&mask;
  if((host&mask)!=base||host==base||host==(base|~mask))continue;
  s->candidates++;unsigned length=a[1][0],name=a[1][5],alen=a[1][6];int invalid=0;
  if(!alen){s->incomplete++;invalid=1;}
  else if(alen!=6||8u+name+alen>length){s->malformed++;invalid=1;}
  else{
   const unsigned char *b=a[1]+8+name;
   if(!(b[0]|b[1]|b[2]|b[3]|b[4]|b[5])){s->zero++;invalid=1;}
   else if(b[0]==2&&!(b[1]|b[2]|b[3]|b[4]|b[5])){s->placeholder++;invalid=1;}
   else if(b[0]&1){s->multicast++;invalid=1;}
   else{
    char mac[18],iptext[16]={0};snprintf(mac,sizeof(mac),"%02x:%02x:%02x:%02x:%02x:%02x",b[0],b[1],b[2],b[3],b[4],b[5]);inet_ntop(AF_INET,&ip,iptext,sizeof(iptext));
    int conflict=0;for(size_t j=0;j<nc;j++)if(conflicts[j]==ip)conflict=1;
    if(conflict){s->conflicting++;continue;}
    size_t j=0;for(;j<count;j++)if(!strcmp(out[j].ip,iptext))break;
    if(j<count){if(!strcmp(out[j].mac,mac)){s->duplicate++;continue;}s->conflicting++;if(nc<1024)conflicts[nc++]=ip;out[j]=out[--count];continue;}
    if(count>=capacity){s->capacityDropped++;continue;}memcpy(out[count].ip,iptext,16);memcpy(out[count].mac,mac,18);count++;
   }
  }
  if(invalid){int seen=0;for(size_t j=0;j<nr;j++)if(rejected[j]==ip)seen=1;if(!seen){if(nr<1024)rejected[nr++]=ip;s->uniqueRejected++;}}
 }
 s->accepted=(unsigned)count;return count;
}
