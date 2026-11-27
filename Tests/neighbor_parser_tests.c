#include "Network/LGNeighborParser.h"
#include "Network/LGRouteABI.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
static size_t record(unsigned char *p,unsigned suffix,const unsigned char *mac,unsigned alen){
 LGRouteHeader h={0};h.version=5;h.type=4;h.index=4;h.flags=0x404;h.addresses=7;h.length=132;memcpy(p,&h,92);memset(p+92,0,40);
 unsigned char *ip=p+92;ip[0]=16;ip[1]=2;ip[4]=192;ip[5]=0;ip[6]=2;ip[7]=suffix;
 unsigned char *link=p+108;link[0]=20;link[1]=18;link[4]=6;link[5]=3;link[6]=alen;memcpy(link+8,"en0",3);if(mac)memcpy(link+11,mac,6);
 /* zero sa_len netmask is legitimate for Darwin; padded 4 bytes */
 return h.length;
}
int main(void){
 unsigned char bytes[132*43]={0};LGNeighbor out[8];LGNeighborStats s;unsigned char valid[]={0x02,0x11,0x22,0x33,0x44,0x55},second[]={0x06,1,2,3,4,5},placeholder[]={2,0,0,0,0,0},zero[6]={0},multi[]={1,2,3,4,5,6};
 size_t n=record(bytes,20,valid,6);assert(lg_parse_neighbors(bytes,n,4,0xc0000201,0xffffff00,out,8,&s)==1);assert(!strcmp(out[0].mac,"02:11:22:33:44:55"));
 for(size_t cut=1;cut<n;cut++){assert(!lg_parse_neighbors(bytes,cut,4,0xc0000201,0xffffff00,out,8,&s));assert(s.malformed);}
 record(bytes+n,20,valid,6);assert(lg_parse_neighbors(bytes,n*2,4,0xc0000201,0xffffff00,out,8,&s)==1&&s.duplicate==1);
 record(bytes+n,20,second,6);assert(!lg_parse_neighbors(bytes,n*2,4,0xc0000201,0xffffff00,out,8,&s)&&s.conflicting==1);
 record(bytes,20,placeholder,6);record(bytes+n,20,placeholder,6);assert(!lg_parse_neighbors(bytes,n*2,4,0xc0000201,0xffffff00,out,8,&s));assert(s.placeholder==2&&s.uniqueRejected==1);
 record(bytes,20,zero,6);record(bytes+n,21,multi,6);record(bytes+n*2,22,0,0);assert(!lg_parse_neighbors(bytes,n*3,4,0xc0000201,0xffffff00,out,8,&s));assert(s.zero==1&&s.multicast==1&&s.incomplete==1&&s.uniqueRejected==3);
 record(bytes,20,valid,6);bytes[108+5]=250;assert(!lg_parse_neighbors(bytes,n,4,0xc0000201,0xffffff00,out,8,&s)&&s.malformed==1);
 record(bytes,20,valid,6);assert(!lg_parse_neighbors(bytes,n,7,0xc0000201,0xffffff00,out,8,&s)&&s.candidates==0);
 assert(!lg_parse_neighbors(bytes,n,4,0xc0000301,0xffffff00,out,8,&s)&&s.candidates==0);
 record(bytes,20,valid,6);assert(!lg_parse_neighbors(bytes,n,4,0xc0000201,0xffffff00,out,0,&s)&&s.capacityDropped==1);
 for(unsigned i=0;i<43;i++){record(bytes+n*i,20+i,placeholder,6);}
 assert(!lg_parse_neighbors(bytes,n*43,4,0xc0000201,0xffffff00,out,8,&s)&&s.placeholder==43&&s.uniqueRejected==43);
 for(unsigned i=0;i<43;i++){record(bytes+n*i,20,placeholder,6);}
 assert(!lg_parse_neighbors(bytes,n*43,4,0xc0000201,0xffffff00,out,8,&s)&&s.placeholder==43&&s.uniqueRejected==1);
 record(bytes,20,valid,6);LGRouteHeader hostOnly;memcpy(&hostOnly,bytes,sizeof(hostOnly));hostOnly.flags=4;memcpy(bytes,&hostOnly,sizeof(hostOnly));assert(lg_parse_neighbors(bytes,n,4,0xc0000201,0xffffff00,out,8,&s)==1);
 record(bytes,20,valid,6);LGRouteHeader connected;memcpy(&connected,bytes,sizeof(connected));connected.flags=1;memcpy(bytes,&connected,sizeof(connected));assert(!lg_parse_neighbors(bytes,n,4,0xc0000201,0xffffff00,out,8,&s)&&s.nonNeighbor==1&&s.candidates==0);
 puts("Production Darwin parser: truncation, alignment, duplicate, conflict, redaction-pattern and valid private-MAC fixtures passed");return 0;
}
