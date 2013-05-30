#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "../Flipswitch/Flipswitch.h"

@interface ISIconSupport : NSObject
+ (id)sharedInstance;
- (BOOL)addExtension:(NSString *)extension;
@end

#define kIdentifierPrefix @"com.rpetrich.switchicon-"

@interface SBLeafIcon : SBIcon
- (id)initWithLeafIdentifier:(NSString *)leafIdentifier;
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

static NSBundle *templateBundle;

%subclass SBSwitchIcon : SBLeafIcon

%new
- (id)initWithSwitchIdentifier:(NSString *)switchIdentifier
{
	if ((self = [self initWithLeafIdentifier:[kIdentifierPrefix stringByAppendingString:switchIdentifier]])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_switchStateChanged:) name:FSSwitchPanelSwitchStateChangedNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig();
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
	return [switchPanel imageOfSwitchState:[switchPanel stateForSwitchIdentifier:switchIdentifier] controlState:UIControlStateNormal forSwitchIdentifier:switchIdentifier usingTemplate:templateBundle];
}

- (UIImage *)generateIconImage:(int)image
{
	FSSwitchPanel *switchPanel = [FSSwitchPanel sharedPanel];
	NSString *switchIdentifier = [self switchIdentifier];
	return [switchPanel imageOfSwitchState:[switchPanel stateForSwitchIdentifier:switchIdentifier] controlState:UIControlStateNormal forSwitchIdentifier:switchIdentifier usingTemplate:templateBundle];
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
	templateBundle = [[NSBundle alloc] initWithPath:isPad ? @"/Library/Application Support/SwitchIcons/IconTemplate~ipad.bundle" : @"/Library/Application Support/SwitchIcons/IconTemplate.bundle"];
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
	// Register with IconSupport.
	dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_NOW);
	[(ISIconSupport *)[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"switchicons"];
	[pool release];
}
