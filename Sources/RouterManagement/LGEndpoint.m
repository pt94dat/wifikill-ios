#import "LGEndpoint.h"
NSString *LGCanonicalEndpoint(NSString *value){
 if(![value isKindOfClass:NSString.class])return nil;
 NSURLComponents *c=[NSURLComponents componentsWithString:[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
 if(![c.scheme.lowercaseString isEqual:@"https"]||!c.host.length||c.user||c.password||c.query||c.fragment||(c.path.length&&![c.path isEqual:@"/"]))return nil;
 if(c.port&&(c.port.integerValue<1||c.port.integerValue>65535))return nil;
 c.scheme=@"https";c.host=c.host.lowercaseString;c.path=@"";if(c.port.integerValue==443)c.port=nil;return c.URL.absoluteString;
}
