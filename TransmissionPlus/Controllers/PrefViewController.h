//
//  PrefViewController.h
//  iTransmission
//
//  Created by Mike Chen on 10/3/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class PortChecker;
@class AppDelegate;

@interface PrefViewController :UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (nonatomic, strong) PortChecker *portChecker;
@property (nonatomic, strong) NSDictionary *originalPreferences;
@property (nonatomic, assign) AppDelegate *controller;

- (void)portCheckButtonClicked;

- (void)loadPreferences;

- (IBAction)enableBackgroundDownloadSwitchChanged:(id)sender;

- (IBAction)uploadSpeedLimitEnabledValueChanged:(id)sender;
- (IBAction)downloadSpeedLimitEnabledValueChanged:(id)sender;
- (IBAction)connectionsPerTorrentChanged:(id)sender;
- (IBAction)maximumConnectionsPerTorrentChanged:(id)sender;

+ (NSInteger)dateToTimeSum:(NSDate*)date;

@end
