//
//  TackersController.m
//  iTransmission
//
//  Created by Dhruvit Raithatha on 16/12/13.
//
//

#import "TrackersViewController.h"
#import "TrackerCell.h"

#define ADD_FROM_URL 010
#define ADD_TRACKER_BUTTON 1002
#define REMOVE_TRACKER_BUTTON 1003

@interface TrackersViewController()

@property (nonatomic, strong) Torrent *fTorrent;
@property (nonatomic, strong) NSMutableArray *trackers;
@property (nonatomic, strong) NSMutableArray *selectedItems;
@property (nonatomic, strong) NSTimer *updateTimer;

@end

@implementation TrackersViewController

- (void)initWithTorrent:(Torrent*)t {
    _fTorrent = t;
    self.title = @"Trackers";
    self.selectedItems = [[NSMutableArray alloc] init];
    self.trackers = [[NSMutableArray alloc] init];
    [self reloadTrackers];
}

- (void)viewDidLoad {
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonTouched)];
    [self.navigationItem setRightBarButtonItem:editButton animated:YES];
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonTouched)];
    UIBarButtonItem *removeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(removeButtonTouched)];
    UIBarButtonItem *emptyButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:@selector(addButtonTouched)];
    [addButton setTag:ADD_TRACKER_BUTTON];
    [removeButton setTag:REMOVE_TRACKER_BUTTON];
    [addButton setEnabled:NO];
    [removeButton setEnabled:NO];
    [self setToolbarItems:[NSArray arrayWithObjects:emptyButton, addButton, emptyButton, removeButton, emptyButton, nil]];
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"TrackerCell" bundle:nil] forCellReuseIdentifier:@"TrackerCell"];

}

- (void)reloadTrackers {
    [self.trackers removeAllObjects];
    for (id object in [self.fTorrent allTrackerStats]) {
        if ([object isKindOfClass:[TrackerNode class]]) {
            if (object != nil) {
                [self.trackers addObject:object];
            }
        }
    }
}

- (void)addButtonTouched {
    __weak TrackersViewController *wself = self;

    UIAlertController *dialog = [UIAlertController alertControllerWithTitle:@"Add Tracker" message:@"Enter the full tracker URL" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *url = dialog.textFields.firstObject.text;
        BOOL exists = NO;
        for (TrackerNode *node in wself.trackers) {
            if (!exists) {
                if ([node fullAnnounceAddress] == url) {
                    exists = YES;
                }
            }
        }
        if (![url hasPrefix:@"http://"] || ![url hasPrefix:@"https://"] || ![url hasPrefix:@"udp://"] || exists) {
            NSString *message = !exists ? @"The URL you entered is invalid. Just where did you get it?" : @"A tracker with the same URL already exists, so both of them are the same trackers.";
            UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alertVC addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
            [wself presentViewController:alertVC animated:YES completion:nil];
        } else {
            [wself.fTorrent addTrackerToNewTier:url];
            
            [wself reloadTrackers];
            [wself.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationLeft];
            [wself.tableView reloadData];
        }
    }];
    [dialog addAction:okAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [dialog addAction:cancelAction];
    
    [dialog addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Enter tracker URL";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.enablesReturnKeyAutomatically = YES;
        textField.keyboardAppearance = UIKeyboardAppearanceDefault;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.returnKeyType = UIReturnKeyDone;
        textField.secureTextEntry = NO;
    }];
    [self presentViewController:dialog animated:YES completion:nil];
}

- (void)removeButtonTouched {
    for (NSString *address in self.selectedItems) {
        TrackerNode *tracker = [self _trackerNodeByAddress:address];
        if (tracker) {
            [self.fTorrent removeTrackers:[NSSet setWithObject:tracker.fullAnnounceAddress]];
        }
    }
    [self reloadTrackers];
    [self.tableView reloadData];
}
- (void)editButtonTouched {
    for (UIBarButtonItem *item in self.toolbarItems) {
        if (item.tag == ADD_TRACKER_BUTTON) {
            [item setEnabled:YES];
        }
    }
    [self.tableView setEditing:YES animated:YES];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(doneButtonTouched)];
    [self.navigationItem setRightBarButtonItem:doneButton animated:YES];
}

- (void)doneButtonTouched {
    for (UIBarButtonItem *item in self.toolbarItems) {
        [item setEnabled:NO];
    }
    [self.tableView setEditing:NO animated:YES];
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                target:self
                                                                                action:@selector(editButtonTouched)];
    [self.navigationItem setRightBarButtonItem:editButton animated:YES];
    
    [self.selectedItems removeAllObjects];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.editing == NO) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        for (UIBarButtonItem *item in self.toolbarItems) {
            if (item.tag == REMOVE_TRACKER_BUTTON) {
                [item setEnabled:YES];
            }
        }
        NSString *address = ((TrackerNode *)self.trackers[indexPath.row]).fullAnnounceAddress;
        [self.selectedItems addObject:address];
    }
    [self reloadTrackers];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    TrackerNode *tracker = self.trackers[indexPath.row];
    if ([self.selectedItems containsObject:tracker.fullAnnounceAddress]) {
        [self.selectedItems removeObject:tracker.fullAnnounceAddress];
    }
    if ([self.selectedItems count] == 0) {
        for (UIBarButtonItem *item in self.toolbarItems) {
            if (item.tag == REMOVE_TRACKER_BUTTON) {
                NSLog(@"Disabling Delete");
                [item setEnabled:NO];
            }
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // start timer
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateUI) userInfo:nil repeats:YES];
    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // start timer
    [self.updateTimer invalidate];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //NSLog(@"Count: %lu", (unsigned long)[self.trackers count]);
    switch (section) {
        case 0:
            return (NSInteger)[self.trackers count];
            break;
        default:
            break;
    }
    return 0;
}

- (void)updateUI {
    for (TrackerCell *cell in [self.tableView visibleCells]) {
        [self _setupCell:cell index:[self.tableView indexPathForCell:cell].row];
    }
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TrackerCell *cell = (TrackerCell*)[tableView dequeueReusableCellWithIdentifier:@"TrackerCell" forIndexPath:indexPath];
    [self _setupCell:cell index:indexPath.row];
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleNone;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 90.0f;
}

//document interaction
- (void) documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
	
}
- (void) documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
	
}
- (void) documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
	
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

#pragma mark -

- (void)_setupCell:(TrackerCell *)cell index:(NSUInteger)index {
    TrackerNode *node = [self.trackers objectAtIndex:index];
    
    cell.TrackerURL.text = node.fullAnnounceAddress;
    
    cell.TrackerLastAnnounceTime.text = node.lastAnnounceStatusString;
    
    if (!([node totalSeeders]) || [node totalSeeders] == -1) {
        cell.SeedNumber.text = @"0";
    } else {
        cell.SeedNumber.text = [NSString stringWithFormat:@"%ld", (long)[node totalSeeders]];
    }
    
    if (!([node totalLeechers]) || [node totalLeechers] == -1) {
        cell.PeerNumber.text = @"0";
    } else {
        cell.PeerNumber.text = [NSString stringWithFormat:@"%ld", (long)[node totalLeechers]];
    }
    BOOL isSelected = [self.selectedItems containsObject:[node fullAnnounceAddress]];
    [cell setSelected:isSelected];
}

- (TrackerNode *)_trackerNodeByAddress:(NSString *)address {
    for (TrackerNode *tracker in self.trackers) {
        if ([tracker.fullAnnounceAddress isEqualToString:address]) {
            return tracker;
        }
    }
    return nil;
}

@end
