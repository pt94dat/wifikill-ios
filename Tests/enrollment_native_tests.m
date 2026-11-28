#import <Foundation/Foundation.h>
#import "RouterManagement/LGEnrollment.h"
#include <assert.h>
int main(void){@autoreleasepool{
 NSString *token=[@"a" stringByPaddingToLength:48 withString:@"b" startingAtIndex:0];
 NSDictionary *valid=@{@"protocol":@"languard-enrollment/1",@"endpoint":@"https://GATEWAY.example:443/",@"token":token};NSDictionary *result=[LGEnrollment decode:[NSJSONSerialization dataWithJSONObject:valid options:0 error:nil]];assert(([result[@"endpoint"] isEqual:@"https://gateway.example"]&&[result[@"token"] isEqual:token]));
 for(NSString *url in @[@"http://gateway.example",@"https://user:secret@gateway.example",@"https://gateway.example/?token=secret",@"https://gateway.example/path",@"https://gateway.example:0"]){NSMutableDictionary *bad=valid.mutableCopy;bad[@"endpoint"]=url;assert((![LGEnrollment decode:[NSJSONSerialization dataWithJSONObject:bad options:0 error:nil]]));}
 assert((![LGEnrollment decode:[@"not-json" dataUsingEncoding:NSUTF8StringEncoding]]));NSMutableDictionary *bad=valid.mutableCopy;bad[@"token"]=@"short";assert((![LGEnrollment decode:[NSJSONSerialization dataWithJSONObject:bad options:0 error:nil]]));
 puts("Production enrollment decoding and shared HTTPS origin validation passed; no network request or Keychain write performed by import parser");
}return 0;}
