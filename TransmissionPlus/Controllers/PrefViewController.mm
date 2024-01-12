//
//  PrefViewController.m
//  iTransmission
//
//  Created by Mike Chen on 10/3/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import "PrefViewController.h"
#import "NSDictionaryAdditions.h"
#import "AppDelegate.h"
#import "PortChecker.h"
#import <MessageUI/MessageUI.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface PrefViewController() <PortCheckerDelegate, MFMailComposeViewControllerDelegate>

@end

@implementation PrefViewController {
    UITableView *fTableView;
    
    IBOutlet UITableViewCell *fAutoPortMapCell;
    IBOutlet UITableViewCell *fBindPortCell;
    IBOutlet UITableViewCell *fBackgroundDownloadingCell;
    IBOutlet UIButton *fCheckPortButton;
    
    IBOutlet UISwitch *fAutoPortMapSwitch;
    IBOutlet UISwitch *fEnableBackgroundDownloadingSwitch;
    IBOutlet UITextField *fBindPortTextField;
    IBOutlet UIActivityIndicatorView *fPortCheckActivityIndicator;
    
    IBOutlet UILabel *fMaximumConnectionsLabel;
    IBOutlet UITableViewCell *fMaximumConnectionsLabelCell;
    IBOutlet UITextField *fMaximumConnectionsTextField;
    
    IBOutlet UITableViewCell *fConnectionsPerTorrentLabelCell;
    IBOutlet UILabel *fConnectionsPerTorrentLabel;
    IBOutlet UITextField *fConnectionsPerTorrentTextField;
    
    IBOutlet UITableViewCell *fDownloadSpeedLimitCell;
    IBOutlet UITextField *fDownloadSpeedLimitField;
    
    IBOutlet UITableViewCell *fUploadSpeedLimitCell;
    IBOutlet UITextField *fUploadSpeedLimitField;
    
    IBOutlet UITableViewCell *fUploadSpeedLimitEnabledCell;
    IBOutlet UISwitch *fUploadSpeedLimitEnabledSwitch;
    
    IBOutlet UITableViewCell *fDownloadSpeedLimitEnabledCell;
    IBOutlet UISwitch *fDownloadSpeedLimitEnabledSwitch;
    
    IBOutlet UITableViewCell *fContactUsCell;
        
    UIColor *fTextFieldTextColor;
    
    BOOL keyboardIsShowing;
    CGRect keyboardBounds;
    
    NSDictionary *fOriginalPreferences;
    PortChecker *fPortChecker;
}

@synthesize tableView = fTableView;
@synthesize originalPreferences = fOriginalPreferences;
@synthesize portChecker = fPortChecker;
@synthesize controller = fController;


- (void) textFieldDidBeginEditing:(UITextField *)textField {

}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    
    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    if ([textField.superview.superview isKindOfClass:[UITableViewCell class]])
    {
        UITableViewCell *cell = (UITableViewCell*)textField.superview.superview;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:TRUE];
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
    UITableViewCell *cell = (UITableViewCell*)[[textField superview] superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    
    if (textField == fBindPortTextField) {
        NSString *newStr = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if ([newStr length] == 0) return YES;
        NSScanner *scanner = [NSScanner scannerWithString:newStr];
        int value;
        if ([scanner scanInt:&value] == NO) return NO;
        if ([scanner isAtEnd] == NO) return NO;
        if (value == INT_MAX || value == INT_MIN || value > 65535 || value < 1) {
            return NO;
        }
        else return YES;
    }
    return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 6;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0: return 2;
        case 1: return 1;
        case 2: return 2;
        case 3: return 2;
        case 4: return 2;
        case 5: return 1;
    }
    return 0;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return @"Port Listening";
        case 1: return @"Background Downloading";
        case 2: return @"Connections";
        case 3: return @"Upload";
        case 4: return @"Download";
        case 5: return @"More";
    }
    return nil;
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch (section) {
        case 0: return nil;
        case 1: return @"Enable downloading while in background through multimedia functions";
        case 2: return @"Caution! Too many connections will make your device unstable.";
        case 3: return @"30KB/s is recommended for upload.";
    }
    return nil;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0: return fBindPortCell;
                case 1: return fAutoPortMapCell;
            }
        }
        case 1:
        {
            switch (indexPath.row) {
                case 0: return fBackgroundDownloadingCell;
            }
        }
        case 2:
        {
            switch (indexPath.row) {
                case 0: return fMaximumConnectionsLabelCell;
                case 1: return fConnectionsPerTorrentLabelCell;
            }
        }
        case 3:
        {
            switch (indexPath.row) {
                case 0: return fUploadSpeedLimitEnabledCell;
                case 1: return fUploadSpeedLimitCell;
                
            }
        }
        case 4:
        {
            switch (indexPath.row) {
                case 0: return fDownloadSpeedLimitEnabledCell;
                case 1: return fDownloadSpeedLimitCell;
            }
        }
        case 5:
            return fContactUsCell;
    }
    return [UITableViewCell new];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 5) {
        MFMailComposeViewController* mailComposer = [[MFMailComposeViewController alloc] init];
        mailComposer.mailComposeDelegate = self;
        [mailComposer setSubject:@"iTransmission feedback"];
        [mailComposer setToRecipients:@[@"itransmissionapp@gmail.com"]];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            mailComposer.modalPresentationStyle = UIModalPresentationCurrentContext;
        }
        [self presentViewController:mailComposer animated:YES completion:nil];
    }
}

- (void)portCheckButtonClicked
{
    self.portChecker = [[PortChecker alloc] initForPort:[self.originalPreferences integerForKey:@"BindPort"] delay:NO withDelegate:self];
    [fPortCheckActivityIndicator startAnimating];
    [fCheckPortButton setEnabled:NO];
}

- (void)portCheckerDidFinishProbing:(PortChecker*)c
{
	[fCheckPortButton setEnabled:YES];
	NSString *msg;
	if ([c status] == PortStatusOpen) {
		msg = [NSString stringWithFormat:@"Congratulations. Your port %li is open!", (long)[c portToCheck]];
	}
	if ([c status] == PortStatusError) {
		msg = @"Failed to perform port check.";
	}
	if ([c status] == PortStatusClosed) {
		msg = [NSString stringWithFormat:@"Oh bad. Your port %li is not accessable from outside.", (long)[c portToCheck]];
	}
	
	[fPortCheckActivityIndicator stopAnimating];
    
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Port check" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alertVC animated:YES completion:nil];
}

- (void)savePreferences {
    [self.controller setGlobalUploadSpeedLimit:[[fUploadSpeedLimitField text] intValue]];
    [self.controller setGlobalDownloadSpeedLimit:[[fDownloadSpeedLimitField text] intValue]];
    tr_session *fHandle = [self.controller sessionHandle];
    NSUserDefaults *fDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([fAutoPortMapSwitch isOn] != [self.originalPreferences boolForKey:@"NatTraversal"]) {
        [fDefaults setBool:[fAutoPortMapSwitch isOn] forKey:@"NatTraversal"];
        tr_sessionSetPortForwardingEnabled(fHandle, [fAutoPortMapSwitch isOn]);
    }
    
    if([fEnableBackgroundDownloadingSwitch isOn] != [self.originalPreferences boolForKey:@"BackgroundDownloading"])
    {
        [fDefaults setBool:[fEnableBackgroundDownloadingSwitch isOn] forKey:@"BackgroundDownloading"];
    }
    
    // set bind port
    uint16_t const port = [fBindPortTextField text].integerValue;
    [fDefaults setInteger:port forKey:@"BindPort"];
    tr_sessionSetPeerPort(fHandle, port);

    [fDefaults synchronize];
    
    NSInteger limit = [[fUploadSpeedLimitField text] integerValue];
    [self.controller setGlobalUploadSpeedLimit:limit];
    
    limit = [[fDownloadSpeedLimitField text] intValue];
    [self.controller setGlobalDownloadSpeedLimit:limit];
    
    [self performSelector:@selector(loadPreferences) withObject:nil afterDelay:0.0f];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
	[fCheckPortButton addTarget:self action:@selector(portCheckButtonClicked) forControlEvents:UIControlEventTouchUpInside];
	
    self.controller = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    
    [fConnectionsPerTorrentTextField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller connectionsPerTorrent]]];
    [fMaximumConnectionsTextField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller globalMaximumConnections]]];
    [fUploadSpeedLimitField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller globalUploadSpeedLimit]]];
    [fDownloadSpeedLimitField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller globalDownloadSpeedLimit]]];
    [fUploadSpeedLimitEnabledSwitch setOn:[self.controller globalUploadSpeedLimitEnabled]];
    [fDownloadSpeedLimitEnabledSwitch setOn:[self.controller globalDownloadSpeedLimitEnabled]];
    
    UIToolbar *keyboardDoneButtonView = [[UIToolbar alloc] init];
    [keyboardDoneButtonView sizeToFit];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                   style:UIBarButtonItemStylePlain target:self
                                                                  action:@selector(keyboardDoneClicked)];
    [keyboardDoneButtonView setItems:[NSArray arrayWithObjects:doneButton, nil]];
    [keyboardDoneButtonView sizeToFit];
    
    fBindPortTextField.delegate = self;
    fUploadSpeedLimitField.delegate = self;
    fDownloadSpeedLimitField.delegate = self;
    fConnectionsPerTorrentTextField.delegate = self;
    fMaximumConnectionsTextField.delegate = self;
    fBindPortTextField.inputAccessoryView = keyboardDoneButtonView;
    fUploadSpeedLimitField.inputAccessoryView = keyboardDoneButtonView;
    fDownloadSpeedLimitField.inputAccessoryView = keyboardDoneButtonView;
    fConnectionsPerTorrentTextField.inputAccessoryView = keyboardDoneButtonView;
    fMaximumConnectionsTextField.inputAccessoryView = keyboardDoneButtonView;
    
    fContactUsCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    fContactUsCell.textLabel.text = @"Contact Us";
    fContactUsCell.textLabel.textAlignment = NSTextAlignmentCenter;
    fContactUsCell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    
    [self.navigationController setToolbarHidden:YES animated:NO];
    
    [self loadPreferences];

}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return UITableViewAutomaticDimension;
}

- (void)loadPreferences
{
    NSMutableDictionary *_originalPref = [NSMutableDictionary dictionary];
	NSUserDefaults *fDefaults = [NSUserDefaults standardUserDefaults];
	[_originalPref setBool:[fDefaults boolForKey:@"NatTraversal"] forKey:@"NatTraversal"];
	[_originalPref setInteger:[fDefaults integerForKey:@"BindPort"] forKey:@"BindPort"];
    [_originalPref setBool:[fDefaults boolForKey:@"BackgroundDownloading"] forKey:@"BackgroundDownloading"];
	self.originalPreferences = [NSDictionary dictionaryWithDictionary:_originalPref];
	
	[fAutoPortMapSwitch setOn:[self.originalPreferences boolForKey:@"NatTraversal"]];
	[fBindPortTextField setText:[NSString stringWithFormat:@"%li", (long)[self.originalPreferences integerForKey:@"BindPort"]]];
    [fEnableBackgroundDownloadingSwitch setOn:[self.originalPreferences boolForKey:@"BackgroundDownloading"]];
    
    [self.navigationItem.rightBarButtonItem setEnabled:NO];
}

- (IBAction)enableBackgroundDownloadSwitchChanged:(id)sender
{
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
    
    NSNumber *value = [NSNumber numberWithBool:fEnableBackgroundDownloadingSwitch.on];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AudioPrefChanged" object:value];
}

- (IBAction)uploadSpeedLimitEnabledValueChanged:(id)sender
{
    BOOL enabled = [fUploadSpeedLimitEnabledSwitch isOn];
    [self.controller setGlobalUploadSpeedLimitEnabled:enabled];
}

- (IBAction)downloadSpeedLimitEnabledValueChanged:(id)sender
{
    BOOL enabled = [fDownloadSpeedLimitEnabledSwitch isOn];
    [self.controller setGlobalDownloadSpeedLimitEnabled:enabled];
}

- (IBAction)connectionsPerTorrentChanged:(id)sender
{
    uint16_t intValue = (uint16_t)[[fConnectionsPerTorrentTextField text] intValue];
    [self.controller setConnectionsPerTorrent:intValue];
}

- (IBAction)maximumConnectionsPerTorrentChanged:(id)sender
{
    uint16_t intValue = (uint16_t)[[fMaximumConnectionsTextField text] intValue];
    [self.controller setConnectionsPerTorrent:intValue];
}

- (IBAction)doneClicked:(id)sender {
    [self savePreferences];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)keyboardDoneClicked {
    [fBindPortTextField resignFirstResponder];
    [fUploadSpeedLimitField resignFirstResponder];
    [fDownloadSpeedLimitField resignFirstResponder];
    [fMaximumConnectionsTextField resignFirstResponder];
    [fConnectionsPerTorrentTextField resignFirstResponder];
    
    [self savePreferences];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
       name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
	[self.portChecker cancelProbe];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    keyboardIsShowing = YES;

    NSDictionary *userInfo = [notification userInfo];
    NSValue *keyboardBoundsValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    [keyboardBoundsValue getValue:&keyboardBounds];
    
    [self resizeToFit];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    keyboardIsShowing = NO;
    keyboardBounds = CGRectZero;
    [self resizeToFit];
}

- (void)resizeToFit {
    
    __weak PrefViewController *wself = self;
    
    CGFloat keyboardHeight = keyboardBounds.size.height;
    
    [UIView animateWithDuration:0.3 animations:^{
        wself.bottomConstraint.constant = keyboardHeight;
        [wself.tableView setNeedsLayout];
        [wself.tableView layoutIfNeeded];
    }];
}


+ (NSInteger)dateToTimeSum:(NSDate*)date
{
    NSCalendar* calendar = NSCalendar.currentCalendar;
    NSDateComponents* components = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:date];
    return static_cast<int>(components.hour * 60 + components.minute);
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [controller.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
	[self.portChecker cancelProbe];
}


@end
