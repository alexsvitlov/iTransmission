//
//  CheckboxControl.m
//  iTransmission
//
//  Created by Mike Chen on 7/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CheckboxControl.h"

@implementation CheckboxControl {
    BOOL checked;
    UIImageView *fImageView;
    UIImage *fUncheckedImage;
    UIImage *fCheckedImage;
}

@synthesize imageView = fImageView;
@synthesize checked;
@synthesize delegate;
@synthesize checkedImage = fCheckedImage;
@synthesize uncheckedImage = fUncheckedImage;
@synthesize backwardReference = fBackwardReference;

- (id)initWithCoder:(NSCoder*)c {
    if ((self = [super initWithCoder:c])) {
        self.checkedImage = [UIImage imageNamed: @"blue-check-selected-icon.png"];
        self.uncheckedImage = [UIImage imageNamed: @"blue-check-unselected-icon.png"];
        self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:self.imageView];
    
        self.imageView.image = self.checkedImage;
        
        [self addTarget:self action: @selector(toggle) forControlEvents: UIControlEventTouchUpInside];
    }
    return self;
}

- (void)toggle {
    [self setChecked:!checked];
    [self.delegate checkbox:self hasChangedState:checked];
}

- (void)setChecked:(BOOL)c
{
    checked = c;
    self.imageView.image = (checked ? self.checkedImage : self.uncheckedImage); 
}

@end
