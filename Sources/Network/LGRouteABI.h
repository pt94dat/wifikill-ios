#ifndef LGRouteABI_h
#define LGRouteABI_h
/* Darwin iOS12 routing-socket wire ABI. Public SDK omits net/route.h.
 * Field sizes verified against Apple XNU xnu-4903.241.1 bsd/net/route.h:
 * https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/route.h
 * This minimal wire-format declaration does not include kernel implementation.
 */
#include <stdint.h>
typedef struct {
 uint16_t length;
 uint8_t version, type;
 uint16_t index;
 int32_t flags, addresses, pid, sequence, error, use;
 uint32_t initialized, metrics[14];
} LGRouteHeader;
_Static_assert(sizeof(LGRouteHeader)==92,"Darwin routing ABI mismatch");
enum { LGRouteDestination=0, LGRouteGateway=1, LGRouteAddressCount=8, LGRouteGatewayFlag=2, LGRouteHostFlag=4 };
#endif
