#include "LGIdentity.h"
#include <ctype.h>
#include <stdio.h>
#include <string.h>
int lg_normalize_mac(const char *input,char output[18]){
 output[0]=0;if(!input||strlen(input)!=17)return 0;unsigned char b[6];
 for(int i=0;i<6;i++){unsigned value=0;for(int n=0;n<2;n++){unsigned char c=(unsigned char)input[i*3+n];if(!isxdigit(c))return 0;value=value*16+(isdigit(c)?c-'0':tolower(c)-'a'+10);}b[i]=(unsigned char)value;if(i<5&&input[i*3+2]!=':')return 0;}
 if((b[0]&1)||!(b[0]|b[1]|b[2]|b[3]|b[4]|b[5]))return 0;
 if(b[0]==2&&!(b[1]|b[2]|b[3]|b[4]|b[5]))return 0;
 snprintf(output,18,"%02x:%02x:%02x:%02x:%02x:%02x",b[0],b[1],b[2],b[3],b[4],b[5]);return 1;
}
int lg_subnet_hosts(unsigned address,unsigned mask,unsigned *base,unsigned *count){
 unsigned inverse=~mask;if((inverse&(inverse+1))||inverse<3||inverse>1023)return 0;*base=address&mask;*count=inverse-1;return 1;
}
int lg_ptr_name(const unsigned char *data,size_t length,char *out,size_t capacity){
 if(!capacity)return 0;
 out[0]=0;if(!data||length>255)return 0;size_t pos=0,used=0;
 while(pos<length){unsigned label=data[pos++];if(!label){if(!used||pos!=length){out[0]=0;return 0;}out[used]=0;return 1;}if(label>63||pos+label>length||used+label+2>capacity){out[0]=0;return 0;}if(used)out[used++]='.';for(unsigned i=0;i<label;i++){unsigned char c=data[pos++];if(c<33||c>126||c=='.'){out[0]=0;return 0;}out[used++]=(char)c;}}
 out[0]=0;return 0;
}
