//
//  TackersController.h
//  iTransmission
//
//  Created by Dhruvit Raithatha on 16/12/13.
//
//

#import <Foundation/Foundation.h>
#import "Torrent.h"
#import "TrackerNode.h"
#import "NSStringAdditions.h"

@class Torrent, TrackerCell;

@interface TrackersViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong, readonly) Torrent *torrent;
@property (nonatomic, strong) IBOutlet UITableView *tableView;

- (void)initWithTorrent:(Torrent*)t;

- (void)editButtonTouched;

- (void)addButtonTouched;

- (void)removeButtonTouched;
- (void)reloadTrackers;

@end
