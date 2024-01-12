//
//  TrackerCell.m
//  iTransmission
//
//  Created by Dhruvit Raithatha on 02/12/13.
//
//

#import "TrackerCell.h"

@implementation TrackerCell {
    UILabel *fURL;
    UILabel *fTime;
    UILabel *fTimeLabel;
    UILabel *fSeedLabel;
    UILabel *fSeedNumber;
    UILabel *fPeerLabel;
    UILabel *fPeerNumber;
}

@synthesize TrackerLastAnnounceTime = fTime;
@synthesize TrackerURL = fURL;
@synthesize SeedNumber = fSeedNumber;
@synthesize SeedLabel = fSeedLabel;
@synthesize PeerNumber = fPeerNumber;
@synthesize PeerLabel = fPeerLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

@end
