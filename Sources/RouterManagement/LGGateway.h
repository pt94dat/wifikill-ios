#import <Foundation/Foundation.h>
#import "LGRouterAdapter.h"
@interface LGGateway:NSObject<LGRouterAdapter,NSURLSessionTaskDelegate,NSNetServiceBrowserDelegate,NSNetServiceDelegate>
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,copy) NSString *endpoint,*authorizationStatus,*networkKey;
@property(nonatomic) BOOL supported;
@property(nonatomic,strong) NSArray<NSString*> *candidates;
+ (NSString*)canonicalEndpoint:(NSString*)value;
- (void)request:(NSString*)method path:(NSString*)path body:(NSDictionary*)body done:(void(^)(NSDictionary*,NSError*))done;
- (void)detect:(void(^)(NSString*))done;
- (void)discover;
- (void)invalidate:(NSString*)reason;
- (BOOL)isBound;
- (void)bindCurrentNetwork;
@end
