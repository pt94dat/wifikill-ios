#import "LGHostProbe.h"
#import "LGNetwork.h"
#import "ThirdParty/SimplePing.h"
#import <arpa/inet.h>
#include <errno.h>
#include <string.h>
@interface LGHostEcho:NSObject<SimplePingDelegate>
@property(nonatomic) BOOL replied,failed;
@property(nonatomic) int error;
@property(nonatomic,strong) NSData *payload,*targetAddress;
@property(nonatomic) double started,latency;
@end
@implementation LGHostEcho
- (void)simplePing:(SimplePing*)pinger didStartWithAddress:(NSData*)address{(void)address;self.started=NSProcessInfo.processInfo.systemUptime;[pinger sendPingWithData:self.payload];}
- (void)simplePing:(SimplePing*)pinger didReceivePingResponsePacket:(NSData*)packet{(void)pinger;if(packet.length<sizeof(IPHeader)+sizeof(ICMPHeader)||self.targetAddress.length!=4)return;const IPHeader *ip=packet.bytes;if(memcmp(ip->sourceAddress,self.targetAddress.bytes,4))return;const ICMPHeader *icmp=[SimplePing icmpInPacket:packet];if(!icmp)return;NSUInteger offset=(const uint8_t*)icmp-(const uint8_t*)packet.bytes+sizeof(*icmp);if(offset>packet.length||packet.length-offset!=self.payload.length||memcmp((const uint8_t*)packet.bytes+offset,self.payload.bytes,self.payload.length))return;self.replied=YES;self.latency=(NSProcessInfo.processInfo.systemUptime-self.started)*1000;}
- (void)simplePing:(SimplePing*)pinger didFailWithError:(NSError*)error{(void)pinger;self.error=(int)error.code?:EIO;self.failed=YES;}
- (void)simplePing:(SimplePing*)pinger didFailToSendPacket:(NSData*)packet error:(NSError*)error{(void)pinger;(void)packet;self.error=(int)error.code?:EIO;self.failed=YES;}
@end
int lg_discover_detail(const char *ip,unsigned timeout_ms,double *latency_ms,int *evidence,int *icmp_error){@autoreleasepool{
 timeout_ms=MIN(timeout_ms,1000u);
 if(icmp_error)*icmp_error=0;if(evidence)*evidence=0;if(latency_ms)*latency_ms=0;
 struct sockaddr_in address={0};address.sin_len=sizeof(address);address.sin_family=AF_INET;if(inet_pton(AF_INET,ip,&address.sin_addr)!=1)return 0;
 double deadline=NSProcessInfo.processInfo.systemUptime+MIN(timeout_ms,1000u)/1000.0;
 LGHostEcho *echo=[LGHostEcho new];echo.payload=[NSUUID.UUID.UUIDString dataUsingEncoding:NSUTF8StringEncoding];echo.targetAddress=[NSData dataWithBytes:&address.sin_addr length:4];SimplePing *pinger=[SimplePing simplePingWithHostAddress:[NSData dataWithBytes:&address length:sizeof(address)]];pinger.delegate=echo;[pinger start];
 double tcpLatency=0;int tcpEvidence=0;int tcp=lg_probe_detail(ip,timeout_ms,&tcpLatency,&tcpEvidence);
 if(!tcp&&!echo.failed){
  /* A TCP wait can leave an already-received echo queued on this worker's run loop. */
  do{double remaining=deadline-NSProcessInfo.processInfo.systemUptime;CFRunLoopRunInMode(kCFRunLoopDefaultMode,MAX(.003,MIN(.02,remaining)),false);}while(!echo.replied&&!echo.failed&&NSProcessInfo.processInfo.systemUptime<deadline);
 }
 pinger.delegate=nil;[pinger stop];if(icmp_error)*icmp_error=echo.error;
 if(tcp){if(evidence)*evidence=tcpEvidence;if(latency_ms)*latency_ms=tcpLatency;return 1;}
 if(echo.replied){if(evidence)*evidence=4;if(latency_ms)*latency_ms=echo.latency;return 1;}return 0;
}}
