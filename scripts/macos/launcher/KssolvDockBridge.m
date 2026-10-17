#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <unistd.h>
#include <dlfcn.h>
#include <libproc.h>
#include <objc/runtime.h>
#include <time.h>

static NSString *bridgeNonce;
static NSString *bridgeSignal;
static BOOL bridgeOwnsCEF = NO;
static BOOL dockTransferred = NO;
static NSString *brandIcon;
static pid_t bridgeHost;
static BOOL startupRevealed = NO;
static __weak NSWindow *startupWindow;
static NSImage *brandImage;
static void applyBrandIdentity(void);
static void publishReady(void);
static void (*originalOrderWindow)(id, SEL, NSWindowOrderingMode, NSInteger);
static dispatch_source_t hostMonitor;
static __weak NSWindow *primaryWindow;
static BOOL bridgeOwnsRuntime;
static BOOL bridgePrewarm;
static BOOL (*originalActivationPolicy)(id, SEL, NSApplicationActivationPolicy);
static void (*originalOrderFrontRegardless)(id, SEL);
static void (*originalAlphaValue)(id, SEL, CGFloat);
static void (*originalActivateIgnoringOtherApps)(id, SEL, BOOL);
static void (*originalMakeKeyWindow)(id, SEL);
static char sourceWindowExecutable[PATH_MAX];
static char sourceWindowExecutableRaw[PATH_MAX];
static char privateWindowExecutable[PATH_MAX];
static char windowLaunchLogPath[PATH_MAX];

// Prepared before fork. Keep the child's exact-path adapter C-only and preserve
// argv, including argv[0], and the inherited environment without modification.
static BOOL sameLaunchPath(const char *left, const char *right) {
    if (!left || !right || !*left || !*right) return NO;
    while (*left && *right) {
        if (*left != *right) return NO;
        if (*left == '/') {
            while (*left == '/') ++left;
            while (*right == '/') ++right;
        } else { ++left; ++right; }
    }
    return *left == *right;
}
static const char *privateWindowPath(const char *path, const char *event) {
    if (!bridgeOwnsRuntime || (!sameLaunchPath(path, sourceWindowExecutable) &&
        !sameLaunchPath(path, sourceWindowExecutableRaw))) return path;
    // Open at the boundary instead of relying on an inherited descriptor. Only
    // the exact matched executable path is recorded, never argv or environment.
    int fd = open(windowLaunchLogPath, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0600);
    if (fd >= 0) {
        (void)write(fd, event, strlen(event));
        (void)write(fd, path, strlen(path));
        (void)write(fd, "\n", 1);
        close(fd);
    }
    return privateWindowExecutable;
}
static int windowExecvp(const char *path, char *const argv[]) {
    return execvp(privateWindowPath(path, "private-window-execvp-matched\n"), argv);
}
static int windowExecv(const char *path, char *const argv[]) {
    return execv(privateWindowPath(path, "private-window-execv-matched\n"), argv);
}
static int windowExecve(const char *path, char *const argv[], char *const envp[]) {
    return execve(privateWindowPath(path, "private-window-execve-matched\n"), argv, envp);
}

static BOOL samePath(const char *left, NSString *right) {
    char a[PATH_MAX], b[PATH_MAX];
    return left && right && realpath(left, a) && realpath(right.fileSystemRepresentation, b) && strcmp(a, b) == 0;
}

// The host supplies these only to its own Runtime launch. Other applications,
// including independently launched MATLAB sessions, never load this library.
static BOOL ownsCEF(void) {
    return bridgeOwnsCEF;
}

static void recordBridge(const char *event) {
    const char *signal = bridgeSignal.fileSystemRepresentation;
    if (!signal) return;
    char path[PATH_MAX];
    if (snprintf(path, sizeof(path), "%s.dock.log", signal) >= sizeof(path)) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0600);
    if (fd < 0) return;
    char line[384];
    struct timespec now;
    clock_gettime(CLOCK_REALTIME, &now);
    int size = snprintf(line, sizeof(line), "time=%lld.%09ld pid=%d pgid=%d %s\n", (long long)now.tv_sec, now.tv_nsec, getpid(), getpgrp(), event);
    if (size > 0 && size < sizeof(line)) (void)write(fd, line, size);
    close(fd);
}

static void reportFailure(NSString *message) {
    recordBridge("transfer-failed");
    NSDictionary *status = @{@"protocol": @1, @"nonce": bridgeNonce, @"status": @"failed", @"error": message};
    NSData *bytes = [NSJSONSerialization dataWithJSONObject:status options:0 error:nil];
    [bytes writeToFile:bridgeSignal options:NSDataWritingAtomic error:nil];
}

static BOOL isStartupCandidate(NSWindow *window) {
    NSWindowStyleMask standard = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
    return ![window isKindOfClass:NSPanel.class] && !window.sheetParent &&
        (window.styleMask & standard) == standard && window.frame.size.width >= 300 && window.frame.size.height >= 200;
}

static void identifyStartupWindow(void) {
    if (startupWindow) return;
    NSWindow *candidate;
    NSUInteger count = 0;
    for (NSWindow *window in NSApp.windows) {
        if (!isStartupCandidate(window)) continue;
        if ([window.title hasPrefix:@"KSSOLV Toolbox"]) { startupWindow = window; break; }
        candidate = window;
        ++count;
    }
    // CEF creates its standard main window before applying the MATLAB title.
    // Bind that single window by identity; never gate another dialog or panel.
    if (!startupWindow && count == 1) startupWindow = candidate;
    if (startupWindow) primaryWindow = startupWindow;
}

static void recoverReveal(void) {
    NSString *path = [bridgeSignal stringByAppendingString:@".reveal"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        NSData *bytes = [NSJSONSerialization dataWithJSONObject:@{@"nonce": bridgeNonce} options:0 error:nil];
        [bytes writeToFile:path options:NSDataWritingAtomic error:nil];
    }
}

// Only the identified startup window is gated. Panels, alerts, sheets and
// unrelated CEF windows retain normal ordering, even before handoff.
static void startupOrderWindow(NSWindow *window, SEL selector, NSWindowOrderingMode mode, NSInteger relative) {
    if (ownsCEF() && bridgePrewarm && mode != NSWindowOut) {
        recordBridge("prewarm-window-order-suppressed");
        return;
    }
    if (ownsCEF() && !startupRevealed) {
        if ([NSFileManager.defaultManager fileExistsAtPath:[bridgeSignal stringByAppendingString:@".reveal"]]) {
            startupRevealed = YES;
            Method method = class_getInstanceMethod(NSWindow.class, selector);
            if (method_getImplementation(method) == (IMP)startupOrderWindow) {
                method_setImplementation(method, (IMP)originalOrderWindow);
            }
            recordBridge("startup-window-guard-released");
        } else if (mode != NSWindowOut) {
            identifyStartupWindow();
            if (window == startupWindow) {
                primaryWindow = window;
                recordBridge("startup-window-order-suppressed");
                return;
            }
        }
    }
    originalOrderWindow(window, selector, mode, relative);
}

static BOOL prewarmActivationPolicy(NSApplication *application, SEL selector, NSApplicationActivationPolicy policy) {
    if (ownsCEF() && bridgePrewarm && policy == NSApplicationActivationPolicyRegular) {
        recordBridge("prewarm-regular-policy-suppressed");
        policy = NSApplicationActivationPolicyAccessory;
    }
    return originalActivationPolicy(application, selector, policy);
}

static void prewarmOrderFrontRegardless(NSWindow *window, SEL selector) {
    // AppKit can order a window without calling orderWindow:relativeTo:.
    // Intercept this public entry before it reaches WindowServer; ordering it
    // out afterwards still permits the installer prewarm to flash onscreen.
    if (ownsCEF() && bridgePrewarm) {
        recordBridge("prewarm-order-front-regardless-suppressed");
        return;
    }
    originalOrderFrontRegardless(window, selector);
}

static void prewarmAlphaValue(NSWindow *window, SEL selector, CGFloat alpha) {
    originalAlphaValue(window, selector, ownsCEF() && bridgePrewarm ? 0 : alpha);
}

static void prewarmActivateIgnoringOtherApps(NSApplication *application, SEL selector, BOOL flag) {
    if (ownsCEF() && bridgePrewarm) { recordBridge("prewarm-activation-suppressed"); return; }
    originalActivateIgnoringOtherApps(application, selector, flag);
}

static void prewarmMakeKeyWindow(NSWindow *window, SEL selector) {
    if (ownsCEF() && bridgePrewarm) { recordBridge("prewarm-key-window-suppressed"); return; }
    originalMakeKeyWindow(window, selector);
}

// CEF can order its own native window through an entry that does not dispatch
// orderWindow:relativeTo:. Keep a prewarm-only zero-opacity invariant from
// construction, before any ordering, including initial-size and teardown UI.
@interface NSWindow (KssolvPrewarm)
- (instancetype)initKssolvPrewarmWithContentRect:(NSRect)rect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backing defer:(BOOL)defer;
- (instancetype)initKssolvPrewarmWithContentRect:(NSRect)rect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backing defer:(BOOL)defer screen:(NSScreen *)screen;
@end
@implementation NSWindow (KssolvPrewarm)
- (instancetype)initKssolvPrewarmWithContentRect:(NSRect)rect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backing defer:(BOOL)defer {
    self = [self initKssolvPrewarmWithContentRect:rect styleMask:style backing:backing defer:defer];
    if (self) [self setAlphaValue:0];
    return self;
}
- (instancetype)initKssolvPrewarmWithContentRect:(NSRect)rect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backing defer:(BOOL)defer screen:(NSScreen *)screen {
    self = [self initKssolvPrewarmWithContentRect:rect styleMask:style backing:backing defer:defer screen:screen];
    if (self) [self setAlphaValue:0];
    return self;
}
@end

static OSStatus kssolvTransformProcessType(const ProcessSerialNumber *psn, ProcessApplicationTransformState state) {
    if (bridgeSignal) {
        char event[128];
        snprintf(event, sizeof(event), "transform-request state=%u process=%s", (unsigned)state, getprogname());
        recordBridge(event);
    }
    if (bridgePrewarm && (ownsCEF() || bridgeOwnsRuntime) && psn && state == kProcessTransformToForegroundApplication) {
        ProcessSerialNumber current;
        BOOL isCurrent = psn->highLongOfPSN == 0 && psn->lowLongOfPSN == kCurrentProcess;
        if (!isCurrent && GetCurrentProcess(&current) == noErr) isCurrent = psn->highLongOfPSN == current.highLongOfPSN && psn->lowLongOfPSN == current.lowLongOfPSN;
        if (isCurrent) {
            recordBridge("prewarm-foreground-suppressed");
            return noErr;
        }
    }
    if (ownsCEF() && dockTransferred && psn && state == kProcessTransformToUIElementApplication) {
        ProcessSerialNumber current;
        BOOL isCurrent = psn->highLongOfPSN == 0 && psn->lowLongOfPSN == kCurrentProcess;
        if (!isCurrent && GetCurrentProcess(&current) == noErr) isCurrent = psn->highLongOfPSN == current.highLongOfPSN && psn->lowLongOfPSN == current.lowLongOfPSN;
        if (isCurrent) {
            recordBridge("preserved-dock-owner");
            dispatch_async(dispatch_get_main_queue(), ^{ [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]; applyBrandIdentity(); });
            return noErr;
        }
    }

    // Qoder's REA report identifies this public API as the CEF Dock promotion.
    // Interpose before that promotion, rather than hiding a tile afterwards.
    if (ownsCEF() && psn && state == kProcessTransformToForegroundApplication) {
        ProcessSerialNumber current;
        BOOL isCurrent = psn->highLongOfPSN == 0 && psn->lowLongOfPSN == kCurrentProcess;
        if (!isCurrent && GetCurrentProcess(&current) == noErr) {
            isCurrent = psn->highLongOfPSN == current.highLongOfPSN && psn->lowLongOfPSN == current.lowLongOfPSN;
        }
        if (isCurrent) {
            if (!dockTransferred) {
                if (!NSApp || !NSThread.isMainThread) {
                    reportFailure(@"The Dock ownership request requires an initialized main-thread application.");
                    return paramErr;
                }
                applyBrandIdentity();
                NSDictionary *request = @{@"nonce": bridgeNonce, @"pid": @(getpid())};
                NSData *bytes = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
                NSString *requestPath = [bridgeSignal stringByAppendingString:@".dock-transfer"];
                if (![bytes writeToFile:requestPath options:NSDataWritingAtomic error:nil]) {
                    reportFailure(@"Unable to request Dock ownership transfer.");
                    return paramErr;
                }
                recordBridge("transfer-requested");
                BOOL retired = NO;
                BOOL hostExited = NO;
                for (int i = 0; i < 500; ++i) {
                    // This wait is bounded; host-death recovery must not depend
                    // on its main-queue dispatch source while this call waits.
                    if (kill(bridgeHost, 0) != 0 && errno == ESRCH) { hostExited = YES; break; }
                    NSData *ack = [NSData dataWithContentsOfFile:[bridgeSignal stringByAppendingString:@".dock-transfer-ack"]];
                    NSDictionary *reply = ack ? [NSJSONSerialization JSONObjectWithData:ack options:0 error:nil] : nil;
                    if ([reply[@"nonce"] isEqual:bridgeNonce] && [reply[@"pid"] intValue] == getpid() && [reply[@"retired"] boolValue]) { retired = YES; break; }
                    usleep(10000);
                }
                if (!retired && !hostExited) {
                    reportFailure(@"The startup host did not acknowledge Dock ownership transfer within five seconds.");
                    return paramErr;
                }
                if (hostExited) recoverReveal();
                OSStatus result = TransformProcessType(psn, state);
                if (result == noErr) {
                    dockTransferred = YES;
                    applyBrandIdentity();
                    recordBridge(hostExited ? "transfer-recovered-after-host-exit" : "transfer-complete");
                    dispatch_async(dispatch_get_main_queue(), ^{ publishReady(); });
                }
                if (result != noErr) reportFailure(@"Unable to promote the Toolbox window process.");
                return result;
            }
            // The native API may reject a redundant promotion even when the
            // requested foreground state is already established.
            if (NSRunningApplication.currentApplication.activationPolicy == NSApplicationActivationPolicyRegular) {
                if (NSThread.isMainThread) applyBrandIdentity();
                return noErr;
            }
            OSStatus result = TransformProcessType(psn, state);
            if (result == noErr && NSThread.isMainThread) applyBrandIdentity();
            return result;
        }
    }
    // Static __interpose excludes its defining image from replacement. Calling
    // the imported function here reaches the original; dlsym can return the
    // interposed address and cause recursion on current dyld.
    OSStatus result = TransformProcessType(psn, state);
    if (bridgeSignal) {
        char event[128];
        snprintf(event, sizeof(event), "transform-forwarded state=%u result=%d process=%s", (unsigned)state, (int)result, getprogname());
        recordBridge(event);
    }
    return result;
}

__attribute__((used)) static struct {
    const void *replacement;
    const void *original;
} dockInterpose[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)&kssolvTransformProcessType, (const void *)&TransformProcessType},
    {(const void *)&windowExecvp, (const void *)&execvp},
    {(const void *)&windowExecv, (const void *)&execv},
    {(const void *)&windowExecve, (const void *)&execve}
};

static void recordWindows(const char *event) {
    for (NSWindow *window in NSApp.windows) {
        char line[256];
        snprintf(line, sizeof(line), "%s window=%ld visible=%d mini=%d key=%d main=%d keyable=%d mainable=%d level=%ld style=%lu behavior=%lu frame=%.0f,%.0f,%.0f,%.0f", event, (long)window.windowNumber, window.visible, window.miniaturized, window.keyWindow, window.mainWindow, window.canBecomeKeyWindow, window.canBecomeMainWindow, (long)window.level, (unsigned long)window.styleMask, (unsigned long)window.collectionBehavior, window.frame.origin.x, window.frame.origin.y, window.frame.size.width, window.frame.size.height);
        recordBridge(line);
    }
}
static NSWindow *mainCandidate(void) {
    NSWindow *best = primaryWindow;
    if (best && (best.visible || best.miniaturized)) return best;
    CGFloat area = 0;
    for (NSWindow *window in NSApp.windows) {
        CGFloat size = window.frame.size.width * window.frame.size.height;
        if (window.canBecomeKeyWindow && window.canBecomeMainWindow && (window.visible || window.miniaturized) && size > area) { best = window; area = size; }
    }
    primaryWindow = best;
    return best;
}
static void showWindows(void) {
    recordWindows("before-show");
    NSWindow *front = NSApp.modalWindow ?: NSApp.keyWindow;
    if (!front || !front.canBecomeMainWindow || (!front.visible && !front.miniaturized)) front = mainCandidate();
    if (front.miniaturized) [front deminiaturize:nil];
    [front makeKeyAndOrderFront:nil];
    if (@available(macOS 14.0, *)) [NSApp activate];
    else [NSApp activateIgnoringOtherApps:YES];
    recordWindows("after-show");
}
static void applyBrandIdentity(void) {
    if (!NSApp || !NSThread.isMainThread) return;
    if (!brandImage) {
        brandImage = [[NSImage alloc] initWithContentsOfFile:brandIcon];
        if (brandImage) {
            // The default AppKit image is process-local. Keep explicit icon
            // resets from falling back to the shared Runtime's bundle image.
            NSImage *previous = [NSImage imageNamed:NSImageNameApplicationIcon];
            if (previous != brandImage) [previous setName:nil];
            recordBridge([brandImage setName:NSImageNameApplicationIcon] ? "branded-default-image-registered" : "branded-default-image-registration-failed");
        }
    }
    if (brandImage) {
        NSApp.applicationIconImage = brandImage;
        [NSApp.dockTile display];
    }
    NSMenuItem *applicationItem = NSApp.mainMenu.itemArray.firstObject;
    applicationItem.title = @"KSSOLV Toolbox";
    applicationItem.submenu.title = @"KSSOLV Toolbox";
    for (NSMenuItem *item in applicationItem.submenu.itemArray) {
        item.title = [item.title stringByReplacingOccurrencesOfString:@"MATLABWindow" withString:@"KSSOLV Toolbox"];
    }
}

static void publishReady(void) {
    if (!NSApp || !dockTransferred) return;
    applyBrandIdentity();
    NSApplicationActivationPolicy policy = NSRunningApplication.currentApplication.activationPolicy;
    if (policy != NSApplicationActivationPolicyRegular) { recordBridge("regular-not-ready"); return; }
    NSDictionary *ready = @{@"protocol": @1, @"nonce": bridgeNonce, @"pid": @(getpid()), @"pgid": @(getpgrp()), @"policy": @(policy)};
    NSData *bytes = [NSJSONSerialization dataWithJSONObject:ready options:0 error:nil];
    if (![bytes writeToFile:[bridgeSignal stringByAppendingString:@".bridge"] options:NSDataWritingAtomic error:nil]) reportFailure(@"Unable to publish Dock bridge readiness.");
    else recordBridge("ready-regular-branded");
}

__attribute__((constructor)) static void installDockBridge(void) {
    // CEF receives DYLD_INSERT_LIBRARIES, but the Runtime may filter other
    // environment keys. Recover the launch token from a private PGID registry.
    @autoreleasepool {
        NSString *folder = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/KSSOLV Toolbox/dock"];
        NSString *path = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.json", getpgrp()]];
        NSData *bytes = [NSData dataWithContentsOfFile:path];
        NSDictionary *config = bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil] : nil;
        if (![config isKindOfClass:NSDictionary.class] || [config[@"pgid"] intValue] != getpgrp()) return;
        pid_t host = [config[@"host"] intValue];
        if (host <= 0 || kill(host, 0) != 0) return;
        Dl_info image;
        if (!dladdr((const void *)&installDockBridge, &image) || !image.dli_fname) return;
        if (!samePath(image.dli_fname, config[@"library"])) return;
        char hostPath[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(host, hostPath, sizeof(hostPath)) <= 0 || !samePath(hostPath, config[@"executable"])) return;
        if (![config[@"nonce"] isKindOfClass:NSString.class] || [config[@"nonce"] length] != 36 ||
            ![config[@"signal"] isKindOfClass:NSString.class]) return;
        bridgeHost = host;
        brandIcon = config[@"icon"];
        bridgeNonce = config[@"nonce"];
        bridgeSignal = config[@"signal"];
        bridgePrewarm = [config[@"mode"] isEqualToString:@"prewarm"];
        char runtimePath[PROC_PIDPATHINFO_MAXSIZE];
        if (strcmp(getprogname(), "KSSOLV_Toolbox") == 0 &&
            proc_pidpath(getpid(), runtimePath, sizeof(runtimePath)) > 0 &&
            samePath(runtimePath, config[@"runtimeExecutable"]) &&
            [config[@"sourceWindowExecutable"] isKindOfClass:NSString.class] &&
            realpath([config[@"sourceWindowExecutable"] fileSystemRepresentation], sourceWindowExecutable) &&
            [config[@"windowExecutable"] isKindOfClass:NSString.class] &&
            realpath([config[@"windowExecutable"] fileSystemRepresentation], privateWindowExecutable)) {
            strlcpy(sourceWindowExecutableRaw, [config[@"sourceWindowExecutable"] fileSystemRepresentation], sizeof(sourceWindowExecutableRaw));
            NSString *launchLogPath = [bridgeSignal stringByAppendingString:@".dock.log"];
            strlcpy(windowLaunchLogPath, launchLogPath.fileSystemRepresentation, sizeof(windowLaunchLogPath));
            bridgeOwnsRuntime = YES;
            recordBridge("private-window-launch-adapter-ready");
        }
        char event[192];
        snprintf(event, sizeof(event), "loaded-process=%s env-nonce=%d", getprogname(), getenv("KSSOLV_STARTUP_NONCE") != NULL);
        recordBridge(event);
        bridgeOwnsCEF = strcmp(getprogname(), "MATLABWindow") == 0;
        if (bridgeOwnsCEF) {
            Method order = class_getInstanceMethod(NSWindow.class, @selector(orderWindow:relativeTo:));
            originalOrderWindow = (void *)method_setImplementation(order, (IMP)startupOrderWindow);
            if (bridgePrewarm) {
                Method activate = class_getInstanceMethod(NSApplication.class, @selector(activateIgnoringOtherApps:));
                originalActivateIgnoringOtherApps = (void *)method_setImplementation(activate, (IMP)prewarmActivateIgnoringOtherApps);
                Method key = class_getInstanceMethod(NSWindow.class, @selector(makeKeyWindow));
                originalMakeKeyWindow = (void *)method_setImplementation(key, (IMP)prewarmMakeKeyWindow);
                Method alpha = class_getInstanceMethod(NSWindow.class, @selector(setAlphaValue:));
                originalAlphaValue = (void *)method_setImplementation(alpha, (IMP)prewarmAlphaValue);
                method_exchangeImplementations(
                    class_getInstanceMethod(NSWindow.class, @selector(initWithContentRect:styleMask:backing:defer:)),
                    class_getInstanceMethod(NSWindow.class, @selector(initKssolvPrewarmWithContentRect:styleMask:backing:defer:)));
                method_exchangeImplementations(
                    class_getInstanceMethod(NSWindow.class, @selector(initWithContentRect:styleMask:backing:defer:screen:)),
                    class_getInstanceMethod(NSWindow.class, @selector(initKssolvPrewarmWithContentRect:styleMask:backing:defer:screen:)));
                Method regardless = class_getInstanceMethod(NSWindow.class, @selector(orderFrontRegardless));
                originalOrderFrontRegardless = (void *)method_setImplementation(regardless, (IMP)prewarmOrderFrontRegardless);
                Method policy = class_getInstanceMethod(NSApplication.class, @selector(setActivationPolicy:));
                originalActivationPolicy = (void *)method_setImplementation(policy, (IMP)prewarmActivationPolicy);
            }
            hostMonitor = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, host, DISPATCH_PROC_EXIT, dispatch_get_main_queue());
            dispatch_source_set_event_handler(hostMonitor, ^{
                if (bridgePrewarm) { recordBridge("prewarm-host-exited"); _exit(1); }
                // If the one Dock owner dies unexpectedly, leave usable windows
                // with their own tile instead of an unreachable accessory app.
                recoverReveal();
                bridgeOwnsCEF = NO;
                ProcessSerialNumber current = {0, kCurrentProcess};
                TransformProcessType(&current, kProcessTransformToForegroundApplication);
                NSImage *icon = [[NSImage alloc] initWithContentsOfFile:config[@"icon"]];
                if (icon) NSApp.applicationIconImage = icon;
                [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
                dockTransferred = YES;
                applyBrandIdentity();
            });
            dispatch_resume(hostMonitor);
        }
    }
    if (!ownsCEF()) return;
    recordBridge("loaded");
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            // Never create NSApplication before CEF constructs its own subclass.
            // LSUIElement already supplies the initial accessory policy.
            identifyStartupWindow();
            recordWindows("bridge-main-ready");
            if (bridgePrewarm) {
                for (NSWindow *window in NSApp.windows) [window setAlphaValue:0];
                [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
                recordBridge("prewarm-accessory-ready");
                return;
            }
            [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { applyBrandIdentity(); }];
            [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { applyBrandIdentity(); }];
            NSString *nonce = bridgeNonce;
            NSString *name = [@"com.pwdft.kssolv.dock." stringByAppendingString:nonce];
            // Keep the observer for this process's lifetime. Match both the
            // unguessable launch token and the target PID on every command.
            static id observer;
            observer = [NSDistributedNotificationCenter.defaultCenter
                addObserverForName:name object:nonce queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *notification) {
                    if ([notification.userInfo[@"pid"] intValue] != getpid()) return;
                    NSString *action = notification.userInfo[@"action"];
                    if ([action isEqualToString:@"show"]) showWindows();
                    else if ([action isEqualToString:@"quit"]) {
                        recordBridge("quit-requested");
                        if (primaryWindow) [primaryWindow performClose:nil];
                        else [NSApp terminate:nil];
                    }
                }];
            publishReady();
        }
    });
}
