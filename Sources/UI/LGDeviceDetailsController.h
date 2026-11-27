#import <UIKit/UIKit.h>
#import "Devices/LGDevice.h"
@interface LGDeviceDetailsController:UITableViewController
@property(nonatomic,strong) LGDevice *device;
@property(nonatomic,copy) NSString *authorizationStatus;
@property(nonatomic,copy) void(^onChange)(LGDevice*);
@end
