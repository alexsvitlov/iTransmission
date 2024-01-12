//
//  FileUtils.m
//  TransmissionPlus
//
//  Created by Alex Svitlov on 08/01/2024.
//  Copyright © 2024 The Transmission Project. All rights reserved.
//

#import "FileUtils.h"

@implementation FileUtils

+ (UIImage *)imageForPath:(NSString *)url {
    NSString *extension = [url pathExtension];
    
    if (extension == nil || [extension length] == 0) {
        return [UIImage imageNamed:@"folder-icon"];
    }
    
    FileType fileType = [FileUtils fileType:url];
    
    switch(fileType) {
        case TYPE_VIDEO:
            return [UIImage imageNamed:@"video-icon"];
        case TYPE_AUDIO:
            return [UIImage imageNamed:@"audio-icon"];
        case TYPE_PICTURE:
            return [UIImage imageNamed:@"image-icon"];
        case TYPE_TXT:
            return [UIImage imageNamed:@"text-icon"];
        case TYPE_PDF:
            return [UIImage imageNamed:@"pdf-icon"];
        case TYPE_ZIP:
            return [UIImage imageNamed:@"zip-icon"];
        case TYPE_RAR:
            return [UIImage imageNamed:@"rar-icon"];
        case TYPE_WORD:
            return [UIImage imageNamed:@"word-icon"];
        case TYPE_PPT:
            return [UIImage imageNamed:@"ppt-icon"];
       case TYPE_EXCEL:
            return [UIImage imageNamed:@"excel-icon"];
        case TYPE_HTML:
            return [UIImage imageNamed:@"html-icon"];
        case TYPE_DOCUMENT:
            return [UIImage imageNamed:@"docs-icon"];
        default:
            return [UIImage imageNamed:@"file-icon"];
    }
}

+ (FileType)fileType:(NSString *)url
{
    NSArray *audioTypes = [NSArray arrayWithObjects:@"mp3", @"aac", @"adts", @"ac3", @"aif", @"aiff", @"aifc", @"caf", @"m4a", @"snd", @"au", @"sd2", @"wav", nil];
    NSArray *videoTypes = [NSArray arrayWithObjects:@"avi", @"mp4", @"fla", @"wmv", @"mkv", @"mov", @"mpg", @"m4v", nil];
    NSArray *imageTypes = [NSArray arrayWithObjects:@"tiff", @"jpeg", @"jpg", @"gif", @"png", @"dib", @"ico", @"cur", @"xbm", nil];
    NSArray *documentTypes = [NSArray arrayWithObjects:@"rtf", @"numbers", @"vcf", @"key", @"xml", @"pages", nil];
    NSString *extension = [url pathExtension];
    
    // check for music
    for(NSUInteger i = 0; i < [audioTypes count]; i++)
    {
        if([audioTypes[i] compare:extension options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            return TYPE_AUDIO;
        }
    }
    
    // check for video
    for(NSUInteger i = 0; i < [videoTypes count]; i++)
    {
        if([videoTypes[i] compare:extension options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            return TYPE_VIDEO;
        }
    }
    
    // check for image
    for(NSUInteger i = 0; i < [imageTypes count]; i++)
    {
        if([imageTypes[i] compare:extension options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            return TYPE_PICTURE;
        }
    }
    
    // check for document
    for(NSUInteger i = 0; i < [documentTypes count]; i++)
    {
        if([documentTypes[i] compare:extension options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            return TYPE_DOCUMENT;
        }
    }
    
    // check for pdf
    if([extension compare:@"pdf" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_PDF;
    }
    
    // check for txt
    if([extension compare:@"txt" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_TXT;
    }
    
    if([extension compare:@"zip" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_ZIP;
    }
    
    if([extension compare:@"rar" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_ZIP;
    }
    
    if([extension compare:@"doc" options:NSCaseInsensitiveSearch] == NSOrderedSame
    || [extension compare:@"docx" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_WORD;
    }
    
    if([extension compare:@"ppt" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [extension compare:@"pptx" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_PPT;
    }
    
    if([extension compare:@"xls" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [extension compare:@"xlsx" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_EXCEL;
    }
    
    if([extension compare:@"html" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [extension compare:@"htm" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        return TYPE_HTML;
    }
    
    return TYPE_NULL;
}

@end
