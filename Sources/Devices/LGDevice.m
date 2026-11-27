#import "LGDevice.h"
@implementation LGDevice
- (instancetype)init { if((self=[super init])){_ip=@"";_mac=@"";_name=@"Unknown device";_status=@"Connectivity unknown";}return self; }
@end
