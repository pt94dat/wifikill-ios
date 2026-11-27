#ifndef LGNeighborParser_h
#define LGNeighborParser_h
#include <stddef.h>
#include <stdint.h>
typedef struct {char ip[16],mac[18];} LGNeighbor;
typedef struct {
 unsigned records,candidates,accepted,duplicate,conflicting,malformed,unsupported,incomplete,placeholder,zero,multicast,uniqueRejected,capacityDropped;
 int apiError,view;
} LGNeighborStats;
size_t lg_parse_neighbors(const unsigned char *bytes,size_t size,unsigned interface_index,uint32_t address,uint32_t mask,LGNeighbor *out,size_t capacity,LGNeighborStats *stats);
#endif
