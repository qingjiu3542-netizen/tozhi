#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const NISettingsDomain = @"com.minis.notifyicon";
static UIImageView *NIIconView;
static NSUInteger NIShowGeneration;

static NSString *NIStringValue(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) return nil;
    id (*send)(id, SEL) = (void *)objc_msgSend;
    id value = send(object, selector);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSData *NIIconData(NSString *bundleID) {
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    SEL lookup = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (!proxyClass || ![proxyClass respondsToSelector:lookup]) return nil;
    id (*lookupSend)(id, SEL, id) = (void *)objc_msgSend;
    id proxy = lookupSend(proxyClass, lookup, bundleID);
    SEL iconSelector = NSSelectorFromString(@"iconDataForVariant:");
    if (!proxy || ![proxy respondsToSelector:iconSelector]) return nil;
    NSData *(*iconSend)(id, SEL, NSInteger) = (void *)objc_msgSend;
    for (NSInteger variant = 0; variant < 4; variant++) {
        NSData *result = iconSend(proxy, iconSelector, variant);
        if ([result isKindOfClass:[NSData class]] && [result length]) return result;
    }
    return nil;
}

static id NISetting(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)NISettingsDomain));
}

static BOOL NIIsEnabled(NSString *bundleID) {
    id masterSwitch = NISetting(@"ShowEnabled");
    if ([masterSwitch respondsToSelector:@selector(boolValue)] && ![masterSwitch boolValue]) return NO;
    id allApps = NISetting(@"AllAppsEnabled");
    if (![allApps respondsToSelector:@selector(boolValue)] || [allApps boolValue]) return YES;
    id setting = NISetting(@"EnabledBundleIDs");
    if (!setting) return NO;
    NSArray<NSString *> *items = nil;
    if ([setting isKindOfClass:[NSArray class]]) {
        items = setting;
    } else if ([setting isKindOfClass:[NSString class]]) {
        items = [setting componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;\n\t "]];
    } else {
        return NO;
    }
    for (id item in items) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *candidate = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([candidate isEqualToString:@"*"] || [candidate isEqualToString:bundleID]) return YES;
    }
    return NO;
}

static UIWindow *NIStatusBarWindow(void) {
    UIApplication *application = [UIApplication sharedApplication];
    for (UIWindow *window in application.windows) {
        NSString *name = NSStringFromClass([window class]);
        if ([name rangeOfString:@"StatusBar" options:NSCaseInsensitiveSearch].location != NSNotFound && !window.hidden) return window;
    }
    for (UIWindow *window in application.windows) {
        if (window.windowLevel >= UIWindowLevelStatusBar - 1 && !window.hidden) return window;
    }
    return nil;
}

static void NIRenderIcon(NSString *bundleID) {
    NSData *data = NIIconData(bundleID);
    UIImage *image = data ? [UIImage imageWithData:data scale:[UIScreen mainScreen].scale] : nil;
    if (!image) return;
    UIWindow *window = NIStatusBarWindow();
    if (!window) return;
    if (!NIIconView || NIIconView.superview != window) {
        [NIIconView removeFromSuperview];
        CGFloat side = 17.0;
        CGFloat x = MAX(window.safeAreaInsets.left + 40.0, 64.0);
        CGFloat y = MAX(2.0, (CGRectGetHeight(window.bounds) - side) * 0.5);
        NIIconView = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, side, side)];
        NIIconView.contentMode = UIViewContentModeScaleAspectFit;
        NIIconView.layer.cornerRadius = 3.5;
        NIIconView.clipsToBounds = YES;
        NIIconView.userInteractionEnabled = NO;
        NIIconView.accessibilityIdentifier = @"com.minis.notifyicon.overlay";
        [window addSubview:NIIconView];
    }
    NIIconView.image = image;
    NIIconView.hidden = NO;
    NIIconView.alpha = 1.0;
    id durationValue = NISetting(@"DisplayDuration");
    NSTimeInterval duration = [durationValue respondsToSelector:@selector(doubleValue)] ? [durationValue doubleValue] : 8.0;
    duration = MIN(30.0, MAX(2.0, duration));
    NSUInteger generation = ++NIShowGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation != NIShowGeneration) return;
        [UIView animateWithDuration:0.25 animations:^{ NIIconView.alpha = 0.0; } completion:^(BOOL finished) {
            if (generation == NIShowGeneration) NIIconView.hidden = YES;
        }];
    });
}

static void NIHandleBulletin(id bulletin) {
    NSString *bundleID = NIStringValue(bulletin, NSSelectorFromString(@"sectionID"));
    if (!bundleID.length || !NIIsEnabled(bundleID)) return;
    dispatch_async(dispatch_get_main_queue(), ^{ NIRenderIcon(bundleID); });
}

%group NCBulletinHook
%hook NCBulletinNotificationSource
- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(unsigned long long)feed playLightsAndSirens:(BOOL)play withReply:(id)reply {
    %orig;
    NIHandleBulletin(bulletin);
}
%end
%end

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"NCBulletinNotificationSource")) %init(NCBulletinHook);
    }
}
