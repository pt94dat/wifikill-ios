#import <UIKit/UIKit.h>
#import "RouterManagement/LGGateway.h"
@interface LGAuthorizationController:UITableViewController <UITextFieldDelegate>
@property(nonatomic,strong) LGGateway *gateway;
@property(nonatomic,copy) NSString *expectedNetwork;
@property(nonatomic,copy) void(^onChange)(void);
@end
