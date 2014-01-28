//
//  SSTheme.m
//  NovaCamera
//
//  Created by Mike Matz on 1/28/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSTheme.h"

@implementation SSTheme

+ (SSTheme *)currentTheme {
    static id _sharedTheme;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedTheme = [[SSTheme alloc] init];
    });
    return _sharedTheme;
}

#pragma mark - Font management

- (NSString *)defaultFontName {
    return @"OpenSans-Light";
}

- (void)updateFontsInView:(UIView *)view includeSubviews:(BOOL)includeSubviews {
    return [self updateFontsInView:view withFontNamed:[self defaultFontName] includeSubviews:includeSubviews];
}

- (void)updateFontsInView:(UIView *)view withFontNamed:(NSString *)fontName includeSubviews:(BOOL)includeSubviews {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        UIFont *font = [UIFont fontWithName:fontName size:label.font.pointSize];
        label.font = font;
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        textField.font = [UIFont fontWithName:fontName size:textField.font.pointSize];
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        textView.font = [UIFont fontWithName:fontName size:textView.font.pointSize];
    }
    if (includeSubviews) {
        for (UIView *subview in view.subviews) {
            [self updateFontsInView:subview withFontNamed:fontName includeSubviews:YES];
        }
    }
}

@end
