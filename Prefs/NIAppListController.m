#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const NIAppListDomain = @"com.minis.notifyicon";
static NSString * const NIAppListIdentifierKey = @"NIApplicationIdentifier";

@interface UIImage (NIApplicationIcon)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface NIAppListController : PSListController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<NSDictionary *> *installedApps;
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, copy) NSString *cachedSearchText;
@end

@implementation NIAppListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择应用";
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    search.searchBar.placeholder = @"搜索应用名称或 Bundle ID";
    self.navigationItem.searchController = search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (id)object:(id)object perform:(SEL)selector {
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

- (NSArray<NSDictionary *> *)installedApps {
    if (_installedApps) return _installedApps;
    if (!NSClassFromString(@"LSApplicationWorkspace")) {
        dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY | RTLD_LOCAL);
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY | RTLD_LOCAL);
    }
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    id workspace = [workspaceClass respondsToSelector:defaultSelector] ? ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultSelector) : nil;
    SEL listSelector = NSSelectorFromString(@"allInstalledApplications");
    NSArray *proxies = [workspace respondsToSelector:listSelector] ? ((id (*)(id, SEL))objc_msgSend)(workspace, listSelector) : nil;
    NSMutableArray *apps = [NSMutableArray array];
    SEL idSelector = NSSelectorFromString(@"bundleIdentifier");
    SEL nameSelector = NSSelectorFromString(@"localizedName");
    SEL typeSelector = NSSelectorFromString(@"applicationType");
    SEL placeholderSelector = NSSelectorFromString(@"isPlaceholder");
    for (id proxy in proxies) {
        id bundleID = [self object:proxy perform:idSelector];
        if (![bundleID isKindOfClass:NSString.class] || ![(NSString *)bundleID length]) continue;
        if ([proxy respondsToSelector:placeholderSelector] && ((BOOL (*)(id, SEL))objc_msgSend)(proxy, placeholderSelector)) continue;
        id localizedName = [self object:proxy perform:nameSelector];
        NSString *name = [localizedName isKindOfClass:NSString.class] && [(NSString *)localizedName length] ? localizedName : bundleID;
        id appType = [self object:proxy perform:typeSelector];
        BOOL systemApp = [appType isKindOfClass:NSString.class] && [(NSString *)appType isEqualToString:@"System"];
        [apps addObject:@{@"id": bundleID, @"name": name, @"system": @(systemApp)}];
    }
    [apps sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSComparisonResult result = [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
        return result == NSOrderedSame ? [a[@"id"] compare:b[@"id"]] : result;
    }];
    _installedApps = [apps copy];
    return _installedApps;
}

- (NSArray *)specifiers {
    NSArray *apps = self.installedApps;
    NSString *query = [self.searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    if (_specifiers && [self.cachedSearchText isEqualToString:query]) return _specifiers;

    NSMutableArray *rows = [NSMutableArray array];
    BOOL didSystem = NO, didUser = NO;
    for (NSDictionary *app in apps) {
        NSString *name = app[@"name"];
        NSString *bundleID = app[@"id"];
        if (query.length && ![name localizedCaseInsensitiveContainsString:query] && ![bundleID localizedCaseInsensitiveContainsString:query]) continue;
        BOOL isSystem = [app[@"system"] boolValue];
        BOOL *hasSection = isSystem ? &didSystem : &didUser;
        if (!*hasSection) {
            [rows addObject:[PSSpecifier groupSpecifierWithName:isSystem ? @"系统应用" : @"用户应用"]];
            *hasSection = YES;
        }
        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(setApplicationEnabled:specifier:) get:@selector(readApplicationEnabled:) detail:nil cell:PSSwitchCell edit:nil];
        row.identifier = bundleID;
        [row setProperty:bundleID forKey:NIAppListIdentifierKey];
        [row setProperty:@"PSSubtitleSwitchTableCell" forKey:@"cellClass"];
        [row setProperty:bundleID forKey:@"cellSubtitleText"];
        SEL iconSelector = @selector(_applicationIconImageForBundleIdentifier:format:scale:);
        if ([UIImage respondsToSelector:iconSelector]) {
            UIImage *icon = ((UIImage *(*)(id, SEL, id, int, CGFloat))objc_msgSend)(UIImage.class, iconSelector, bundleID, 0, UIScreen.mainScreen.scale);
            if ([icon isKindOfClass:UIImage.class]) [row setProperty:icon forKey:@"iconImage"];
        }
        [rows addObject:row];
    }
    if (apps.count == 0) {
        [rows addObject:[PSSpecifier groupSpecifierWithName:@"无法读取已安装应用"]];
    } else if (rows.count == 0) {
        [rows addObject:[PSSpecifier groupSpecifierWithName:@"没有匹配的应用"]];
    }
    self.cachedSearchText = query;
    _specifiers = rows;
    return _specifiers;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchText = searchController.searchBar.text ?: @"";
    self.cachedSearchText = nil;
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSMutableSet<NSString *> *)savedIDs {
    NSMutableSet *ids = [NSMutableSet set];
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("EnabledBundleIDs"), (__bridge CFStringRef)NIAppListDomain));
    if ([value isKindOfClass:NSArray.class]) {
        for (id item in value) if ([item isKindOfClass:NSString.class]) [ids addObject:item];
    } else if ([value isKindOfClass:NSString.class]) {
        NSArray *parts = [(NSString *)value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;\n\t "]];
        for (NSString *part in parts) {
            NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmed.length) [ids addObject:trimmed];
        }
    }
    return ids;
}

- (BOOL)allAppsEnabled {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("AllAppsEnabled"), (__bridge CFStringRef)NIAppListDomain));
    return !value || [value boolValue];
}

- (id)readApplicationEnabled:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:NIAppListIdentifierKey];
    if (![bundleID isKindOfClass:NSString.class]) return @NO;
    NSMutableSet *ids = [self savedIDs];
    if ([self allAppsEnabled]) return @YES;
    return @([ids containsObject:bundleID]);
}

- (void)setApplicationEnabled:(id)value specifier:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:NIAppListIdentifierKey];
    if (![bundleID isKindOfClass:NSString.class]) return;
    BOOL enabled = [value respondsToSelector:@selector(boolValue)] && [value boolValue];
    BOOL all = [self allAppsEnabled];
    NSMutableSet<NSString *> *ids = [self savedIDs];
    if (all) {
        if (enabled) return;
        for (NSDictionary *app in self.installedApps) {
            NSString *installedID = app[@"id"];
            if ([installedID isKindOfClass:NSString.class]) [ids addObject:installedID];
        }
        [ids removeObject:bundleID];
        CFPreferencesSetAppValue(CFSTR("AllAppsEnabled"), kCFBooleanFalse, (__bridge CFStringRef)NIAppListDomain);
    } else if (enabled) {
        [ids addObject:bundleID];
    } else {
        [ids removeObject:bundleID];
    }
    CFPreferencesSetAppValue(CFSTR("EnabledBundleIDs"), (__bridge CFArrayRef)ids.allObjects, (__bridge CFStringRef)NIAppListDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)NIAppListDomain);
}
@end
