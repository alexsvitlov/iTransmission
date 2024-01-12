//
//  AppShareItem.m
//  TransmissionPlus
//
//  Created by Alex Svitlov on 10/01/2024.
//  Copyright © 2024 The Transmission Project. All rights reserved.
//

#import "AppShareItem.h"

@implementation AppShareItem

- (nullable id)activityViewController:(nonnull UIActivityViewController *)activityViewController itemForActivityType:(nullable UIActivityType)activityType { 
    return @"Download iTransmission, fast and effective torrent client for iOS https://github.com/alexsvitlov/itransmission";
}

- (nonnull id)activityViewControllerPlaceholderItem:(nonnull UIActivityViewController *)activityViewController { 
    return @"";
}

@end
