//
//  AppDelegate.h
//  TransmissionPlus
//
//  Created by Alex Svitlov on 04/12/2023.
//  Copyright © 2023 The Transmission Project. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <libtransmission/transmission.h>

@class TorrentViewController;
@class Torrent;

typedef NS_ENUM(NSUInteger, AddType) { //
    AddTypeManual,
    AddTypeAuto,
    AddTypeShowOptions,
    AddTypeURL,
    AddTypeCreated
};

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) TorrentViewController *torrentViewController;

- (void)removeTorrents:(NSArray<Torrent*>*)torrents deleteData:(BOOL)deleteData afterDelay:(NSTimeInterval)delay;
- (void)removeTorrents:(NSArray<Torrent*>*)torrents deleteData:(BOOL)deleteData;

- (tr_session*)sessionHandle;
- (void)rpcCallback:(tr_rpc_callback_type)type forTorrentStruct:(struct tr_torrent*)torrentStruct;
- (void)altSpeedToggledCallbackIsLimited:(NSDictionary*)dict;
- (BOOL)openURL:(NSString*)urlString;
- (BOOL)openFilePathURL:(NSURL *)url shouldOpenInPlace:(BOOL)shouldOpenInPlace;
- (NSUInteger)torrentsCount;
- (Torrent*)torrentAtIndex:(NSInteger)index;
- (NSString*)documentsDirectory;
- (NSString*)defaultDownloadDir;
- (void)setGlobalUploadSpeedLimit:(NSInteger)kbytes;
- (void)setGlobalUploadSpeedLimitEnabled:(BOOL)enabled;
- (void)setGlobalDownloadSpeedLimitEnabled:(BOOL)enabled;
- (BOOL)globalUploadSpeedLimitEnabled;
- (BOOL)globalDownloadSpeedLimitEnabled;
- (void)setGlobalDownloadSpeedLimit:(NSInteger)kbytes;
- (NSInteger)globalDownloadSpeedLimit;
- (NSInteger)globalUploadSpeedLimit;
- (void)setGlobalMaximumConnections:(NSInteger)c;
- (NSInteger)globalMaximumConnections;
- (void)setConnectionsPerTorrent:(NSInteger)c;
- (NSInteger)connectionsPerTorrent;
- (void)postError:(NSString *)err_msg;
- (void)postMessage:(NSString*)msg;
- (void)postFinishMessage:(NSString*)msg;

@end

