//
//  FileListCell.m
//  iTransmission
//
//  Created by Mike Chen on 7/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileListCell.h"

@implementation FileListCell {
    UILabel *fFilenameLabel;
    UILabel *fSizeLabel;
    UILabel *fProgressLabel;
    CheckboxControl *fCheckbox;
}

@synthesize filenameLabel = fFilenameLabel;
@synthesize sizeLabel = fSizeLabel;
@synthesize progressLabel = fProgressLabel;
@synthesize checkbox = fCheckbox;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

+ (id)cellFromNib
{
    NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"FileListCell" owner:nil options:nil];
    FileListCell *cell = (FileListCell*)[objects objectAtIndex:0];
        
    return cell;
}

@end
