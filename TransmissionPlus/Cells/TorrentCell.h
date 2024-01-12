//
//  TorrentCell.h
//  iTransmission
//
//  Created by Mike Chen on 10/3/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#define TorrentCellIdentifier @"TorrentCellIdentifier"

@class ControlButton;
@interface TorrentCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UILabel *upperDetailLabel;
@property (nonatomic, strong) IBOutlet UILabel *lowerDetailLabel;
@property (nonatomic, strong) IBOutlet ControlButton *controlButton;

- (IBAction)pausedPressed:(id)sender;
- (void)useGreenColor;
- (void)useBlueColor;

@end
