//
//  SSTheme.m
//  NovaCamera
//
//  Created by Mike Matz on 1/28/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSTheme.h"
#import <QuartzCore/QuartzCore.h>

@implementation SSTheme

+ (SSTheme *)currentTheme {
    static id _sharedTheme;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedTheme = [[SSTheme alloc] init];
    });
    return _sharedTheme;
}

- (void)styleAppearanceProxies {
    UIFont *navBarFont = [UIFont fontWithName:self.defaultFontName size:21];
    UIColor *navBarFontColor = [UIColor whiteColor];
    UIColor *navBarColor = [UIColor colorWithRed:.901 green:.404 blue:.255 alpha:1];
    
    NSDictionary *navBarTitleTextAttributes = @{
                                                NSFontAttributeName: navBarFont,
                                                NSForegroundColorAttributeName: navBarFontColor,
                                                };
    [[UINavigationBar appearance] setTitleTextAttributes:navBarTitleTextAttributes];
    [[UINavigationBar appearance] setTintColor:navBarFontColor];
    
    // Nav bar background - simulate with a fake background image
    UIView *background = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    background.backgroundColor = navBarColor;
    background.alpha = 1.0;
    background.opaque = YES;
    UIGraphicsBeginImageContext(background.frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [background.layer renderInContext:context];
    UIImage *backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [[UINavigationBar appearance] setBackgroundImage:backgroundImage
                                       forBarMetrics:UIBarMetricsDefault];

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

#pragma mark - Custom controls

- (void)styleSlider:(UISlider *)slider {
    [slider setThumbImage:[UIImage imageNamed:@"slider-thumb"] forState:UIControlStateNormal];
    
    /*
    slider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    slider.minimumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
     */
    
    UIImage *trackImage = [[UIImage imageNamed:@"slider-track"] resizableImageWithCapInsets:UIEdgeInsetsZero];
    [slider setMinimumTrackImage:trackImage forState:UIControlStateNormal];
    [slider setMaximumTrackImage:trackImage forState:UIControlStateNormal];
}

- (void)styleSwitch:(UISwitch *)aSwitch {
    // See: http://stackoverflow.com/a/20039695/72
    aSwitch.layer.cornerRadius = 16.0;
}

@end
