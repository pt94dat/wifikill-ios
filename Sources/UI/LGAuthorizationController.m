#import "LGAuthorizationController.h"
#import "Storage/LGStore.h"
#import "Network/LGNetworkContext.h"
#import "DesignSystem/LGStyle.h"
@interface LGAuthorizationController ()
@property(nonatomic,strong) UITextField *endpointField,*tokenField;
@property(nonatomic,copy) NSString *feedback;
@property(nonatomic) BOOL saving;
@end
@implementation LGAuthorizationController
- (void)viewDidLoad {
 [super viewDidLoad];self.title=@"Network access";self.tableView.backgroundColor=LGStyle.background;self.tableView.separatorColor=LGStyle.background;self.tableView.rowHeight=UITableViewAutomaticDimension;self.tableView.estimatedRowHeight=80;self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
 self.endpointField=[self field:NO];self.endpointField.text=self.gateway.endpoint;self.endpointField.placeholder=@"https://gateway-name:8443";self.endpointField.keyboardType=UIKeyboardTypeURL;
 self.tokenField=[self field:YES];self.tokenField.placeholder=@"Enrolled gateway token";
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (UITextField*)field:(BOOL)secure{UITextField *f=[UITextField new];f.secureTextEntry=secure;f.delegate=self;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.autocorrectionType=UITextAutocorrectionTypeNo;f.textColor=UIColor.whiteColor;f.font=[UIFont systemFontOfSize:15];f.returnKeyType=UIReturnKeyDone;return f;}
- (BOOL)textFieldShouldReturn:(UITextField*)textField{[textField resignFirstResponder];return YES;}
- (void)keyboard:(NSNotification*)note{CGRect frame=[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];CGRect local=[self.view convertRect:frame fromView:nil];CGFloat overlap=MAX(0,CGRectGetMaxY(self.view.bounds)-CGRectGetMinY(local)-self.view.safeAreaInsets.bottom);UIEdgeInsets insets=self.tableView.contentInset;insets.bottom=overlap;self.tableView.contentInset=insets;self.tableView.scrollIndicatorInsets=insets;}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView{(void)tableView;return 5;}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section{(void)tableView;return section==3?(NSInteger)self.gateway.candidates.count+1:1;}
- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section{(void)tableView;return @[@"Capability",@"HTTPS endpoint",@"Authorization token",@"Advertised suggestions",@"Recovery"][section];}
- (NSString*)tableView:(UITableView*)tableView titleForFooterInSection:(NSInteger)section{(void)tableView;if(section==0)return @"Discovery works independently. Kill requires an administrator-controlled compatible gateway component. A jailbreak alone does not provide router-management authority.";if(section==2)return @"This is not your Wi-Fi password. Blank keeps the token for this exact endpoint. Tokens stay in Keychain; enrollment is saved for this network.";if(section==3)return @"Tap a suggestion to select it; it is not trusted until you explicitly save and authorize. If none is advertised, the gateway component may be absent or its advertisement blocked. Find again using the button below.";return nil;}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)index{(void)tableView;UITableViewCell *cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.backgroundColor=LGStyle.surface;cell.textLabel.textColor=UIColor.whiteColor;cell.detailTextLabel.textColor=LGStyle.muted;cell.textLabel.numberOfLines=0;cell.detailTextLabel.numberOfLines=0;
 if(index.section==0){cell.textLabel.text=self.feedback?:self.gateway.authorizationStatus;cell.detailTextLabel.text=@"Supported reference: LanGuard HTTPS gateway on Linux/nftables. Stock routers without an authorized adapter remain unsupported.";}
 else if(index.section==1||index.section==2){UITextField *field=index.section==1?self.endpointField:self.tokenField;[cell.contentView addSubview:field];field.translatesAutoresizingMaskIntoConstraints=NO;[NSLayoutConstraint activateConstraints:@[[field.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],[field.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],[field.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:14],[field.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-14],[field.heightAnchor constraintGreaterThanOrEqualToConstant:30]]];}
 else if(index.section==3){cell.textLabel.text=index.row<(NSInteger)self.gateway.candidates.count?self.gateway.candidates[index.row]:@"Find advertised adapters";cell.detailTextLabel.text=@"Local suggestions only; no token is sent automatically.";}
 else{cell.textLabel.text=@"Forget this endpoint’s authorization";cell.detailTextLabel.text=@"Restore owned rules first, or allow existing five-minute leases to expire.";cell.textLabel.textColor=LGStyle.red;}
 return cell;
}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)index{[tableView deselectRowAtIndexPath:index animated:YES];if(index.section==3){if(index.row<(NSInteger)self.gateway.candidates.count){self.endpointField.text=self.gateway.candidates[index.row];self.tokenField.text=@"";self.feedback=@"Suggestion selected; enter its enrolled token and Save.";[self.tableView reloadData];}else [self find];}else if(index.section==4){if(self.saving)return;[LGStore setToken:@"" endpoint:self.gateway.endpoint];[LGStore setToken:@""];[self.gateway invalidate:@"Authorization removed"];self.feedback=@"Authorization removed. Existing gateway leases expire independently.";if(self.onChange)self.onChange();[self.tableView reloadData];}}
- (void)find{[self.view endEditing:YES];[self.gateway discover];self.feedback=@"Searching local advertisements…";[self.tableView reloadData];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{self.feedback=self.gateway.candidates.count?@"Suggestions found; select one to enroll":@"No service advertised. This is not proof that every management protocol is unsupported.";[self.tableView reloadData];});}
- (void)save{
 if(self.saving)return;[self.view endEditing:YES];LGNetworkContext *now=[LGNetworkContext current];NSString *endpoint=[LGGateway canonicalEndpoint:self.endpointField.text];
 if(!now||![now.networkKey isEqual:self.expectedNetwork]||!endpoint){self.feedback=@"Not saved: check Wi-Fi and use an HTTPS origin without path, credentials or query.";[self.tableView reloadData];return;}
 NSString *token=self.tokenField.text;if(!token.length&&![LGStore tokenForEndpoint:endpoint].length){self.feedback=@"No enrolled token exists for this endpoint. Deploy/enroll a compatible gateway component first.";[self.tableView reloadData];return;}
 if(token.length&&![LGStore setToken:token endpoint:endpoint]){self.feedback=@"Keychain rejected token storage; existing authorization was not replaced.";[self.tableView reloadData];return;}
 [self.gateway invalidate:@"Authorization updated"];self.gateway.endpoint=endpoint;self.gateway.networkKey=now.networkKey;[NSUserDefaults.standardUserDefaults setObject:endpoint forKey:@"endpoint"];[self.gateway bindCurrentNetwork];self.saving=YES;self.navigationItem.rightBarButtonItem.enabled=NO;self.feedback=@"Checking authenticated gateway capability…";[self.tableView reloadData];
 [self.gateway detect:^(NSString *status){self.saving=NO;self.navigationItem.rightBarButtonItem.enabled=YES;self.feedback=status;self.tokenField.text=@"";if(self.onChange)self.onChange();[self.tableView reloadData];}];
}
@end
