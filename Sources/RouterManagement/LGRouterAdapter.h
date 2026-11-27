#import <Foundation/Foundation.h>
@protocol LGRouterAdapter<NSObject>
@property(nonatomic,copy) NSString *endpoint;
@property(nonatomic,readonly) BOOL supported;
@property(nonatomic,copy,readonly) NSString *authorizationStatus;
- (void)detect:(void(^)(NSString*))done;
- (void)request:(NSString*)method path:(NSString*)path body:(NSDictionary*)body done:(void(^)(NSDictionary*,NSError*))done;
@end
