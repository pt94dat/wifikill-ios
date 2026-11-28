#import "LGEnrollment.h"
#import "LGEndpoint.h"
@implementation LGEnrollment
+ (NSDictionary*)decode:(NSData*)data{
 if(!data.length||data.length>4096)return nil;id raw=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if(![raw isKindOfClass:NSDictionary.class]||![raw[@"protocol"] isEqual:@"languard-enrollment/1"])return nil;
 NSString *endpoint=[raw[@"endpoint"] isKindOfClass:NSString.class]?LGCanonicalEndpoint(raw[@"endpoint"]):nil;NSString *token=raw[@"token"];
 if(!endpoint||![token isKindOfClass:NSString.class]||token.length<32||token.length>256)return nil;for(NSUInteger i=0;i<token.length;i++){unichar c=[token characterAtIndex:i];if(c<33||c>126)return nil;}
 return @{@"endpoint":endpoint,@"token":token};
}
@end
