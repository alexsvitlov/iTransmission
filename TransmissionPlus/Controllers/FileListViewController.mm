//
//  FileListViewController.m
//  iTransmission
//
//  Created by Mike Chen on 7/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileListViewController.h"
#import "FileListCell.h"
#import "Torrent.h"
#import "FileListNode.h"
#import "NSStringAdditions.h"
#import "AppDelegate.h"
#import "AudioPlayer.h"
#import "FileUtils.h"

#define NSOffState 0
#define NSOnState 1
#define NSMixedState 2

@implementation FileListViewController {
    Torrent *fTorrent;
    UITableView *fTableView;
    UIDocumentInteractionController *_docController;
}
@synthesize torrent = fTorrent;
@synthesize tableView = fTableView;
@synthesize docController = _docController;
@synthesize path;
@synthesize actionIndexPath;

- (void)initWithTorrent:(Torrent*)t
{
    fTorrent = t;
    self.title = @"Files";
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.torrent update];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];
    
    // start timer
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateUI) userInfo:nil repeats:YES];
    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // stop timer
    [self.updateTimer invalidate];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return (NSInteger)[[self.torrent flatFileList] count];
            break;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FileListCell *cell = nil;
    
    cell = (FileListCell*)[tableView dequeueReusableCellWithIdentifier:@"FileListCell"];
    
    if (cell == nil) {
        cell = [FileListCell cellFromNib];
    }
    
    FileListNode *node = [[self.torrent flatFileList] objectAtIndex:(NSUInteger)indexPath.row];
    cell.filenameLabel.text = node.name;
    cell.sizeLabel.text = [NSString stringForFileSize:node.size];
    cell.progressLabel.text = [NSString percentString:[self.torrent fileProgress:node] longDecimals:NO];
    
    if ([self.torrent canChangeDownloadCheckForFiles:node.indexes]) {
        cell.checkbox.hidden = NO;
        cell.checkbox.checked = [self.torrent checkForFiles:node.indexes] == NSOnState ? YES : NO; 
        cell.checkbox.delegate = self;
        cell.checkbox.backwardReference = cell;
    }
    else {
        cell.checkbox.hidden = YES;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0f;
}

- (void)updateCell:(FileListCell*)c
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:c];
	if (indexPath) {
		FileListNode *node = [[self.torrent flatFileList] objectAtIndex:(NSUInteger)indexPath.row];
        c.progressLabel.text = [NSString percentString:[self.torrent fileProgress:node] longDecimals:NO];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FileListNode *node = [[self.torrent flatFileList] objectAtIndex:(NSUInteger)indexPath.row];
    NSString *p = [[[(AppDelegate *)[UIApplication sharedApplication].delegate defaultDownloadDir] stringByAppendingPathComponent:[node path]] stringByAppendingPathComponent:[node name]];
    NSLog(@"Path : %@",p);
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
        NSLog(@"OpenClicked");

        FileListCell *cell = (FileListCell*)[self.tableView cellForRowAtIndexPath:indexPath];

        self.docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:p]];
        self.docController.delegate = self;
        [self.docController presentOpenInMenuFromRect:CGRectMake(0.0, 0.0, cell.contentView.frame.size.width, 20.0) inView:cell.contentView animated:YES];
    } else {
        if (![self.torrent canChangeDownloadCheckForFiles:node.indexes]) {
            NSLog(@"[torrent canChangeDownloadCheckForFiles] returned false");
            return;
        }
        
        NSInteger state = [self.torrent checkForFiles:node.indexes];
        if (state == NSOnState) {
            state = NSOffState;
        }
        else {
            state = NSOnState;
        }
        
        [self.torrent setFileCheckState:state forIndexes:node.indexes];
        
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)viewDocument:(NSString *)url
{
    self.docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:url]];
    self.docController.delegate = self;
    [self.docController presentPreviewAnimated:YES];
}

- (void)updateUI
{
    [self.torrent update];
        
    for (FileListCell *cell in [self.tableView visibleCells]) {
        [self performSelector:@selector(updateCell:) withObject:cell afterDelay:0.0f];
    }
}

- (void)checkbox:(id)checkbox hasChangedState:(BOOL)checked
{
    UITableViewCell *cell = (UITableViewCell*)[checkbox backwardReference];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[self.tableView indexPathForCell:cell]] withRowAnimation:UITableViewRowAnimationNone];
}


#pragma mark -
#pragma mark UIDocumentInteractionControllerDelegate methods

//TODO: Alex
- (void) documentInteractionControllerWillPresentOpenInMenu:(UIDocumentInteractionController *)controller
{
    NSLog(@"Test");
    // check for filetype
    switch ([FileUtils fileType:[controller.URL absoluteString]]) {
        case TYPE_VIDEO:
        {
            NSLog(@"Type video");
        }
        break;
        
        case TYPE_AUDIO:
        {
            NSLog(@"Type audio");
        }
        break;
            
        case TYPE_PICTURE:
        {
            NSLog(@"Type picture");
        }
        break;
            
        case TYPE_TXT:
        {
            NSLog(@"Type txt");
        }
        break;
            
        case TYPE_PDF:
        {
            NSLog(@"Type pdf");
        }
        break;
            
        case TYPE_NULL:
        {
            NSLog(@"Unknown type");
        }
        break;
            
        default:
            break;
    }
}

- (void) documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
	
}

- (void) documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
	
}

- (UIViewController *) documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
	return self;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
	return self.navigationController.view;
}

- (CGRect) documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller {
	return self.view.frame;
}

- (void) documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
	
}

@end
