//
//  FileListCell.h
//  iTransmission
//
//  Created by Mike Chen on 7/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CheckboxControl.h"

@interface FileListCell : UITableViewCell
@property (nonatomic, strong) IBOutlet UILabel* filenameLabel;
@property (nonatomic, strong) IBOutlet UILabel* sizeLabel;
@property (nonatomic, strong) IBOutlet UILabel *progressLabel;
@property (nonatomic, strong) IBOutlet CheckboxControl *checkbox;

+ (id)cellFromNib;

@end
