#import "LGStore.h"
#import <Security/Security.h>
@implementation LGStore
+ (NSMutableDictionary*)query { return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"com.pt94dat.wifikillios",(__bridge id)kSecAttrAccount:@"gateway"} mutableCopy]; }
+ (NSString*)token { NSMutableDictionary *q=[self query];q[(__bridge id)kSecReturnData]=@YES;CFTypeRef value=NULL;if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&value)!=errSecSuccess)return @"";NSData *d=CFBridgingRelease(value);return [[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]?:@""; }
+ (BOOL)setToken:(NSString*)token { NSMutableDictionary *q=[self query];SecItemDelete((__bridge CFDictionaryRef)q);if(!token.length)return YES;q[(__bridge id)kSecValueData]=[token dataUsingEncoding:NSUTF8StringEncoding];q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;return SecItemAdd((__bridge CFDictionaryRef)q,NULL)==errSecSuccess; }
+ (void)record:(NSString*)event { NSMutableArray *a=[[self history] mutableCopy];[a insertObject:@{ @"time":[NSDate.date description],@"event":event } atIndex:0];if(a.count>300)[a removeObjectsInRange:NSMakeRange(300,a.count-300)];[NSUserDefaults.standardUserDefaults setObject:a forKey:@"history"]; }
+ (NSArray*)history { return [NSUserDefaults.standardUserDefaults arrayForKey:@"history"]?:@[]; }

+ (NSMutableDictionary*)queryForEndpoint:(NSString*)endpoint{NSMutableDictionary *q=[self query];q[(__bridge id)kSecAttrAccount]=[@"gateway:" stringByAppendingString:endpoint];return q;}
+ (NSString*)tokenForEndpoint:(NSString*)endpoint{
 NSMutableDictionary *q=[self queryForEndpoint:endpoint];q[(__bridge id)kSecReturnData]=@YES;CFTypeRef value=NULL;
 if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&value)==errSecSuccess){NSData *data=CFBridgingRelease(value);return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"";}
 NSString *legacy=[NSUserDefaults.standardUserDefaults stringForKey:@"endpoint"]?:@"";
 if([[legacy stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] isEqual:endpoint]){NSString *old=[self token];if(old.length&&[self setToken:old endpoint:endpoint]){[self setToken:@""];return old;}}
 return @"";
}
+ (BOOL)setToken:(NSString*)token endpoint:(NSString*)endpoint{
 NSMutableDictionary *q=[self queryForEndpoint:endpoint];if(!token.length){OSStatus status=SecItemDelete((__bridge CFDictionaryRef)q);return status==errSecSuccess||status==errSecItemNotFound;}
 NSDictionary *attributes=@{(__bridge id)kSecValueData:[token dataUsingEncoding:NSUTF8StringEncoding],(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
 OSStatus status=SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)attributes);if(status==errSecSuccess)return YES;if(status!=errSecItemNotFound)return NO;[q addEntriesFromDictionary:attributes];return SecItemAdd((__bridge CFDictionaryRef)q,NULL)==errSecSuccess;
}
+ (NSArray*)observations:(NSString*)network{NSDictionary *all=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"observations.v2"]?:@{};return [all[network] isKindOfClass:NSArray.class]?all[network]:@[];}
+ (void)saveObservations:(NSArray*)observations network:(NSString*)network{
 NSMutableDictionary *all=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"observations.v2"] mutableCopy]?:[NSMutableDictionary new];if(all.count>=8&&!all[network])[all removeObjectForKey:[all.allKeys sortedArrayUsingSelector:@selector(compare:)].firstObject];all[network]=observations.count>512?[observations subarrayWithRange:NSMakeRange(0,512)]:observations;[NSUserDefaults.standardUserDefaults setObject:all forKey:@"observations.v2"];
}
+ (NSDictionary*)journal{return [NSUserDefaults.standardUserDefaults dictionaryForKey:@"operationJournal.v2"]?:@{};}
+ (void)journal:(NSDictionary*)operation key:(NSString*)key{NSMutableDictionary *values=[[self journal] mutableCopy];values[key]=operation;[NSUserDefaults.standardUserDefaults setObject:values forKey:@"operationJournal.v2"];[NSUserDefaults.standardUserDefaults synchronize];}
+ (void)removeJournal:(NSString*)key{NSMutableDictionary *values=[[self journal] mutableCopy];[values removeObjectForKey:key];[NSUserDefaults.standardUserDefaults setObject:values forKey:@"operationJournal.v2"];}
@end

