#import <Foundation/Foundation.h>
#import "LGNetwork.h"
#import "Devices/LGDevice.h"
@interface LGServiceEvidence:NSObject
+ (NSDictionary*)mergeObservation:(NSDictionary*)row previous:(NSDictionary*)previous;
+ (NSDictionary*)removeName:(NSString*)name type:(NSString*)type previous:(NSDictionary*)previous;
+ (NSString*)serviceType:(NSString*)record;
+ (NSUInteger)merge:(NSDictionary<NSString*,NSDictionary*>*)evidence into:(NSMutableDictionary<NSString*,LGDevice*>*)devices network:(LGNetwork)network;
@end
