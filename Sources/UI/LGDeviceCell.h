#import <UIKit/UIKit.h>
#import "Devices/LGDevice.h"
@interface LGDeviceCell:UITableViewCell
@property(nonatomic,strong) UIButton *actionButton;
- (void)render:(LGDevice*)device available:(BOOL)available;
@end
