#import "LGDeviceCell.h"
#import "DesignSystem/LGStyle.h"
@interface LGDeviceCell()
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UILabel *nameLabel,*addressLabel,*stateLabel,*glyph;
@end
@implementation LGDeviceCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identifier{
 if((self=[super initWithStyle:style reuseIdentifier:identifier])){
 self.backgroundColor=UIColor.clearColor;self.selectionStyle=UITableViewCellSelectionStyleNone;
 self.card=[UIView new];self.card.backgroundColor=LGStyle.surface;self.card.layer.cornerRadius=14;
 self.glyph=[UILabel new];self.glyph.font=[UIFont systemFontOfSize:25 weight:UIFontWeightLight];self.glyph.textAlignment=NSTextAlignmentCenter;
 self.nameLabel=[UILabel new];self.nameLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];self.nameLabel.textColor=UIColor.whiteColor;
 self.addressLabel=[UILabel new];self.addressLabel.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];self.addressLabel.textColor=LGStyle.muted;
 self.stateLabel=[UILabel new];self.stateLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];self.stateLabel.numberOfLines=2;
 self.actionButton=[UIButton buttonWithType:UIButtonTypeSystem];self.actionButton.layer.cornerRadius=10;self.actionButton.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
 [self.contentView addSubview:self.card];for(UIView *v in @[self.glyph,self.nameLabel,self.addressLabel,self.stateLabel,self.actionButton]){[self.card addSubview:v];v.translatesAutoresizingMaskIntoConstraints=NO;}self.card.translatesAutoresizingMaskIntoConstraints=NO;
 [NSLayoutConstraint activateConstraints:@[
 [self.card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],[self.card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],[self.card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],[self.card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
 [self.glyph.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:10],[self.glyph.centerYAnchor constraintEqualToAnchor:self.card.centerYAnchor],[self.glyph.widthAnchor constraintEqualToConstant:30],
 [self.actionButton.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-10],[self.actionButton.centerYAnchor constraintEqualToAnchor:self.card.centerYAnchor],[self.actionButton.widthAnchor constraintEqualToConstant:72],[self.actionButton.heightAnchor constraintEqualToConstant:44],
 [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.glyph.trailingAnchor constant:10],[self.nameLabel.trailingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:-8],[self.nameLabel.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:12],
 [self.addressLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],[self.addressLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],[self.addressLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],
 [self.stateLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],[self.stateLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],[self.stateLabel.topAnchor constraintEqualToAnchor:self.addressLabel.bottomAnchor constant:5],[self.stateLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.card.bottomAnchor constant:-10]]];
 }return self;
}
- (void)render:(LGDevice*)d available:(BOOL)available{
 self.nameLabel.text=[NSString stringWithFormat:@"%@%@",d.favorite?@"★ ":@"",d.displayName];self.addressLabel.text=[d.displayName isEqual:d.ip]?(d.typeHint.length?d.typeHint:@"Identity unknown"):d.ip;self.stateLabel.text=d.status;
 UIColor *color=d.pending?LGStyle.amber:(d.restricted?LGStyle.red:(d.reachability>=LGReachabilityResponded?LGStyle.accent:LGStyle.muted));if(d.control==LGControlUnverified)color=LGStyle.amber;
 self.stateLabel.textColor=color;self.glyph.textColor=color;self.glyph.text=d.systemProtected?@"◇":@"◉";
 NSString *action=d.pending?@"Working…":(d.protectedDevice?@"Protected":(d.routerRulePresent?@"Unkill":@"Kill"));[self.actionButton setTitle:action forState:UIControlStateNormal];self.actionButton.hidden=!available&&!d.protectedDevice&&!d.pending;self.actionButton.enabled=available&&!d.pending&&!d.protectedDevice&&d.mac.length;
 self.actionButton.backgroundColor=self.actionButton.enabled?[LGStyle.accent colorWithAlphaComponent:.12]:[UIColor colorWithWhite:1 alpha:.035];[self.actionButton setTitleColor:LGStyle.accent forState:UIControlStateNormal];[self.actionButton setTitleColor:LGStyle.muted forState:UIControlStateDisabled];
 self.actionButton.accessibilityLabel=[NSString stringWithFormat:@"%@ %@",action,d.displayName];
}
@end
