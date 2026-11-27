#include "LGNetBIOS.h"
#include "LGIdentity.h"
#include <stdio.h>
#include <string.h>
static unsigned word(const unsigned char *p){return ((unsigned)p[0]<<8)|p[1];}
static int skip_name(const unsigned char *data,size_t length,size_t *offset){
 size_t p=*offset;unsigned labels=0;
 while(p<length&&labels++<128){unsigned n=data[p++];if(!n){*offset=p;return 1;}if((n&0xc0)==0xc0){if(p>=length||(((n&0x3f)<<8)|data[p])>=length)return 0;*offset=p+1;return 1;}if(n>63||p+n>length)return 0;p+=n;}return 0;
}
int lg_nbns_parse(const unsigned char *data,size_t length,uint16_t query_id,char name[64],char mac[18]){
 name[0]=0;mac[0]=0;if(length<12||word(data)!=query_id||!(word(data+2)&0x8000)||(word(data+2)&0x7800)||(word(data+2)&15))return 0;
 unsigned questions=word(data+4),answers=word(data+6);if(questions>32||answers>32)return 0;size_t offset=12;
 for(unsigned i=0;i<questions;i++){if(!skip_name(data,length,&offset)||offset+4>length)return 0;offset+=4;}
 for(unsigned i=0;i<answers;i++){
  if(!skip_name(data,length,&offset)||offset+10>length)return 0;
  unsigned type=word(data+offset),cls=word(data+offset+2),size=word(data+offset+8);offset+=10;
  if(size>length-offset)return 0;
  if(type==0x21&&cls==1){
   if(size<7)return 0;
   unsigned count=data[offset];if(count>64||1+18*count+6>size)return 0;
   for(unsigned j=0;j<count;j++){
    const unsigned char *entry=data+offset+1+18*j;unsigned flags=word(entry+16);if((flags&0x8000)||(entry[15]!=0&&entry[15]!=0x20))continue;
    size_t n=15;while(n&&entry[n-1]==' ')n--;if(!n||entry[0]=='*')continue;int valid=1;for(size_t k=0;k<n;k++)if(entry[k]<33||entry[k]>126)valid=0;
    if(valid){memcpy(name,entry,n);name[n]=0;break;}
   }
   const unsigned char *b=data+offset+1+18*count;char raw[18];snprintf(raw,18,"%02x:%02x:%02x:%02x:%02x:%02x",b[0],b[1],b[2],b[3],b[4],b[5]);lg_normalize_mac(raw,mac);
   return name[0]||mac[0];
  }offset+=size;
 }return 0;
}
#ifndef LG_NBNS_PARSER_ONLY
#include <arpa/inet.h>
#include <sys/socket.h>
#include <poll.h>
#include <unistd.h>
#include <stdlib.h>
int lg_nbns_query(const char *ip,unsigned timeout_ms,char name[64],char mac[18]){
 name[0]=0;mac[0]=0;struct sockaddr_in target={0};
#ifdef __APPLE__
 target.sin_len=sizeof(target);
#endif
 target.sin_family=AF_INET;target.sin_port=htons(137);if(inet_pton(AF_INET,ip,&target.sin_addr)!=1)return 0;
 int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)return 0;int result=0;
 if(connect(fd,(void*)&target,sizeof(target))==0){
  uint16_t id=(uint16_t)arc4random_uniform(65536);unsigned char query[50]={0};query[0]=(unsigned char)(id>>8);query[1]=(unsigned char)id;query[5]=1;query[12]=32;
  unsigned char netbios[16]={0};netbios[0]='*';for(unsigned i=0;i<16;i++){query[13+i*2]='A'+(netbios[i]>>4);query[14+i*2]='A'+(netbios[i]&15);}query[46]=0;query[47]=0x21;query[49]=1;
  if(send(fd,query,sizeof(query),0)==(ssize_t)sizeof(query)){struct pollfd p={fd,POLLIN,0};if(poll(&p,1,(int)timeout_ms)>0){unsigned char data[2048];ssize_t n=recv(fd,data,sizeof(data),0);if(n>0)result=lg_nbns_parse(data,(size_t)n,id,name,mac);}}
 }close(fd);return result;
}
#endif
