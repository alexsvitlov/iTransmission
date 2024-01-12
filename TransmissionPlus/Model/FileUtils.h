//
//  FileUtils.h
//  TransmissionPlus
//
//  Created by Alex Svitlov on 08/01/2024.
//  Copyright © 2024 The Transmission Project. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;

typedef enum FileType
{
    TYPE_VIDEO,
    TYPE_AUDIO,
    TYPE_PICTURE,
    TYPE_TXT,
    TYPE_PDF,
    TYPE_ZIP,
    TYPE_RAR,
    TYPE_WORD,
    TYPE_PPT,
    TYPE_EXCEL,
    TYPE_HTML,
    TYPE_DOCUMENT,
    TYPE_NULL,
} FileType;

NS_ASSUME_NONNULL_BEGIN

@interface FileUtils : NSObject

+ (UIImage *)imageForPath:(NSString *)url;

+ (FileType)fileType:(NSString*)url;

@end

NS_ASSUME_NONNULL_END
