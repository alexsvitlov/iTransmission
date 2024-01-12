//
//  WebViewController.m
//  iTransmission
//
//  Created by Beecher Adams on 4/25/17.
//
//

#import "WebViewController.h"
#import "TorrentViewController.h"

static NSString * const TransmissionWebViewURLKey = @"URL";
static NSString * const TransmissionWebViewLoadingKey = @"loading";

@interface WebViewController ()

@property (nonatomic, assign) BOOL shouldStartLoadingWasCalled;
@property (nonatomic, assign) BOOL didStartLoadingCalled;

@end

@implementation WebViewController

@synthesize currentURL;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationController setToolbarHidden:YES animated:NO];
    
    self.wkWebView.allowsBackForwardNavigationGestures = YES;
    self.wkWebView.navigationDelegate = self;
    self.wkWebView.allowsLinkPreview = NO;
    
    [self _registerForWKWebViewKVO];
    
    // load current url
    [self.wkWebView loadRequest:[NSURLRequest requestWithURL:self.currentURL]];
}

-(IBAction)goBackClicked:(UIBarButtonItem *)sender
{
    [self.wkWebView goBack];
}

-(IBAction)closeClicked:(UIBarButtonItem *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)setData:(NSString *)url controller:(AppDelegate *)libtransmission
{
    [self loadURL:[NSURL URLWithString:url]];
    self.transmission = libtransmission;
}

- (void)loadURL:(NSURL *)pageURL {
    self.currentURL = pageURL;
    [self.wkWebView loadRequest:[NSURLRequest requestWithURL:pageURL]];
}

#pragma mark - View lifecycle

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self _unregisterFromWKWebViewKVO];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return YES;
    
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)_registerForWKWebViewKVO {
    [self.wkWebView addObserver:self forKeyPath:TransmissionWebViewURLKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.wkWebView addObserver:self forKeyPath:TransmissionWebViewLoadingKey options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)_unregisterFromWKWebViewKVO {
    [self.wkWebView removeObserver:self forKeyPath:TransmissionWebViewURLKey];
    [self.wkWebView removeObserver:self forKeyPath:TransmissionWebViewLoadingKey];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object != self.wkWebView) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    [self _callWebViewDidStartLoadIfNeeded];
    
    if ([keyPath isEqualToString:TransmissionWebViewLoadingKey]){
        [self _callWebViewDidFinishWithSuccess];
    }
    else if ([keyPath isEqualToString:TransmissionWebViewURLKey]) {
        [self _callWebViewDidFinishWithSuccess];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_callWebViewDidStartLoadIfNeeded {
    if (self.wkWebView.isLoading && self.shouldStartLoadingWasCalled && !self.didStartLoadingCalled) {
        self.didStartLoadingCalled = YES;
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    }
}

- (void)_callWebViewDidFinishWithSuccess {
    if (!self.wkWebView.isLoading && self.wkWebView.estimatedProgress == 1) {
        [self _resetFlags];
        
        // set current url
        self.URLTextfield.text = self.wkWebView.URL.absoluteString;
        self.currentURL = self.wkWebView.URL;
    }
}

- (void)_resetFlags {
    self.shouldStartLoadingWasCalled = NO;
    self.didStartLoadingCalled = NO;
}

//- (void)webViewDidStartLoad:(UIWebView *)webView {
//    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
//}
//
//- (void)webViewDidFinishLoad:(UIWebView *)web
//{
//    // set current url
//    self.URLTextfield.text = web.request.URL.absoluteString;
//    self.currentURL = web.request.URL;
//}
//
//- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
//{
//    NSURL *requestedURL = [request URL];
//    NSString *scheme = [requestedURL scheme];
//    NSString *fileExtension = [requestedURL pathExtension];
//    NSString *torrent;
//    
//    if(navigationType == UIWebViewNavigationTypeLinkClicked)
//    {
//        // make network icon visible
//        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
//        
//        if([scheme isEqualToString:@"magnet"] || [fileExtension isEqualToString:@"torrent"]) {
//            torrent = [requestedURL absoluteString];
//            
//            // add torrent
//            [self.transmission openURL:torrent];
//            
//            // close view controller
//            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
//        }
//    }
//    
//    return YES;
//}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
        
    NSURL *requestedURL = [navigationAction.request URL];
    NSString *scheme = [requestedURL scheme];
    NSString *fileExtension = [requestedURL pathExtension];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    if(navigationAction.navigationType == WKNavigationTypeLinkActivated && ([scheme isEqualToString:@"magnet"] || [fileExtension isEqualToString:@"torrent"])) {
        NSString *torrent = [requestedURL absoluteString];
        
        // add torrent
        [self.transmission openURL:torrent];
        
        // close view controller
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        
        decisionHandler(WKNavigationActionPolicyCancel);

        return;
    }
    
    self.shouldStartLoadingWasCalled = YES;
    self.didStartLoadingCalled = NO;
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {

    NSURL *responseURL = [navigationResponse.response URL];
    NSString *fileExtension = [responseURL pathExtension];
    
    if ([fileExtension isEqualToString:@"torrent"] || [navigationResponse.response.MIMEType containsString:@"torrent"]) {
        NSString *torrent = [responseURL absoluteString];
        
        // add torrent
        [self.transmission openURL:torrent];
        
        // close view controller
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        
        decisionHandler(WKNavigationResponsePolicyCancel);
        
        return;

    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self _resetFlags];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self _resetFlags];
}


@end
