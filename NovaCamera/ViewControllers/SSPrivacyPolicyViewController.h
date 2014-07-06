//
//  SSPrivacyPolicyViewController.h
//  NovaCamera
//
//  Created by Joe Walnes on 6/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Shows privacy policy to user
 */
@interface SSPrivacyPolicyViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, strong) IBOutlet UIWebView *webView;

@end
