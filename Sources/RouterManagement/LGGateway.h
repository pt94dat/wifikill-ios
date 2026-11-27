#import <Foundation/Foundation.h>
@interface LGGateway : NSObject <NSURLSessionTaskDelegate>
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,copy) NSString *endpoint;
@property(nonatomic) BOOL supported;
- (void)request:(NSString*)method path:(NSString*)path body:(NSDictionary*)body done:(void(^)(NSDictionary*,NSError*))done;
- (void)detect:(void(^)(NSString*))done;
@end
