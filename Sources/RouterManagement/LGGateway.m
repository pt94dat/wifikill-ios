#import "LGGateway.h"
#import "Storage/LGStore.h"
#import "Network/LGNetworkContext.h"
@interface LGGateway()
@property(nonatomic,strong) NSNetServiceBrowser *browser;
@property(nonatomic,strong) NSMutableArray<NSNetService*> *services;
@property(nonatomic) NSUInteger epoch;
@end
@implementation LGGateway
+ (NSString*)canonicalEndpoint:(NSString*)value{
 NSURLComponents *c=[NSURLComponents componentsWithString:[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
 if(![c.scheme.lowercaseString isEqual:@"https"]||!c.host.length||c.user||c.password||c.query||c.fragment||(c.path.length&&![c.path isEqual:@"/"]))return nil;
 c.scheme=@"https";c.host=c.host.lowercaseString;c.path=@"";if(c.port.integerValue==443)c.port=nil;return c.URL.absoluteString;
}
- (instancetype)init{if((self=[super init])){NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;c.timeoutIntervalForRequest=8;c.timeoutIntervalForResource=12;_session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];_endpoint=[self.class canonicalEndpoint:[NSUserDefaults.standardUserDefaults stringForKey:@"endpoint"]?:@""]?:@"";_authorizationStatus=@"Access control not configured";_candidates=@[];_services=[NSMutableArray new];}return self;}
- (void)invalidate:(NSString*)reason{self.epoch++;self.supported=NO;self.authorizationStatus=reason;}
- (BOOL)isBound{NSDictionary *all=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"gateway.bindings.v2"]?:@{};return self.networkKey.length&&[all[self.endpoint] isEqual:self.networkKey];}
- (void)bindCurrentNetwork{if(!self.endpoint.length||!self.networkKey.length)return;NSMutableDictionary *all=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"gateway.bindings.v2"] mutableCopy]?:[NSMutableDictionary new];all[self.endpoint]=self.networkKey;[NSUserDefaults.standardUserDefaults setObject:all forKey:@"gateway.bindings.v2"];}
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void(^)(NSURLRequest*))completionHandler{(void)session;(void)task;(void)response;(void)request;completionHandler(nil);}
- (void)request:(NSString*)method path:(NSString*)path body:(NSDictionary*)body done:(void(^)(NSDictionary*,NSError*))done{
 NSString *endpoint=[self.class canonicalEndpoint:self.endpoint];NSString *token=endpoint?[LGStore tokenForEndpoint:endpoint]:@"";LGNetworkContext *now=[LGNetworkContext current];BOOL mutation=![method isEqual:@"GET"];
 if(!endpoint||!token.length||!now||![now.networkKey isEqual:self.networkKey]||(mutation&&(!self.supported||![self isBound]))){done(nil,[NSError errorWithDomain:@"LanGuard" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Authorize a compatible HTTPS adapter on this network first"}]);return;}
 NSURLComponents *url=[NSURLComponents componentsWithString:endpoint];url.path=path;NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url.URL];request.HTTPMethod=method;[request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];if(body){request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];}
 [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{NSError *failure=error;NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class]?(NSHTTPURLResponse*)response:nil;id object=nil;if(data.length&&data.length<=1024*1024)object=[NSJSONSerialization JSONObjectWithData:data options:0 error:&failure];if(!failure&&(!http||http.statusCode<200||http.statusCode>=300||![object isKindOfClass:NSDictionary.class])){NSString *message=([object isKindOfClass:NSDictionary.class]&&[object[@"error"] isKindOfClass:NSString.class])?object[@"error"]:@"Invalid or oversized gateway response";failure=[NSError errorWithDomain:@"LanGuard" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey:message}];}done(failure?nil:object,failure);});}]resume];
}
- (void)detect:(void(^)(NSString*))done{
 [self invalidate:@"Checking adapter…"];NSUInteger epoch=self.epoch;if(!self.endpoint.length||![self isBound]){self.authorizationStatus=self.endpoint.length?@"Authorize this adapter for the current network":@"No compatible adapter configured";done(self.authorizationStatus);return;}
 [self request:@"GET" path:@"/v1/capabilities" body:nil done:^(NSDictionary *r,NSError *error){if(epoch!=self.epoch){done(@"Capability check interrupted; retry on the current network");return;}self.supported=!error&&[r[@"protocol"] isKindOfClass:NSString.class]&&[r[@"protocol"] isEqual:@"languard-gateway/1"]&&[r[@"lease_max_seconds"] isKindOfClass:NSNumber.class]&&[r[@"lease_max_seconds"] integerValue]>=300;if(r[@"management_authorized"]&&(![r[@"management_authorized"] isKindOfClass:NSNumber.class]||![r[@"management_authorized"] boolValue]))self.supported=NO;self.authorizationStatus=error?error.localizedDescription:(self.supported?@"Authorized · timed gateway control available":@"Unsupported adapter or management client not protected");done(self.authorizationStatus);}];
}
- (void)discover{
 [self.browser stop];[self.services removeAllObjects];self.candidates=@[];self.browser=[NSNetServiceBrowser new];self.browser.delegate=self;[self.browser searchForServicesOfType:@"_languard._tcp." inDomain:@"local."];NSNetServiceBrowser *browser=self.browser;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{[browser stop];});
}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindService:(NSNetService*)service moreComing:(BOOL)more{(void)browser;(void)more;if(self.services.count>=8)return;[self.services addObject:service];service.delegate=self;[service resolveWithTimeout:2];}
- (void)netServiceDidResolveAddress:(NSNetService*)service{
 if(!service.hostName.length||service.port<1||service.port>65535)return;NSString *host=[service.hostName hasSuffix:@"."]?[service.hostName substringToIndex:service.hostName.length-1]:service.hostName;
 NSString *endpoint=[self.class canonicalEndpoint:[NSString stringWithFormat:@"https://%@:%ld",host,(long)service.port]];if(!endpoint)return;NSMutableArray *values=[self.candidates mutableCopy];if(![values containsObject:endpoint])[values addObject:endpoint];self.candidates=values;
}
@end
