#include "Network/LGNetBIOS.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
int main(void){char name[64],mac[18];int result=lg_nbns_query("127.0.0.1",150,name,mac);assert(result&&!strcmp(name,"OWNED-FIXTURE")&&!strcmp(mac,"02:11:22:33:44:55"));puts("Production NBNS socket send/receive and matching transaction passed against owned loopback fixture; port injected only in test build");return 0;}
