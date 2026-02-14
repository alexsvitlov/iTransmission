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

static NSInteger const PrefSectionPort          = 0;
static NSInteger const PrefSectionNetwork       = 1;
static NSInteger const PrefSectionConnections   = 2;
static NSInteger const PrefSectionUpload        = 3;
static NSInteger const PrefSectionDownload      = 4;
static NSInteger const PrefSectionEncryption    = 5;
static NSInteger const PrefSectionSeeding       = 6;
static NSInteger const PrefSectionQueue         = 7;
static NSInteger const PrefSectionPeerDiscovery = 8;
static NSInteger const PrefSectionBlocklist     = 9;
static NSInteger const PrefSectionRPC           = 10;
static NSInteger const PrefSectionMore          = 11;
static NSInteger const PrefSectionCount         = 12;

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

    // Network
    UITableViewCell *fWifiOnlyCell;
    UISwitch *fWifiOnlySwitch;

    // Encryption
    UITableViewCell *fEncryptionCell;
    UISegmentedControl *fEncryptionSegment;

    // Seeding
    UITableViewCell *fRatioLimitEnabledCell;
    UISwitch *fRatioLimitEnabledSwitch;
    UITableViewCell *fRatioLimitCell;
    UITextField *fRatioLimitField;
    UITableViewCell *fIdleLimitEnabledCell;
    UISwitch *fIdleLimitEnabledSwitch;
    UITableViewCell *fIdleLimitCell;
    UITextField *fIdleLimitField;

    // Queue
    UITableViewCell *fDownloadQueueEnabledCell;
    UISwitch *fDownloadQueueEnabledSwitch;
    UITableViewCell *fDownloadQueueSizeCell;
    UITextField *fDownloadQueueSizeField;
    UITableViewCell *fSeedQueueEnabledCell;
    UISwitch *fSeedQueueEnabledSwitch;
    UITableViewCell *fSeedQueueSizeCell;
    UITextField *fSeedQueueSizeField;

    // Peer discovery
    UITableViewCell *fDHTCell;
    UISwitch *fDHTSwitch;
    UITableViewCell *fPEXCell;
    UISwitch *fPEXSwitch;
    UITableViewCell *fUTPCell;
    UISwitch *fUTPSwitch;
    UITableViewCell *fLPDCell;
    UISwitch *fLPDSwitch;

    // Blocklist
    UITableViewCell *fBlocklistEnabledCell;
    UISwitch *fBlocklistEnabledSwitch;
    UITableViewCell *fBlocklistURLCell;
    UITextField *fBlocklistURLField;

    // RPC
    UITableViewCell *fRPCEnabledCell;
    UISwitch *fRPCEnabledSwitch;
    UITableViewCell *fRPCPortCell;
    UITextField *fRPCPortField;
    UITableViewCell *fRPCAuthEnabledCell;
    UISwitch *fRPCAuthEnabledSwitch;
    UITableViewCell *fRPCUsernameCell;
    UITextField *fRPCUsernameField;
    UITableViewCell *fRPCPasswordCell;
    UITextField *fRPCPasswordField;
}

@synthesize tableView = fTableView;
@synthesize originalPreferences = fOriginalPreferences;
@synthesize portChecker = fPortChecker;
@synthesize controller = fController;

#pragma mark - Cell factory helpers

- (UITableViewCell *)cellWithLabel:(NSString *)label switchControl:(UISwitch *)sw
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = label;
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    cell.accessoryView = sw;
    return cell;
}

- (UITableViewCell *)cellWithLabel:(NSString *)label textField:(UITextField *)tf keyboard:(UIKeyboardType)keyboardType toolbar:(UIToolbar *)toolbar
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = label;
    lbl.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:lbl];

    tf.textAlignment = NSTextAlignmentRight;
    tf.font = [UIFont fontWithName:@"Helvetica" size:18];
    tf.textColor = self.view.tintColor;
    tf.keyboardType = keyboardType;
    tf.delegate = self;
    tf.inputAccessoryView = toolbar;
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:tf];

    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [lbl.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [tf.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [tf.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [tf.leadingAnchor constraintGreaterThanOrEqualToAnchor:lbl.trailingAnchor constant:8],
        [tf.widthAnchor constraintGreaterThanOrEqualToConstant:60],
    ]];

    return cell;
}


- (void) textFieldDidBeginEditing:(UITextField *)textField {

}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{

    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    UIView *view = textField.superview;
    while (view && ![view isKindOfClass:[UITableViewCell class]])
        view = view.superview;

    if (view) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)view];
        if (indexPath)
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
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
    UIView *view = textField.superview;
    while (view && ![view isKindOfClass:[UITableViewCell class]])
        view = view.superview;
    if (view) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)view];
        if (indexPath)
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }

    if (textField == fBindPortTextField || textField == fRPCPortField) {
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return PrefSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case PrefSectionPort:          return 2;
        case PrefSectionNetwork:       return 2;
        case PrefSectionConnections:   return 2;
        case PrefSectionUpload:        return 2;
        case PrefSectionDownload:      return 2;
        case PrefSectionEncryption:    return 1;
        case PrefSectionSeeding:       return 4;
        case PrefSectionQueue:         return 4;
        case PrefSectionPeerDiscovery: return 4;
        case PrefSectionBlocklist:     return 2;
        case PrefSectionRPC:           return 5;
        case PrefSectionMore:          return 1;
    }
    return 0;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case PrefSectionPort:          return @"Port Listening";
        case PrefSectionNetwork:       return @"Network";
        case PrefSectionConnections:   return @"Connections";
        case PrefSectionUpload:        return @"Upload";
        case PrefSectionDownload:      return @"Download";
        case PrefSectionEncryption:    return @"Encryption";
        case PrefSectionSeeding:       return @"Seeding";
        case PrefSectionQueue:         return @"Queue";
        case PrefSectionPeerDiscovery: return @"Peer Discovery";
        case PrefSectionBlocklist:     return @"Blocklist";
        case PrefSectionRPC:           return @"Remote Access";
        case PrefSectionMore:          return @"More";
    }
    return nil;
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch (section) {
        case PrefSectionNetwork:       return @"Enable downloading while in background through multimedia functions.";
        case PrefSectionConnections:   return @"Caution! Too many connections will make your device unstable.";
        case PrefSectionUpload:        return @"30KB/s is recommended for upload.";
        case PrefSectionEncryption:    return @"Encryption protects your traffic from eavesdropping.";
        case PrefSectionRPC:           return @"Allows controlling iTransmission from a web browser or remote client.";
    }
    return nil;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case PrefSectionPort: {
            switch (indexPath.row) {
                case 0: return fBindPortCell;
                case 1: return fAutoPortMapCell;
            }
            break;
        }
        case PrefSectionNetwork: {
            switch (indexPath.row) {
                case 0: return fBackgroundDownloadingCell;
                case 1: return fWifiOnlyCell;
            }
            break;
        }
        case PrefSectionConnections: {
            switch (indexPath.row) {
                case 0: return fMaximumConnectionsLabelCell;
                case 1: return fConnectionsPerTorrentLabelCell;
            }
            break;
        }
        case PrefSectionUpload: {
            switch (indexPath.row) {
                case 0: return fUploadSpeedLimitEnabledCell;
                case 1: return fUploadSpeedLimitCell;
            }
            break;
        }
        case PrefSectionDownload: {
            switch (indexPath.row) {
                case 0: return fDownloadSpeedLimitEnabledCell;
                case 1: return fDownloadSpeedLimitCell;
            }
            break;
        }
        case PrefSectionEncryption:
            return fEncryptionCell;
        case PrefSectionSeeding: {
            switch (indexPath.row) {
                case 0: return fRatioLimitEnabledCell;
                case 1: return fRatioLimitCell;
                case 2: return fIdleLimitEnabledCell;
                case 3: return fIdleLimitCell;
            }
            break;
        }
        case PrefSectionQueue: {
            switch (indexPath.row) {
                case 0: return fDownloadQueueEnabledCell;
                case 1: return fDownloadQueueSizeCell;
                case 2: return fSeedQueueEnabledCell;
                case 3: return fSeedQueueSizeCell;
            }
            break;
        }
        case PrefSectionPeerDiscovery: {
            switch (indexPath.row) {
                case 0: return fDHTCell;
                case 1: return fPEXCell;
                case 2: return fUTPCell;
                case 3: return fLPDCell;
            }
            break;
        }
        case PrefSectionBlocklist: {
            switch (indexPath.row) {
                case 0: return fBlocklistEnabledCell;
                case 1: return fBlocklistURLCell;
            }
            break;
        }
        case PrefSectionRPC: {
            switch (indexPath.row) {
                case 0: return fRPCEnabledCell;
                case 1: return fRPCPortCell;
                case 2: return fRPCAuthEnabledCell;
                case 3: return fRPCUsernameCell;
                case 4: return fRPCPasswordCell;
            }
            break;
        }
        case PrefSectionMore:
            return fContactUsCell;
    }
    return [UITableViewCell new];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == PrefSectionMore && [MFMailComposeViewController canSendMail]) {
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

#pragma mark - Save / load

- (void)savePreferences {
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

    // set speed limits
    NSInteger limit = [[fUploadSpeedLimitField text] integerValue];
    [self.controller setGlobalUploadSpeedLimit:limit];

    limit = [[fDownloadSpeedLimitField text] integerValue];
    [self.controller setGlobalDownloadSpeedLimit:limit];

    // set connection limits
    NSInteger connections = [[fMaximumConnectionsTextField text] integerValue];
    [self.controller setGlobalMaximumConnections:connections];

    connections = [[fConnectionsPerTorrentTextField text] integerValue];
    [self.controller setConnectionsPerTorrent:connections];

    // set seeding limits
    [self.controller setRatioLimit:[[fRatioLimitField text] floatValue]];
    [self.controller setIdleLimitMinutes:[[fIdleLimitField text] integerValue]];

    // set queue sizes
    [self.controller setDownloadQueueSize:[[fDownloadQueueSizeField text] integerValue]];
    [self.controller setSeedQueueSize:[[fSeedQueueSizeField text] integerValue]];

    // set blocklist URL
    NSString *blocklistURL = [fBlocklistURLField text];
    if (blocklistURL.length > 0)
        [self.controller setBlocklistURL:blocklistURL];

    // set RPC text fields
    [self.controller setRPCPort:[[fRPCPortField text] integerValue]];
    NSString *rpcUser = [fRPCUsernameField text];
    if (rpcUser)
        [self.controller setRPCUsername:rpcUser];
    NSString *rpcPass = [fRPCPasswordField text];
    if (rpcPass)
        [self.controller setRPCPassword:rpcPass];

    [fDefaults synchronize];

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

    // Wifi-only
    fWifiOnlySwitch = [[UISwitch alloc] init];
    fWifiOnlyCell = [self cellWithLabel:@"Wifi Only" switchControl:fWifiOnlySwitch];
    [fWifiOnlySwitch setOn:[self.controller wifiOnlyEnabled]];
    [fWifiOnlySwitch addTarget:self action:@selector(wifiOnlySwitchChanged:) forControlEvents:UIControlEventValueChanged];

    // Encryption
    fEncryptionCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    fEncryptionCell.selectionStyle = UITableViewCellSelectionStyleNone;
    fEncryptionSegment = [[UISegmentedControl alloc] initWithItems:@[@"Off", @"Preferred", @"Required"]];
    fEncryptionSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [fEncryptionSegment setSelectedSegmentIndex:[self.controller encryptionMode]];
    [fEncryptionSegment addTarget:self action:@selector(encryptionModeChanged:) forControlEvents:UIControlEventValueChanged];
    [fEncryptionCell.contentView addSubview:fEncryptionSegment];
    [NSLayoutConstraint activateConstraints:@[
        [fEncryptionSegment.leadingAnchor constraintEqualToAnchor:fEncryptionCell.contentView.leadingAnchor constant:16],
        [fEncryptionSegment.trailingAnchor constraintEqualToAnchor:fEncryptionCell.contentView.trailingAnchor constant:-16],
        [fEncryptionSegment.centerYAnchor constraintEqualToAnchor:fEncryptionCell.contentView.centerYAnchor],
    ]];

    // Seeding — ratio
    fRatioLimitEnabledSwitch = [[UISwitch alloc] init];
    fRatioLimitEnabledCell = [self cellWithLabel:@"Stop at Ratio" switchControl:fRatioLimitEnabledSwitch];
    [fRatioLimitEnabledSwitch setOn:[self.controller ratioLimitEnabled]];
    [fRatioLimitEnabledSwitch addTarget:self action:@selector(ratioLimitEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fRatioLimitField = [[UITextField alloc] init];
    fRatioLimitCell = [self cellWithLabel:@"Ratio Limit" textField:fRatioLimitField keyboard:UIKeyboardTypeDecimalPad toolbar:keyboardDoneButtonView];
    [fRatioLimitField setText:[NSString stringWithFormat:@"%.2f", [self.controller ratioLimit]]];

    // Seeding — idle
    fIdleLimitEnabledSwitch = [[UISwitch alloc] init];
    fIdleLimitEnabledCell = [self cellWithLabel:@"Stop if Idle" switchControl:fIdleLimitEnabledSwitch];
    [fIdleLimitEnabledSwitch setOn:[self.controller idleLimitEnabled]];
    [fIdleLimitEnabledSwitch addTarget:self action:@selector(idleLimitEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fIdleLimitField = [[UITextField alloc] init];
    fIdleLimitCell = [self cellWithLabel:@"Idle Minutes" textField:fIdleLimitField keyboard:UIKeyboardTypeNumberPad toolbar:keyboardDoneButtonView];
    [fIdleLimitField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller idleLimitMinutes]]];

    // Queue — download
    fDownloadQueueEnabledSwitch = [[UISwitch alloc] init];
    fDownloadQueueEnabledCell = [self cellWithLabel:@"Download Queue" switchControl:fDownloadQueueEnabledSwitch];
    [fDownloadQueueEnabledSwitch setOn:[self.controller downloadQueueEnabled]];
    [fDownloadQueueEnabledSwitch addTarget:self action:@selector(downloadQueueEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fDownloadQueueSizeField = [[UITextField alloc] init];
    fDownloadQueueSizeCell = [self cellWithLabel:@"Max Downloads" textField:fDownloadQueueSizeField keyboard:UIKeyboardTypeNumberPad toolbar:keyboardDoneButtonView];
    [fDownloadQueueSizeField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller downloadQueueSize]]];

    // Queue — seed
    fSeedQueueEnabledSwitch = [[UISwitch alloc] init];
    fSeedQueueEnabledCell = [self cellWithLabel:@"Seed Queue" switchControl:fSeedQueueEnabledSwitch];
    [fSeedQueueEnabledSwitch setOn:[self.controller seedQueueEnabled]];
    [fSeedQueueEnabledSwitch addTarget:self action:@selector(seedQueueEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fSeedQueueSizeField = [[UITextField alloc] init];
    fSeedQueueSizeCell = [self cellWithLabel:@"Max Seeds" textField:fSeedQueueSizeField keyboard:UIKeyboardTypeNumberPad toolbar:keyboardDoneButtonView];
    [fSeedQueueSizeField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller seedQueueSize]]];

    // Peer discovery
    fDHTSwitch = [[UISwitch alloc] init];
    fDHTCell = [self cellWithLabel:@"DHT" switchControl:fDHTSwitch];
    [fDHTSwitch setOn:[self.controller dhtEnabled]];
    [fDHTSwitch addTarget:self action:@selector(dhtSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    fPEXSwitch = [[UISwitch alloc] init];
    fPEXCell = [self cellWithLabel:@"PEX" switchControl:fPEXSwitch];
    [fPEXSwitch setOn:[self.controller pexEnabled]];
    [fPEXSwitch addTarget:self action:@selector(pexSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    fUTPSwitch = [[UISwitch alloc] init];
    fUTPCell = [self cellWithLabel:@"uTP" switchControl:fUTPSwitch];
    [fUTPSwitch setOn:[self.controller utpEnabled]];
    [fUTPSwitch addTarget:self action:@selector(utpSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    fLPDSwitch = [[UISwitch alloc] init];
    fLPDCell = [self cellWithLabel:@"Local Peer Discovery" switchControl:fLPDSwitch];
    [fLPDSwitch setOn:[self.controller lpdEnabled]];
    [fLPDSwitch addTarget:self action:@selector(lpdSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    // Blocklist
    fBlocklistEnabledSwitch = [[UISwitch alloc] init];
    fBlocklistEnabledCell = [self cellWithLabel:@"Enable Blocklist" switchControl:fBlocklistEnabledSwitch];
    [fBlocklistEnabledSwitch setOn:[self.controller blocklistEnabled]];
    [fBlocklistEnabledSwitch addTarget:self action:@selector(blocklistEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fBlocklistURLField = [[UITextField alloc] init];
    fBlocklistURLCell = [self cellWithLabel:@"URL" textField:fBlocklistURLField keyboard:UIKeyboardTypeURL toolbar:keyboardDoneButtonView];
    fBlocklistURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    fBlocklistURLField.autocorrectionType = UITextAutocorrectionTypeNo;
    [fBlocklistURLField setText:[self.controller blocklistURL]];

    // RPC
    fRPCEnabledSwitch = [[UISwitch alloc] init];
    fRPCEnabledCell = [self cellWithLabel:@"Enable Remote Access" switchControl:fRPCEnabledSwitch];
    [fRPCEnabledSwitch setOn:[self.controller rpcEnabled]];
    [fRPCEnabledSwitch addTarget:self action:@selector(rpcEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fRPCPortField = [[UITextField alloc] init];
    fRPCPortCell = [self cellWithLabel:@"Port" textField:fRPCPortField keyboard:UIKeyboardTypeNumberPad toolbar:keyboardDoneButtonView];
    [fRPCPortField setText:[NSString stringWithFormat:@"%ld", (long)[self.controller rpcPort]]];

    fRPCAuthEnabledSwitch = [[UISwitch alloc] init];
    fRPCAuthEnabledCell = [self cellWithLabel:@"Require Authentication" switchControl:fRPCAuthEnabledSwitch];
    [fRPCAuthEnabledSwitch setOn:[self.controller rpcAuthEnabled]];
    [fRPCAuthEnabledSwitch addTarget:self action:@selector(rpcAuthEnabledChanged:) forControlEvents:UIControlEventValueChanged];

    fRPCUsernameField = [[UITextField alloc] init];
    fRPCUsernameCell = [self cellWithLabel:@"Username" textField:fRPCUsernameField keyboard:UIKeyboardTypeDefault toolbar:keyboardDoneButtonView];
    fRPCUsernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    fRPCUsernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    [fRPCUsernameField setText:[self.controller rpcUsername]];

    fRPCPasswordField = [[UITextField alloc] init];
    fRPCPasswordCell = [self cellWithLabel:@"Password" textField:fRPCPasswordField keyboard:UIKeyboardTypeDefault toolbar:keyboardDoneButtonView];
    fRPCPasswordField.secureTextEntry = YES;
    fRPCPasswordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    fRPCPasswordField.autocorrectionType = UITextAutocorrectionTypeNo;
    [fRPCPasswordField setText:[self.controller rpcPassword]];

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

#pragma mark - Switch actions (save immediately)

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
    [self.controller setGlobalMaximumConnections:intValue];
}

- (void)wifiOnlySwitchChanged:(id)sender
{
    [self.controller setWifiOnlyEnabled:[fWifiOnlySwitch isOn]];
}

- (void)encryptionModeChanged:(id)sender
{
    [self.controller setEncryptionMode:(tr_encryption_mode)[fEncryptionSegment selectedSegmentIndex]];
}

- (void)ratioLimitEnabledChanged:(id)sender
{
    [self.controller setRatioLimitEnabled:[fRatioLimitEnabledSwitch isOn]];
}

- (void)idleLimitEnabledChanged:(id)sender
{
    [self.controller setIdleLimitEnabled:[fIdleLimitEnabledSwitch isOn]];
}

- (void)downloadQueueEnabledChanged:(id)sender
{
    [self.controller setDownloadQueueEnabled:[fDownloadQueueEnabledSwitch isOn]];
}

- (void)seedQueueEnabledChanged:(id)sender
{
    [self.controller setSeedQueueEnabled:[fSeedQueueEnabledSwitch isOn]];
}

- (void)dhtSwitchChanged:(id)sender
{
    [self.controller setDHTEnabled:[fDHTSwitch isOn]];
}

- (void)pexSwitchChanged:(id)sender
{
    [self.controller setPEXEnabled:[fPEXSwitch isOn]];
}

- (void)utpSwitchChanged:(id)sender
{
    [self.controller setUTPEnabled:[fUTPSwitch isOn]];
}

- (void)lpdSwitchChanged:(id)sender
{
    [self.controller setLPDEnabled:[fLPDSwitch isOn]];
}

- (void)blocklistEnabledChanged:(id)sender
{
    [self.controller setBlocklistEnabled:[fBlocklistEnabledSwitch isOn]];
}

- (void)rpcEnabledChanged:(id)sender
{
    [self.controller setRPCEnabled:[fRPCEnabledSwitch isOn]];
}

- (void)rpcAuthEnabledChanged:(id)sender
{
    [self.controller setRPCAuthEnabled:[fRPCAuthEnabledSwitch isOn]];
}

#pragma mark - Done / dismiss

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
    [fRatioLimitField resignFirstResponder];
    [fIdleLimitField resignFirstResponder];
    [fDownloadQueueSizeField resignFirstResponder];
    [fSeedQueueSizeField resignFirstResponder];
    [fBlocklistURLField resignFirstResponder];
    [fRPCPortField resignFirstResponder];
    [fRPCUsernameField resignFirstResponder];
    [fRPCPasswordField resignFirstResponder];

    [self savePreferences];
}

#pragma mark - Keyboard handling

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
