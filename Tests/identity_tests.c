#include "Network/LGIdentity.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void){
 char mac[18];const char *bad[]={"02:00:00:00:00:00","00:00:00:00:00:00","ff:ff:ff:ff:ff:ff","01:00:5e:00:00:01","aa:bb:cc:dd:ee:zz","AA-BB-CC-DD-EE-FF","02:00:00:00:00:01;reboot",""};
 for(unsigned i=0;i<sizeof(bad)/sizeof(*bad);i++){assert(!lg_normalize_mac(bad[i],mac));assert(!mac[0]);}
 assert(lg_normalize_mac("AA:BB:CC:DD:EE:FF",mac));assert(!strcmp(mac,"aa:bb:cc:dd:ee:ff"));assert(lg_normalize_mac("02:00:00:00:00:01",mac));
 unsigned base,count;assert(lg_subnet_hosts(0xc000020a,0xffffff00,&base,&count));assert(base==0xc0000200&&count==254);
 assert(lg_subnet_hosts(0xc0000201,0xfffffffc,&base,&count)&&count==2);assert(!lg_subnet_hosts(0x0a000001,0xffff0000,&base,&count));assert(!lg_subnet_hosts(0x0a000001,0xff00ff00,&base,&count));assert(!lg_subnet_hosts(0x0a000001,0xffffffff,&base,&count));
 char name[64];unsigned char valid[]={4,'t','e','s','t',5,'l','o','c','a','l',0};assert(lg_ptr_name(valid,sizeof(valid),name,sizeof(name)));assert(!strcmp(name,"test.local"));assert(!lg_ptr_name(valid,3,name,sizeof(name)));assert(!lg_ptr_name(valid,sizeof(valid),name,4));
 unsigned char pointer[]={0xc0,1};assert(!lg_ptr_name(pointer,sizeof(pointer),name,sizeof(name)));unsigned char malicious[]={3,'a','\n','b',0};assert(!lg_ptr_name(malicious,sizeof(malicious),name,sizeof(name)));
 puts("Identity, subnet and bounded DNS-label regression assertions passed");return 0;
}
