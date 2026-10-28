#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const NIAppPreferenceDomain = @"com.minis.notifyicon";

@interface NIInstalledApp : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *bundlePath;
@property (nonatomic, strong) id proxy;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) BOOL systemApp;
@end
@implementation NIInstalledApp
@end

@interface NIAppSwitchCell : UITableViewCell
@property (nonatomic, strong) UIImageView *appIconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@property (nonatomic, strong) UISwitch *appSwitch;
@property (nonatomic, copy) void (^switchChanged)(BOOL enabled);
- (void)configureWithApp:(NIInstalledApp *)app enabled:(BOOL)enabled changed:(void (^)(BOOL enabled))changed;
@end

@implementation NIAppSwitchCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _appIconView = [UIImageView new];
    _appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _appIconView.contentMode = UIViewContentModeScaleAspectFit;
    _appIconView.clipsToBounds = YES;
    _appIconView.layer.cornerRadius = 11.0;
    _nameLabel = [UILabel new];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [UIFont systemFontOfSize:19.0];
    _nameLabel.textColor = UIColor.labelColor;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _bundleLabel = [UILabel new];
    _bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bundleLabel.font = [UIFont systemFontOfSize:14.0];
    _bundleLabel.textColor = UIColor.secondaryLabelColor;
    _bundleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _appSwitch = [UISwitch new];
    _appSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [_appSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
    UIStackView *labels = [[UIStackView alloc] initWithArrangedSubviews:@[_nameLabel, _bundleLabel]];
    labels.translatesAutoresizingMaskIntoConstraints = NO;
    labels.axis = UILayoutConstraintAxisVertical;
    labels.alignment = UIStackViewAlignmentLeading;
    labels.distribution = UIStackViewDistributionEqualCentering;
    labels.spacing = 3.0;
    [self.contentView addSubview:_appIconView];
    [self.contentView addSubview:labels];
    [self.contentView addSubview:_appSwitch];
    [NSLayoutConstraint activateConstraints:@[
        [_appIconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_appIconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_appIconView.widthAnchor constraintEqualToConstant:50.0],
        [_appIconView.heightAnchor constraintEqualToConstant:50.0],
        [labels.leadingAnchor constraintEqualToAnchor:_appIconView.trailingAnchor constant:14.0],
        [labels.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [labels.trailingAnchor constraintLessThanOrEqualToAnchor:_appSwitch.leadingAnchor constant:-12.0],
        [_appSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_appSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:78.0]
    ]];
    return self;
}
- (void)configureWithApp:(NIInstalledApp *)app enabled:(BOOL)enabled changed:(void (^)(BOOL))changed {
    self.nameLabel.text = app.name.length ? app.name : app.bundleID;
    self.bundleLabel.text = app.bundleID;
    self.appIconView.image = app.icon ?: [UIImage systemImageNamed:@"app.dashed"];
    self.appSwitch.on = enabled;
    self.switchChanged = changed;
}
- (void)switchValueChanged:(UISwitch *)sender {
    if (self.switchChanged) self.switchChanged(sender.isOn);
}
@end

@interface NIAppListController : PSListController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<NIInstalledApp *> *allApps;
@property (nonatomic, copy) NSArray<NIInstalledApp *> *systemApps;
@property (nonatomic, copy) NSArray<NIInstalledApp *> *userApps;
@property (nonatomic, copy) NSArray<NIInstalledApp *> *filteredSystemApps;
@property (nonatomic, copy) NSArray<NIInstalledApp *> *filteredUserApps;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedBundleIDs;
@property (nonatomic) BOOL allAppsEnabled;
- (void)setApp:(NIInstalledApp *)app enabled:(BOOL)enabled;
@end

@implementation NIAppListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择应用";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 78.0;
    [self.tableView registerClass:NIAppSwitchCell.class forCellReuseIdentifier:@"AppSwitch"];
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.obscuresBackgroundDuringPresentation = NO;
    _searchController.searchBar.placeholder = @"搜索应用名称或 Bundle ID";
    self.navigationItem.searchController = _searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    _tableView.tableFooterView = [UIView new];
    [self loadInstalledApps];
    [self reloadSavedSettings];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSavedSettings];
    [self.tableView reloadData];
}
- (id)message:(id)object selector:(SEL)selector {
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}
- (void)loadInstalledApps {
    if (!NSClassFromString(@"LSApplicationWorkspace")) {
        dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY | RTLD_LOCAL);
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY | RTLD_LOCAL);
    }
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    id workspace = [workspaceClass respondsToSelector:defaultSelector] ? ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultSelector) : nil;
    SEL appsSelector = NSSelectorFromString(@"allInstalledApplications");
    NSArray *proxies = [workspace respondsToSelector:appsSelector] ? ((id (*)(id, SEL))objc_msgSend)(workspace, appsSelector) : nil;
    NSMutableArray<NIInstalledApp *> *items = [NSMutableArray array];
    SEL bundleSelector = NSSelectorFromString(@"bundleIdentifier");
    SEL nameSelector = NSSelectorFromString(@"localizedName");
    SEL pathSelector = NSSelectorFromString(@"bundleURL");
    SEL placeholderSelector = NSSelectorFromString(@"isPlaceholder");
    for (id proxy in proxies) {
        id identifier = [self message:proxy selector:bundleSelector];
        if (![identifier isKindOfClass:NSString.class] || ![(NSString *)identifier length]) continue;
        if ([proxy respondsToSelector:placeholderSelector] && ((BOOL (*)(id, SEL))objc_msgSend)(proxy, placeholderSelector)) continue;
        NIInstalledApp *app = [NIInstalledApp new];
        app.bundleID = identifier;
        id displayName = [self message:proxy selector:nameSelector];
        app.name = [displayName isKindOfClass:NSString.class] && [displayName length] ? displayName : identifier;
        app.proxy = proxy;
        NSURL *bundleURL = [self message:proxy selector:pathSelector];
        app.bundlePath = [bundleURL isKindOfClass:NSURL.class] ? bundleURL.path : @"";
        app.systemApp = [app.bundlePath hasPrefix:@"/Applications/"] || [app.bundlePath hasPrefix:@"/System/Applications/"] || [app.bundlePath hasPrefix:@"/System/Library/CoreServices/"];
        [items addObject:app];
    }
    [items sortUsingComparator:^NSComparisonResult(NIInstalledApp *a, NIInstalledApp *b) {
        NSComparisonResult result = [a.name localizedCaseInsensitiveCompare:b.name];
        return result == NSOrderedSame ? [a.bundleID compare:b.bundleID] : result;
    }];
    _allApps = items;
    NSPredicate *systemPredicate = [NSPredicate predicateWithBlock:^BOOL(NIInstalledApp *app, NSDictionary *bindings) { return app.systemApp; }];
    _systemApps = [items filteredArrayUsingPredicate:systemPredicate];
    _userApps = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NIInstalledApp *app, NSDictionary *bindings) { return !app.systemApp; }]];
    _filteredSystemApps = _systemApps;
    _filteredUserApps = _userApps;
}
- (void)reloadSavedSettings {
    id all = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("AllAppsEnabled"), (__bridge CFStringRef)NIAppPreferenceDomain));
    _allAppsEnabled = all ? [all boolValue] : YES;
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("EnabledBundleIDs"), (__bridge CFStringRef)NIAppPreferenceDomain));
    NSMutableSet *ids = [NSMutableSet set];
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in value) if ([entry isKindOfClass:NSString.class]) [ids addObject:entry];
    } else if ([value isKindOfClass:NSString.class]) {
        NSArray *parts = [(NSString *)value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;\n\t "]];
        for (NSString *entry in parts) { NSString *trimmed = [entry stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (trimmed.length) [ids addObject:trimmed]; }
    }
    _selectedBundleIDs = ids;
}
- (UIImage *)iconForApp:(NIInstalledApp *)app {
    if (app.icon) return app.icon;
    SEL iconSelector = NSSelectorFromString(@"iconDataForVariant:");
    if ([app.proxy respondsToSelector:iconSelector]) {
        for (NSInteger variant = 0; variant < 4; variant++) {
            NSData *data = ((NSData *(*)(id, SEL, NSInteger))objc_msgSend)(app.proxy, iconSelector, variant);
            UIImage *image = data.length ? [UIImage imageWithData:data scale:UIScreen.mainScreen.scale] : nil;
            if (image) { app.icon = image; return image; }
        }
    }
    app.icon = [UIImage systemImageNamed:@"app.dashed"];
    return app.icon;
}
- (NSArray<NIInstalledApp *> *)appsForSection:(NSInteger)section {
    return section == 0 ? self.filteredSystemApps : self.filteredUserApps;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self appsForSection:section].count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"系统应用" : @"用户应用";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NIInstalledApp *app = [self appsForSection:indexPath.section][indexPath.row];
    NIAppSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppSwitch" forIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    BOOL enabled = self.allAppsEnabled || [self.selectedBundleIDs containsObject:app.bundleID];
    [cell configureWithApp:app enabled:enabled changed:^(BOOL on) { [weakSelf setApp:app enabled:on]; }];
    cell.appIconView.image = [self iconForApp:app];
    return cell;
}
- (void)setApp:(NIInstalledApp *)app enabled:(BOOL)enabled {
    NSMutableSet<NSString *> *ids = [self.selectedBundleIDs mutableCopy] ?: [NSMutableSet set];
    if (self.allAppsEnabled && !enabled) {
        for (NIInstalledApp *installed in self.allApps) if (![installed.bundleID isEqualToString:app.bundleID]) [ids addObject:installed.bundleID];
        _allAppsEnabled = NO;
    } else if (!self.allAppsEnabled && enabled) {
        [ids addObject:app.bundleID];
    } else if (!self.allAppsEnabled && !enabled) {
        [ids removeObject:app.bundleID];
    }
    _selectedBundleIDs = ids;
    CFPreferencesSetAppValue(CFSTR("AllAppsEnabled"), (__bridge CFPropertyListRef)@(_allAppsEnabled), (__bridge CFStringRef)NIAppPreferenceDomain);
    CFPreferencesSetAppValue(CFSTR("EnabledBundleIDs"), (__bridge CFPropertyListRef)[ids allObjects], (__bridge CFStringRef)NIAppPreferenceDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)NIAppPreferenceDomain);
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) { _filteredSystemApps = _systemApps; _filteredUserApps = _userApps; }
    else {
        NSPredicate *match = [NSPredicate predicateWithBlock:^BOOL(NIInstalledApp *app, NSDictionary *bindings) {
            return [app.name localizedCaseInsensitiveContainsString:query] || [app.bundleID localizedCaseInsensitiveContainsString:query];
        }];
        _filteredSystemApps = [_systemApps filteredArrayUsingPredicate:match];
        _filteredUserApps = [_userApps filteredArrayUsingPredicate:match];
    }
    [self.tableView reloadData];
}
@end
