#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <CaptainHook/CaptainHook.h>
#import "../Flipswitch/Flipswitch.h"

@interface ISIconSupport : NSObject
+ (id)sharedInstance;
- (BOOL)addExtension:(NSString *)extension;
@end

#define kIdentifierPrefix @"com.rpetrich.switchicon-"

@interface SBLeafIcon : SBIcon
- (id)initWithLeafIdentifier:(NSString *)leafIdentifier;
- (id)initWithLeafIdentifier:(NSString *)leafIdentifier applicationBundleID:(NSString *)bundleIdentifier;
- (NSString *)leafIdentifier;
- (void)reloadIconImagePurgingImageCache:(BOOL)purgingImageCache;
@end

@interface SBSwitchIcon : SBLeafIcon
- (NSString *)switchIdentifier;
- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier;
@end

@interface SBIconModel (iOS5)
- (void)addIcon:(SBIcon *)icon;
- (void)removeIconForIdentifier:(NSString *)identifier;
@end

@interface SBIconController (iOS5)
- (void)addNewIconToDesignatedLocation:(SBIcon *)icon animate:(BOOL)animate scrollToList:(BOOL)scrollToList saveIconState:(BOOL)saveIconState;
@end

@interface SBIconView : UIView
@property (nonatomic, readonly) id icon;
- (UIImageView *)_iconImageView;
@end

@interface SBSwitchIconView : SBIconView
@end

@interface SBIconImageView (iOS7)
@property (nonatomic, retain) SBIcon *icon;
@end

@interface SBSwitchIconImageView : SBIconImageView
@end

@interface SBFolderIconBackgroundView : UIView
- (id)initWithDefaultSize;
- (void)setWallpaperRelativeCenter:(CGPoint)wallpaperRelativeCenter;
@end

@implementation NSObject (SwitchIcons)

- (BOOL)isSwitchIcon
{
	return NO;
}

@end

static NSBundle *templateBundle;

%subclass SBSwitchIcon : SBLeafIcon

%group iOS5

%new
- (id)initWithLeafIdentifier:(NSString *)leafIdentifier
{
	if ((self = [self init])) {
		objc_setAssociatedObject(self, @selector(leafIdentifier), leafIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
	}
	return self;
}

%new
- (NSString *)leafIdentifier
{
	return objc_getAssociatedObject(self, @selector(leafIdentifier));
}

%end


%new
- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *leafIdentifier = [kIdentifierPrefix stringByAppendingString:switchIdentifier];
	if ([self respondsToSelector:@selector(initWithLeafIdentifier:applicationBundleID:)]) {
		self = [self initWithLeafIdentifier:leafIdentifier applicationBundleID:nil];
	} else {
		self = [self initWithLeafIdentifier:leafIdentifier];
	}
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_switchStateChanged:) name:FSSwitchPanelSwitchStateChangedNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig();
}

- (BOOL)isSwitchIcon
{
	return YES;
}

%new
- (NSString *)switchIdentifier
{
	return [[self leafIdentifier] substringFromIndex:24];
}

- (UIImage *)getGenericIconImage:(int)image
{
	FSSwitchPanel *switchPanel = [FSSwitchPanel sharedPanel];
	NSString *switchIdentifier = [self switchIdentifier];
	return [switchPanel imageOfSwitchState:[switchPanel stateForSwitchIdentifier:switchIdentifier] controlState:[switchPanel switchWithIdentifierIsEnabled:switchIdentifier] ? UIControlStateNormal : UIControlStateDisabled forSwitchIdentifier:switchIdentifier usingTemplate:templateBundle];
}

- (UIImage *)generateIconImage:(int)image
{
	FSSwitchPanel *switchPanel = [FSSwitchPanel sharedPanel];
	NSString *switchIdentifier = [self switchIdentifier];
	return [switchPanel imageOfSwitchState:[switchPanel stateForSwitchIdentifier:switchIdentifier] controlState:[switchPanel switchWithIdentifierIsEnabled:switchIdentifier] ? UIControlStateNormal : UIControlStateDisabled forSwitchIdentifier:switchIdentifier usingTemplate:templateBundle];
}

%new
- (void)_switchStateChanged:(NSNotification *)notification
{
	if ([[notification.userInfo objectForKey:FSSwitchPanelSwitchIdentifierKey] isEqual:[self switchIdentifier]]) {
		[self reloadIconImagePurgingImageCache:YES];
	}
}

- (void)launchFromViewSwitcher
{
	[[FSSwitchPanel sharedPanel] applyActionForSwitchIdentifier:[self switchIdentifier]];
}

- (void)launch
{
	[[FSSwitchPanel sharedPanel] applyActionForSwitchIdentifier:[self switchIdentifier]];
}

- (void)launchFromLocation:(int)location
{
	[[FSSwitchPanel sharedPanel] applyActionForSwitchIdentifier:[self switchIdentifier]];
}

- (BOOL)launchEnabled
{
	return YES;
}

- (NSString *)displayName
{
	return [[FSSwitchPanel sharedPanel] titleForSwitchIdentifier:[self switchIdentifier]];
}

- (BOOL)canEllipsizeLabel
{
	return NO;
}

- (NSString *)folderFallbackTitle
{
	return @"Switches";
}

- (NSString *)applicationBundleID
{
	return [@"switchicons-fix-for-ios7-crash-" stringByAppendingString:[self switchIdentifier]];
}

- (Class)iconViewClassForLocation:(int)location
{
	return %c(SBSwitchIconView);
}

- (Class)iconImageViewClassForLocation:(int)location
{
	return %c(SBSwitchIconImageView);
}

%end

%subclass SBSwitchIconView : SBIconView

- (NSString *)accessibilityValue
{
	switch ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:[self.icon switchIdentifier]]) {
		case FSSwitchStateOff:
			return @"Off";
		case FSSwitchStateOn:
			return @"On";
		default:
			return nil;
	}
}

- (NSString *)accessibilityHint
{
	switch ([[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:[self.icon switchIdentifier]]) {
		case FSSwitchStateOff:
		case FSSwitchStateOn:
			return @"Double tap to switch";
		default:
			return %orig();
	}
}

- (void)setHighlighted:(BOOL)highlighted delayUnhighlight:(BOOL)delayUnhighlight
{
	if (highlighted) {
		if (![[FSSwitchPanel sharedPanel] switchWithIdentifierIsEnabled:[self.icon switchIdentifier]]) {
			highlighted = NO;
		}
	}
	if (!highlighted && delayUnhighlight && [[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:[self.icon switchIdentifier]] != FSSwitchStateIndeterminate)
		delayUnhighlight = NO;
	%orig();
}

- (id)initWithDefaultSize
{
	if ((self = %orig())) {
		SBFolderIconBackgroundView *backgroundView = [[%c(SBFolderIconBackgroundView) alloc] initWithDefaultSize];
		objc_setAssociatedObject(self, &templateBundle, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[self addSubview:backgroundView];
		[backgroundView release];
	}
	return self;
}

- (void)_updateAdaptiveColors
{
	%orig();
	CGPoint *_wallpaperRelativeImageCenter = CHIvarRef(self, _wallpaperRelativeImageCenter, CGPoint);
	if (_wallpaperRelativeImageCenter) {
		SBFolderIconBackgroundView *backgroundView = objc_getAssociatedObject(self, &templateBundle);
		[backgroundView setWallpaperRelativeCenter:*_wallpaperRelativeImageCenter];
	}
}

- (void)_updateIconImageViewAnimated:(BOOL)animated
{
	%orig();
}

%end

%subclass SBSwitchIconImageView : SBIconImageView

- (void)updateImageAnimated:(BOOL)animated
{
	%orig();
	[[FSSwitchPanel sharedPanel] applyEffectsToLayer:self.layer forSwitchState:[[FSSwitchPanel sharedPanel] stateForSwitchIdentifier:[(SBSwitchIcon *)self.icon switchIdentifier]] controlState:UIControlStateNormal usingTemplate:templateBundle];
}

%end

%hook SBIconController

- (Class)viewMap:(id)map iconViewClassForIcon:(SBIcon *)icon
{
	if ([icon isSwitchIcon])
		return %c(SBSwitchIconView);
	return %orig();
}

%end

%hook SBIconModel

static BOOL hasRegistered;
static NSArray *loadedSwitchIdentifiers;

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig();
}

- (void)loadAllIcons
{
	%orig();
	BOOL isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
	NSString *path;
	if (kCFCoreFoundationVersionNumber >= 800.0) {
		path = isPad ? @"/Library/Application Support/SwitchIcons/IconTemplate-ios7~ipad.bundle" : @"/Library/Application Support/SwitchIcons/IconTemplate-ios7.bundle";
	} else {
		path = isPad ? @"/Library/Application Support/SwitchIcons/IconTemplate~ipad.bundle" : @"/Library/Application Support/SwitchIcons/IconTemplate.bundle";
	}
	templateBundle = [[NSBundle alloc] initWithPath:path];
	[FSSwitchPanel sharedPanel];
	NSArray *newSwitchIdentifiers = [[FSSwitchPanel sharedPanel].switchIdentifiers copy];
	[loadedSwitchIdentifiers release];
	loadedSwitchIdentifiers = newSwitchIdentifiers;
	for (NSString *switchIdentifier in loadedSwitchIdentifiers) {
		SBSwitchIcon *icon = [[%c(SBSwitchIcon) alloc] initWithSwitchIdentifier:switchIdentifier];
		[self addIcon:icon];
		[icon release];
	}
	if (!hasRegistered) {
		hasRegistered = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadSwitches) name:FSSwitchPanelSwitchesChangedNotification object:nil];
	}
}

%new
- (void)_reloadSwitches
{
	NSArray *newSwitchIdentifiers = [[FSSwitchPanel sharedPanel].switchIdentifiers copy];
	for (NSString *switchIdentifier in newSwitchIdentifiers) {
		if (![loadedSwitchIdentifiers containsObject:switchIdentifier]) {
			SBSwitchIcon *icon = [[%c(SBSwitchIcon) alloc] initWithSwitchIdentifier:switchIdentifier];
			[self addIcon:icon];
			[[%c(SBIconController) sharedInstance] addNewIconToDesignatedLocation:icon animate:YES scrollToList:NO saveIconState:YES]; 
			[icon release];
		}
	}
	for (NSString *switchIdentifier in loadedSwitchIdentifiers) {
		if (![newSwitchIdentifiers containsObject:switchIdentifier]) {
			[self removeIconForIdentifier:[kIdentifierPrefix stringByAppendingString:switchIdentifier]];
		}
	}
	[loadedSwitchIdentifiers release];
	loadedSwitchIdentifiers = newSwitchIdentifiers;
}

%end

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	%init();
	if (kCFCoreFoundationVersionNumber < 700.0) {
		%init(iOS5);
	}
	// Register with IconSupport.
	dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_NOW);
	[(ISIconSupport *)[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"switchicons"];
	[pool release];
}
