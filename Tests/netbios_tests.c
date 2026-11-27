#include "Network/LGNetBIOS.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void){
 unsigned char packet[48]={0x12,0x34,0x84,0,0,0,0,1,0,0,0,0,0,0,0x21,0,1,0,0,0,1,0,25};
 packet[23]=1;memset(packet+24,' ',15);memcpy(packet+24,"LABPC",5);packet[39]=0;packet[40]=4;packet[41]=0;
 unsigned char macBytes[]={0,0x11,0x22,0x33,0x44,0x55};memcpy(packet+42,macBytes,6);
 char name[64],mac[18];assert(lg_nbns_parse(packet,sizeof(packet),0x1234,name,mac));assert(!strcmp(name,"LABPC"));assert(!strcmp(mac,"00:11:22:33:44:55"));
 for(size_t n=0;n<sizeof(packet);n++)assert(!lg_nbns_parse(packet,n,0x1234,name,mac));
 assert(!lg_nbns_parse(packet,sizeof(packet),0xabcd,name,mac));assert(!name[0]&&!mac[0]);
 packet[2]=0;assert(!lg_nbns_parse(packet,sizeof(packet),0x1234,name,mac));packet[2]=0x84;
 memset(packet+42,0,6);assert(lg_nbns_parse(packet,sizeof(packet),0x1234,name,mac));assert(name[0]&&!mac[0]);
 packet[24]='\n';assert(!lg_nbns_parse(packet,sizeof(packet),0x1234,name,mac));packet[24]='L';
 packet[23]=65;assert(!lg_nbns_parse(packet,sizeof(packet),0x1234,name,mac));
 puts("NetBIOS transaction, length, name and invalid-MAC regression assertions passed");return 0;
}
