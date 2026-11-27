#import <Foundation/Foundation.h>
@interface LGStore : NSObject
+ (NSString*)token;
+ (BOOL)setToken:(NSString*)token;
+ (void)record:(NSString*)event;
+ (NSArray*)history;
+ (NSString*)tokenForEndpoint:(NSString*)endpoint;
+ (BOOL)setToken:(NSString*)token endpoint:(NSString*)endpoint;
+ (NSArray*)observations:(NSString*)network;
+ (void)saveObservations:(NSArray*)observations network:(NSString*)network;
+ (NSDictionary*)journal;
+ (void)journal:(NSDictionary*)operation key:(NSString*)key;
+ (void)removeJournal:(NSString*)key;
@end
