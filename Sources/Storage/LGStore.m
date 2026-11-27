#import "LGStore.h"
#import <Security/Security.h>
@implementation LGStore
+ (NSMutableDictionary*)query { return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"com.pt94dat.wifikillios",(__bridge id)kSecAttrAccount:@"gateway"} mutableCopy]; }
+ (NSString*)token { NSMutableDictionary *q=[self query];q[(__bridge id)kSecReturnData]=@YES;CFTypeRef value=NULL;if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&value)!=errSecSuccess)return @"";NSData *d=CFBridgingRelease(value);return [[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]?:@""; }
+ (BOOL)setToken:(NSString*)token { NSMutableDictionary *q=[self query];SecItemDelete((__bridge CFDictionaryRef)q);if(!token.length)return YES;q[(__bridge id)kSecValueData]=[token dataUsingEncoding:NSUTF8StringEncoding];q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;return SecItemAdd((__bridge CFDictionaryRef)q,NULL)==errSecSuccess; }
+ (void)record:(NSString*)event { NSMutableArray *a=[[self history] mutableCopy];[a insertObject:@{ @"time":[NSDate.date description],@"event":event } atIndex:0];if(a.count>300)[a removeObjectsInRange:NSMakeRange(300,a.count-300)];[NSUserDefaults.standardUserDefaults setObject:a forKey:@"history"]; }
+ (NSArray*)history { return [NSUserDefaults.standardUserDefaults arrayForKey:@"history"]?:@[]; }
@end
