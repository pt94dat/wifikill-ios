#ifndef LGNetBIOS_h
#define LGNetBIOS_h
#include <stddef.h>
#include <stdint.h>
int lg_nbns_parse(const unsigned char *data,size_t length,uint16_t query_id,char name[64],char mac[18]);
int lg_nbns_query(const char *ip,unsigned timeout_ms,char name[64],char mac[18]);
#endif
