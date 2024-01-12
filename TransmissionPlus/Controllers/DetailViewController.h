//
//  DetailViewController.h
//  iTransmission
//
//  Created by Mike Chen on 10/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Torrent;
@class AppDelegate;
@class FlexibleLabelCell;

@interface DetailViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, assign) Torrent *torrent;
@property (nonatomic, strong) UIBarButtonItem *startButton;
@property (nonatomic, strong) UIBarButtonItem *pauseButton;
@property (nonatomic, strong) UIBarButtonItem *removeButton;
@property (nonatomic, strong) UIBarButtonItem *refreshButton;
@property (nonatomic, strong) UIBarButtonItem *bandwidthButton;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) AppDelegate *controller;
@property (nonatomic, strong) NSTimer *updateTimer;

- (void)initWithTorrent:(Torrent*)t controller:(AppDelegate*)c;

- (void)startButtonClicked:(id)sender;
- (void)pauseButtonClicked:(id)sender;
- (void)removeButtonClicked:(id)sender;
- (void)sessionStatusChanged:(NSNotification*)notif;
- (void)bandwidthButtonClicked:(id)sender;

- (void)performRemove:(BOOL)trashData;

@end
