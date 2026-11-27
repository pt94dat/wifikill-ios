#import <UIKit/UIKit.h>
#import "UI/LGNetworkController.h"
@interface LGAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation LGAppDelegate
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
 (void)application;(void)options;self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
 UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:[LGNetworkController new]];
 nav.navigationBar.barStyle=UIBarStyleBlack;nav.navigationBar.tintColor=[UIColor colorWithRed:.22 green:.85 blue:.67 alpha:1];
 self.window.tintColor=nav.navigationBar.tintColor;nav.toolbar.barStyle=UIBarStyleBlack;nav.toolbar.tintColor=nav.navigationBar.tintColor;self.window.rootViewController=nav;[self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char *argv[]){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(LGAppDelegate.class));}}
