//
//  DDGPreferences.m
//  DDG Library
//
//  Created by Andrew Donoho on 2010/02/09.
//  Copyright 2010-2014 Donoho Design Group, L.L.C. All rights reserved.
//

/*
 
 The below license is the new BSD license with the OSI recommended 
 personalizations.
 <http://www.opensource.org/licenses/bsd-license.php>
 
 Copyright (C) 2010-2012 Donoho Design Group, LLC. All Rights Reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:
 
 * Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of Andrew W. Donoho nor Donoho Design Group, L.L.C.
 may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY DONOHO DESIGN GROUP, L.L.C. "AS IS" AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

#if !__has_feature(objc_arc)
#  warning Please compile this class with ARC (-fobjc-arc).
#endif

#import <objc/runtime.h>

#import "DDGPreferences.h"

static bool
supportedPropName(const char *propName)
{
    
    return (strcmp(propName, "hash") != 0 &&
            strcmp(propName, "dirty") != 0 &&
            strcmp(propName, "blockingNotifications") != 0 &&
            strcmp(propName, "superclass") != 0 &&
            strcmp(propName, "settingsKeys") != 0 &&
            strcmp(propName, "description") != 0 &&
            strcmp(propName, "debugDescription") != 0);
}

@interface DDGPreferences ()

@property (getter = isDirty, readwrite, nonatomic) BOOL dirty;
@property (readonly, nonatomic) NSArray *settingsKeys;

- (void) observeProperties;
- (void) removeSelfObserver;

- (void) observeNotifications;

- (void) readSettingsDefaultValues;
- (void) readPropertiesDefaultValues;

@end

@implementation DDGPreferences

@dynamic settingsKeys;

- (void) dealloc {
    
    [self removeSelfObserver];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
} // -dealloc


- (instancetype) init {
	
	self = [super init];
	
	if (self) {
		
        [self readSettingsDefaultValues];
        [self readPropertiesDefaultValues];
        
		[self readPreferences];
        
		[self observeProperties];
        [self observeNotifications];
    }
	return self;
	
} // -init


#pragma mark -
#pragma mark NSUserDefaults Methods


static NSString *const  kKey           = @"Key";
static NSString *const  kDefaultValue  = @"DefaultValue";
static NSString *const  kSettings      = @"Settings.bundle";
static NSString *const  kRoot          = @"Root.plist";
static NSString *const  kPrefSpecifier = @"PreferenceSpecifiers";
static NSString *const  kType		   = @"Type";
static NSString *const  kChildPane	   = @"PSChildPaneSpecifier";
static NSString *const  kFile		   = @"File";

- (NSMutableDictionary *) defaultSettings: (NSString *) prefList {
	// Settings are always associated with this class, Preferences.
	// Each setting is named identically to a property.
	
	NSString *path = nil;
	path = [[NSBundle mainBundle] bundlePath];
	path = [path stringByAppendingPathComponent: kSettings];
	path = [path stringByAppendingPathComponent: prefList];
	
	NSDictionary  *settingsDict = [NSDictionary dictionaryWithContentsOfFile: path];
	
	if (settingsDict) {
		
		NSArray  *prefSpecifierArray = settingsDict[kPrefSpecifier];
		
		NSMutableDictionary  *items = [NSMutableDictionary dictionaryWithCapacity: [prefSpecifierArray count]];
		
		for (NSDictionary *pref in prefSpecifierArray) {
			
			NSString *key = [pref valueForKey: kKey];
			
			if (key) {
				
				[items setValue: [pref valueForKey: kDefaultValue] forKey: key];
			} 
			else { // check to see if this is a child pane
			
				NSString *type = [pref valueForKey: kType];
				
				if ([type isEqualToString: kChildPane]) {
				
					NSString *child = [pref valueForKey: kFile];
					
					child = [child stringByAppendingString:@".plist"];
					
					[items addEntriesFromDictionary: [self defaultSettings: child]];
				}
			}
		}
		return items;
	}
	return nil;
	
} // -defaultSettings:


- (NSArray *) settingsKeys {

    return [[self defaultSettings: kRoot] allKeys];
    	
} // -settingsKeys


- (void) readSettingsDefaultValues {
	
	NSMutableDictionary *items = [self defaultSettings: kRoot];
	
	if (items.count) {
		
		NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
        const char     *className = class_getName(self.class);
        
        [defaults registerDefaults: items];
        
        for (NSString *key in items.keyEnumerator) {
            
            NSString *prefKey = [NSString.alloc initWithFormat: @"%s_%@", className, key];
            
            if (![defaults objectForKey: prefKey]) {
                
                id value = [items valueForKey: key];
                
                [self     setValue:  value forKey: key];
                [defaults setObject: value forKey: prefKey];
            }
        }
	}
	
} // -readSettingsDefaultValues


- (void) readSettings {
	
	NSArray *settingsKeys = self.settingsKeys;
	
	if (settingsKeys.count) {
		
		NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
        const char     *className = class_getName(self.class);
        
        for (NSString *key in settingsKeys) {
            
            NSString *prefKey = [NSString.alloc initWithFormat: @"%s_%@", className, key];

            id value = [defaults objectForKey: key];
            id pref  = [defaults objectForKey: prefKey];
            
            if (![value isEqual: pref]) {
                
                // Settings overwrite the preferences.
                [self     setValue:  value forKey: key];
                [defaults setObject: value forKey: prefKey];
            }
        }
	}
	
} // -readSettings


- (void) writeSettings {
	
	NSArray *keys = self.settingsKeys;
	
	if (keys.count) {
		
		NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];

        for (NSString *key in keys) {
            
            id value = [self valueForKey: key];
            id pref  = [defaults objectForKey: key];
            
            if (![value isEqual: pref]) {
            
                [defaults setObject: value forKey: key];
            }
        }
	}
	
} // -writeSettings


#pragma mark - Property Reading/Writing Methods


- (BOOL) doPreferencesExist {
	
	unsigned int     propertyCount = 0;
	objc_property_t *propertyList  = class_copyPropertyList([self class], &propertyCount);
	const char      *className     = class_getName(self.class);
	NSUserDefaults  *defaults      = [NSUserDefaults standardUserDefaults];
	
    NSArray *settingsKeys = self.settingsKeys;
    
    BOOL exists = NO;
    
	// Loop through properties.
	for (unsigned int i = 0; i < propertyCount; i++) {
		
        const char *propName = property_getName(propertyList[i]);
		NSString   *prefKey  = [NSString.alloc initWithFormat: @"%s_%s", className, propName];
        NSString   *key = [NSString.alloc initWithBytesNoCopy: (void *)propName
                                                       length: strlen( propName)
                                                     encoding: NSUTF8StringEncoding
                                                 freeWhenDone: NO];
        if (settingsKeys && ([settingsKeys indexOfObject: key] != NSNotFound)) { continue; }
        
        if ([defaults objectForKey: prefKey]) {
            
            exists = YES;
            break;
        }
	}
	free(propertyList), propertyList = NULL;
    
    return exists;
	
} // -doPreferencesExist


- (void) readPropertiesDefaultValues {
    
    if ([self respondsToSelector: kDDGPreferencesSetDefaultPreferences]) {
        
        if (!self.doPreferencesExist) {
            
            [(id<DDGPreferences>)self setDefaultPreferences];
        }
    }

} // -readPropertiesDefaultValues


- (void) setNilValueForKey: (NSString *) key {
    
} // -setNilValueForKey:


- (void) readProperties {

	unsigned int     propertyCount = 0;
	objc_property_t *propertyList  = class_copyPropertyList(self.class, &propertyCount);
	const char      *className     = class_getName(self.class);
	NSUserDefaults  *defaults      = [NSUserDefaults standardUserDefaults];

	// Loop through properties.
	for (unsigned int i = 0; i < propertyCount; i++) {

        const char *propName = property_getName(propertyList[i]);

        if (supportedPropName(propName)) {

            NSString   *prefKey  = [NSString.alloc initWithFormat: @"%s_%s", className, propName];
            NSString   *key = [NSString.alloc initWithBytesNoCopy: (void *)propName
                                                           length: strlen( propName)
                                                         encoding: NSUTF8StringEncoding
                                                     freeWhenDone: NO];
            id value = [self     valueForKey:  key];
            id pref  = [defaults objectForKey: prefKey];

            if (pref && ![value isEqual: pref]) {
                // Don't overwrite if the value doesn't exist.

                [self setValue: pref forKey: key];
            }
        }
	}
	free(propertyList), propertyList = NULL;

} // -readProperties


- (void) readPreferences {
	
	// Allow the settings to overwrite the properties.
	[self readSettings];

	[self readProperties];
    
    self.dirty = NO;
	
} // readPreferences


- (void) writeProperties {

	unsigned int     propertyCount = 0;
	objc_property_t *propertyList  = class_copyPropertyList([self class], &propertyCount);
	const char      *className     = class_getName(self.class);
	NSUserDefaults  *defaults      = [NSUserDefaults standardUserDefaults];

	// Loop through properties.
	for (unsigned int i = 0; i < propertyCount; i++) {

        const char *propName = property_getName(propertyList[i]);

        if (supportedPropName(propName)) {

            NSString   *prefKey  = [NSString.alloc initWithFormat: @"%s_%s", className, propName];
            NSString   *key = [NSString.alloc initWithBytesNoCopy: (void *)propName
                                                           length: strlen( propName)
                                                         encoding: NSUTF8StringEncoding
                                                     freeWhenDone: NO];
            id value = [self     valueForKey:  key];
            id pref  = [defaults objectForKey: prefKey];

            if (![value isEqual: pref]) {

                [defaults setObject: value forKey: prefKey];
            }
        }
	}
	free(propertyList), propertyList = NULL;

} // -writeProperties


- (void) writePreferences {
    
    [self writeProperties];
    
    [self writeSettings];

	[NSUserDefaults.standardUserDefaults synchronize];

	self.dirty = NO;
    
} // -writePreferences


#pragma mark - Self Observing KVO Methods


static void *ddgPreferencesContext = &ddgPreferencesContext;

- (void) observeValueForKeyPath: (NSString *) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary *) change 
						context: (void *) context {

    if (context == ddgPreferencesContext) {

        id<NSObject> newValue = [change valueForKey: NSKeyValueChangeNewKey];
        id<NSObject> oldValue = [change valueForKey: NSKeyValueChangeOldKey];

        if (newValue && ![newValue isEqual: oldValue]) {

            self.dirty = YES;
        }
    }

} // -observeValueForKeyPath:ofObject:change:context:


- (void) observeProperties {

	unsigned int     propertyCount = 0;
	objc_property_t *propertyList  = class_copyPropertyList([self class], &propertyCount);

	// Loop through properties.
	for (unsigned int i = 0; i < propertyCount; i++) {

        const char *propName = property_getName(propertyList[i]);

        if (supportedPropName(propName)) {
            
            NSString *name = [NSString.alloc initWithBytesNoCopy: (void *)propName
                                                          length: strlen( propName)
                                                        encoding: NSUTF8StringEncoding
                                                    freeWhenDone: NO];
            [self addObserver: self
                   forKeyPath: name
                      options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                      context: ddgPreferencesContext];
        }
	}
	free(propertyList), propertyList = NULL;

} // -observeProperties


- (void) removeSelfObserver {

	unsigned int     propertyCount = 0;
	objc_property_t *propertyList  = class_copyPropertyList([self class], &propertyCount);

	// Loop through properties.
	for (unsigned int i = 0; i < propertyCount; i++) {

        const char *propName = property_getName(propertyList[i]);

        if (supportedPropName(propName)) {

            NSString *name = [NSString.alloc initWithBytesNoCopy: (void *)propName
                                                          length: strlen( propName)
                                                        encoding: NSUTF8StringEncoding
                                                    freeWhenDone: NO];
            [self removeObserver: self forKeyPath: name context: ddgPreferencesContext];
        }
	}
	free(propertyList), propertyList = NULL;

} // -removeSelfObserver


#pragma mark - UIApplication Notifications


#define kApplicationWillTerminate  (@selector(applicationWillTerminate:))
- (void) applicationWillTerminate: (NSNotification *) notification {

    [self applicationDidEnterBackground: notification];

} // -applicationWillTerminate:


#define kApplicationDidEnterBackground  (@selector(applicationDidEnterBackground:))
- (void) applicationDidEnterBackground: (NSNotification *) notification {
	
	if (self.isDirty) {
		
		[self writePreferences];
	}
} // -applicationDidEnterBackground:


#define kUserDefaultsDidChange  (@selector(userDefaultsDidChange:))
- (void) userDefaultsDidChange: (NSNotification *) notification {

    if (!self.isDirty && !self.blockingNotifications) {
        // Only read the settings when the prefs are clean. I.e. this notification
        // is fired on every setValue on the -standardUserDefaults. Hence, let
        // the update finish before synchronizing the data. When the prefs are
        // clean, as they always are after exiting the app, then it is safe to
        // read the -standardUserDefaults upon reactivation.

        [NSUserDefaults.standardUserDefaults synchronize];

        [self readSettings];

        [NSUserDefaults.standardUserDefaults synchronize];
    }

} // -userDefaultsDidChange:

- (void)setBlockingNotifications:(BOOL)blockingNotifications
{
    _blockingNotifications = blockingNotifications;
    if (!blockingNotifications) [self userDefaultsDidChange:nil];
}

- (void) observeNotifications {

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;

    [nc removeObserver: self];

    [nc addObserver: self
           selector:  kApplicationWillTerminate
               name: UIApplicationWillTerminateNotification
             object: nil];

    [nc addObserver: self
           selector:  kApplicationDidEnterBackground
               name: UIApplicationDidEnterBackgroundNotification
             object: nil];

    [nc addObserver: self
           selector:  kUserDefaultsDidChange
               name: NSUserDefaultsDidChangeNotification
             object: NSUserDefaults.standardUserDefaults];

} // -observeNotifications;

@end
