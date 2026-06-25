#import "LKOsAppMCPHandler.h"
#import <AppKit/AppKit.h>

/// Matches `LKFoo` and Swift module names like `Lookin.LKFoo`.
static BOOL LookinMCPClassNameMatches(NSString *runtimeName, NSString *shortName) {
    if (runtimeName.length == 0 || shortName.length == 0) {
        return NO;
    }
    if ([runtimeName isEqualToString:shortName]) {
        return YES;
    }
    return [runtimeName hasSuffix:[NSString stringWithFormat:@".%@", shortName]];
}

static SEL LKOsAppMCPSelRawClassName(void) {
    return NSSelectorFromString(@"rawClassName");
}

static SEL LKOsAppMCPSelTriggerClickAction(void) {
    return NSSelectorFromString(@"triggerClickAction");
}

static SEL LKOsAppMCPSelMcpRowDisplayItem(void) {
    return NSSelectorFromString(@"mcp_rowDisplayItem");
}

@implementation LKOsAppMCPHandler

- (void)splitPath:(NSString *)path pathOnly:(NSString * _Nonnull * _Nonnull)pathOnly query:(NSString * _Nullable * _Nullable)query {
    NSRange q = [path rangeOfString:@"?"];
    if (q.location == NSNotFound) {
        *pathOnly = path;
        *query = nil;
        return;
    }
    *pathOnly = [path substringToIndex:q.location];
    *query = [path substringFromIndex:q.location + 1];
}

- (NSInteger)queryIntValue:(NSString *)query key:(NSString *)key defaultValue:(NSInteger)defaultValue {
    if (query.length == 0) {
        return defaultValue;
    }
    for (NSString *part in [query componentsSeparatedByString:@"&"]) {
        NSArray<NSString *> *kv = [part componentsSeparatedByString:@"="];
        if (kv.count == 2 && [kv[0] isEqualToString:key]) {
            return [kv[1] integerValue];
        }
    }
    return defaultValue;
}

- (NSData *)handleMethod:(NSString *)method
                    path:(NSString *)path
                    body:(NSData *)body
              statusCode:(NSInteger *)statusCode {
    NSString *pathOnly = path;
    NSString *query = nil;
    [self splitPath:path pathOnly:&pathOnly query:&query];

    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/status"]) {
        return [self handleStatus:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/connection"]) {
        return [self handleConnectionDiagnostics:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/diag-log"]) {
        return [self handleDiagLogWithQuery:query statusCode:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/ui/diag-log/clear"]) {
        return [self handleDiagLogClear:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/discover-apps"]) {
        return [self handleDiscoverAppsWithBody:body statusCode:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/end-inspect-session"]) {
        return [self handleEndInspectSession:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/simulator-peertalk-probe"]) {
        return [self handleSimulatorPeertalkProbe:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/wire-v2-ping"]) {
        return [self handleWireV2PingWithQuery:query statusCode:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/state"]) {
        return [self handleUIState:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/hierarchy"]) {
        return [self handleHierarchy:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/hierarchy"]) {
        return [self handleUIHierarchy:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/tap-targets"]) {
        return [self handleUITapTargets:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/launch-targets"]) {
        return [self handleLaunchTargets:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/launch-health"]) {
        return [self handleLaunchHealth:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/refresh-launch-targets"]) {
        return [self handleRefreshLaunchTargetsWithBody:body statusCode:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/open-app-switcher"]) {
        return [self handleOpenAppSwitcher:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/select-inspect-target"]) {
        return [self handleSelectInspectTargetWithBody:body statusCode:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/ui/tap"]) {
        return [self handleUITapWithBody:body statusCode:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/ui/open-inspector"]) {
        return [self handleOpenInspector:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/client-state"]) {
        return [self handleClientState:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/inspector-parity"]) {
        return [self handleInspectorParity:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/event-log"]) {
        return [self handleEventLog:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/ui/event-log/clear"]) {
        return [self handleEventLogClear:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/reload"]) {
        return [self handleReloadHierarchy:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/action/toggle-fast-mode"]) {
        return [self handleToggleFastMode:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/preview/state"]) {
        return [self handlePreviewState:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/preview/structure"]) {
        return [self handlePreviewStructure:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/preview/screenshot"]) {
        return [self handlePreviewScreenshot:statusCode];
    }
    if ([method isEqualToString:@"POST"] && [pathOnly isEqualToString:@"/ui/preview/export-screenshots"]) {
        return [self handleExportPreviewScreenshotsWithBody:body statusCode:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/preview/lighting"]) {
        return [self handlePreviewLighting:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/preview/scene-graph"]) {
        return [self handlePreviewSceneGraph:statusCode];
    }
    if ([method isEqualToString:@"GET"] && [pathOnly isEqualToString:@"/ui/preview/texture-sources"]) {
        return [self handlePreviewTextureSources:statusCode];
    }
    // /ui/view/{oid}/screenshot  and  /view/{oid}/screenshot
    if ([method isEqualToString:@"GET"] && [pathOnly hasSuffix:@"/screenshot"]) {
        NSArray<NSString *> *parts = [pathOnly componentsSeparatedByString:@"/"];
        if ([parts.lastObject isEqualToString:@"screenshot"] && parts.count >= 4) {
            NSString *kindSegment = parts[parts.count - 3]; // "view"
            NSString *oidSegment  = parts[parts.count - 2];
            NSUInteger oid = (NSUInteger)[oidSegment longLongValue];
            if ([kindSegment isEqualToString:@"view"] && oid > 0) {
                // /ui/view/{oid}/screenshot → macOS NSView
                if (parts.count == 5 && [parts[1] isEqualToString:@"ui"]) {
                    return [self handleUIScreenshotForOid:oid statusCode:statusCode];
                }
                // /view/{oid}/screenshot → iOS item
                if (parts.count == 4) {
                    return [self handleScreenshotForOid:oid statusCode:statusCode];
                }
            }
        }
    }
    *statusCode = 404;
    return [self errorJSON:@"Not found"];
}

// MARK: - Handlers

- (NSData *)handleStatus:(NSInteger *)statusCode {
    NSObject *info = [_dataSource mcp_currentAppInfo];
    NSMutableDictionary *data = [@{
        @"connected":          @(info != nil),
        @"appName":            [self kvc:info key:@"appName"] ?: @"",
        @"bundleId":           [self kvc:info key:@"appBundleIdentifier"] ?: @"",
        @"deviceDescription":  [self kvc:info key:@"deviceDescription"] ?: @"",
        @"osDescription":      [self kvc:info key:@"osDescription"] ?: @"",
        @"screenWidth":        [self kvc:info key:@"screenWidth"] ?: @0,
        @"screenHeight":       [self kvc:info key:@"screenHeight"] ?: @0,
    } mutableCopy];
    if ([_dataSource respondsToSelector:@selector(mcp_connectionDiagnostics)]) {
        NSDictionary *diag = [_dataSource mcp_connectionDiagnostics];
        if (diag.count > 0) {
            data[@"client"] = diag;
        }
    }
    *statusCode = 200;
    return [self successJSON:data];
}

- (NSData *)handleConnectionDiagnostics:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_connectionDiagnostics)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    *statusCode = 200;
    return [self successJSON:[_dataSource mcp_connectionDiagnostics]];
}

- (NSData *)handleDiagLogWithQuery:(NSString *)query statusCode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_diagLogLinesWithLimit:)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSInteger limit = [self queryIntValue:query key:@"tail" defaultValue:100];
    if (limit < 1) {
        limit = 1;
    }
    if (limit > 500) {
        limit = 500;
    }
    NSArray<NSString *> *lines = [_dataSource mcp_diagLogLinesWithLimit:limit];
    *statusCode = 200;
    return [self successJSON:@{@"count": @(lines.count), @"lines": lines ?: @[]}];
}

- (NSData *)handleDiagLogClear:(NSInteger *)statusCode {
    if ([_dataSource respondsToSelector:@selector(mcp_clearDiagLog)]) {
        [_dataSource mcp_clearDiagLog];
    }
    *statusCode = 200;
    return [self successJSON:@{@"cleared": @YES}];
}

- (NSData *)handleDiscoverAppsWithBody:(NSData *)body statusCode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_discoverAppsSyncWithTimeout:)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSTimeInterval timeout = 20.0;
    NSDictionary *json = [self parseJSONObjectFromBody:body];
    if (json[@"timeout"]) {
        timeout = [json[@"timeout"] doubleValue];
    }
    if (timeout < 3.0) {
        timeout = 3.0;
    }
    if (timeout > 60.0) {
        timeout = 60.0;
    }

    __block NSDictionary *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        result = [self->_dataSource mcp_discoverAppsSyncWithTimeout:timeout];
        dispatch_semaphore_signal(sem);
    });
    long wait = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 20.0) * NSEC_PER_SEC)));
    if (wait != 0) {
        *statusCode = 504;
        return [self errorJSON:@"discover-apps timed out waiting for worker"];
    }
    *statusCode = 200;
    return [self successJSON:result ?: @{}];
}

- (NSData *)handleEndInspectSession:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_endInspectSession)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_dataSource mcp_endInspectSession];
    });
    *statusCode = 200;
    return [self successJSON:@{@"ended": @YES, @"async": @YES}];
}

- (NSData *)handleSimulatorPeertalkProbe:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_simulatorPeertalkPortProbe)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    *statusCode = 200;
    return [self successJSON:[_dataSource mcp_simulatorPeertalkPortProbe]];
}

- (NSData *)handleWireV2PingWithQuery:(NSString *)query statusCode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_wireV2PingSyncWithTimeout:)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSTimeInterval timeout = (NSTimeInterval)[self queryIntValue:query key:@"timeout" defaultValue:5];
    if (timeout < 1) {
        timeout = 1;
    }
    if (timeout > 30) {
        timeout = 30;
    }

    __block NSDictionary *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        result = [self->_dataSource mcp_wireV2PingSyncWithTimeout:timeout];
        dispatch_semaphore_signal(sem);
    });
    long wait = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 3.0) * NSEC_PER_SEC)));
    if (wait != 0) {
        *statusCode = 504;
        return [self errorJSON:@"wire-v2-ping timed out"];
    }
    *statusCode = 200;
    return [self successJSON:result ?: @{}];
}

- (NSData *)handleHierarchy:(NSInteger *)statusCode {
    NSObject *info = [_dataSource mcp_currentHierarchyInfo];
    if (!info) {
        *statusCode = 503;
        return [self errorJSON:@"No hierarchy. Connect an iOS app to Lookin first."];
    }
    NSArray *items = [self kvc:info key:@"displayItems"];
    if (![items isKindOfClass:[NSArray class]] || [(NSArray *)items count] == 0) {
        *statusCode = 503;
        return [self errorJSON:@"No hierarchy. Connect an iOS app to Lookin first."];
    }
    NSObject *appInfo = [self kvc:info key:@"appInfo"];
    NSString *appName = (NSString *)[self kvc:appInfo key:@"appName"] ?: @"";
    NSMutableArray *serialized = [NSMutableArray array];
    for (NSObject *item in (NSArray *)items) {
        [serialized addObject:[self serializeItem:item]];
    }
    *statusCode = 200;
    return [self successJSON:@{@"appName": appName, @"items": serialized}];
}

- (NSData *)handleScreenshotForOid:(NSUInteger)oid statusCode:(NSInteger *)statusCode {
    NSObject *info = [_dataSource mcp_currentHierarchyInfo];
    if (!info) {
        *statusCode = 503;
        return [self errorJSON:@"No hierarchy"];
    }
    NSArray *roots = [self kvc:info key:@"displayItems"];
    if (![roots isKindOfClass:[NSArray class]]) roots = @[];
    NSArray *flat = [self flatItems:(NSArray *)roots];
    NSObject *found = nil;
    for (NSObject *item in flat) {
        if ([self oidForItem:item] == oid) { found = item; break; }
    }
    if (!found) {
        *statusCode = 404;
        return [self errorJSON:[NSString stringWithFormat:@"Item with oid %lu not found", (unsigned long)oid]];
    }
    NSImage *image = (NSImage *)[self kvc:found key:@"soloScreenshot"];
    if (![image isKindOfClass:[NSImage class]]) {
        image = (NSImage *)[self kvc:found key:@"groupScreenshot"];
    }
    if (![image isKindOfClass:[NSImage class]]) {
        *statusCode = 404;
        return [self errorJSON:@"No screenshot for this item"];
    }
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (!cgImage) {
        *statusCode = 500;
        return [self errorJSON:@"Failed to get CGImage"];
    }
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (!png) {
        *statusCode = 500;
        return [self errorJSON:@"Failed to encode PNG"];
    }
    *statusCode = 200;
    return [self successJSON:@{
        @"imageBase64": [png base64EncodedStringWithOptions:0],
        @"mimeType":    @"image/png",
        @"width":       @(image.size.width),
        @"height":      @(image.size.height),
    }];
}

// MARK: - Serialization

- (NSDictionary *)serializeItem:(NSObject *)item {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"oid"] = @([self oidForItem:item]);

    NSObject *viewObj  = [self kvc:item key:@"viewObject"];
    NSObject *layerObj = [self kvc:item key:@"layerObject"];
    NSObject *dispObj  = viewObj ?: layerObj;
    if (dispObj) {
        SEL rawClassNameSel = LKOsAppMCPSelRawClassName();
        NSString *className = nil;
        if ([dispObj respondsToSelector:rawClassNameSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            className = [dispObj performSelector:rawClassNameSel];
#pragma clang diagnostic pop
        }
        d[@"className"] = className ?: @"";
    } else {
        d[@"className"] = @"";
    }

    id frameVal = [self kvc:item key:@"frame"];
    if ([frameVal isKindOfClass:[NSValue class]]) {
        CGRect r = [(NSValue *)frameVal rectValue];
        d[@"frame"] = @{@"x": @(r.origin.x), @"y": @(r.origin.y),
                        @"width": @(r.size.width), @"height": @(r.size.height)};
    }

    id hidden = [self kvc:item key:@"isHidden"];
    if ([hidden isKindOfClass:[NSNumber class]] && [(NSNumber *)hidden boolValue]) {
        d[@"hidden"] = @YES;
    }

    id alpha = [self kvc:item key:@"alpha"];
    if ([alpha isKindOfClass:[NSNumber class]] && [(NSNumber *)alpha floatValue] < 0.999f) {
        d[@"alpha"] = alpha;
    }

    id title = [self kvc:item key:@"customDisplayTitle"];
    if ([title isKindOfClass:[NSString class]] && [(NSString *)title length] > 0) {
        d[@"customTitle"] = title;
    }

    NSObject *vcObj = [self kvc:item key:@"hostViewControllerObject"];
    if (vcObj) {
        SEL rawClassNameSel = LKOsAppMCPSelRawClassName();
        NSString *vcName = nil;
        if ([vcObj respondsToSelector:rawClassNameSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            vcName = [vcObj performSelector:rawClassNameSel];
#pragma clang diagnostic pop
        }
        if (vcName) d[@"viewController"] = vcName;
    }

    id subitems = [self kvc:item key:@"subitems"];
    NSArray *children = [subitems isKindOfClass:[NSArray class]] ? (NSArray *)subitems : @[];
    NSMutableArray *childArray = [NSMutableArray arrayWithCapacity:children.count];
    for (NSObject *child in children) {
        [childArray addObject:[self serializeItem:child]];
    }
    d[@"children"] = childArray;
    return d;
}

- (NSUInteger)oidForItem:(NSObject *)item {
    NSObject *view  = [self kvc:item key:@"viewObject"];
    NSObject *layer = [self kvc:item key:@"layerObject"];
    id viewOid  = [self kvc:view  key:@"oid"];
    id layerOid = [self kvc:layer key:@"oid"];
    if ([viewOid isKindOfClass:[NSNumber class]])  return [(NSNumber *)viewOid unsignedIntegerValue];
    if ([layerOid isKindOfClass:[NSNumber class]]) return [(NSNumber *)layerOid unsignedIntegerValue];
    return 0;
}

- (NSArray *)flatItems:(NSArray *)items {
    NSMutableArray *result = [NSMutableArray array];
    for (NSObject *item in items) {
        [result addObject:item];
        id sub = [self kvc:item key:@"subitems"];
        if ([sub isKindOfClass:[NSArray class]]) {
            [result addObjectsFromArray:[self flatItems:(NSArray *)sub]];
        }
    }
    return result;
}

// MARK: - Lookin macOS UI hierarchy

- (NSData *)handleUIHierarchy:(NSInteger *)statusCode {
    NSMutableArray *windows = [NSMutableArray array];
    for (NSWindow *win in [NSApp windows]) {
        [windows addObject:[self serializeNSWindow:win]];
    }
    *statusCode = 200;
    return [self successJSON:@{@"appName": @"Lookin", @"windows": windows}];
}

- (NSDictionary *)serializeNSWindow:(NSWindow *)win {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"oid"]     = @((NSUInteger)win);
    d[@"title"]   = win.title ?: @"";
    d[@"visible"] = @(win.isVisible);
    NSRect f = win.frame;
    d[@"frame"] = @{@"x": @(f.origin.x), @"y": @(f.origin.y),
                    @"width": @(f.size.width), @"height": @(f.size.height)};
    if (win.contentView) {
        d[@"contentView"] = [self serializeNSView:win.contentView];
    }
    return d;
}

- (NSDictionary *)serializeNSView:(NSView *)view {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"oid"]       = @((NSUInteger)view);
    d[@"className"] = NSStringFromClass([view class]) ?: @"";
    NSRect f = view.frame;
    d[@"frame"] = @{@"x": @(f.origin.x), @"y": @(f.origin.y),
                    @"width": @(f.size.width), @"height": @(f.size.height)};
    if (view.isHidden) {
        d[@"hidden"] = @YES;
    }
    if (view.alphaValue < 0.999) {
        d[@"alpha"] = @(view.alphaValue);
    }
    NSString *identifier = view.identifier;
    if (identifier.length > 0) {
        d[@"identifier"] = identifier;
    }
    NSString *label = view.accessibilityLabel;
    if (label.length > 0) {
        d[@"label"] = label;
    }
    NSMutableArray *children = [NSMutableArray arrayWithCapacity:view.subviews.count];
    for (NSView *sub in view.subviews) {
        [children addObject:[self serializeNSView:sub]];
    }
    d[@"children"] = children;
    return d;
}

- (NSData *)handleUIScreenshotForOid:(NSUInteger)oid statusCode:(NSInteger *)statusCode {
    NSView *found = [self findNSViewWithOid:oid];
    if (!found) {
        *statusCode = 404;
        return [self errorJSON:[NSString stringWithFormat:@"NSView with oid %lu not found", (unsigned long)oid]];
    }
    NSBitmapImageRep *rep = [found bitmapImageRepForCachingDisplayInRect:found.bounds];
    if (!rep) {
        *statusCode = 500;
        return [self errorJSON:@"Failed to create bitmap rep"];
    }
    [found cacheDisplayInRect:found.bounds toBitmapImageRep:rep];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (!png) {
        *statusCode = 500;
        return [self errorJSON:@"Failed to encode PNG"];
    }
    *statusCode = 200;
    return [self successJSON:@{
        @"imageBase64": [png base64EncodedStringWithOptions:0],
        @"mimeType":    @"image/png",
        @"width":       @(found.bounds.size.width),
        @"height":      @(found.bounds.size.height),
    }];
}

- (void)enumerateToolbarViewsInWindow:(NSWindow *)window usingBlock:(void (^)(NSView *view))block {
    if (!window || !block) {
        return;
    }
    NSToolbar *toolbar = window.toolbar;
    if (!toolbar) {
        return;
    }
    for (NSToolbarItem *item in toolbar.items) {
        NSView *view = item.view;
        if (view && !view.isHidden) {
            block(view);
        }
    }
}

- (nullable NSView *)findNSViewWithOid:(NSUInteger)oid {
    for (NSWindow *win in [NSApp windows]) {
        if (!win.isVisible) {
            continue;
        }
        __block NSView *toolbarHit = nil;
        [self enumerateToolbarViewsInWindow:win usingBlock:^(NSView *view) {
            if (!toolbarHit && (NSUInteger)view == oid) {
                toolbarHit = view;
            }
        }];
        if (toolbarHit) {
            return toolbarHit;
        }
        NSView *found = [self findNSView:oid inView:win.contentView];
        if (found) return found;
    }
    return nil;
}

- (nullable NSView *)findNSView:(NSUInteger)oid inView:(NSView *)view {
    if (!view) return nil;
    if ((NSUInteger)view == oid) return view;
    for (NSView *sub in view.subviews) {
        NSView *found = [self findNSView:oid inView:sub];
        if (found) return found;
    }
    return nil;
}

// MARK: - UI state & tap

- (NSData *)handleUITapTargets:(NSInteger *)statusCode {
    NSMutableArray *targets = [NSMutableArray array];
    NSUInteger hierarchyRowIndex = 0;
    for (NSWindow *win in [NSApp windows]) {
        if (!win.isVisible) {
            continue;
        }
        __weak typeof(self) weakSelf = self;
        [self enumerateToolbarViewsInWindow:win usingBlock:^(NSView *view) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            NSDictionary *info = [self tapTargetInfoForView:view
                                                     window:win
                                          hierarchyRowIndex:&hierarchyRowIndex];
            if (info) {
                [targets addObject:info];
            }
        }];
        [self collectTapTargetsInView:win.contentView
                               window:win
                    hierarchyRowIndex:&hierarchyRowIndex
                              targets:targets];
    }
    *statusCode = 200;
    return [self successJSON:@{@"count": @(targets.count), @"targets": targets}];
}

- (void)collectTapTargetsInView:(NSView *)view
                         window:(NSWindow *)window
              hierarchyRowIndex:(NSUInteger *)hierarchyRowIndex
                        targets:(NSMutableArray *)targets {
    if (!view || view.isHidden) {
        return;
    }
    NSRect bounds = view.bounds;
    if (bounds.size.width < 4 || bounds.size.height < 4) {
        for (NSView *sub in view.subviews) {
            [self collectTapTargetsInView:sub
                                   window:window
                        hierarchyRowIndex:hierarchyRowIndex
                                  targets:targets];
        }
        return;
    }
    if (view.alphaValue < 0.05) {
        for (NSView *sub in view.subviews) {
            [self collectTapTargetsInView:sub
                                   window:window
                        hierarchyRowIndex:hierarchyRowIndex
                                  targets:targets];
        }
        return;
    }

    NSDictionary *info = [self tapTargetInfoForView:view
                                             window:window
                                  hierarchyRowIndex:hierarchyRowIndex];
    if (info) {
        [targets addObject:info];
        NSString *className = NSStringFromClass([view class]);
        if (LookinMCPClassNameMatches(className, @"LKHierarchyRowView")) {
            (*hierarchyRowIndex)++;
        }
    }

    for (NSView *sub in view.subviews) {
        [self collectTapTargetsInView:sub
                               window:window
                    hierarchyRowIndex:hierarchyRowIndex
                              targets:targets];
    }
}

- (nullable NSObject *)displayItemForHierarchyRowView:(NSView *)view {
    NSObject *item = [self kvc:view key:@"displayItem"];
    if (item) {
        return item;
    }
    if ([view respondsToSelector:LKOsAppMCPSelMcpRowDisplayItem()]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id result = [view performSelector:LKOsAppMCPSelMcpRowDisplayItem()];
#pragma clang diagnostic pop
        if ([result isKindOfClass:[NSObject class]]) {
            return (NSObject *)result;
        }
    }
    return nil;
}

- (nullable NSDictionary *)tapTargetInfoForView:(NSView *)view
                                         window:(NSWindow *)window
                              hierarchyRowIndex:(NSUInteger *)hierarchyRowIndex {
    NSString *className = NSStringFromClass([view class]);

    if (LookinMCPClassNameMatches(className, @"LKHierarchyRowView")) {
        NSMutableDictionary *d = [self baseTapTargetDictForView:view window:window];
        d[@"action"] = @"hierarchySelect";
        d[@"effect"] = @"Select connected iOS view/layer in inspector";
        d[@"hierarchyRowIndex"] = @(*hierarchyRowIndex);
        NSObject *item = [self displayItemForHierarchyRowView:view];
        if (item) {
            NSString *title = (NSString *)[self kvc:item key:@"title"];
            if ([title isKindOfClass:[NSString class]] && title.length > 0) {
                d[@"title"] = title;
            }
            NSString *subtitle = (NSString *)[self kvc:item key:@"subtitle"];
            if ([subtitle isKindOfClass:[NSString class]] && subtitle.length > 0) {
                d[@"subtitle"] = subtitle;
            }
            NSUInteger iosOid = 0;
            NSObject *viewObj = [self kvc:item key:@"viewObject"];
            NSObject *layerObj = [self kvc:item key:@"layerObject"];
            id viewOid = [self kvc:viewObj key:@"oid"];
            id layerOid = [self kvc:layerObj key:@"oid"];
            if ([viewOid isKindOfClass:[NSNumber class]]) {
                iosOid = [(NSNumber *)viewOid unsignedIntegerValue];
            } else if ([layerOid isKindOfClass:[NSNumber class]]) {
                iosOid = [(NSNumber *)layerOid unsignedIntegerValue];
            }
            if (iosOid > 0) {
                d[@"iosOid"] = @(iosOid);
            }
        } else {
            NSString *label = view.accessibilityLabel;
            if (label.length > 0) {
                d[@"title"] = label;
            }
        }
        return d;
    }

    if (LookinMCPClassNameMatches(className, @"LKWindowToolbarAppButton")) {
        NSMutableDictionary *d = [self baseTapTargetDictForView:view window:window];
        d[@"action"] = @"toolbarSelectApp";
        d[@"effect"] = @"Open app switcher popover (sim/USB tiles)";
        return d;
    }

    if (LookinMCPClassNameMatches(className, @"LKLaunchAppView")) {
        NSMutableDictionary *d = [self baseTapTargetDictForView:view window:window];
        d[@"action"] = @"openInspector";
        NSObject *app = [self kvc:view key:@"app"];
        NSObject *appInfo = [self kvc:app key:@"appInfo"];
        NSString *appName = (NSString *)[self kvc:appInfo key:@"appName"];
        NSString *deviceDescription = (NSString *)[self kvc:appInfo key:@"deviceDescription"];
        NSString *bundleId = (NSString *)[self kvc:appInfo key:@"appBundleIdentifier"];
        NSString *osDescription = (NSString *)[self kvc:appInfo key:@"osDescription"];
        NSString *a11y = view.accessibilityIdentifier;
        NSString *channel = nil;
        if (a11y.length > 0) {
            d[@"accessibilityIdentifier"] = a11y;
            if ([a11y hasSuffix:@".usb"]) {
                channel = @"usb";
            } else if ([a11y hasSuffix:@".sim"]) {
                channel = @"sim";
            }
        }
        if (channel.length > 0) {
            d[@"channel"] = channel;
            d[@"effect"] = [channel isEqualToString:@"usb"]
                ? @"Open inspector for USB-connected iOS app"
                : @"Open inspector for Simulator iOS app";
        } else {
            d[@"effect"] = @"Open inspector for this connected iOS app";
        }
        if ([deviceDescription isKindOfClass:[NSString class]] && deviceDescription.length > 0) {
            d[@"title"] = deviceDescription;
        } else if ([appName isKindOfClass:[NSString class]] && appName.length > 0) {
            d[@"title"] = appName;
        }
        if ([bundleId isKindOfClass:[NSString class]] && bundleId.length > 0) {
            d[@"bundleId"] = bundleId;
        }
        if ([appName isKindOfClass:[NSString class]] && appName.length > 0) {
            d[@"appName"] = appName;
        }
        if ([deviceDescription isKindOfClass:[NSString class]] && deviceDescription.length > 0) {
            d[@"deviceDescription"] = deviceDescription;
        }
        if ([osDescription isKindOfClass:[NSString class]] && osDescription.length > 0) {
            d[@"osDescription"] = osDescription;
        }
        return d;
    }

    if ([view respondsToSelector:LKOsAppMCPSelTriggerClickAction()]) {
        id target = [self kvc:view key:@"target"];
        id clickAction = [self kvc:view key:@"clickAction"];
        if (!target || !clickAction || clickAction == [NSNull null]) {
            return nil;
        }
        NSMutableDictionary *d = [self baseTapTargetDictForView:view window:window];
        d[@"action"] = @"clickAction";
        d[@"effect"] = @"Fire control click handler (triggerClickAction)";
        if ([clickAction isKindOfClass:[NSString class]] && [(NSString *)clickAction length] > 0) {
            d[@"selector"] = clickAction;
        }
        return d;
    }

    if ([view isKindOfClass:[NSControl class]]) {
        NSControl *control = (NSControl *)view;
        if (!control.isEnabled || control.isHidden) {
            return nil;
        }
        NSMutableDictionary *d = [self baseTapTargetDictForView:view window:window];
        d[@"action"] = @"controlClick";
        d[@"effect"] = @"Perform NSControl click (performClick:)";
        if ([control respondsToSelector:@selector(title)] && [(id)control title].length > 0) {
            d[@"title"] = [(id)control title];
        }
        return d;
    }

    if ([self viewHasCustomMouseClickHandler:view]) {
        NSMutableDictionary *d = [self baseTapTargetDictForView:view window:window];
        d[@"action"] = @"mouseClick";
        d[@"effect"] = @"Deliver synthetic mouseDown/mouseUp";
        return d;
    }

    return nil;
}

- (NSMutableDictionary *)baseTapTargetDictForView:(NSView *)view window:(NSWindow *)window {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"oid"] = @((NSUInteger)view);
    d[@"className"] = NSStringFromClass([view class]) ?: @"";
    NSRect f = view.frame;
    d[@"frame"] = @{@"x": @(f.origin.x), @"y": @(f.origin.y),
                    @"width": @(f.size.width), @"height": @(f.size.height)};
    NSString *windowTitle = window.title;
    if (windowTitle.length > 0) {
        d[@"windowTitle"] = windowTitle;
    }
    NSString *identifier = view.identifier;
    if (identifier.length > 0) {
        d[@"identifier"] = identifier;
    }
    NSString *a11y = view.accessibilityIdentifier;
    if (a11y.length > 0) {
        d[@"accessibilityIdentifier"] = a11y;
    }
    NSString *label = view.accessibilityLabel;
    if (label.length > 0) {
        d[@"label"] = label;
    }
    return d;
}

- (BOOL)viewHasCustomMouseClickHandler:(NSView *)view {
    NSString *className = NSStringFromClass([view class]);
    static NSSet<NSString *> *knownClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownClasses = [NSSet setWithArray:@[
            @"LKDashboardCardView",
            @"LKDashboardHeaderView",
            @"LKDashboardAttributeColorView",
            @"LKDashboardAttributeEnumsView",
            @"LKTextFieldView",
        ]];
    });
    if ([knownClasses containsObject:className]) {
        return YES;
    }
    if ([className hasPrefix:@"LKDashboardAttribute"] &&
        [view respondsToSelector:@selector(mouseDown:)] &&
        [view respondsToSelector:@selector(mouseUp:)]) {
        return YES;
    }
    return NO;
}

- (NSData *)handleUIState:(NSInteger *)statusCode {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    if ([_dataSource respondsToSelector:@selector(mcp_inspectorUIState)]) {
        NSDictionary *clientState = [_dataSource mcp_inspectorUIState];
        if ([clientState isKindOfClass:[NSDictionary class]]) {
            for (id key in clientState) {
                if (![key isKindOfClass:[NSString class]]) {
                    continue;
                }
                id value = clientState[key];
                if ([value isKindOfClass:[NSString class]] ||
                    [value isKindOfClass:[NSNumber class]]) {
                    data[key] = value;
                }
            }
        }
    }
    NSUInteger dashboardCards = 0;
    NSUInteger hierarchyRows = 0;
    [self countLookinUIViews:&dashboardCards hierarchyRows:&hierarchyRows];
    data[@"dashboardCards"] = @(dashboardCards);
    data[@"hierarchyRows"] = @(hierarchyRows);
    data[@"hasInspectorShell"] = @([self hasInspectorSplitView]);
    *statusCode = 200;
    return [self successJSON:data];
}

- (void)countLookinUIViews:(NSUInteger *)outCards hierarchyRows:(NSUInteger *)outRows {
    NSUInteger cards = 0;
    NSUInteger rows = 0;
    for (NSWindow *win in [NSApp windows]) {
        [self countLookinUIViewsInView:win.contentView cards:&cards rows:&rows];
    }
    if (outCards) *outCards = cards;
    if (outRows) *outRows = rows;
}

- (void)countLookinUIViewsInView:(NSView *)view cards:(NSUInteger *)cards rows:(NSUInteger *)rows {
    if (!view) return;
    NSString *name = NSStringFromClass([view class]);
    if (LookinMCPClassNameMatches(name, @"LKDashboardCardView")) {
        (*cards)++;
    } else if (LookinMCPClassNameMatches(name, @"LKHierarchyRowView")) {
        (*rows)++;
    }
    for (NSView *sub in view.subviews) {
        [self countLookinUIViewsInView:sub cards:cards rows:rows];
    }
}

- (BOOL)hasInspectorSplitView {
    for (NSWindow *win in [NSApp windows]) {
        if ([self view:win.contentView hasClassNamed:@"LKSplitView"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)view:(NSView *)view hasClassNamed:(NSString *)className {
    if (!view) return NO;
    if (LookinMCPClassNameMatches(NSStringFromClass([view class]), className)) return YES;
    for (NSView *sub in view.subviews) {
        if ([self view:sub hasClassNamed:className]) return YES;
    }
    return NO;
}

- (nullable NSDictionary *)parseJSONObjectFromBody:(NSData *)body {
    if (body.length == 0) return @{};
    id json = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    return [json isKindOfClass:[NSDictionary class]] ? (NSDictionary *)json : nil;
}

- (NSData *)handleUITapWithBody:(NSData *)body statusCode:(NSInteger *)statusCode {
    NSDictionary *json = [self parseJSONObjectFromBody:body];
    if (!json) {
        *statusCode = 400;
        return [self errorJSON:@"Invalid JSON body"];
    }

    NSString *channel = json[@"channel"];
    if ([channel isKindOfClass:[NSString class]]) {
        channel = [channel lowercaseString];
    } else {
        channel = nil;
    }
    NSString *accessibilityIdentifier = json[@"accessibilityIdentifier"];
    if (![accessibilityIdentifier isKindOfClass:[NSString class]] || accessibilityIdentifier.length == 0) {
        accessibilityIdentifier = nil;
    }

    if ((channel.length > 0 || accessibilityIdentifier.length > 0) &&
        [_dataSource respondsToSelector:@selector(mcp_selectInspectTargetWithChannel:accessibilityIdentifier:index:timeout:)]) {
        NSInteger index = NSNotFound;
        if (json[@"index"] && json[@"index"] != [NSNull null]) {
            index = [json[@"index"] integerValue];
        }
        NSTimeInterval timeout = 45.0;
        if (json[@"timeout"]) {
            timeout = [json[@"timeout"] doubleValue];
        }
        if (timeout < 5.0) {
            timeout = 5.0;
        }
        if (timeout > 120.0) {
            timeout = 120.0;
        }
        __block NSDictionary *selectResult = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            selectResult = [self->_dataSource mcp_selectInspectTargetWithChannel:channel
                                                         accessibilityIdentifier:accessibilityIdentifier
                                                                           index:index
                                                                         timeout:timeout];
            dispatch_semaphore_signal(sem);
        });
        long wait = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 60.0) * NSEC_PER_SEC)));
        if (wait != 0) {
            *statusCode = 504;
            return [self errorJSON:@"select-inspect-target timed out"];
        }
        BOOL ok = [selectResult[@"ok"] boolValue];
        *statusCode = ok ? 200 : 404;
        NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:selectResult ?: @{}];
        payload[@"clicked"] = @YES;
        payload[@"selectionApplied"] = @(ok);
        return [self successJSON:payload];
    }

    NSView *targetView = nil;
    CGPoint point = CGPointZero;
    BOOL hasPoint = NO;

    if (accessibilityIdentifier.length > 0) {
        targetView = [self findNSViewWithAccessibilityIdentifier:accessibilityIdentifier];
    }
    if (!targetView && channel.length > 0) {
        targetView = [self findLaunchAppViewWithChannel:channel];
    }

    id oidValue = json[@"oid"];
    if (oidValue && oidValue != [NSNull null]) {
        NSUInteger oid = 0;
        if ([oidValue isKindOfClass:[NSNumber class]]) {
            oid = [(NSNumber *)oidValue unsignedIntegerValue];
        } else if ([oidValue isKindOfClass:[NSString class]]) {
            oid = [(NSString *)oidValue longLongValue];
        }
        if (oid == 0) {
            *statusCode = 400;
            return [self errorJSON:@"Invalid oid"];
        }
        targetView = [self findNSViewWithOid:oid];
        if (!targetView) {
            *statusCode = 404;
            return [self errorJSON:[NSString stringWithFormat:@"NSView with oid %lu not found", (unsigned long)oid]];
        }
        point = [self defaultClickPointForView:targetView];
        hasPoint = YES;
    }

    if (!hasPoint) {
        NSNumber *xNum = json[@"x"];
        NSNumber *yNum = json[@"y"];
        if (![xNum isKindOfClass:[NSNumber class]] || ![yNum isKindOfClass:[NSNumber class]]) {
            *statusCode = 400;
            return [self errorJSON:@"Provide either 'oid' or window 'x'+'y'"];
        }
        point = CGPointMake(xNum.doubleValue, yNum.doubleValue);
        hasPoint = YES;
    }

    NSWindow *window = targetView.window;
    if (!window) {
        window = [NSApp keyWindow] ?: [NSApp mainWindow];
    }
    if (!window) {
        *statusCode = 503;
        return [self errorJSON:@"No key window"];
    }

    if (!targetView) {
        NSView *contentView = window.contentView;
        targetView = [contentView hitTest:point];
        if (!targetView) {
            *statusCode = 404;
            return [self errorJSON:@"No view at the given point"];
        }
    }

    NSString *className = NSStringFromClass([targetView class]);
    if (LookinMCPClassNameMatches(className, @"LKWindowToolbarAppButton") &&
        [_dataSource respondsToSelector:@selector(mcp_openAppSwitcherPopover)]) {
        [_dataSource mcp_openAppSwitcherPopover];
        *statusCode = 200;
        return [self successJSON:@{
            @"clicked": @YES,
            @"popoverOpened": @YES,
            @"className": className ?: @"",
            @"oid": @((NSUInteger)targetView),
        }];
    }

    if (LookinMCPClassNameMatches(className, @"LKLaunchAppView") &&
        [_dataSource respondsToSelector:@selector(mcp_selectInspectTargetWithChannel:accessibilityIdentifier:index:timeout:)]) {
        NSString *launchChannel = nil;
        NSString *a11y = targetView.accessibilityIdentifier;
        if (a11y.length > 0) {
            if ([a11y hasSuffix:@".usb"]) {
                launchChannel = @"usb";
            } else if ([a11y hasSuffix:@".sim"]) {
                launchChannel = @"sim";
            }
        }
        NSTimeInterval timeout = 45.0;
        if (json[@"timeout"]) {
            timeout = [json[@"timeout"] doubleValue];
        }
        if (timeout < 5.0) {
            timeout = 5.0;
        }
        if (timeout > 120.0) {
            timeout = 120.0;
        }
        __block NSDictionary *selectResult = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            selectResult = [self->_dataSource mcp_selectInspectTargetWithChannel:launchChannel
                                                         accessibilityIdentifier:a11y
                                                                           index:NSNotFound
                                                                         timeout:timeout];
            dispatch_semaphore_signal(sem);
        });
        long wait = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 60.0) * NSEC_PER_SEC)));
        if (wait != 0) {
            *statusCode = 504;
            return [self errorJSON:@"select-inspect-target timed out"];
        }
        BOOL ok = [selectResult[@"ok"] boolValue];
        *statusCode = ok ? 200 : 404;
        NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:selectResult ?: @{}];
        payload[@"clicked"] = @YES;
        payload[@"oid"] = @((NSUInteger)targetView);
        payload[@"className"] = className ?: @"";
        payload[@"x"] = @(point.x);
        payload[@"y"] = @(point.y);
        payload[@"selectionApplied"] = @(ok);
        if (a11y.length > 0) {
            payload[@"accessibilityIdentifier"] = a11y;
        }
        if (launchChannel.length > 0) {
            payload[@"channel"] = launchChannel;
        }
        return [self successJSON:payload];
    }

    BOOL hierarchySelected = NO;
    if ([_dataSource respondsToSelector:@selector(mcp_selectHierarchyRowMacView:)]) {
        hierarchySelected = [_dataSource mcp_selectHierarchyRowMacView:targetView];
    }

    BOOL clicked = hierarchySelected;
    if (!clicked) {
        clicked = [self sendSyntheticClickAtPoint:point onView:targetView inWindow:window];
    }
    if (!clicked) {
        *statusCode = 500;
        return [self errorJSON:@"Failed to deliver click"];
    }

    NSMutableDictionary *payload = [@{
        @"clicked": @YES,
        @"oid": @((NSUInteger)targetView),
        @"className": NSStringFromClass([targetView class]) ?: @"",
        @"x": @(point.x),
        @"y": @(point.y),
        @"hierarchySelectionApplied": @(hierarchySelected),
    } mutableCopy];
    if ([_dataSource respondsToSelector:@selector(mcp_inspectorUIState)]) {
        NSDictionary *ui = [_dataSource mcp_inspectorUIState];
        if (ui[@"selectedOid"]) {
            payload[@"selectedOid"] = ui[@"selectedOid"];
        }
        if (ui[@"selectedTitle"]) {
            payload[@"selectedTitle"] = ui[@"selectedTitle"];
        }
        if (ui[@"uiMode"]) {
            payload[@"uiMode"] = ui[@"uiMode"];
        }
    }

    *statusCode = 200;
    return [self successJSON:payload];
}

- (NSData *)handleOpenAppSwitcher:(NSInteger *)statusCode {
    // Prefer sync variant: discovers apps (no images), opens popover, returns tiles immediately.
    if ([_dataSource respondsToSelector:@selector(mcp_fetchAndOpenAppSwitcherWithTimeout:)]) {
        __block NSDictionary *result = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            result = [self->_dataSource mcp_fetchAndOpenAppSwitcherWithTimeout:30.0];
            dispatch_semaphore_signal(sem);
        });
        long waited = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45.0 * NSEC_PER_SEC)));
        if (waited != 0) {
            *statusCode = 504;
            return [self errorJSON:@"open-app-switcher timed out waiting for discovery"];
        }
        BOOL ok = [result[@"ok"] boolValue] || [result[@"count"] integerValue] > 0;
        *statusCode = ok ? 200 : 404;
        return [self successJSON:result ?: @{}];
    }
    // Fallback: fire-and-forget.
    if (![_dataSource respondsToSelector:@selector(mcp_openAppSwitcherPopover)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    [_dataSource mcp_openAppSwitcherPopover];
    *statusCode = 200;
    return [self successJSON:@{@"ok": @YES, @"popoverOpened": @YES}];
}

- (NSData *)handleLaunchTargets:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_launchInspectTargets)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSArray *targets = [_dataSource mcp_launchInspectTargets];
    NSString *uiMode = @"unknown";
    if ([_dataSource respondsToSelector:@selector(mcp_inspectorUIState)]) {
        NSDictionary *ui = [_dataSource mcp_inspectorUIState];
        if ([ui[@"uiMode"] isKindOfClass:[NSString class]]) {
            uiMode = ui[@"uiMode"];
        }
    }
    // Only auto-refresh on the launch screen. In inspector mode the popover is driven by
    // popupAllInspectableApps which holds fetchAppInfosLock — refreshLaunchTargets would
    // block on the same lock and stall wait_popover_tiles for 30+ seconds.
    if (targets.count == 0 && [uiMode isEqualToString:@"launch"] &&
        [_dataSource respondsToSelector:@selector(mcp_refreshLaunchTargetsWithTimeout:)]) {
        NSDictionary *refreshed = [_dataSource mcp_refreshLaunchTargetsWithTimeout:30.0];
        NSArray *refreshedTargets = refreshed[@"targets"];
        if ([refreshedTargets isKindOfClass:[NSArray class]] && refreshedTargets.count > 0) {
            targets = refreshedTargets;
        }
    }
    *statusCode = 200;
    return [self successJSON:@{
        @"uiMode": uiMode,
        @"count": @(targets.count),
        @"targets": targets ?: @[],
    }];
}

- (NSData *)handleLaunchHealth:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_launchHealth)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *health = [_dataSource mcp_launchHealth];
    *statusCode = 200;
    return [self successJSON:health ?: @{}];
}

- (NSData *)handleRefreshLaunchTargetsWithBody:(NSData *)body statusCode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_refreshLaunchTargetsWithTimeout:)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *json = [self parseJSONObjectFromBody:body];
    NSTimeInterval timeout = 45.0;
    if ([json isKindOfClass:[NSDictionary class]] && json[@"timeout"]) {
        timeout = [json[@"timeout"] doubleValue];
    }
    if (timeout < 10.0) {
        timeout = 10.0;
    }
    if (timeout > 120.0) {
        timeout = 120.0;
    }
    __block NSDictionary *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        result = [self->_dataSource mcp_refreshLaunchTargetsWithTimeout:timeout];
        dispatch_semaphore_signal(sem);
    });
    long wait = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 20.0) * NSEC_PER_SEC)));
    if (wait != 0) {
        *statusCode = 504;
        return [self errorJSON:@"refresh-launch-targets timed out"];
    }
    BOOL ok = [result[@"ok"] boolValue];
    *statusCode = ok ? 200 : 404;
    return [self successJSON:result ?: @{}];
}

- (NSData *)handleSelectInspectTargetWithBody:(NSData *)body statusCode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_selectInspectTargetWithChannel:accessibilityIdentifier:index:timeout:)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *json = [self parseJSONObjectFromBody:body];
    if (!json) {
        *statusCode = 400;
        return [self errorJSON:@"Invalid JSON body"];
    }
    NSString *channel = json[@"channel"];
    if ([channel isKindOfClass:[NSString class]]) {
        channel = [channel lowercaseString];
    } else {
        channel = nil;
    }
    NSString *accessibilityIdentifier = json[@"accessibilityIdentifier"];
    if (![accessibilityIdentifier isKindOfClass:[NSString class]] || accessibilityIdentifier.length == 0) {
        accessibilityIdentifier = nil;
    }
    NSInteger index = NSNotFound;
    if (json[@"index"] && json[@"index"] != [NSNull null]) {
        index = [json[@"index"] integerValue];
    }
    NSTimeInterval timeout = 45.0;
    if (json[@"timeout"]) {
        timeout = [json[@"timeout"] doubleValue];
    }
    if (timeout < 5.0) {
        timeout = 5.0;
    }
    if (timeout > 120.0) {
        timeout = 120.0;
    }
    if (channel.length == 0 && accessibilityIdentifier.length == 0 && index == NSNotFound) {
        *statusCode = 400;
        return [self errorJSON:@"Provide channel, accessibilityIdentifier, or index"];
    }

    __block NSDictionary *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        result = [self->_dataSource mcp_selectInspectTargetWithChannel:channel
                                                 accessibilityIdentifier:accessibilityIdentifier
                                                                   index:index
                                                                 timeout:timeout];
        dispatch_semaphore_signal(sem);
    });
    long wait = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 60.0) * NSEC_PER_SEC)));
    if (wait != 0) {
        *statusCode = 504;
        return [self errorJSON:@"select-inspect-target timed out"];
    }
    BOOL ok = [result[@"ok"] boolValue];
    *statusCode = ok ? 200 : 404;
    return [self successJSON:result ?: @{}];
}

- (nullable NSView *)findNSViewWithAccessibilityIdentifier:(NSString *)identifier {
    for (NSWindow *win in [NSApp windows]) {
        if (!win.isVisible) {
            continue;
        }
        __block NSView *toolbarHit = nil;
        [self enumerateToolbarViewsInWindow:win usingBlock:^(NSView *view) {
            if (!toolbarHit && [view.accessibilityIdentifier isEqualToString:identifier]) {
                toolbarHit = view;
            }
        }];
        if (toolbarHit) {
            return toolbarHit;
        }
        NSView *found = [self findNSViewWithAccessibilityIdentifier:identifier inView:win.contentView];
        if (found) {
            return found;
        }
    }
    return nil;
}

- (nullable NSView *)findNSViewWithAccessibilityIdentifier:(NSString *)identifier inView:(NSView *)view {
    if (!view || view.isHidden) {
        return nil;
    }
    if ([view.accessibilityIdentifier isEqualToString:identifier]) {
        return view;
    }
    for (NSView *sub in view.subviews) {
        NSView *found = [self findNSViewWithAccessibilityIdentifier:identifier inView:sub];
        if (found) {
            return found;
        }
    }
    return nil;
}

- (nullable NSView *)findLaunchAppViewWithChannel:(NSString *)channel {
    NSString *suffix = [NSString stringWithFormat:@".%@", channel];
    for (NSWindow *win in [NSApp windows]) {
        if (!win.isVisible) {
            continue;
        }
        NSView *found = [self findLaunchAppViewWithChannelSuffix:suffix inView:win.contentView];
        if (found) {
            return found;
        }
    }
    return nil;
}

- (nullable NSView *)findLaunchAppViewWithChannelSuffix:(NSString *)suffix inView:(NSView *)view {
    if (!view || view.isHidden) {
        return nil;
    }
    NSString *className = NSStringFromClass([view class]);
    if (LookinMCPClassNameMatches(className, @"LKLaunchAppView")) {
        NSString *a11y = view.accessibilityIdentifier;
        if (a11y.length > 0 && [a11y hasSuffix:suffix]) {
            return view;
        }
    }
    for (NSView *sub in view.subviews) {
        NSView *found = [self findLaunchAppViewWithChannelSuffix:suffix inView:sub];
        if (found) {
            return found;
        }
    }
    return nil;
}

- (CGPoint)defaultClickPointForView:(NSView *)view {
    NSRect rectInWindow = [view convertRect:view.bounds toView:nil];
    return CGPointMake(NSMidX(rectInWindow), NSMidY(rectInWindow));
}

- (NSData *)handleEventLog:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_eventLog)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSArray *events = [_dataSource mcp_eventLog];
    *statusCode = 200;
    return [self successJSON:@{@"count": @(events.count), @"events": events ?: @[]}];
}

- (NSData *)handleEventLogClear:(NSInteger *)statusCode {
    if ([_dataSource respondsToSelector:@selector(mcp_clearEventLog)]) {
        [_dataSource mcp_clearEventLog];
    }
    *statusCode = 200;
    return [self successJSON:@{@"cleared": @YES}];
}

- (NSData *)handleReloadHierarchy:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_reloadHierarchy)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    [_dataSource mcp_reloadHierarchy];
    *statusCode = 200;
    return [self successJSON:@{@"triggered": @YES}];
}

- (NSData *)handleToggleFastMode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_toggleFastMode)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    BOOL enabled = [_dataSource mcp_toggleFastMode];
    *statusCode = 200;
    return [self successJSON:@{@"fastMode": @(enabled)}];
}

- (NSData *)handlePreviewState:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_iosPreviewState)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *state = [_dataSource mcp_iosPreviewState];
    if (!state) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview available (inspector not open or hierarchy not loaded)"];
    }
    *statusCode = 200;
    return [self successJSON:state];
}

- (NSData *)handlePreviewStructure:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_iosPreviewState)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *state = [_dataSource mcp_iosPreviewState];
    if (!state) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview available"];
    }
    *statusCode = 200;
    NSArray *layers = state[@"layers"] ?: state[@"structure"] ?: @[];
    return [self successJSON:@{
        @"sceneLayout": state[@"sceneLayout"] ?: @"flat",
        @"layers": layers,
        @"structure": layers,
        @"dimension": state[@"dimension"] ?: @0,
        @"visibleLayersCount": state[@"visibleLayersCount"] ?: @(layers.count),
        @"displayItemNodesCount": state[@"displayItemNodesCount"] ?: @0,
        @"flatDisplayItemsCount": state[@"flatDisplayItemsCount"] ?: @0,
    }];
}

- (NSData *)handleExportPreviewScreenshotsWithBody:(NSData *)body statusCode:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_exportPreviewLayerScreenshotsToDirectory:)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *json = [self parseJSONObjectFromBody:body];
    if (!json) {
        *statusCode = 400;
        return [self errorJSON:@"Invalid JSON body"];
    }
    NSString *directory = json[@"directory"];
    if (![directory isKindOfClass:[NSString class]] || directory.length == 0) {
        *statusCode = 400;
        return [self errorJSON:@"Missing \"directory\" string in body"];
    }
    NSDictionary *result = [_dataSource mcp_exportPreviewLayerScreenshotsToDirectory:directory];
    if (!result) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview available"];
    }
    if (result[@"error"]) {
        *statusCode = 400;
        return [self errorJSON:result[@"error"]];
    }
    *statusCode = 200;
    return [self successJSON:result];
}

- (NSData *)handlePreviewLighting:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_iosPreviewLighting)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *info = [_dataSource mcp_iosPreviewLighting];
    if (!info) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview available"];
    }
    *statusCode = 200;
    return [self successJSON:info];
}

- (NSData *)handlePreviewSceneGraph:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_iosPreviewSceneGraph)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *graph = [_dataSource mcp_iosPreviewSceneGraph];
    if (!graph) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview available"];
    }
    *statusCode = 200;
    return [self successJSON:graph];
}

- (NSData *)handlePreviewTextureSources:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_iosPreviewTextureSources)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *info = [_dataSource mcp_iosPreviewTextureSources];
    if (!info) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview available"];
    }
    *statusCode = 200;
    return [self successJSON:info];
}

- (NSData *)handlePreviewScreenshot:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_iosPreviewScreenshotPNG)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSData *png = [_dataSource mcp_iosPreviewScreenshotPNG];
    if (!png.length) {
        *statusCode = 503;
        return [self errorJSON:@"No iOS preview screenshot available"];
    }
    *statusCode = 200;
    return [self successJSON:@{
        @"imageBase64": [png base64EncodedStringWithOptions:0],
        @"mimeType": @"image/png",
        @"width": @640,
        @"height": @480,
    }];
}

- (NSData *)handleClientState:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_clientState)]) {
        *statusCode = 501;
        return [self errorJSON:@"Not implemented by this version"];
    }
    NSDictionary *state = [_dataSource mcp_clientState];
    if (!state) {
        *statusCode = 503;
        return [self errorJSON:@"No client state available (hierarchy not loaded)"];
    }
    *statusCode = 200;
    return [self successJSON:state];
}

#pragma mark - Inspector parity (ObjC fallback + Swift snapshot)

- (nullable NSString *)rawClassNameForObject:(nullable NSObject *)obj {
    if (!obj) return nil;
    if ([obj respondsToSelector:LKOsAppMCPSelRawClassName()]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id name = [obj performSelector:LKOsAppMCPSelRawClassName()];
#pragma clang diagnostic pop
        if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
            return (NSString *)name;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)ivarNamesForObject:(nullable NSObject *)obj {
    if (!obj) return @[];
    id traces = [self kvc:obj key:@"ivarTraces"];
    if (![traces isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSObject *trace in (NSArray *)traces) {
        NSString *name = (NSString *)[self kvc:trace key:@"ivarName"];
        if (![name isKindOfClass:[NSString class]] || name.length == 0) continue;
        if ([seen containsObject:name]) continue;
        [seen addObject:name];
        [names addObject:name];
    }
    [names sortUsingSelector:@selector(compare:)];
    return names;
}

- (NSString *)titleForDisplayItem:(NSObject *)item {
    NSObject *customInfo = [self kvc:item key:@"customInfo"];
    if (customInfo) {
        NSString *title = (NSString *)[self kvc:customInfo key:@"title"];
        if ([title isKindOfClass:[NSString class]] && title.length > 0) return title;
    }
    NSString *customTitle = (NSString *)[self kvc:item key:@"customDisplayTitle"];
    if ([customTitle isKindOfClass:[NSString class]] && customTitle.length > 0) return customTitle;
    NSString *viewName = [self rawClassNameForObject:[self kvc:item key:@"viewObject"]];
    if (viewName.length > 0) return viewName;
    NSString *layerName = [self rawClassNameForObject:[self kvc:item key:@"layerObject"]];
    return layerName ?: @"";
}

- (nullable NSString *)subtitleForDisplayItem:(NSObject *)item {
    NSObject *customInfo = [self kvc:item key:@"customInfo"];
    if (customInfo) {
        NSString *subtitle = (NSString *)[self kvc:customInfo key:@"subtitle"];
        return ([subtitle isKindOfClass:[NSString class]] && subtitle.length > 0) ? subtitle : nil;
    }
    NSString *hostName = [self rawClassNameForObject:[self kvc:item key:@"hostViewControllerObject"]];
    if (hostName.length > 0) {
        return [NSString stringWithFormat:@"%@.view", hostName];
    }
    NSObject *viewObj = [self kvc:item key:@"viewObject"];
    NSObject *layerObj = [self kvc:item key:@"layerObject"];
    NSObject *represented = viewObj ?: layerObj;
    if (!represented) return nil;
    NSString *specialTrace = (NSString *)[self kvc:represented key:@"specialTrace"];
    if ([specialTrace isKindOfClass:[NSString class]] && specialTrace.length > 0) {
        return specialTrace;
    }
    NSArray<NSString *> *ivarNames = [self ivarNamesForObject:represented];
    if (ivarNames.count > 0) {
        return [ivarNames componentsJoinedByString:@"   "];
    }
    return nil;
}

- (id)rgbaArrayForBackgroundColorOnItem:(NSObject *)item {
    id color = [self kvc:item key:@"backgroundColor"];
    if (!color) return [NSNull null];
    id rgba = nil;
    @try {
        rgba = [color valueForKey:@"lookin_rgbaComponents"];
    } @catch (__unused NSException *e) {
        return [NSNull null];
    }
    if (![rgba isKindOfClass:[NSArray class]]) return [NSNull null];
    NSMutableArray *nums = [NSMutableArray array];
    for (id n in (NSArray *)rgba) {
        if ([n isKindOfClass:[NSNumber class]]) [nums addObject:n];
    }
    return nums.count >= 4 ? nums : (id)[NSNull null];
}

- (NSDictionary *)parityFieldsForItem:(NSObject *)item indentLevel:(NSInteger)indentLevel {
    NSObject *viewObj = [self kvc:item key:@"viewObject"];
    NSObject *layerObj = [self kvc:item key:@"layerObject"];
    NSObject *represented = viewObj ?: layerObj;
    id displaying = [self kvc:item key:@"displayingInHierarchy"];
    BOOL displayingInHierarchy = ![displaying isKindOfClass:[NSNumber class]] || [(NSNumber *)displaying boolValue];
    id expandable = [self kvc:item key:@"isExpandable"];
    id expanded = [self kvc:item key:@"isExpanded"];
    id soloShot = [self kvc:item key:@"soloScreenshot"];
    id groupShot = [self kvc:item key:@"groupScreenshot"];
    return @{
        @"oid": @([self oidForItem:item]),
        @"title": [self titleForDisplayItem:item] ?: @"",
        @"subtitle": [self subtitleForDisplayItem:item] ?: @"",
        @"specialTrace": [self kvc:represented key:@"specialTrace"] ?: @"",
        @"ivarNames": [self ivarNamesForObject:represented],
        @"memoryAddress": [self kvc:represented key:@"memoryAddress"] ?: @"",
        @"backgroundColorRGBA": [self rgbaArrayForBackgroundColorOnItem:item],
        @"indentLevel": @(indentLevel),
        @"displayingInHierarchy": @(displayingInHierarchy),
        @"isExpandable": @([expandable isKindOfClass:[NSNumber class]] ? [(NSNumber *)expandable boolValue] : NO),
        @"isExpanded": @([expanded isKindOfClass:[NSNumber class]] ? [(NSNumber *)expanded boolValue] : NO),
        @"hasSoloScreenshot": @(soloShot != nil),
        @"hasGroupScreenshot": @(groupShot != nil),
    };
}

- (void)flattenParityTree:(NSArray *)items indentLevel:(NSInteger)indentLevel into:(NSMutableArray *)out {
    for (NSObject *item in items) {
        id displaying = [self kvc:item key:@"displayingInHierarchy"];
        if (![displaying isKindOfClass:[NSNumber class]] || [(NSNumber *)displaying boolValue]) {
            [out addObject:[self parityFieldsForItem:item indentLevel:indentLevel]];
        }
        id subitems = [self kvc:item key:@"subitems"];
        if ([subitems isKindOfClass:[NSArray class]] && [(NSArray *)subitems count] > 0) {
            [self flattenParityTree:(NSArray *)subitems indentLevel:indentLevel + 1 into:out];
        }
    }
}

- (BOOL)macRowBoolProperty:(NSView *)view key:(NSString *)key {
    id val = [self kvc:view key:key];
    if ([val isKindOfClass:[NSNumber class]]) return [(NSNumber *)val boolValue];
    if ([key isEqualToString:@"isSelected"]) {
        val = [self kvc:view key:@"_lookinSelected"];
        if ([val isKindOfClass:[NSNumber class]]) return [(NSNumber *)val boolValue];
    }
    if ([key isEqualToString:@"isHovered"]) {
        val = [self kvc:view key:@"_lookinHovered"];
        if ([val isKindOfClass:[NSNumber class]]) return [(NSNumber *)val boolValue];
    }
    if ([view respondsToSelector:NSSelectorFromString(key)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id result = [view performSelector:NSSelectorFromString(key)];
#pragma clang diagnostic pop
        if ([result isKindOfClass:[NSNumber class]]) return [(NSNumber *)result boolValue];
    }
    return NO;
}

- (void)collectHierarchyMacRowsInView:(NSView *)view rowIndex:(NSUInteger *)rowIndex into:(NSMutableArray *)rows {
    if (!view) return;
    NSString *className = NSStringFromClass([view class]);
    if (LookinMCPClassNameMatches(className, @"LKHierarchyRowView")) {
        NSObject *item = [self kvc:view key:@"displayItem"];
        if (item) {
            NSMutableDictionary *row = [[self parityFieldsForItem:item indentLevel:0] mutableCopy];
            row[@"row"] = @(*rowIndex);
            row[@"macIsSelected"] = @([self macRowBoolProperty:view key:@"isSelected"]);
            row[@"macIsHovered"] = @([self macRowBoolProperty:view key:@"isHovered"]);
            NSView *subtitleLabel = (NSView *)[self kvc:view key:@"subtitleLabel"];
            if ([subtitleLabel isKindOfClass:[NSView class]]) {
                row[@"subtitleLabelHidden"] = @(subtitleLabel.isHidden);
            }
            [rows addObject:row];
            (*rowIndex)++;
        }
    }
    for (NSView *sub in view.subviews) {
        [self collectHierarchyMacRowsInView:sub rowIndex:rowIndex into:rows];
    }
}

- (NSArray *)collectHierarchyMacRows {
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger rowIndex = 0;
    for (NSWindow *win in [NSApp windows]) {
        [self collectHierarchyMacRowsInView:win.contentView rowIndex:&rowIndex into:rows];
    }
    return rows;
}

- (NSDictionary *)selectionParityFieldsForOid:(NSUInteger)selectedOid
                                       tree:(NSArray *)tree
                                    macRows:(NSArray *)macRows {
    NSDictionary *match = nil;
    for (NSDictionary *entry in tree) {
        if ([entry[@"oid"] unsignedIntegerValue] == selectedOid) {
            match = entry;
            break;
        }
    }
    NSMutableDictionary *selection = match ? [match mutableCopy] : [NSMutableDictionary dictionary];
    if (!match) {
        selection[@"oid"] = @(selectedOid);
        selection[@"title"] = @"";
        selection[@"subtitle"] = @"";
        selection[@"specialTrace"] = @"";
        selection[@"ivarNames"] = @[];
        selection[@"backgroundColorRGBA"] = [NSNull null];
    }
    BOOL macSelected = NO;
    for (NSDictionary *row in macRows) {
        if ([row[@"oid"] unsignedIntegerValue] == selectedOid && [row[@"macIsSelected"] boolValue]) {
            macSelected = YES;
            break;
        }
    }
    selection[@"macRowIsSelected"] = @(macSelected);
    return selection;
}

- (NSDictionary *)buildInspectorParityFallbackSnapshot {
    NSString *uiMode = @"unknown";
    NSUInteger selectedOid = 0;
    if ([_dataSource respondsToSelector:@selector(mcp_inspectorUIState)]) {
        NSDictionary *ui = [_dataSource mcp_inspectorUIState];
        if ([ui isKindOfClass:[NSDictionary class]]) {
            NSString *mode = ui[@"uiMode"];
            if ([mode isKindOfClass:[NSString class]] && mode.length > 0) uiMode = mode;
            selectedOid = [ui[@"selectedOid"] unsignedIntegerValue];
        }
    }
    if (selectedOid == 0 && [_dataSource respondsToSelector:@selector(mcp_clientState)]) {
        NSDictionary *client = [_dataSource mcp_clientState];
        if ([client isKindOfClass:[NSDictionary class]]) {
            selectedOid = [client[@"selectedOid"] unsignedIntegerValue];
            NSString *mode = client[@"uiMode"];
            if ([mode isKindOfClass:[NSString class]] && mode.length > 0) uiMode = mode;
        }
    }

    NSObject *info = [_dataSource mcp_currentHierarchyInfo];
    NSArray *roots = @[];
    if (info) {
        id displayItems = [self kvc:info key:@"displayItems"];
        if ([displayItems isKindOfClass:[NSArray class]]) roots = (NSArray *)displayItems;
    }

    NSMutableArray *tree = [NSMutableArray array];
    [self flattenParityTree:roots indentLevel:0 into:tree];
    NSArray *macRows = [self collectHierarchyMacRows];
    NSUInteger selectedMacCount = 0;
    for (NSDictionary *row in macRows) {
        if ([row[@"macIsSelected"] boolValue]) selectedMacCount++;
    }

    NSMutableDictionary *preview = [NSMutableDictionary dictionary];
    if ([_dataSource respondsToSelector:@selector(mcp_iosPreviewTextureSources)]) {
        NSDictionary *tex = [_dataSource mcp_iosPreviewTextureSources];
        if ([tex isKindOfClass:[NSDictionary class]]) {
            preview[@"items"] = tex[@"items"] ?: @[];
            preview[@"displayItemNodesCount"] = tex[@"displayItemNodesCount"] ?: @([(NSArray *)(tex[@"items"] ?: @[]) count]);
        }
    }
    if (!preview[@"items"]) {
        preview[@"items"] = @[];
        preview[@"displayItemNodesCount"] = @0;
    }

    NSDictionary *selection = [self selectionParityFieldsForOid:selectedOid tree:tree macRows:macRows];
    return @{
        @"schemaVersion": @1,
        @"uiMode": uiMode,
        @"flatItemsCount": @(tree.count),
        @"displayingFlatItemsCount": @(tree.count),
        @"selection": selection,
        @"hierarchyTree": tree,
        @"hierarchyMacRows": macRows,
        @"hierarchyMacSelectedRowCount": @(selectedMacCount),
        @"preview": preview,
        @"dashboard": @{
            @"selectedOid": @(selectedOid),
            @"attributes": @[],
            @"attributeCount": @0,
        },
        @"paritySource": @"handler_fallback",
    };
}

- (NSData *)handleInspectorParity:(NSInteger *)statusCode {
    NSDictionary *snapshot = nil;
    if ([_dataSource respondsToSelector:@selector(mcp_inspectorParitySnapshot)]) {
        snapshot = [_dataSource mcp_inspectorParitySnapshot];
    }
    if (![snapshot isKindOfClass:[NSDictionary class]] || snapshot.count == 0) {
        if (![_dataSource respondsToSelector:@selector(mcp_currentHierarchyInfo)]) {
            *statusCode = 501;
            return [self errorJSON:@"Data source does not implement hierarchy snapshot"];
        }
        NSObject *info = [_dataSource mcp_currentHierarchyInfo];
        if (!info) {
            *statusCode = 503;
            return [self errorJSON:@"No inspector parity snapshot (connect iOS app and open inspector)"];
        }
        snapshot = [self buildInspectorParityFallbackSnapshot];
    }
    *statusCode = 200;
    return [self successJSON:snapshot];
}

- (NSData *)handleOpenInspector:(NSInteger *)statusCode {
    if (![_dataSource respondsToSelector:@selector(mcp_openInspectorForAutomation)]) {
        *statusCode = 501;
        return [self errorJSON:@"Data source does not implement mcp_openInspectorForAutomation"];
    }
    [_dataSource mcp_openInspectorForAutomation];
    *statusCode = 200;
    return [self successJSON:@{@"started": @YES}];
}

- (BOOL)sendSyntheticClickAtPoint:(CGPoint)pointInWindow
                           onView:(NSView *)hitView
                         inWindow:(NSWindow *)window {
    if ([hitView respondsToSelector:LKOsAppMCPSelTriggerClickAction()]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [hitView performSelector:LKOsAppMCPSelTriggerClickAction()];
#pragma clang diagnostic pop
        NSLog(@"[LookinMCP] triggerClickAction %@", NSStringFromClass([hitView class]));
        return YES;
    }

    NSView *view = hitView;
    while (view) {
        if ([view isKindOfClass:[NSControl class]]) {
            NSControl *control = (NSControl *)view;
            if ([control isEnabled] && !control.isHidden) {
                [control performClick:nil];
                NSLog(@"[LookinMCP] performClick %@ at (%.1f, %.1f)",
                      NSStringFromClass([control class]), pointInWindow.x, pointInWindow.y);
                return YES;
            }
        }
        view = view.superview;
    }

    view = hitView;
    while (view) {
        if ([view respondsToSelector:@selector(mouseDown:)] &&
            [view respondsToSelector:@selector(mouseUp:)]) {
            CGPoint loc = [view convertPoint:pointInWindow fromView:nil];
            NSEvent *down = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                               location:pointInWindow
                                          modifierFlags:0
                                              timestamp:[NSDate timeIntervalSinceReferenceDate]
                                           windowNumber:window.windowNumber
                                                context:nil
                                            eventNumber:0
                                             clickCount:1
                                               pressure:1.0];
            NSEvent *up = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp
                                             location:pointInWindow
                                        modifierFlags:0
                                            timestamp:[NSDate timeIntervalSinceReferenceDate]
                                         windowNumber:window.windowNumber
                                              context:nil
                                          eventNumber:0
                                           clickCount:1
                                             pressure:0.0];
            [view mouseDown:down];
            [view mouseUp:up];
            NSLog(@"[LookinMCP] mouseDown/Up %@ local (%.1f, %.1f) window (%.1f, %.1f)",
                  NSStringFromClass([view class]), loc.x, loc.y, pointInWindow.x, pointInWindow.y);
            return YES;
        }
        view = view.superview;
    }
    return NO;
}

// MARK: - Helpers

- (nullable id)kvc:(nullable NSObject *)obj key:(NSString *)key {
    if (!obj) return nil;
    @try { return [obj valueForKey:key]; }
    @catch (...) { return nil; }
}

- (NSData *)successJSON:(id)data {
    NSDictionary *d = @{@"success": @YES, @"data": data};
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil] ?: [NSData data];
}

- (NSData *)errorJSON:(NSString *)message {
    NSDictionary *d = @{@"success": @NO, @"error": message};
    return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil] ?: [NSData data];
}

@end
