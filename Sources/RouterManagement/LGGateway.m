#import "LGGateway.h"
#import "Storage/LGStore.h"
#import <arpa/inet.h>
@implementation LGGateway
- (instancetype)init { if((self=[super init])){NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;c.timeoutIntervalForRequest=8;c.timeoutIntervalForResource=12;_session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];_endpoint=[NSUserDefaults.standardUserDefaults stringForKey:@"endpoint"]?:@"";}return self; }
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void(^)(NSURLRequest*))completionHandler { (void)session;(void)task;(void)response;(void)request;completionHandler(nil); }
- (void)request:(NSString*)method path:(NSString*)path body:(NSDictionary*)body done:(void(^)(NSDictionary*,NSError*))done {
 NSURLComponents *base=[NSURLComponents componentsWithString:self.endpoint];
 if(![base.scheme isEqualToString:@"https"]||!base.host.length||base.user||base.password||base.query||base.fragment||!LGStore.token.length){done(nil,[NSError errorWithDomain:@"LanGuard" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Configure an HTTPS gateway agent and token first"}]);return;}
 base.path=path;NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:base.URL];r.HTTPMethod=method;[r setValue:[@"Bearer " stringByAppendingString:LGStore.token] forHTTPHeaderField:@"Authorization"];
 if(body){r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];[r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];}
 [[self.session dataTaskWithRequest:r completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
  dispatch_async(dispatch_get_main_queue(),^{
   NSHTTPURLResponse *http=(NSHTTPURLResponse*)response;NSError *e=error;id obj=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:&e]:nil;
   if(!e&&(http.statusCode<200||http.statusCode>=300||![obj isKindOfClass:NSDictionary.class]))e=[NSError errorWithDomain:@"LanGuard" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey:[obj isKindOfClass:NSDictionary.class]?obj[@"error"]?:@"Gateway rejected request":@"Invalid gateway response"}];
   done(e?nil:obj,e);
  });
 }]resume];
}
- (void)detect:(void(^)(NSString*))done { self.supported=NO;[self request:@"GET" path:@"/v1/capabilities" body:nil done:^(NSDictionary *r,NSError *e){self.supported=!e&&[r[@"protocol"] isEqual:@"languard-gateway/1"]&&[r[@"lease_max_seconds"] integerValue]>0;done(e?e.localizedDescription:(self.supported?@"Authenticated lease control available":@"Unsupported gateway protocol"));}]; }
@end
