//
//  CheckboxControl.h
//  iTransmission
//
//  Created by Mike Chen on 7/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CheckboxControlDelegate <NSObject>
- (void)checkbox:(id)checkbox hasChangedState:(BOOL)checked;
@end

@interface CheckboxControl : UIControl

@property (nonatomic, assign) BOOL checked;
@property (nonatomic, assign) id<CheckboxControlDelegate> delegate;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImage *checkedImage;
@property (nonatomic, strong) UIImage *uncheckedImage;
@property (nonatomic, assign) id<NSObject> backwardReference;
- (void)toggle;

@end
