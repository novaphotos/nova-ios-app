//
//  SSTheme.h
//  NovaCamera
//
//  Created by Mike Matz on 1/28/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Provide a mechanism for styling various interface components, using
 * appearance proxies and
 */
@interface SSTheme : NSObject

/**
 * Singleton accessor; if this were a class cluster, presumably we'd have
 * a mechanism for switching themes.
 */
+ (SSTheme *)currentTheme;

///----------------------
/// @name Font management
///----------------------

/**
 * Default font used throughout theme
 */
- (NSString *)defaultFontName;


/**
 * Update fonts for UILabels, UITextViews, and UITextFields to the specified font name
 */
- (void)updateFontsInView:(UIView *)view withFontNamed:(NSString *)fontName includeSubviews:(BOOL)includeSubviews;

/**
 * Update fonts for UILabels, UITextViews, and UITextFields to the default theme font
 */
- (void)updateFontsInView:(UIView *)view includeSubviews:(BOOL)includeSubviews;


@end
