//
//  SSPrivacyPolicyViewController.m
//  NovaCamera
//
//  Created by Joe Walnes on 6/15/14.
//  Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSPrivacyPolicyViewController.h"

@implementation SSPrivacyPolicyViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    if (self) {
        
        // Ensures that "<" back button on the next screen does not show label.
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                                 style:self.navigationItem.backBarButtonItem.style
                                                                                target:nil
                                                                                action:nil];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.webView.delegate = self;

    self.webView.scrollView.bounces = NO;
    
    self.webView.alpha = 0; // Hide until loaded, so we don't see the white background
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"HtmlResources/Privacy/index" ofType:@"html"];
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - UIWebViewDelegate callbacks

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([[request.URL scheme] isEqualToString:@"file"]) {
        // Internal file links load in UIWebView
        return YES;
    } else {
        // Everything else should use the external browser
        [[UIApplication sharedApplication] openURL:request.URL];
        return NO;
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.webView.alpha = 1; // Show view now it's loaded
}



@end
