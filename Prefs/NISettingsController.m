#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const NISettingsDomain = @"com.minis.notifyicon";

@interface NISettingsController : PSListController
@end

@implementation NISettingsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSArray<NSString *> *)installedBundleIdentifiers {
    if (!NSClassFromString(@"LSApplicationWorkspace")) {
        dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY | RTLD_LOCAL);
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY | RTLD_LOCAL);
    }
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    id workspace = [workspaceClass respondsToSelector:defaultSelector] ? ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultSelector) : nil;
    SEL applicationsSelector = NSSelectorFromString(@"allInstalledApplications");
    NSArray *applications = [workspace respondsToSelector:applicationsSelector] ? ((id (*)(id, SEL))objc_msgSend)(workspace, applicationsSelector) : nil;
    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    SEL identifierSelector = NSSelectorFromString(@"bundleIdentifier");
    for (id application in applications) {
        if (![application respondsToSelector:identifierSelector]) continue;
        id identifier = ((id (*)(id, SEL))objc_msgSend)(application, identifierSelector);
        if ([identifier isKindOfClass:NSString.class] && [identifier length]) [identifiers addObject:identifier];
    }
    return identifiers.array;
}

- (NSMutableSet<NSString *> *)stringSetForKey:(NSString *)key {
    NSMutableSet<NSString *> *result = [NSMutableSet set];
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)NISettingsDomain));
    if ([value isKindOfClass:NSArray.class]) {
        for (id item in value) if ([item isKindOfClass:NSString.class]) [result addObject:item];
    } else if ([value isKindOfClass:NSString.class]) {
        NSArray *parts = [(NSString *)value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;\n\t "]];
        for (NSString *part in parts) {
            NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmed.length) [result addObject:trimmed];
        }
    }
    return result;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"AllAppsEnabled"] && [value respondsToSelector:@selector(boolValue)]) {
        CFPreferencesAppSynchronize((__bridge CFStringRef)NISettingsDomain);
        id oldValue = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("AllAppsEnabled"), (__bridge CFStringRef)NISettingsDomain));
        BOOL wasAllEnabled = !oldValue || [oldValue boolValue];
        BOOL willAllEnable = [value boolValue];
        if (wasAllEnabled != willAllEnable) {
            NSArray<NSString *> *allIDs = [self installedBundleIdentifiers];
            if (allIDs.count) {
                NSMutableSet<NSString *> *all = [NSMutableSet setWithArray:allIDs];
                if (willAllEnable) {
                    // Convert the explicit enabled list to the equivalent disabled list.
                    NSMutableSet<NSString *> *enabled = [self stringSetForKey:@"EnabledBundleIDs"];
                    [all minusSet:enabled];
                    CFPreferencesSetAppValue(CFSTR("DisabledBundleIDs"), (__bridge CFArrayRef)all.allObjects, (__bridge CFStringRef)NISettingsDomain);
                } else {
                    // Convert the all-enabled exclusions to an explicit enabled list.
                    NSMutableSet<NSString *> *disabled = [self stringSetForKey:@"DisabledBundleIDs"];
                    [all minusSet:disabled];
                    CFPreferencesSetAppValue(CFSTR("EnabledBundleIDs"), (__bridge CFArrayRef)all.allObjects, (__bridge CFStringRef)NISettingsDomain);
                }
                CFPreferencesAppSynchronize((__bridge CFStringRef)NISettingsDomain);
            }
        }
    }
    [super setPreferenceValue:value specifier:specifier];
    CFPreferencesAppSynchronize((__bridge CFStringRef)NISettingsDomain);
}

@end
