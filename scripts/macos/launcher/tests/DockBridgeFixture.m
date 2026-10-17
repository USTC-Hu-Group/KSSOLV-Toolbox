#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

// Native-only fixture: tests the same public process-policy calls without a
// MATLAB installation, Java, a JVM, or third-party frameworks.
@interface DockFixture : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property NSWindow *window;
@property NSTimer *timer;
@property int phase;
@property BOOL permitClose;
@end

@implementation DockFixture
- (void)publish:(NSString *)status {
    NSDictionary *value = @{@"protocol": @1, @"nonce": @(getenv("KSSOLV_STARTUP_NONCE")), @"status": status};
    NSData *bytes = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    [bytes writeToFile:@(getenv("KSSOLV_STARTUP_SIGNAL")) options:NSDataWritingAtomic error:nil];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.pwdft.kssolv.window"]) {
        fprintf(stderr, "Fixture bundle mismatch: %s at %s\n", NSBundle.mainBundle.bundleIdentifier.UTF8String, NSBundle.mainBundle.bundlePath.UTF8String); exit(12);
    }
    if (![NSFileManager.defaultManager fileExistsAtPath:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"KssolvBrand.icns"]]) exit(13);
    NSString *layout = NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
    if (![NSFileManager.defaultManager fileExistsAtPath:[layout stringByAppendingPathComponent:@"Frameworks"]] ||
        ![NSFileManager.defaultManager fileExistsAtPath:[layout stringByAppendingPathComponent:@"matlabwindowhelper.app"]]) exit(14);
    [NSBundle.mainBundle.bundlePath writeToFile:@(getenv("KSSOLV_STARTUP_TEST_CACHE")) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 400)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"KSSOLV Toolbox fixture";
    self.window.releasedWhenClosed = NO;
    self.window.delegate = self;
    self.permitClose = YES;
    [self.window center];
    if (getenv("KSSOLV_STARTUP_TEST_PREWARM")) {
        if (self.window.alphaValue != 0) exit(26);
        self.window.alphaValue = 1;
        if (self.window.alphaValue != 0) exit(27);
        NSPanel *later = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO screen:NSScreen.mainScreen];
        later.alphaValue = 1;
        if (later.alphaValue != 0) exit(28);
        [later close];
        ProcessSerialNumber current = {0, kCurrentProcess};
        if (TransformProcessType(&current, kProcessTransformToForegroundApplication) != noErr) exit(20);
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [self.window makeKeyAndOrderFront:nil];
        if (self.window.visible || NSRunningApplication.currentApplication.activationPolicy == NSApplicationActivationPolicyRegular) exit(21);
        // AppKit's unconditional ordering entry does not have to call the
        // overridable orderWindow:relativeTo: method.
        [self.window orderFrontRegardless];
        if (self.window.visible) { fprintf(stderr, "Prewarm orderFrontRegardless exposed a window\n"); exit(24); }
        [self.window orderFront:nil];
        [self.window setIsVisible:YES];
        [self.window orderWindow:NSWindowAbove relativeTo:0];
        if (self.window.visible) exit(25);
        [NSApp activateIgnoringOtherApps:YES];
        [self.window makeKeyWindow];
        if (self.window.keyWindow || NSApp.active) exit(30);
        [@"background" writeToFile:@(getenv("KSSOLV_STARTUP_TEST_PREWARM")) atomically:YES encoding:NSUTF8StringEncoding error:nil];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
            // Include deferred UI work and the final iteration before teardown.
            [self.window orderFrontRegardless];
            if (self.window.visible || NSRunningApplication.currentApplication.activationPolicy == NSApplicationActivationPolicyRegular) exit(22);
            if (++self.phase < 15 || getenv("KSSOLV_STARTUP_TEST_PREWARM_HOLD")) return;
            if (getenv("KSSOLV_STARTUP_TEST_PREWARM_FAIL")) exit(23);
            puts("KSSOLV_UI_PREWARM_OK");
            fflush(stdout);
            [NSApp terminate:nil];
        }];
        return;
    }
    if (self.window.alphaValue != 1) exit(29); // Normal launches stay opaque.
    ProcessSerialNumber initial = {0, kCurrentProcess};
    if (TransformProcessType(&initial, kProcessTransformToForegroundApplication) != noErr) exit(4);
    [self.window orderFront:nil];
    if (self.window.visible) exit(5); // No initial-size window before reveal.
    NSPanel *diagnostic = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskUtilityWindow backing:NSBackingStoreBuffered defer:NO];
    diagnostic.title = @"Startup error diagnostic";
    [diagnostic orderFront:nil];
    if (!diagnostic.visible || diagnostic.alphaValue != 1) exit(6); // Error/utility panels remain usable.
    [diagnostic orderOut:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
        NSString *path = @(getenv("KSSOLV_STARTUP_SIGNAL"));
        if (self.phase == 0 && [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingString:@".bridge"]]) {
            [self publish:@"shell-ready"];
            self.phase = 1;
        } else if (self.phase == 1 && [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingString:@".reveal"]]) {
            ProcessSerialNumber current = {0, kCurrentProcess};
            // Forwarding the UIElement call used to recurse; promotion must be
            // intercepted synchronously before any second Dock tile can exist.
            (void)TransformProcessType(&current, kProcessTransformToUIElementApplication);
            if (TransformProcessType(&current, kProcessTransformToForegroundApplication) != noErr) { fprintf(stderr, "Fixture foreground request failed\n"); exit(3); }
            [self.window makeKeyAndOrderFront:nil];
            [self publish:@"visible"];
            [@"visible" writeToFile:@(getenv("KSSOLV_STARTUP_TEST_VISIBLE")) atomically:YES encoding:NSUTF8StringEncoding error:nil];
            self.phase = 2;
        } else if (self.phase == 2 && getenv("KSSOLV_STARTUP_TEST_CLOSE") &&
            [NSFileManager.defaultManager fileExistsAtPath:@(getenv("KSSOLV_STARTUP_TEST_CLOSE"))]) {
            self.phase = 3;
            NSImage *branded = NSApp.applicationIconImage;
            NSApp.applicationIconImage = nil;
            if (![[NSApp.applicationIconImage TIFFRepresentation] isEqual:[branded TIFFRepresentation]]) {
                fprintf(stderr, "AppKit default icon reset lost the brand\n"); exit(10);
            }
            NSApp.applicationIconImage = branded;
            NSWindow *settings = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 240)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
            settings.releasedWhenClosed = NO;
            [settings orderFront:nil];
            [settings close];
            if (NSRunningApplication.currentApplication.activationPolicy != NSApplicationActivationPolicyRegular) exit(7);
            self.permitClose = NO;
            [self.window performClose:nil];
            if (!self.window.visible || NSRunningApplication.currentApplication.activationPolicy != NSApplicationActivationPolicyRegular) exit(8);
            self.permitClose = YES;
            [self.window performClose:nil];
            if (self.window.visible || NSRunningApplication.currentApplication.activationPolicy != NSApplicationActivationPolicyRegular) exit(9);
            NSString *passed = [@(getenv("KSSOLV_STARTUP_TEST_CLOSE")) stringByAppendingString:@".passed"];
            [@"settings-close-and-cancel-preserve-dock; native-quit-after-committed-close" writeToFile:passed atomically:YES encoding:NSUTF8StringEncoding error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{ [NSApp terminate:nil]; });
        }
    }];
}
- (BOOL)windowShouldClose:(NSWindow *)sender { return self.permitClose; }
@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        static DockFixture *fixture;
        fixture = [DockFixture new];
        application.delegate = fixture;
        [application run];
    }
    return 0;
}
