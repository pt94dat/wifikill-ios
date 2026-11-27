#import "LGNetworkController.h"
#import "LGDeviceCell.h"
#import "LGDeviceDetailsController.h"
#import "LGAuthorizationController.h"
#import "DesignSystem/LGStyle.h"
#import "Network/LGScanner.h"
#import "Network/LGIdentity.h"
#import "RouterManagement/LGGateway.h"
#import "Storage/LGStore.h"
#import <arpa/inet.h>
@interface LGNetworkController()
@property(nonatomic,strong) LGScanner *scanner;
@property(nonatomic,strong) LGGateway *gateway;
@property(nonatomic,strong) LGNetworkContext *context;
@property(nonatomic,strong) NSArray<LGDevice*> *devices,*visible;
@property(nonatomic,strong) NSMutableSet<NSString*> *pending;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,strong) UILabel *networkLabel,*connectionLabel,*counts,*subcounts;
@property(nonatomic,strong) UIButton *authorizationButton;
@property(nonatomic,strong) UIActivityIndicatorView *activity;
@property(nonatomic,strong) UISegmentedControl *filter;
@property(nonatomic,strong) UIBarButtonItem *restoreButton;
@property(nonatomic,strong) NSTimer *refreshTimer;
@property(nonatomic,strong) NSDate *lastScan;
@property(nonatomic,copy) NSString *scanExplanation;
@property(nonatomic) BOOL scanning,restoringAll;
@property(nonatomic) NSUInteger contextEpoch;
@end
@implementation LGNetworkController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"LanGuard";self.devices=@[];self.visible=@[];self.pending=[NSMutableSet new];self.scanner=[LGScanner new];self.gateway=[LGGateway new];self.scanExplanation=@"No completed scan yet";
 self.tableView.backgroundColor=LGStyle.background;self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;self.tableView.rowHeight=110;[self.tableView registerClass:LGDeviceCell.class forCellReuseIdentifier:@"device"];
 self.search=[[UISearchController alloc]initWithSearchResultsController:nil];self.search.searchResultsUpdater=self;self.search.obscuresBackgroundDuringPresentation=NO;self.search.searchBar.placeholder=@"Find a name or address";self.search.searchBar.barStyle=UIBarStyleBlack;self.navigationItem.searchController=self.search;self.definesPresentationContext=YES;
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Settings" style:0 target:self action:@selector(settings)];self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Scan" style:0 target:self action:@selector(scan)];
 self.refreshControl=[UIRefreshControl new];self.refreshControl.tintColor=LGStyle.accent;[self.refreshControl addTarget:self action:@selector(scan) forControlEvents:UIControlEventValueChanged];
 self.restoreButton=[[UIBarButtonItem alloc]initWithTitle:@"Restore all" style:0 target:self action:@selector(restoreAll)];
 self.toolbarItems=@[[[UIBarButtonItem alloc]initWithTitle:@"Network" style:0 target:self action:@selector(networkDetails)],[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],[[UIBarButtonItem alloc]initWithTitle:@"History" style:0 target:self action:@selector(history)],[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],self.restoreButton];self.navigationController.toolbarHidden=NO;
 [self buildHeader];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];[self updateContext];[self scan];[self.gateway discover];
}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self foreground];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.refreshTimer invalidate];self.refreshTimer=nil;[self.scanner cancel];self.scanning=NO;[self.activity stopAnimating];[self.refreshControl endRefreshing];self.navigationItem.leftBarButtonItem.title=@"Scan";}
- (UILabel*)label:(CGFloat)size color:(UIColor*)color{UILabel *v=[UILabel new];v.font=[UIFont systemFontOfSize:size weight:UIFontWeightMedium];v.textColor=color;return v;}
- (void)buildHeader{
 UIView *header=[[UIView alloc]initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,222)];
 self.networkLabel=[self label:22 color:UIColor.whiteColor];self.connectionLabel=[self label:12 color:LGStyle.muted];self.counts=[self label:16 color:UIColor.whiteColor];self.subcounts=[self label:12 color:LGStyle.muted];
 self.counts.font=[UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightSemibold];self.counts.adjustsFontSizeToFitWidth=YES;self.subcounts.adjustsFontSizeToFitWidth=YES;self.subcounts.minimumScaleFactor=.8;self.counts.minimumScaleFactor=.8;
 self.authorizationButton=[UIButton buttonWithType:UIButtonTypeSystem];self.authorizationButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;self.authorizationButton.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];self.authorizationButton.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;[self.authorizationButton addTarget:self action:@selector(settings) forControlEvents:UIControlEventTouchUpInside];
 self.filter=[[UISegmentedControl alloc]initWithItems:@[@"All",@"Responded",@"Cached",@"Unknown"]];self.filter.selectedSegmentIndex=0;self.filter.tintColor=LGStyle.accent;[self.filter addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
 self.activity=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];self.activity.hidesWhenStopped=YES;
 for(UIView *v in @[self.networkLabel,self.connectionLabel,self.counts,self.subcounts,self.authorizationButton,self.filter,self.activity]){[header addSubview:v];v.translatesAutoresizingMaskIntoConstraints=NO;}
 [NSLayoutConstraint activateConstraints:@[
 [self.networkLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],[self.networkLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-48],[self.networkLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:12],
 [self.activity.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],[self.activity.centerYAnchor constraintEqualToAnchor:self.networkLabel.centerYAnchor],
 [self.connectionLabel.leadingAnchor constraintEqualToAnchor:self.networkLabel.leadingAnchor],[self.connectionLabel.topAnchor constraintEqualToAnchor:self.networkLabel.bottomAnchor constant:6],[self.connectionLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
 [self.counts.leadingAnchor constraintEqualToAnchor:self.networkLabel.leadingAnchor],[self.counts.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],[self.counts.topAnchor constraintEqualToAnchor:self.connectionLabel.bottomAnchor constant:22],
 [self.subcounts.leadingAnchor constraintEqualToAnchor:self.networkLabel.leadingAnchor],[self.subcounts.topAnchor constraintEqualToAnchor:self.counts.bottomAnchor constant:8],[self.subcounts.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
 [self.authorizationButton.leadingAnchor constraintEqualToAnchor:self.networkLabel.leadingAnchor],[self.authorizationButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],[self.authorizationButton.topAnchor constraintEqualToAnchor:self.subcounts.bottomAnchor constant:4],[self.authorizationButton.heightAnchor constraintEqualToConstant:36],
 [self.filter.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],[self.filter.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],[self.filter.topAnchor constraintEqualToAnchor:self.authorizationButton.bottomAnchor constant:8],[self.filter.heightAnchor constraintEqualToConstant:30]]];self.tableView.tableHeaderView=header;[self render];
}
- (BOOL)updateContext{
 LGNetworkContext *now=[LGNetworkContext current];BOOL changed=(self.context&&!now)||(!self.context&&now)||(self.context&&now&&![self.context.fingerprint isEqual:now.fingerprint]);
 if(changed){self.contextEpoch++;[self.scanner cancel];self.scanning=NO;[self.activity stopAnimating];[self.refreshControl endRefreshing];self.navigationItem.leftBarButtonItem.title=@"Scan";self.devices=@[];self.visible=@[];self.scanner.metrics=@{};[self.gateway invalidate:@"Network changed; authorization must match the current network"];}
 self.context=now;self.gateway.networkKey=now.networkKey?:@"";return changed;
}
- (BOOL)contextIsCurrent{LGNetworkContext *now=[LGNetworkContext current];return now&&[now.fingerprint isEqual:self.context.fingerprint];}
- (void)background{[self.scanner cancel];self.scanning=NO;[self.activity stopAnimating];[self.refreshControl endRefreshing];self.navigationItem.leftBarButtonItem.title=@"Scan";[self.gateway invalidate:@"Paused; authorization will be rechecked"];for(LGDevice *d in self.devices)d.restrictionKnown=NO;[self.refreshTimer invalidate];self.refreshTimer=nil;}
- (void)foreground{if(self.navigationController.topViewController!=self)return;if(!self.refreshTimer)self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(tick) userInfo:nil repeats:YES];[self tick];}
- (void)tick{
 BOOL changed=[self updateContext];[self render];if(self.pending.count||self.restoringAll)return;
 if(!self.scanning){if(changed||!self.lastScan||-[self.lastScan timeIntervalSinceNow]>45)[self scan];else [self.gateway detect:^(NSString *status){(void)status;[self refreshAdapter];}];}
}
- (void)scan{
 if(self.pending.count||self.restoringAll){[self.refreshControl endRefreshing];return;}
 if(self.scanning){[self.scanner cancel];self.scanning=NO;[self.activity stopAnimating];self.navigationItem.leftBarButtonItem.title=@"Scan";[self.refreshControl endRefreshing];self.scanExplanation=@"Scan cancelled; previous completed results retained";[self render];return;}
 [self updateContext];self.scanning=YES;self.navigationItem.leftBarButtonItem.title=@"Cancel";[self.activity startAnimating];[self render];
 [self.scanner scan:^(NSArray<LGDevice*> *devices,NSString *explanation){self.scanning=NO;[self.activity stopAnimating];[self.refreshControl endRefreshing];self.navigationItem.leftBarButtonItem.title=@"Scan";self.scanExplanation=explanation;self.lastScan=NSDate.date;
  LGNetworkContext *scanned=self.scanner.context;NSDictionary *metrics=self.scanner.metrics;[self updateContext];if(scanned&&[scanned.fingerprint isEqual:self.context.fingerprint]){self.devices=devices;self.scanner.metrics=metrics;}else self.devices=@[];
  for(LGDevice *d in self.devices)[self loadPreferences:d];[self filterChanged];
  [LGStore record:[NSString stringWithFormat:@"Scan: %@ entries; %@ responses; %@ cached; %@ unknown; %@ invalid neighbor identifiers excluded",metrics[@"discovered"]?:@0,metrics[@"reachable"]?:@0,metrics[@"cached"]?:@0,metrics[@"unknown"]?:@0,metrics[@"rejectedNeighbors"]?:@0]];
  if(self.context)[self.gateway detect:^(NSString *status){(void)status;[self refreshAdapter];}];
 }];
}
- (NSString*)preferenceKey:(LGDevice*)d {
 NSString *network=self.context.networkKey?:@"unknown";return d.mac.length&&!d.macSelfReported?[NSString stringWithFormat:@"device.v3:%@:mac:%@",network,d.mac]:[NSString stringWithFormat:@"device.v3:%@:address:%@",network,d.ip];
}
- (void)loadPreferences:(LGDevice*)d {
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;NSString *key=[self preferenceKey:d];NSDictionary *prefs=[defaults dictionaryForKey:key];
 if(!prefs&&d.mac.length&&!d.macSelfReported){prefs=[defaults dictionaryForKey:[@"device:" stringByAppendingString:d.mac]];if(prefs)[defaults setObject:prefs forKey:key];}
 if(!prefs){NSDictionary *old=[defaults dictionaryForKey:[@"device.v2:" stringByAppendingString:d.identityKey]];if(old){NSMutableDictionary *migrated=[old mutableCopy];migrated[@"expires"]=@(NSDate.date.timeIntervalSince1970+900);prefs=migrated;[defaults setObject:prefs forKey:key];}}
 if(prefs[@"expires"]&&[prefs[@"expires"] doubleValue]<NSDate.date.timeIntervalSince1970)prefs=nil;
 if([prefs[@"mac"] isKindOfClass:NSString.class]&&[prefs[@"mac"] length]&&d.mac.length&&![prefs[@"mac"] isEqual:d.mac])prefs=nil;
 if([prefs[@"name"] isKindOfClass:NSString.class])d.name=prefs[@"name"];d.favorite=[prefs[@"favorite"] boolValue];d.protectedDevice=d.systemProtected||[prefs[@"protected"] boolValue];
}
- (void)savePreferences:(LGDevice*)d {
 NSMutableDictionary *prefs=[@{@"name":d.name?:@"",@"favorite":@(d.favorite),@"protected":@(d.protectedDevice),@"mac":d.mac?:@""} mutableCopy];if(!d.mac.length||d.macSelfReported)prefs[@"expires"]=@(NSDate.date.timeIntervalSince1970+900);[NSUserDefaults.standardUserDefaults setObject:prefs forKey:[self preferenceKey:d]];[self filterChanged];
}
- (void)refreshAdapter{
 NSUInteger epoch=self.contextEpoch;NSString *endpoint=self.gateway.endpoint;
 if(!self.gateway.supported){for(LGDevice *d in self.devices)d.restrictionKnown=NO;[self render];return;}
 [self.gateway request:@"GET" path:@"/v1/devices" body:nil done:^(NSDictionary *r,NSError *error){
  if(epoch!=self.contextEpoch||![endpoint isEqual:self.gateway.endpoint]||![self contextIsCurrent])return;
  if(!error&&[r[@"devices"] isKindOfClass:NSArray.class]){NSMutableDictionary *mapping=[NSMutableDictionary new];NSMutableSet *conflicts=[NSMutableSet new];
   for(id row in r[@"devices"]){if(![row isKindOfClass:NSDictionary.class]||![row[@"dst"] isKindOfClass:NSString.class]||![row[@"lladdr"] isKindOfClass:NSString.class])continue;char mac[18];if(!lg_normalize_mac([row[@"lladdr"] UTF8String],mac))continue;NSString *ip=row[@"dst"];if(mapping[ip]&&![mapping[ip] isEqual:@(mac)])[conflicts addObject:ip];mapping[ip]=@(mac);}
   for(LGDevice *d in self.devices)if(mapping[d.ip]&&![conflicts containsObject:d.ip]){d.mac=mapping[d.ip];d.identitySource=@"Authenticated gateway neighbor cache";d.macSelfReported=NO;[self loadPreferences:d];}
  }[self refreshRestrictions];
 }];
}
- (void)refreshRestrictions{[self refreshRestrictionsCompleting:nil];}
- (void)refreshRestrictionsCompleting:(LGDevice*)target{
 if(!self.gateway.supported){if(target)[self.pending removeObject:target.identityKey];[self render];return;}
 NSUInteger epoch=self.contextEpoch;NSString *endpoint=self.gateway.endpoint;
 [self.gateway request:@"GET" path:@"/v1/restrictions" body:nil done:^(NSDictionary *r,NSError *error){
  if(target)[self.pending removeObject:target.identityKey];if(epoch!=self.contextEpoch||![endpoint isEqual:self.gateway.endpoint]||![self contextIsCurrent]){[self updateContext];[self render];return;}
  if(error||![r[@"active"] isKindOfClass:NSDictionary.class]){for(LGDevice *d in self.devices)d.restrictionKnown=NO;[self.gateway invalidate:error?error.localizedDescription:@"Invalid router readback"];[self render];return;}
  NSDictionary *active=r[@"active"];for(LGDevice *d in self.devices){if(d.pending&&d!=target)continue;[d applyRulePresence:d.mac.length&&active[d.mac]!=nil];}
  NSString *prefix=[NSString stringWithFormat:@"%@|%@|",self.context.networkKey,self.gateway.endpoint];
  for(NSString *key in [LGStore journal].allKeys)if([key hasPrefix:prefix]){NSDictionary *entry=[LGStore journal][key];BOOL busy=NO;for(LGDevice *d in self.devices)if([d.ip isEqual:entry[@"ip"]]&&[self.pending containsObject:d.identityKey])busy=YES;if(!busy)[LGStore removeJournal:key];}
  [self render];
 }];
}
- (void)render{
 self.networkLabel.text=self.context?self.context.title:@"Wi-Fi disconnected";self.connectionLabel.text=self.scanning?@"Scanning local addresses…":(self.context?@"Local network · tap Network for details":@"Connect to Wi-Fi to scan");
 NSUInteger replied=0,cached=0,unknown=0,rules=0;for(LGDevice *d in self.devices){if(d.reachability>=LGReachabilityResponded)replied++;else if(d.reachability==LGReachabilityCached)cached++;else unknown++;if(d.restricted)rules++;}
 self.counts.text=[NSString stringWithFormat:@"%lu entries    %lu responded    %lu rules",(unsigned long)self.devices.count,(unsigned long)replied,(unsigned long)rules];self.subcounts.text=[NSString stringWithFormat:@"Cached %lu · Unknown %lu · Internet unverified",(unsigned long)cached,(unsigned long)unknown];
 [self.authorizationButton setTitle:self.gateway.supported?@"Authorized gateway connected  ›":@"Access control unavailable · tap to see why  ›" forState:UIControlStateNormal];[self.authorizationButton setTitleColor:self.gateway.supported?LGStyle.accent:LGStyle.amber forState:UIControlStateNormal];self.restoreButton.enabled=self.gateway.supported&&!self.pending.count&&!self.restoringAll;[self.tableView reloadData];
}
- (void)filterChanged{[self updateSearchResultsForSearchController:self.search];}
- (void)updateSearchResultsForSearchController:(UISearchController*)search{
 NSString *q=search.searchBar.text.lowercaseString?:@"";NSInteger selected=self.filter.selectedSegmentIndex;
 self.visible=[self.devices filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LGDevice *d,NSDictionary *bindings){(void)bindings;BOOL group=selected==0||(selected==1&&d.reachability>=LGReachabilityResponded)||(selected==2&&d.reachability==LGReachabilityCached)||(selected==3&&d.reachability==LGReachabilityUnknown);return group&&(!q.length||[d.displayName.lowercaseString containsString:q]||[d.ip containsString:q]||[d.mac containsString:q]);}]];
 self.visible=[self.visible sortedArrayUsingComparator:^NSComparisonResult(LGDevice *a,LGDevice *b){if(a.favorite!=b.favorite)return a.favorite?NSOrderedAscending:NSOrderedDescending;return [a.ip compare:b.ip options:NSNumericSearch];}];[self render];
}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section{(void)tableView;(void)section;return self.visible.count;}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)index{
 LGDeviceCell *cell=[tableView dequeueReusableCellWithIdentifier:@"device" forIndexPath:index];LGDevice *d=self.visible[index.row];[cell render:d available:self.gateway.supported&&!self.restoringAll&&![self.pending containsObject:d.identityKey]];cell.actionButton.tag=index.row;[cell.actionButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];[cell.actionButton addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];return cell;
}
- (void)toggle:(UIButton*)button{if(button.tag<0||(NSUInteger)button.tag>=self.visible.count)return;LGDevice *d=self.visible[button.tag];[self operate:d restore:d.routerRulePresent];}
- (void)operate:(LGDevice*)d restore:(BOOL)restore{
 char mac[18];if(self.restoringAll||d.protectedDevice||!lg_normalize_mac(d.mac.UTF8String,mac)||!self.gateway.supported||[self.pending containsObject:d.identityKey])return;
 if(![self contextIsCurrent]||[d.ip isEqual:@(self.context.network.ip)]||[d.ip isEqual:@(self.context.network.gateway)]){[self updateContext];[self render];return;}
 NSUInteger epoch=self.contextEpoch;NSString *endpoint=self.gateway.endpoint;NSString *key=[NSString stringWithFormat:@"%@|%@|%@",self.context.networkKey,endpoint,d.mac];
 [LGStore journal:@{@"ip":d.ip,@"mac":d.mac,@"restore":@(restore),@"time":@(NSDate.date.timeIntervalSince1970),@"expiresAfter":@300} key:key];
 [self.pending addObject:d.identityKey];d.hasIntent=YES;d.desiredRestricted=!restore;d.restrictionKnown=NO;d.control=restore?LGControlRestoring:LGControlRestricting;[self render];
 [self.gateway request:restore?@"DELETE":@"PUT" path:[@"/v1/restrictions/" stringByAppendingString:d.mac] body:restore?nil:@{@"seconds":@300,@"ip":d.ip} done:^(NSDictionary *r,NSError *error){
  (void)r;if(epoch!=self.contextEpoch||![endpoint isEqual:self.gateway.endpoint]||![self contextIsCurrent]){[self.pending removeObject:d.identityKey];[self updateContext];[self render];return;}
  d.control=LGControlUnverified;d.operationError=error?error.localizedDescription:@"Request accepted; router readback pending";[LGStore record:[NSString stringWithFormat:@"%@ %@ · %@",restore?@"Unkill":@"Kill",d.ip,d.operationError]];[self refreshRestrictionsCompleting:d];[self render];
 }];
}

- (void)message:(NSString*)title text:(NSString*)text{if(self.presentedViewController)return;UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:1];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];[self presentViewController:a animated:YES completion:nil];}
- (void)showText:(NSString*)text title:(NSString*)title{
 UIViewController *v=[UIViewController new];v.title=title;UITextView *view=[[UITextView alloc]initWithFrame:self.view.bounds];view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;view.backgroundColor=LGStyle.background;view.textColor=UIColor.whiteColor;view.font=[UIFont systemFontOfSize:15];view.textContainerInset=UIEdgeInsetsMake(20,20,24,20);view.editable=NO;view.text=text;v.view=view;[self.navigationController pushViewController:v animated:YES];
}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)index {
 [tableView deselectRowAtIndexPath:index animated:YES];LGDeviceDetailsController *details=[[LGDeviceDetailsController alloc]initWithStyle:UITableViewStyleGrouped];details.device=self.visible[index.row];details.authorizationStatus=self.gateway.authorizationStatus;__weak typeof(self) weakSelf=self;details.onChange=^(LGDevice *device){[weakSelf savePreferences:device];};[self.navigationController pushViewController:details animated:YES];
}
- (void)settings {
 if(self.pending.count||self.restoringAll){[self message:@"Operation pending" text:@"Finish gateway verification before changing authorization."];return;}
 [self updateContext];LGAuthorizationController *form=[[LGAuthorizationController alloc]initWithStyle:UITableViewStyleGrouped];form.gateway=self.gateway;form.expectedNetwork=self.context.networkKey;__weak typeof(self) weakSelf=self;form.onChange=^{weakSelf.contextEpoch++;for(LGDevice *d in weakSelf.devices)d.restrictionKnown=NO;[weakSelf refreshAdapter];[weakSelf render];};[self.navigationController pushViewController:form animated:YES];
}
- (void)networkDetails{
 LGNetworkContext *context=[LGNetworkContext current];if(!context){[self message:@"Disconnected" text:@"Local Wi-Fi IPv4 is unavailable."];return;}LGNetwork n=context.network;
 NSString *text=[NSString stringWithFormat:@"NETWORK\n%@\nInterface: %s\nThis iPhone: %s\nMask: %s\nGateway: %s\nSSID: %@\n\nDISCOVERY EVIDENCE\n%@\nScan budget: %@ addresses; 12 concurrent TCP/443 probes; 300 ms each. PTR lookup budget: 400 ms; directed NetBIOS: 150 ms; Bonjour collection: 1.5 seconds. Network-reported clues are not authenticated identity.\nExcluded invalid neighbor identifiers: %@\n\nCOUNT DEFINITIONS\nResponded = TCP connection or refusal, plus this iPhone. This is address response evidence, not authenticated physical identity. Cached = valid current neighbor with no TCP response. Unknown = a previously responding address not verified now. Categories are mutually exclusive. DHCP may reassign historical addresses.\n\nACCESS CONTROL\n%@\nEndpoint: %@\nRecovery records: %lu\nOnly router rule presence/removal is verified. Target Internet access requires an independent client test.\n\nAPP\nLanGuard 0.3.0-beta.1",context.title,n.interface,n.ip,n.mask,n.gateway,context.ssid.length?context.ssid:@"Unavailable under current OS permissions",[self.scanExplanation stringByAppendingFormat:@"\nTCP accepted: %@ · refused: %@ · neighbor view: %@",self.scanner.metrics[@"tcpAccepted"]?:@0,self.scanner.metrics[@"tcpRefused"]?:@0,self.scanner.metrics[@"neighborView"]?:@0],self.scanner.metrics[@"probed"]?:@0,self.scanner.metrics[@"rejectedNeighbors"]?:@0,self.gateway.authorizationStatus,self.gateway.endpoint.length?self.gateway.endpoint:@"Not configured",(unsigned long)LGStore.journal.count];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Network & diagnostics" message:@"View network evidence or perform a gateway reachability check." preferredStyle:1];
 [a addAction:[UIAlertAction actionWithTitle:@"View details" style:0 handler:^(UIAlertAction *action){(void)action;[self showText:text title:@"Network details"];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Check gateway TCP reachability" style:0 handler:^(UIAlertAction *action){(void)action;[self diagnostics];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Close" style:1 handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
- (void)diagnostics{
 LGNetworkContext *context=[LGNetworkContext current];if(!context||!context.network.gateway[0]){[self message:@"Diagnostics" text:@"Gateway unavailable"];return;}NSString *ip=@(context.network.gateway);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{double ms=0;BOOL responded=lg_probe(ip.UTF8String,1000,&ms);dispatch_async(dispatch_get_main_queue(),^{NSString *result=[NSString stringWithFormat:@"Gateway %@\nTCP/443: %@\nMeasured interval: %.1f ms\n\nA connection or refusal is local address-response evidence. A timeout is unknown, not proof of offline or Internet restriction.",ip,responded?@"Response observed":@"Unknown / no response",ms];[LGStore record:result];[self showText:result title:@"Diagnostics"];});});
}
- (void)history{NSMutableString *text=[NSMutableString new];for(NSDictionary *event in LGStore.history)[text appendFormat:@"%@\n%@\n\n",event[@"time"],event[@"event"]];[self showText:text.length?text:@"No recorded operations." title:@"History"];}
- (void)restoreAll{
 if(!self.gateway.supported||self.pending.count||self.restoringAll)return;
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Restore LanGuard rules?" message:@"Only the enrolled adapter’s LanGuard set will be changed. Other firewall policies are preserved. Internet restoration still needs a client test." preferredStyle:1];
 [a addAction:[UIAlertAction actionWithTitle:@"Restore all" style:2 handler:^(UIAlertAction *action){(void)action;self.restoringAll=YES;NSUInteger epoch=self.contextEpoch;[self render];
  [self.gateway request:@"DELETE" path:@"/v1/restrictions" body:nil done:^(NSDictionary *r,NSError *error){(void)r;self.restoringAll=NO;if(epoch!=self.contextEpoch||![self contextIsCurrent]){[self updateContext];[self render];return;}[LGStore record:error?[@"Restore All unverified: " stringByAppendingString:error.localizedDescription]:@"Restore All submitted; independent router-set readback requested"];[self refreshRestrictions];[self render];}];
 }]];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:1 handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
@end
