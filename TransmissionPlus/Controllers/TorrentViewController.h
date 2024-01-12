//
//  TorrentViewController.h
//  iTransmission
//
//  Created by Mike Chen on 10/3/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ALAlertBanner.h"
#import <AVFoundation/AVFoundation.h>

@class AppDelegate;
@class Torrent;
@class TorrentCell;
@class PrefViewController;

@interface TorrentViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, AVAudioPlayerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UIView *tableViewPlaceholder;
@property (nonatomic, strong) NSMutableArray *selectedIndexPaths;
@property (strong, nonatomic) AVAudioPlayer *audio;
@property (nonatomic, strong) PrefViewController *pref;
@property (nonatomic, strong) AppDelegate *controller;
@property (nonatomic, strong) NSTimer *updateTimer;

- (void)addFromURLWithExistingURL:(NSString*)url message:(NSString*)msg;
- (void)addFromMagnetWithExistingMagnet:(NSString*)magnet message:(NSString*)msg;
- (void)newTorrentAdded:(NSNotification*)notif;
- (void)removedTorrents:(NSNotification*)notif;
- (void)playAudio:(NSNotification*)notif;

- (void)controlButtonClicked:(id)sender;
- (void)resumeButtonClicked:(id)sender;
- (void)pauseButtonClicked:(id)sender;
- (void)removeButtonClicked:(id)sender;

- (void)setupCell:(TorrentCell*)cell forTorrent:(Torrent*)torrent;

- (void)updateCell:(TorrentCell*)c;

- (IBAction)openMenuAction:(UIBarButtonItem *)sender;

- (IBAction)shareApp;

@end
