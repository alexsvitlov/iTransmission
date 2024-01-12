//
//  TrackerCell.h
//  iTransmission
//
//  Created by Dhruvit Raithatha on 02/12/13.
//
//

#import <UIKit/UIKit.h>

@interface TrackerCell : UITableViewCell


@property (nonatomic, strong) IBOutlet UILabel *TrackerURL;
@property (nonatomic, strong) IBOutlet UILabel *TrackerLastAnnounceTime;
@property (nonatomic, strong) IBOutlet UILabel *SeedLabel;
@property (nonatomic, strong) IBOutlet UILabel *SeedNumber;
@property (nonatomic, strong) IBOutlet UILabel *PeerLabel;
@property (nonatomic, strong) IBOutlet UILabel *PeerNumber;

@end
