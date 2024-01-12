//
//  FileListViewController.h
//  iTransmission
//
//  Created by Mike Chen on 7/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CheckboxControl.h"

@class Torrent, FileListCell;
@interface FileListViewController : UIViewController <CheckboxControlDelegate,UITableViewDataSource, UITableViewDelegate, UIDocumentInteractionControllerDelegate>
@property (nonatomic, readonly) Torrent *torrent;
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) UIDocumentInteractionController *docController;
@property (nonatomic, retain) NSTimer *updateTimer;
@property (nonatomic, retain) NSString *path;
@property (nonatomic, retain) NSIndexPath *actionIndexPath;

- (void)initWithTorrent:(Torrent*)t;
- (void)updateCell:(FileListCell*)cell;
- (void)viewDocument:(NSString*)url;

@end
