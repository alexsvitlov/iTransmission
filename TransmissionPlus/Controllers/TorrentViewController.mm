//
//  TorrentViewController.m
//  iTransmission
//
//  Created by Mike Chen on 10/3/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import "TorrentViewController.h"
#import "AppDelegate.h"
#import "TorrentCell.h"
#import "Torrent.h"
#import "PrefViewController.h"
#import "Notifications.h"
#import "NSStringAdditions.h"
#import "DetailViewController.h"
#import "ControlButton.h"
#import "BandwidthController.h"
#import "WebViewController.h"
#import "AppShareItem.h"
#import <SafariServices/SafariServices.h>

#define ADD_TAG 1000
#define ADD_FROM_URL_TAG 1001
#define ADD_FROM_MAGNET_TAG 1002
#define REMOVE_COMFIRM_TAG 1003

@implementation TorrentViewController

@synthesize tableView;
@synthesize selectedIndexPaths;
@synthesize audio;
@synthesize pref;

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return [self.controller torrentsCount];
        
    }
    return 0;
}

- (void)tableView:(UITableView *)ftableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.tableView.editing == NO) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_Storyboard" bundle:nil];
        DetailViewController *detailController = [storyboard instantiateViewControllerWithIdentifier:@"detail_view"];
        [detailController initWithTorrent:[self.controller torrentAtIndex:indexPath.row] controller:self.controller];
		[self.navigationController pushViewController:detailController animated:YES];
		[ftableView deselectRowAtIndexPath:indexPath animated:YES];
	}
	else {
		[self.selectedIndexPaths addObject:indexPath];
        TorrentCell *cell = (TorrentCell*)[self.tableView cellForRowAtIndexPath:indexPath];
		[cell.controlButton setEnabled:NO];
	}
}

- (UITableViewCell *)tableView:(UITableView *)ftableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = indexPath.row;
    
    TorrentCell *cell = (TorrentCell*)[ftableView dequeueReusableCellWithIdentifier:TorrentCellIdentifier];
    
    [cell.controlButton addTarget:self action:@selector(controlButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    Torrent *t = [self.controller torrentAtIndex:index];
    [self setupCell:cell forTorrent:t];
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
}
       
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    Torrent * torrent = [self.controller torrentAtIndex:indexPath.row];
    self.selectedIndexPaths = [NSMutableArray array];
    [self.selectedIndexPaths addObject:indexPath];
    NSString *msg = [NSString stringWithFormat:@"Are you sure to remove %@ torrent?", [torrent name]];
    
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:msg message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *removeDataAction = [UIAlertAction actionWithTitle:@"Yes and remove data" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self removeTorrentsTrashData:YES];
    }];
    [actionSheet addAction:removeDataAction];
    
    UIAlertAction *keepDataAction = [UIAlertAction actionWithTitle:@"Yes, but keep data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self removeTorrentsTrashData:NO];
    }];
    [actionSheet addAction:keepDataAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.selectedIndexPaths = [NSMutableArray array];
    }];
    [actionSheet addAction:cancelAction];
    
    if (actionSheet.popoverPresentationController != nil) {
        actionSheet.popoverPresentationController.sourceView = self.tableView;
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)controlButtonClicked:(id)sender
{
    CGPoint pos = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:pos];
	
	Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
	if ([torrent isActive])
		[torrent stopTransfer];
	else 
		[torrent startTransfer];
	
	[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)setupCell:(TorrentCell*)cell forTorrent:(Torrent*)t
{
	[t update];
	cell.nameLabel.text = [t name];
	cell.upperDetailLabel.text = [t progressString];
	if (![t isChecking]) {
        [cell.progressView setProgress:[t progress]];
    }
    
	if ([t isSeeding])
		[cell useGreenColor];
	else if ([t isChecking]) {
		[cell useGreenColor];
        [cell.progressView setProgress:[t checkingProgress]];
    }
	else if ([t isActive] && ![t isComplete])
		[cell useBlueColor];
	else if (![t isActive])
		[cell useBlueColor];
	else if (![t isChecking])
		[cell useGreenColor];
	if ([t isActive])
		[cell.controlButton setPauseStyle];
	else 
		[cell.controlButton setResumeStyle];

    [cell.controlButton setEnabled:YES];
	cell.lowerDetailLabel.text = [t statusString];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
        
    // transmission init
    self.controller = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    
    if (@available(iOS 14.0, *)) {
        __weak TorrentViewController *wself = self;
        self.navigationItem.rightBarButtonItem.menu = [UIMenu menuWithChildren:@[
            [UIAction actionWithTitle:NSLocalizedString(@"Add Torrent from Files", @"Menu action title for adding torrent from the files") image:[UIImage systemImageNamed:@"doc"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [wself _addTorrentFromFiles];
        }],
            [UIAction actionWithTitle:NSLocalizedString(@"Add Torrent from Magnet URL", @"Menu action title for adding torrent from the provided URL") image:[UIImage systemImageNamed:@"link"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [wself _addTorrentFromMagnetUrl];
        }],
            [UIAction actionWithTitle:NSLocalizedString(@"Add Torrent from Web", @"Menu action title for adding torrent from the web") image:[UIImage systemImageNamed:@"globe"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [wself _addTorrentFromWeb];
        }],
            [UIAction actionWithTitle:NSLocalizedString(@"Preferences", @"Menu action title for opening preferences screen") image:[UIImage systemImageNamed:@"gear"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [wself _openPreferences];
        }]
        ]];
    } else {
        self.navigationItem.rightBarButtonItem.target = self;
        self.navigationItem.rightBarButtonItem.action = @selector(openMenuAction:);
    }
   
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80.0;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removedTorrents:) name:NotificationTorrentsRemoved object:self.controller];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newTorrentAdded:) name:NotificationNewTorrentAdded object:self.controller];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playAudio:) name:@"AudioPrefChanged" object:self.pref];
    
    // load audio
    NSURL *audioURL = [[NSBundle mainBundle] URLForResource:@"phone" withExtension:@"mp3"];
    self.audio = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL error:nil];
    self.audio.numberOfLoops = -1;
    [self.audio setVolume:0.0];
    
    // only play if enabled
    NSUserDefaults *fDefaults = [NSUserDefaults standardUserDefaults];
    if([fDefaults boolForKey:@"BackgroundDownloading"])
    {
        // play audio
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive: YES error: nil];
        [self.audio play];
    }
    
    [self _updateTableViewVisibility];
}

- (void)_updateTableViewVisibility {
    if ([self.controller torrentsCount] > 0) {
        self.tableView.hidden = NO;
        self.tableViewPlaceholder.hidden = YES;
    }
    else {
        self.tableView.hidden = YES;
        self.tableViewPlaceholder.hidden = NO;
    }
}

- (void)resumeButtonClicked:(id)sender
{
	for (NSIndexPath *indexPath in self.selectedIndexPaths) {
		Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
		[torrent startTransfer];
	}
	[self.tableView reloadData];
	self.selectedIndexPaths = nil;	
}

- (void)pauseButtonClicked:(id)sender
{
	for (NSIndexPath *indexPath in self.selectedIndexPaths) {
		Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
		[torrent stopTransfer];
	}
	[self.tableView reloadData];
	self.selectedIndexPaths = nil;
}

- (void)removeButtonClicked:(id)sender
{
	NSString *msg;
    if ([self.selectedIndexPaths count] == 1) {
		msg = @"Are you sure to remove one torrent?";
    } else {
        msg = [NSString stringWithFormat:@"Are you sure to remove %lu torrents?", (unsigned long)[self.selectedIndexPaths count]];
    }
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:msg message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *removeDataAction = [UIAlertAction actionWithTitle:@"Yes and remove data" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self removeTorrentsTrashData:YES];
    }];
    [actionSheet addAction:removeDataAction];
    
    UIAlertAction *keepDataAction = [UIAlertAction actionWithTitle:@"Yes, but keep data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self removeTorrentsTrashData:NO];
    }];
    [actionSheet addAction:keepDataAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.selectedIndexPaths = [NSMutableArray array];
    }];
    [actionSheet addAction:cancelAction];
    
    if (actionSheet.popoverPresentationController != nil) {
        actionSheet.popoverPresentationController.sourceView = (UIView *)sender;
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)removeTorrentsTrashData:(BOOL)trashData {
    
    NSMutableArray *torrents = [NSMutableArray arrayWithCapacity:[self.selectedIndexPaths count]];
    for (NSIndexPath *indexPath in self.selectedIndexPaths) {
        Torrent *t = [self.controller torrentAtIndex:indexPath.row];
        [torrents addObject:t];
    }
    [self.controller removeTorrents:torrents deleteData:trashData];
    self.selectedIndexPaths = [NSMutableArray array];
    
    [self _updateTableViewVisibility];
    [self.tableView reloadData];
}

- (void)updateUI
{
    [self _updateTableViewVisibility];
    
	NSArray *visibleCells = [self.tableView visibleCells];
	
	for (TorrentCell *cell in visibleCells) {
		[self performSelector:@selector(updateCell:) withObject:cell afterDelay:0.0f];
	}
}
	
- (void)updateCell:(TorrentCell*)c
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:c];
	if (indexPath) {
		Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
		[self setupCell:c forTorrent:torrent];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)addFromURLWithExistingURL:(NSString*)url message:(NSString*)msg
{
    UIAlertController *dialog = [UIAlertController alertControllerWithTitle:@"Add from Magnet URL" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *url = dialog.textFields.firstObject.text;
        if (![url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
            [self addFromURLWithExistingURL:url message:@"Error: The URL provided is malformed!"];
        else {
            [self.controller openURL:url];
        }
    }];
    [dialog addAction:okAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [dialog addAction:cancelAction];
    
    [dialog addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.enablesReturnKeyAutomatically = YES;
        textField.keyboardAppearance = UIKeyboardAppearanceDefault;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.returnKeyType = UIReturnKeyDone;
        textField.secureTextEntry = NO;
    }];
    [self presentViewController:dialog animated:YES completion:nil];
}

- (void)addFromMagnetWithExistingMagnet:(NSString*)magnet message:(NSString*)msg
{
    UIAlertController *dialog = [UIAlertController alertControllerWithTitle:@"Add from magnet" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *magnet = dialog.textFields.firstObject.text;
        BOOL res = [self.controller openURL:magnet];
        if (!res) {
            [self addFromMagnetWithExistingMagnet:magnet message:nil];
        }
    }];
    [dialog addAction:okAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [dialog addAction:cancelAction];
    
    [dialog addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.enablesReturnKeyAutomatically = YES;
        textField.keyboardAppearance = UIKeyboardAppearanceDefault;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.returnKeyType = UIReturnKeyDone;
        textField.secureTextEntry = NO;
    }];
    
    [self presentViewController:dialog animated:YES completion:nil];
}

- (void)newTorrentAdded:(NSNotification*)notif
{
    [self _updateTableViewVisibility];

    [self.tableView reloadData];
}

- (void)removedTorrents:(NSNotification*)notif
{
    [self _updateTableViewVisibility];

	[self.tableView reloadData];
}

- (void)playAudio:(NSNotification *)notif
{
    // load audio
    NSError *error;
    NSURL *audioURL = [[NSBundle mainBundle] URLForResource:@"phone" withExtension:@"mp3"];
    self.audio = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL error:&error];
    self.audio.numberOfLoops = -1;
    [self.audio setVolume:0.0];
    
    NSLog(@"%@", error.localizedDescription);
    
    // only play if enabled
    NSNumber *value = notif.object;
    if(value.intValue == 1)
    {
        // play audio
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive: YES error: nil];
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        [self.audio setDelegate:self];
        [self.audio prepareToPlay];
        [self.audio play];
        NSLog(@"Going to play");
        
    }
    else
    {
        // stop audio
        [self.audio stop];
        NSLog(@"Not going to play");
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    
    // start timer
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateUI) userInfo:nil repeats:YES];
    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // stop update timer
    [self.updateTimer invalidate];
}

- (void)showViewController:(UIViewController *)vc sender:(id)sender shouldShowFullScreen:(BOOL)showFullScreen {
    if ([vc isKindOfClass:[UIAlertController class]] || [vc isKindOfClass:[SFSafariViewController class]]) {
        [self presentViewController:vc animated:YES completion:nil];
    } else if ([vc isKindOfClass: [DetailViewController class]]) {
        [super showViewController:vc sender:sender];
    } else {
        UINavigationController *navigationControlller = [[UINavigationController alloc] initWithRootViewController:vc];
        if (showFullScreen) {
            navigationControlller.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        else {
            navigationControlller.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        [self presentViewController:navigationControlller animated:YES completion:nil];
    }
}

#pragma mark -

- (void)openMenuAction:(UIBarButtonItem *)sender {
    UIAlertController *menuActionSheetController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Menu", @"Menu action sheet title")
                                                                                       message:nil
                                                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    __weak TorrentViewController *wself = self;

    [menuActionSheetController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Torrent from Files", @"Menu action title for adding torrent from the files")
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
        [wself _addTorrentFromFiles];
                                                                }]];


    [menuActionSheetController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Torrent from Magnet URL", @"Menu action title for adding torrent from the provided URL")
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
        [wself _addTorrentFromMagnetUrl];
                                                                }]];
    
    [menuActionSheetController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Torrent from Web", @"Menu action title for adding torrent from the web")
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
        [wself _addTorrentFromWeb];
                                                                }]];
    

    [menuActionSheetController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Preferences", @"Menu action title for opening preferences screen")
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
        [self _openPreferences];
                                                                }]];

    [menuActionSheetController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Menu action title for canceling the menu")
                                                                  style:UIAlertActionStyleCancel
                                                                handler:nil]];

    UIPopoverPresentationController *popoverPresentationController = menuActionSheetController.popoverPresentationController;
    popoverPresentationController.barButtonItem = sender;

    [self showViewController:menuActionSheetController sender:menuActionSheetController shouldShowFullScreen:NO];
}

- (IBAction)shareApp {
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[AppShareItem new]] applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypePrint, UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll, UIActivityTypeAddToReadingList, UIActivityTypeOpenInIBooks];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)_addTorrentFromFiles {
    UIDocumentPickerViewController *documentPickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"com.bittorrent.torrent"] inMode:UIDocumentPickerModeImport];
    documentPickerVC.delegate = self;
    [self presentViewController:documentPickerVC animated:YES completion:nil];
}

- (void)_addTorrentFromMagnetUrl {
    UIAlertController *dialog = [UIAlertController alertControllerWithTitle:@"Add from magnet" message:@"Please input torrent or magnet" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *data = dialog.textFields.firstObject.text;
        NSString *magnetSubstring = [data substringWithRange:NSMakeRange(0,6)];
        NSLog(@"Magnet substring: %@", magnetSubstring);
        if([magnetSubstring isEqualToString:@"magnet"])
        {
            // add torrent from magnet
            BOOL res = [self.controller openURL:data];
            if (!res) {
                NSLog(@"Error adding magnet");
            }
        }
    }];
    [dialog addAction:okAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [dialog addAction:cancelAction];

    [dialog addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.enablesReturnKeyAutomatically = YES;
        textField.keyboardAppearance = UIKeyboardAppearanceDefault;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.returnKeyType = UIReturnKeyDone;
        textField.secureTextEntry = NO;
    }];

    [self showViewController:dialog sender:dialog shouldShowFullScreen:NO];
}

- (void)_addTorrentFromWeb {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_Storyboard" bundle:nil];
    WebViewController *webVC = [storyboard instantiateViewControllerWithIdentifier:@"web"];
    [webVC setData:@"http://google.com" controller:self.controller];
    [self showViewController:webVC sender:webVC shouldShowFullScreen:YES];
}

- (void)_openPreferences {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_Storyboard" bundle:nil];
    UIViewController *preferencesViewController = [storyboard instantiateViewControllerWithIdentifier:@"pref"];
    [self showViewController:preferencesViewController sender:preferencesViewController shouldShowFullScreen:NO];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) {
        return;
    }
    NSURL *url = [urls firstObject];
    [self.controller openFilePathURL:url shouldOpenInPlace:NO];
}

@end
