//
//  FlexibleLabelCell.h
//  iTransmission
//
//  Created by Mike Chen on 10/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface FlexibleLabelCell : UITableViewCell
@property (nonatomic, strong) IBOutlet UILabel *flexibleLabel;

- (void)resizeToFitText;

@end
