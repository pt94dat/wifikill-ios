#import "LGNetworkController.h"
#import "Network/LGScanner.h"
#import "RouterManagement/LGGateway.h"
#import "Storage/LGStore.h"
@interface LGNetworkController ()
@property(nonatomic,strong) LGScanner *scanner;
@property(nonatomic,strong) LGGateway *gateway;
@property(nonatomic,strong) NSArray<LGDevice*> *devices,*visible;
@property(nonatomic,strong) NSMutableSet *pending;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,strong) UILabel *summary;
@property(nonatomic,strong) NSTimer *refreshTimer;
@property(nonatomic) BOOL scanning, restoringAll;
@property(nonatomic,copy) NSString *networkID;
@end
@implementation LGNetworkController
- (void)viewDidLoad {
 [super viewDidLoad];self.title=@"LanGuard";self.devices=@[];self.visible=@[];self.pending=[NSMutableSet new];self.scanner=[LGScanner new];self.gateway=[LGGateway new];
 self.tableView.backgroundColor=[UIColor colorWithRed:.04 green:.07 blue:.11 alpha:1];self.tableView.separatorColor=[UIColor colorWithWhite:.2 alpha:1];self.tableView.rowHeight=88;
 self.summary=[[UILabel alloc]initWithFrame:CGRectMake(16,0,343,95)];self.summary.numberOfLines=0;self.summary.font=[UIFont systemFontOfSize:13];self.summary.textColor=UIColor.lightGrayColor;self.summary.text=@"Scan your authorized Wi-Fi network. Access control requires a compatible authenticated gateway agent.";self.tableView.tableHeaderView=self.summary;
 self.search=[[UISearchController alloc]initWithSearchResultsController:nil];self.search.searchResultsUpdater=self;self.search.obscuresBackgroundDuringPresentation=NO;self.navigationItem.searchController=self.search;self.definesPresentationContext=YES;
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(settings)];
 self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Scan" style:UIBarButtonItemStylePlain target:self action:@selector(scan)];
 self.refreshControl=[UIRefreshControl new];[self.refreshControl addTarget:self action:@selector(scan) forControlEvents:UIControlEventValueChanged];
 self.toolbarItems=@[[[UIBarButtonItem alloc]initWithTitle:@"Diagnostics" style:0 target:self action:@selector(diagnostics)],[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],[[UIBarButtonItem alloc]initWithTitle:@"History" style:0 target:self action:@selector(history)],[[UIBarButtonItem alloc]initWithTitle:@"Restore all" style:0 target:self action:@selector(restoreAll)]];self.navigationController.toolbarHidden=NO;
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];[self scan];
}
- (void)background { [self.scanner cancel];self.scanning=NO;[self.refreshControl endRefreshing];self.navigationItem.leftBarButtonItem.title=@"Scan";self.gateway.supported=NO;[self.refreshTimer invalidate];self.refreshTimer=nil; }
- (void)foreground { if(!self.refreshTimer)self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(autoRefresh) userInfo:nil repeats:YES];[self autoRefresh]; }
- (void)autoRefresh { if(!self.scanning&&self.pending.count==0)[self scan]; }
- (void)scan {
 if(self.scanning){[self.scanner cancel];self.scanning=NO;[self.refreshControl endRefreshing];self.navigationItem.leftBarButtonItem.title=@"Scan";return;}
 LGNetwork n;if(!lg_network(&n)){NSString *identity=[NSString stringWithFormat:@"%s|%s|%s",n.ip,n.mask,n.gateway];if(self.networkID&&![self.networkID isEqual:identity]){self.gateway.supported=NO;self.devices=@[];[self.pending removeAllObjects];}self.networkID=identity;}
 self.scanning=YES;self.navigationItem.leftBarButtonItem.title=@"Cancel";self.summary.text=@"Scanning local subnet…";
 [self.scanner scan:^(NSArray *devices,NSString *info){self.scanning=NO;self.navigationItem.leftBarButtonItem.title=@"Scan";[self.refreshControl endRefreshing];self.devices=devices;
 for(LGDevice *d in devices){NSDictionary *prefs=[NSUserDefaults.standardUserDefaults dictionaryForKey:[@"device:" stringByAppendingString:d.mac.length?d.mac:[NSString stringWithFormat:@"%@:%@",self.networkID?:@"unknown",d.ip]]];d.name=prefs[@"name"]?:d.name;d.favorite=[prefs[@"favorite"] boolValue];d.protectedDevice|=[prefs[@"protected"] boolValue];}
 self.summary.text=[NSString stringWithFormat:@"%@\n%lu discovered · reachability is not Internet access\nAccess control: %@",info,(unsigned long)devices.count,self.gateway.supported?@"configured":@"unsupported until authorized"];
 [self updateSearchResultsForSearchController:self.search];[LGStore record:[NSString stringWithFormat:@"Scan: %lu devices",(unsigned long)devices.count]];
 if(self.gateway.endpoint.length)[self.gateway detect:^(NSString *status){self.summary.text=[self.summary.text stringByAppendingFormat:@"\n%@",status];[self refreshRestrictions];}];
 }];
}
- (void)refreshRestrictions { if(!self.gateway.supported)return;[self.gateway request:@"GET" path:@"/v1/restrictions" body:nil done:^(NSDictionary *r,NSError *e){if(e){self.gateway.supported=NO;[self.tableView reloadData];return;}NSDictionary *active=r[@"active"];if(![active isKindOfClass:NSDictionary.class]){self.gateway.supported=NO;return;}for(LGDevice *d in self.devices){d.restricted=active[d.mac]!=nil;if(d.restricted)d.status=@"Router rule present · end-to-end unverified";}[self.tableView reloadData];}]; }
- (void)updateSearchResultsForSearchController:(UISearchController*)s { NSString *q=s.searchBar.text.lowercaseString?:@"";self.visible=[self.devices filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LGDevice *d,NSDictionary *bindings){(void)bindings;return !q.length||[d.name.lowercaseString containsString:q]||[d.ip containsString:q]||[d.mac containsString:q];}]];self.visible=[self.visible sortedArrayUsingComparator:^NSComparisonResult(LGDevice *a,LGDevice *b){if(a.favorite!=b.favorite)return a.favorite?NSOrderedAscending:NSOrderedDescending;return [a.ip compare:b.ip options:NSNumericSearch];}];[self.tableView reloadData]; }
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {(void)tableView;(void)section;return self.visible.count;}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)index {
 UITableViewCell *c=[tableView dequeueReusableCellWithIdentifier:@"device"];if(!c)c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"device"];
 LGDevice *d=self.visible[index.row];c.backgroundColor=[UIColor colorWithRed:.07 green:.10 blue:.15 alpha:1];c.textLabel.textColor=UIColor.whiteColor;c.detailTextLabel.textColor=UIColor.lightGrayColor;c.detailTextLabel.numberOfLines=2;c.textLabel.text=[NSString stringWithFormat:@"%@%@",d.favorite?@"★ ":@"",d.name];c.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@\n%@",d.ip,d.mac.length?d.mac:@"MAC unavailable",d.status];
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.frame=CGRectMake(0,0,88,44);BOOL pending=[self.pending containsObject:d.mac];[b setTitle:pending?@"Pending…":(d.protectedDevice?@"Protected":(d.restricted?@"Unkill":@"Kill")) forState:UIControlStateNormal];b.enabled=!pending&&!self.restoringAll&&!d.protectedDevice&&d.mac.length&&self.gateway.supported;b.tag=index.row;[b addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];c.accessoryView=b;return c;
}
- (void)toggle:(UIButton*)button { if(button.tag<0||(NSUInteger)button.tag>=self.visible.count)return;LGDevice *d=self.visible[button.tag];[self operate:d restore:d.restricted]; }
- (void)operate:(LGDevice*)d restore:(BOOL)restore {
 if(self.restoringAll||d.protectedDevice||!d.mac.length||!self.gateway.supported||[self.pending containsObject:d.mac])return;
 LGNetwork n;if(lg_network(&n)||[d.ip isEqualToString:@(n.ip)]||[d.ip isEqualToString:@(n.gateway)])return;
 [self.pending addObject:d.mac];d.status=restore?@"Restoration requested":@"Restriction requested";[self.tableView reloadData];
 NSString *path=[@"/v1/restrictions/" stringByAppendingString:d.mac];
 [self.gateway request:restore?@"DELETE":@"PUT" path:path body:restore?nil:@{@"seconds":@300,@"ip":d.ip} done:^(NSDictionary *r,NSError *e){[self.pending removeObject:d.mac];if(e)d.status=[@"Failed/unverified: " stringByAppendingString:e.localizedDescription];else if([r[@"router_verified"] boolValue]){d.restricted=[r[@"restricted"] boolValue];d.status=d.restricted?@"Router restriction verified · 5 min lease":@"Router rule removed · Internet unverified";}else d.status=@"Operation unverified";[LGStore record:[NSString stringWithFormat:@"%@ %@: %@",restore?@"Unkill":@"Kill",d.ip,d.status]];[self.tableView reloadData];}];
}
- (void)message:(NSString*)title text:(NSString*)text { UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:1];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];[self presentViewController:a animated:YES completion:nil]; }
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)index {
 [tableView deselectRowAtIndexPath:index animated:YES];LGDevice *d=self.visible[index.row];UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Device details" message:[NSString stringWithFormat:@"%@\n%@\n%@\nLast seen: %@\nManufacturer: unavailable",d.ip,d.mac,d.status,d.lastSeen?:@"unknown"] preferredStyle:1];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.text=d.name;f.placeholder=@"Custom name";}];
 void(^save)(void)=^{NSString *key=[@"device:" stringByAppendingString:d.mac.length?d.mac:[NSString stringWithFormat:@"%@:%@",self.networkID?:@"unknown",d.ip]];[NSUserDefaults.standardUserDefaults setObject:@{@"name":d.name,@"protected":@(d.protectedDevice),@"favorite":@(d.favorite)} forKey:key];[self updateSearchResultsForSearchController:self.search];};
 [a addAction:[UIAlertAction actionWithTitle:@"Save name" style:0 handler:^(UIAlertAction *action){(void)action;d.name=a.textFields.firstObject.text.length?a.textFields.firstObject.text:d.ip;save();}]];
 [a addAction:[UIAlertAction actionWithTitle:d.favorite?@"Remove favorite":@"Favorite" style:0 handler:^(UIAlertAction *action){(void)action;d.favorite=!d.favorite;save();}]];
 LGNetwork network;BOOL systemProtected=lg_network(&network)||[d.ip isEqualToString:@(network.ip)]||[d.ip isEqualToString:@(network.gateway)];
 if(!d.restricted&&!systemProtected)[a addAction:[UIAlertAction actionWithTitle:d.protectedDevice?@"Remove protection":@"Protect device" style:0 handler:^(UIAlertAction *action){(void)action;d.protectedDevice=!d.protectedDevice;save();}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Close" style:1 handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
- (void)settings {
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Authorized gateway" message:@"Optional vendor-independent gateway agent. Use its HTTPS URL and enrolled token. TLS must be trusted by iOS. No router credentials are sent elsewhere. Kill leases expire after 5 minutes." preferredStyle:1];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"https://gateway-name:8443";f.text=self.gateway.endpoint;f.keyboardType=UIKeyboardTypeURL;f.autocapitalizationType=UITextAutocapitalizationTypeNone;}];
 [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"Gateway token (blank keeps existing)";f.secureTextEntry=YES;}];
 [a addAction:[UIAlertAction actionWithTitle:@"Save & detect" style:0 handler:^(UIAlertAction *action){(void)action;NSString *token=a.textFields[1].text;if(token.length&&![LGStore setToken:token]){[self message:@"Not saved" text:@"Keychain rejected token storage"];return;}self.gateway.endpoint=[a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];[NSUserDefaults.standardUserDefaults setObject:self.gateway.endpoint forKey:@"endpoint"];[self.gateway detect:^(NSString *status){[self message:@"Gateway capability" text:status];[self refreshRestrictions];[self.tableView reloadData];}];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Forget authorization" style:2 handler:^(UIAlertAction *action){(void)action;[LGStore setToken:@""];self.gateway.supported=NO;[self.tableView reloadData];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:1 handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
- (void)history { NSMutableString *s=[NSMutableString new];for(NSDictionary *e in LGStore.history)[s appendFormat:@"%@\n%@\n\n",e[@"time"],e[@"event"]];UIViewController *v=[UIViewController new];v.title=@"History";UITextView *t=[[UITextView alloc]initWithFrame:self.view.bounds];t.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;t.editable=NO;t.text=s;t.font=[UIFont systemFontOfSize:14];v.view=t;[self.navigationController pushViewController:v animated:YES]; }
- (void)diagnostics { LGNetwork n;if(lg_network(&n)){[self message:@"Diagnostics" text:@"Wi-Fi IPv4 unavailable"];return;}NSString *gateway=@(n.gateway);dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{double ms=0;BOOL live=gateway.length&&lg_probe(gateway.UTF8String,1000,&ms);dispatch_async(dispatch_get_main_queue(),^{NSString *s=[NSString stringWithFormat:@"Gateway: %@\nTCP/443 reachability: %@\nResponse time: %.1f ms\nA response or refusal establishes local reachability only. This does not verify another device’s Internet access.",gateway,live?@"responded":@"unknown",ms];[LGStore record:s];[self message:@"Gateway diagnostic" text:s];});}); }
- (void)restoreAll { if(self.restoringAll||self.pending.count){[self message:@"Operation pending" text:@"Wait for the current gateway operation to finish before restoring all leases."];return;}if(!self.gateway.supported){[self message:@"Unsupported" text:@"Configure and authorize a compatible gateway first."];return;}UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Restore all leases?" message:@"Remove every LanGuard restriction on this enrolled gateway." preferredStyle:1];[a addAction:[UIAlertAction actionWithTitle:@"Restore all" style:2 handler:^(UIAlertAction *action){(void)action;self.restoringAll=YES;[self.tableView reloadData];[self.gateway request:@"DELETE" path:@"/v1/restrictions" body:nil done:^(NSDictionary *r,NSError *e){self.restoringAll=NO;[self.tableView reloadData];[self message:@"Restore all" text:e?e.localizedDescription:([r[@"router_verified"] boolValue]?@"Router set empty. End-to-end connectivity still requires testing.":@"Restoration unverified")];[self refreshRestrictions];}];}]];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:1 handler:nil]];[self presentViewController:a animated:YES completion:nil]; }
@end
