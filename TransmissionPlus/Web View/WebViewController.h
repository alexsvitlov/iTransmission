//
//  WebViewController.h
//  iTransmission
//
//  Created by Beecher Adams on 4/25/17.
//
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
@import WebKit;

@class TorrentViewController;

@interface WebViewController : UIViewController <WKNavigationDelegate>

- (void)setData:(NSString *)url controller:(AppDelegate *)libtransmission;

// web view
@property (nonatomic, strong) IBOutlet WKWebView *wkWebView;
@property (nonatomic, strong) NSURL *currentURL;

// disappering toolbar
@property (nonatomic, strong) IBOutlet UITextField *URLTextfield;

// lib transmission
@property (nonatomic, strong) AppDelegate *transmission;


- (void)loadURL:(NSURL*)URL;

- (IBAction) goBackClicked:(UIBarButtonItem *)sender;
- (IBAction) closeClicked:(UIBarButtonItem *)sender;

@end
