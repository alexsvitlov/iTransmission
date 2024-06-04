    //
//  DetailViewController.m
//  iTransmission
//
//  Created by Mike Chen on 10/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "DetailViewController.h"
#import "Torrent.h"
#import "AppDelegate.h"
#import "NSStringAdditions.h"
#import "Notifications.h"
#import "FlexibleLabelCell.h"
#import "NSDate+Helper.h"
#import "BandwidthController.h"
#import "FileListViewController.h"
#import "TrackersViewController.h"
#import "TrackerNode.h"

#define HEADER_SECTION 0
#define TITLE_ROW 0

#define STATE_SECTION 1
#define STATE_ROW 0
#define ERROR_MESSAGE_ROW (STATE_ROW+1)

#define MORE_SECTION 2
#define FILES_ROW 0
#define TRACKERS_ROW 1

#define SPEED_SECTION 3
#define DL_SPEED_ROW 0
#define UL_SPEED_ROW 1
#define AVERAGE_DL_SPEED_ROW 2
#define AVERAGE_UL_SPEED_ROW 3

#define GENERAL_INFO_SECTION 4
#define HASH_ROW 0
#define MAGNET_ROW 1
#define IS_PRIVATE_ROW 2
#define CREATOR_ROW 3
#define CREATED_ON_ROW 4
#define ACTIVITY_ROW 5
#define COMMENT_ROW 6

#define TRANSFER_SECTION 5
#define TOTAL_SIZE_ROW 0
#define SIZE_COMPLETED_ROW 1
#define PROGRESS_ROW 2
#define DOWNLOADED_ROW 3
#define UPLOADED_ROW 4
#define RATIO_ROW 5
#define SEEDERS_ROW 6
#define PEERS_ROW 7

#define ACTIONS_SECTION 6
#define RECHECK_DATA_ROW 1
#define START_PAUSE_ROW 0

#define LOCATION_SECTION 7
#define DATA_LOCATION_ROW 0
#define TORRENT_LOCATION_ROW 1

#define REMOVE_COMFIRM_TAG 1003

@implementation DetailViewController {
    UITableView *fTableView;
    UIBarButtonItem *fStartButton;
    UIBarButtonItem *fPauseButton;
    UIBarButtonItem *fRemoveButton;
    UIBarButtonItem *fRefreshButton;
    UIBarButtonItem *fBandwidthButton;
    NSIndexPath *fSelectedIndexPath;
    
    IBOutlet UITableViewCell *fTitleCell;
    IBOutlet UILabel *fTitleLabel;
    IBOutlet UIImageView *fIconView;
    
    IBOutlet UITableViewCell *fTotalSizeCell;
    IBOutlet UILabel *fTotalSizeLabel;
    
    IBOutlet UITableViewCell *fTorrentSeedersCell;
    IBOutlet UILabel *fTorrentSeedersLabel;
    
    IBOutlet UITableViewCell *fTorrentPeersCell;
    IBOutlet UILabel *fTorrentPeersLabel;
    
    IBOutlet UITableViewCell *fCompletedSizeCell;
    IBOutlet UILabel *fCompletedSizeLabel;
    
    IBOutlet UITableViewCell *fProgressCell;
    IBOutlet UILabel *fProgressLabel;
    
    IBOutlet UITableViewCell *fDownloadedSizeCell;
    IBOutlet UILabel *fDownloadedSizeLabel;
    
    IBOutlet UITableViewCell *fUploadedSizeCell;
    IBOutlet UILabel *fUploadedSizeLabel;
    
    IBOutlet UITableViewCell *fStateCell;
    IBOutlet UILabel *fStateLabel;
    
    IBOutlet FlexibleLabelCell *fErrorMessageCell;
    IBOutlet UILabel *fErrorMessageLabel;
    
    IBOutlet UITableViewCell *fHashCell;
    IBOutlet UILabel *fHashLabel;
    
    IBOutlet UITableViewCell *fRatioCell;
    IBOutlet UILabel *fRatioLabel;
    
    IBOutlet UITableViewCell *fRecheckDataCell;
    
    IBOutlet UITableViewCell *fStartPauseCell;
    IBOutlet UIButton *fStartPauseButton;
    
    IBOutlet FlexibleLabelCell *fDataLocationCell;
    IBOutlet UILabel *fDataLocationLabel;
    
    IBOutlet FlexibleLabelCell *fTorrentLocationCell;
    IBOutlet UILabel *fTorrentLocationLabel;
    
    IBOutlet FlexibleLabelCell *fTorrentMagnetLinkCell;
    IBOutlet UILabel *fTorrentMagnetLinkLabel;
    
    IBOutlet UITableViewCell *fULSpeedCell;
    IBOutlet UILabel *fULSpeedLabel;
    
    IBOutlet UITableViewCell *fDLSpeedCell;
    IBOutlet UILabel *fDLSpeedLabel;
    
    IBOutlet UITableViewCell *fTorrentActivityCell;
    IBOutlet UILabel *fTorrentActivityLabel;
    
    IBOutlet UITableViewCell *fAverageULSpeedCell;
    IBOutlet UILabel *fAverageULSpeedLabel;
    
    IBOutlet UITableViewCell *fAverageDLSpeedCell;
    IBOutlet UILabel *fAverageDLSpeedLabel;
    
    IBOutlet UITableViewCell *fCreatorCell;
    IBOutlet UILabel *fCreatorLabel;
    
    IBOutlet UITableViewCell *fCreatedOnCell;
    IBOutlet UILabel *fCreatedOnLabel;
    
    IBOutlet FlexibleLabelCell *fCommentCell;
    IBOutlet UILabel *fCommentLabel;
    
    IBOutlet UITableViewCell *fIsPrivateCell;
    IBOutlet UISwitch *fIsPrivateSwitch;
    
    UITableViewCell *fTrackersCell;
    UITableViewCell *fFilesCell;
    
    BOOL displayedError;
}

@synthesize tableView = fTableView;
@synthesize torrent = fTorrent;
@synthesize startButton = fStartButton;
@synthesize pauseButton = fPauseButton;
@synthesize removeButton = fRemoveButton;
@synthesize refreshButton = fRefreshButton;
@synthesize bandwidthButton = fBandwidthButton;
@synthesize selectedIndexPath = fSelectedIndexPath;
@synthesize controller;

- (void)initWithTorrent:(Torrent*)t controller:(AppDelegate*)c {
    self.title = @"Details";
    fTorrent = t;
    controller = c;
		
    self.startButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(startButtonClicked:)];
    self.pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseButtonClicked:)];
    self.removeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(removeButtonClicked:)];
        
    self.bandwidthButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"bandwidth-icon"] style:UIBarButtonItemStylePlain target:self action:@selector(bandwidthButtonClicked:)];
        
    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(updateUI)];

    UIBarButtonItem *flexSpaceOne = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flexSpaceTwo = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flexSpaceThree = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flexSpaceFour = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		
    self.toolbarItems = [NSArray arrayWithObjects:self.startButton, flexSpaceOne, self.pauseButton, flexSpaceTwo, self.refreshButton, flexSpaceThree, self.bandwidthButton, flexSpaceFour, self.removeButton, nil];
    displayedError = NO;
}

- (void)bandwidthButtonClicked:(id)sender
{
    BandwidthController *bandwidthController = [[BandwidthController alloc] initWithNibName:@"BandwidthController" bundle:nil];
    [bandwidthController setTorrent:self.torrent];
    [bandwidthController setController:self.controller];
    [self.navigationController pushViewController:bandwidthController animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 8;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == MORE_SECTION) {
		return indexPath;
	}
    if (indexPath.section == LOCATION_SECTION) {
        return indexPath;
    }
    if (indexPath.section == ACTIONS_SECTION) {
        return indexPath;
    }
    if (indexPath.section == GENERAL_INFO_SECTION) {
        return indexPath;
    }
	return nil;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell setSelected:NO animated:YES];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_Storyboard" bundle:nil];
	if (indexPath.section == MORE_SECTION) {
        if (indexPath.row == FILES_ROW) {
            FileListViewController *c = [storyboard instantiateViewControllerWithIdentifier:@"file_view"];
            [c initWithTorrent:fTorrent];
            [self.navigationController pushViewController:c animated:YES];
        } else if (indexPath.row == TRACKERS_ROW) {
            TrackersViewController *cb = [storyboard instantiateViewControllerWithIdentifier:@"trackers_view"];
            [cb initWithTorrent:fTorrent];
            [self.navigationController pushViewController:cb animated:YES];
        }
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
    else if (indexPath.section == ACTIONS_SECTION) {
        if (indexPath.row == RECHECK_DATA_ROW) {
            [fTorrent resetCache];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        else if (indexPath.row == START_PAUSE_ROW) {
            if ([[fTorrent stateString]  isEqualToString:@"Downloading"]) {
                [self pauseButtonClicked:fPauseButton];
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                if ([[fTorrent stateString] isEqualToString:@"Paused"]) fStartPauseCell.textLabel.text = @"Start";
                    else fStartPauseCell.textLabel.text = @"Pause";
            }
            else if ([[fTorrent stateString] isEqualToString:@"Paused"]) {
                [self startButtonClicked:fStartButton];
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                if ([[fTorrent stateString] isEqualToString:@"Paused"]) fStartPauseCell.textLabel.text = @"Start";
                    else fStartPauseCell.textLabel.text = @"Pause";
            }
        }
    }
    else if (indexPath.section == GENERAL_INFO_SECTION) {
        if (indexPath.row == MAGNET_ROW) {
            [[UIPasteboard generalPasteboard] setString:[fTorrent magnetLink]];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            [fTorrentMagnetLinkLabel setText:@"Copied!"];
        }
    } else {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[self.tableView setAllowsSelection:YES];

	[fTitleLabel setText:[fTorrent name]];
    
    [fTorrentMagnetLinkLabel setText:@"Tap to Copy"];
    [fTorrentMagnetLinkLabel setTextAlignment:NSTextAlignmentRight];
    
    NSMutableArray *fPeers = [[NSMutableArray alloc] init];
    [fPeers removeAllObjects];
    [fPeers addObjectsFromArray:[fTorrent peers]];
    NSInteger totalSeeder = 0;
    NSInteger totalPeers = 0;
    for (NSDictionary *peer in fPeers) {
        /*
        {
            Client = "BitTorrent 7.7.3";
            "DL From Rate" = "4.365";
            Encryption = 0;
            Flags = DU;f
            From = 5;
            IP = "85.59.25.37";
            Name = "XCOM Enemy Unknown Elite Edition [MULTI][MACOSX][MONEY][WwW.GamesTorrents.CoM]";
            Port = 53346;
            Progress = "0.9570978";
            Seed = 0;
            "UL To Rate" = "8.198";
            uTP = 0;
         
        }
        */
        BOOL isSeed = [[peer valueForKey:@"Seed"] boolValue];
        if (isSeed) {
            totalSeeder = totalSeeder + 1;
        } else {
            totalPeers = totalPeers + 1;
        }
    }
    totalSeeder = (NSInteger)totalSeeder + (NSInteger)[fTorrent webSeedCount];
    [fTorrentSeedersLabel setText:[NSString stringWithFormat:@"%ld", totalSeeder]];
    [fTorrentPeersLabel setText:[NSString stringWithFormat:@"%ld", totalPeers]];
    
	if ([fTorrent icon])
		[fIconView setImage:[fTorrent icon]];
	else 
		[fIconView setImage:[UIImage imageNamed:@"question-mark.png"]];
	[fHashLabel setText:[fTorrent hashString]];
    
	[fDataLocationLabel setText:[fTorrent dataLocation]];
	[fDataLocationCell resizeToFitText];
	[fTorrentLocationLabel setText:[fTorrent torrentLocation]];
	[fTorrentLocationCell resizeToFitText];
	[fIsPrivateSwitch setOn:[fTorrent privateTorrent]];
	[fCommentLabel setText:[fTorrent comment]];
	[fCommentCell resizeToFitText];
	[fCreatorLabel setText:[fTorrent creator]];
	
    NSInteger activityTimeInSeconds = (NSInteger)[fTorrent secondsDownloading] + (NSInteger)[fTorrent secondsSeeding];
    [fTorrentActivityLabel setText:[NSString stringForTime:activityTimeInSeconds]];
    [fTorrentActivityLabel setTextAlignment:NSTextAlignmentRight];
    
	fFilesCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	fFilesCell.textLabel.text = @"Files";
	fFilesCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    fFilesCell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];

	fTrackersCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	fTrackersCell.textLabel.text = @"Trackers";
	fTrackersCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    fTrackersCell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];

    fRecheckDataCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    fRecheckDataCell.textLabel.text = @"Recheck Data";
    fRecheckDataCell.textLabel.textAlignment = NSTextAlignmentCenter;
    fRecheckDataCell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    
    fStartPauseCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if ([[fTorrent stateString] isEqualToString:@"Paused"]) fStartPauseCell.textLabel.text = @"Start";
        else fStartPauseCell.textLabel.text = @"Pause";
    fStartPauseCell.textLabel.textAlignment = NSTextAlignmentCenter;
    fStartPauseCell.textLabel.font = [UIFont boldSystemFontOfSize:16];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionStatusChanged:) name:NotificationSessionStatusChanged object:self.controller];
    
    // start timer
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateUI) userInfo:nil repeats:YES];
    [self updateUI];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationSessionStatusChanged object:self.controller];
    
    // stop timer
    [self.updateTimer invalidate];
}

- (void)startButtonClicked:(id)sender
{
	[fTorrent startTransfer];
	[self updateUI];
}

- (void)pauseButtonClicked:(id)sender
{
	[fTorrent stopTransfer];
	[self updateUI];
}

- (void)removeButtonClicked:(id)sender
{
    __weak DetailViewController *wself = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Are you sure to remove this torrent?" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Yes and remove data" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [wself performRemove:YES];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Yes but keep data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [wself performRemove:NO];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
        popoverPresentationController.barButtonItem = self.removeButton;
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)performRemove:(BOOL)trashData
{
	[self.navigationController popViewControllerAnimated:YES];	
    [self.controller removeTorrents:[NSArray arrayWithObject:self.torrent] deleteData:trashData afterDelay:0.25f];
}

- (void)sessionStatusChanged:(NSNotification*)notif
{
	[self updateUI];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case HEADER_SECTION:
			return 1;
			break;
		case STATE_SECTION:
			return displayedError ? 2 : 1;
		case SPEED_SECTION:
			return 2;
			break;
		case GENERAL_INFO_SECTION:
			return 7;
			break;
		case TRANSFER_SECTION:
			return 8;
			break;
        case ACTIONS_SECTION:
            return 2;
            break;
		case LOCATION_SECTION:
			return 2;
			break;
		case MORE_SECTION:
			return 2;
			break;
		default:
			break;
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.section) {
		case HEADER_SECTION:
			switch (indexPath.row) {
				case TITLE_ROW:
					return fTitleCell;
					break;
				default:
					break;
			}
			break;
		case STATE_SECTION:
			switch (indexPath.row) {
				case STATE_ROW:
					return fStateCell;
					break;
				case ERROR_MESSAGE_ROW:
					return fErrorMessageCell;
					break;
				default:
					break;
			}
			break;
		case SPEED_SECTION:
			switch (indexPath.row) {
				case UL_SPEED_ROW:
					return fULSpeedCell;
					break;
				case DL_SPEED_ROW:
					return fDLSpeedCell;
					break;
                case AVERAGE_UL_SPEED_ROW:
                    return fAverageULSpeedCell;
                case AVERAGE_DL_SPEED_ROW:
                    return fAverageDLSpeedCell;
				default:
					break;
			}
			break;
		case GENERAL_INFO_SECTION:
			switch (indexPath.row) {
				case HASH_ROW:
					return fHashCell;
					break;
                case MAGNET_ROW:
                    return fTorrentMagnetLinkCell;
                    break;
				case CREATOR_ROW:
					return fCreatorCell;
					break;
				case CREATED_ON_ROW:
					return fCreatedOnCell;
					break;
                case ACTIVITY_ROW:
                    return fTorrentActivityCell;
                    break;
				case COMMENT_ROW:
					return fCommentCell;
					break;
				case IS_PRIVATE_ROW:
					return fIsPrivateCell;
					break;
				default:
					break;
			}
			break;
		case TRANSFER_SECTION:
			switch (indexPath.row) {
				case TOTAL_SIZE_ROW:
					return fTotalSizeCell;
					break;
				case SIZE_COMPLETED_ROW:
					return fCompletedSizeCell;
					break;
				case PROGRESS_ROW:
					return fProgressCell;
					break;
				case UPLOADED_ROW:
					return fUploadedSizeCell;
					break;
				case DOWNLOADED_ROW:
					return fDownloadedSizeCell;
					break;
				case RATIO_ROW:
					return fRatioCell;
					break;
                case SEEDERS_ROW:
                    return fTorrentSeedersCell;
                    break;
                case PEERS_ROW:
                    return fTorrentPeersCell;
                    break;
				default:
					break;
			}
			break;
        case ACTIONS_SECTION:
            switch (indexPath.row) {
                case START_PAUSE_ROW:
                    return fStartPauseCell;
                    break;
                case RECHECK_DATA_ROW:
                    return fRecheckDataCell;
                default:
                    break;
            }
            break;
		case LOCATION_SECTION:
			switch (indexPath.row) {
				case DATA_LOCATION_ROW:
					return fDataLocationCell;
					break;
				case TORRENT_LOCATION_ROW:
					return fTorrentLocationCell;
					break;
				default:
					break;
			}
			break;
		case MORE_SECTION:
			switch (indexPath.row) {
				case FILES_ROW:
					return fFilesCell;
					break;
                case TRACKERS_ROW:
                    return fTrackersCell;
                    break;
				default:
					break;
			}
			break;

		default:
			break;
	}
	return [UITableViewCell new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
	CGFloat height = cell.bounds.size.height;
	return height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case TRANSFER_SECTION:
			return @"Transfer";
			break;
        case ACTIONS_SECTION:
            return @"Actions";
            break;
		case SPEED_SECTION:
			return @"Speed";
			break;
		case GENERAL_INFO_SECTION:
			return @"General Information";
			break;
		case LOCATION_SECTION:
			return @"Location";
			break;
		case MORE_SECTION:
			return nil;
			break;
		default:
			break;
	}
	return nil;
}

- (void)updateUI
{
    [self.startButton setEnabled:YES && (![self.torrent isActive])];
    [self.pauseButton setEnabled:YES && ([self.torrent isActive])];
    
    [fTorrent update];
    [fTotalSizeLabel setText:[NSString stringForFileSize:[fTorrent size]]];
    [fCompletedSizeLabel setText:[NSString stringForFileSize:[fTorrent haveVerified]]];
    [fProgressLabel setText:[NSString stringWithFormat:@"%.2f%%",[fTorrent progress] * 100.0f]];
    [fUploadedSizeLabel setText:[NSString stringForFileSize:[fTorrent uploadedTotal]]];
    [fDownloadedSizeLabel setText:[NSString stringForFileSize:[fTorrent downloadedTotal]]];
    [fCreatedOnLabel setText:[NSDateFormatter localizedStringFromDate:[fTorrent dateCreated] dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterShortStyle]];
    
    NSMutableArray *fPeers = [[NSMutableArray alloc] init];
    [fPeers removeAllObjects];
    [fPeers addObjectsFromArray:[fTorrent peers]];
    NSInteger totalSeeder = 0;
    NSInteger totalPeers = 0;
    for (NSDictionary *peer in fPeers) {
        BOOL isSeed = [[peer valueForKey:@"Seed"] boolValue];
        if (isSeed) {
            totalSeeder = totalSeeder + 1;
        } else {
            totalPeers = totalPeers + 1;
        }
    }
    totalSeeder = (NSInteger)totalSeeder + (NSInteger)[fTorrent webSeedCount];
    [fTorrentSeedersLabel setText:[NSString stringWithFormat:@"%ld", totalSeeder]];
    [fTorrentPeersLabel setText:[NSString stringWithFormat:@"%ld", totalPeers]];
    
    NSInteger activityTimeInSeconds = (NSInteger)[fTorrent secondsDownloading] + (NSInteger)[fTorrent secondsSeeding];
    [fTorrentActivityLabel setText:[NSString stringForTime:activityTimeInSeconds]];
    [fTorrentActivityLabel setTextAlignment:NSTextAlignmentRight];

	BOOL hasError = [fTorrent isAnyErrorOrWarning];
	if (hasError) {
		if (!displayedError) {
            displayedError = YES;
            [fErrorMessageLabel setText:[self.torrent errorMessage]];
            [fErrorMessageCell resizeToFitText];
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:ERROR_MESSAGE_ROW inSection:STATE_SECTION]] withRowAnimation:UITableViewRowAnimationTop];
		}
		
	}
	else {
		if (displayedError) {
            displayedError = NO;
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:ERROR_MESSAGE_ROW inSection:STATE_SECTION]] withRowAnimation:UITableViewRowAnimationTop];
		}
	}
    
    if ([[fTorrent stateString] isEqualToString:@"Downloading"]) [fStartPauseButton setTitle:@"Start" forState:UIControlStateNormal];
        else [fStartPauseButton setTitle:@"Pause" forState:UIControlStateNormal];
	
	[fStateLabel setText:[fTorrent stateString]];
	[fRatioLabel setText:[NSString stringForRatio:[fTorrent ratio]]];
	
	[fULSpeedLabel setText:[NSString stringForSpeed:[fTorrent uploadRate]]];
	[fDLSpeedLabel setText:[NSString stringForSpeed:[fTorrent downloadRate]]];
}

@end
