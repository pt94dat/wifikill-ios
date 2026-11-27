#ifndef LGIdentity_h
#define LGIdentity_h
#include <stddef.h>
int lg_normalize_mac(const char *input,char output[18]);
int lg_subnet_hosts(unsigned address,unsigned mask,unsigned *base,unsigned *count);
int lg_ptr_name(const unsigned char *data,size_t length,char *out,size_t capacity);
#endif
