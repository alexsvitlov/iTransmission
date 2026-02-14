//
//  AppDelegate.m
//  TransmissionPlus
//
//  Created by Alex Svitlov on 04/12/2023.
//  Copyright © 2023 The Transmission Project. All rights reserved.
//

#import "AppDelegate.h"
@import UserNotifications;
@import Network;
#include <atomic> /* atomic, atomic_fetch_add_explicit, memory_order_relaxed */

#include <libtransmission/transmission.h>
#include <libtransmission/log.h>
#include <libtransmission/torrent-metainfo.h>
#include <libtransmission/utils.h>
#include <libtransmission/values.h>
#include <libtransmission/variant.h>

#import "TorrentViewController.h"
#import "Torrent.h"
#import "NSMutableArrayAdditions.h"
#import "NSStringAdditions.h"
#import "PrefViewController.h"
#import "Notifications.h"
#import "UIApplication+TopViewControllerUtil.h"
#import "WebViewController.h"
@import FirebaseCore;

static void initUnits()
{
    using Config = libtransmission::Values::Config;

    // use a random value to avoid possible pluralization issues with 1 or 0 (an example is if we use 1 for bytes,
    // we'd get "byte" when we'd want "bytes" for the generic libtransmission value at least)
    int const ArbitraryPluralNumber = 17;

    NSByteCountFormatter* unitFormatter = [[NSByteCountFormatter alloc] init];
    unitFormatter.includesCount = NO;
    unitFormatter.allowsNonnumericFormatting = NO;
    unitFormatter.allowedUnits = NSByteCountFormatterUseBytes;
    NSString* b_str = [unitFormatter stringFromByteCount:ArbitraryPluralNumber];
    unitFormatter.allowedUnits = NSByteCountFormatterUseKB;
    NSString* k_str = [unitFormatter stringFromByteCount:ArbitraryPluralNumber];
    unitFormatter.allowedUnits = NSByteCountFormatterUseMB;
    NSString* m_str = [unitFormatter stringFromByteCount:ArbitraryPluralNumber];
    unitFormatter.allowedUnits = NSByteCountFormatterUseGB;
    NSString* g_str = [unitFormatter stringFromByteCount:ArbitraryPluralNumber];
    unitFormatter.allowedUnits = NSByteCountFormatterUseTB;
    NSString* t_str = [unitFormatter stringFromByteCount:ArbitraryPluralNumber];
    Config::Memory = { Config::Base::Kilo, b_str.UTF8String, k_str.UTF8String,
                       m_str.UTF8String,   g_str.UTF8String, t_str.UTF8String };
    Config::Storage = { Config::Base::Kilo, b_str.UTF8String, k_str.UTF8String,
                        m_str.UTF8String,   g_str.UTF8String, t_str.UTF8String };

    b_str = NSLocalizedString(@"B/s", "Transfer speed (bytes per second)");
    k_str = NSLocalizedString(@"KB/s", "Transfer speed (kilobytes per second)");
    m_str = NSLocalizedString(@"MB/s", "Transfer speed (megabytes per second)");
    g_str = NSLocalizedString(@"GB/s", "Transfer speed (gigabytes per second)");
    t_str = NSLocalizedString(@"TB/s", "Transfer speed (terabytes per second)");
    Config::Speed = { Config::Base::Kilo, b_str.UTF8String, k_str.UTF8String,
                      m_str.UTF8String,   g_str.UTF8String, t_str.UTF8String };
}

static void altSpeedToggledCallback([[maybe_unused]] tr_session* handle, bool active, bool byUser, void* controller)
{
    NSDictionary* dict = @{@"Active" : @(active), @"ByUser" : @(byUser)};
    [(__bridge AppDelegate*)controller performSelectorOnMainThread:@selector(altSpeedToggledCallbackIsLimited:) withObject:dict
                                                    waitUntilDone:NO];
}

static tr_rpc_callback_status rpcCallback([[maybe_unused]] tr_session* handle, tr_rpc_callback_type type, struct tr_torrent* torrentStruct, void* controller)
{
    [(__bridge AppDelegate*)controller rpcCallback:type forTorrentStruct:torrentStruct];
    return TR_RPC_NOREMOVE; //we'll do the remove manually
}


@interface AppDelegate () <NSURLSessionDataDelegate>

@property(nonatomic, readonly) tr_session* fLib;

@property(nonatomic, readonly) NSMutableArray<Torrent*>* fTorrents;
@property(nonatomic, readonly) NSMutableArray* fDisplayedTorrents;
@property(nonatomic, readonly) NSMutableDictionary<NSString*, Torrent*>* fTorrentHashes;
@property(nonatomic) NSMutableSet<Torrent*>* fAddingTransfers;
@property(nonatomic, readonly) NSUserDefaults* fDefaults;
@property(nonatomic) NSURLSession* fSession;
@property(nonatomic) nw_path_monitor_t pathMonitor;
@property(nonatomic) NSMutableSet<NSString*>* wifiPausedHashes;

@end

@implementation AppDelegate

@synthesize window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [FIRApp configure];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_Storyboard" bundle:nil];
    
    // init torrent view controller
    self.torrentViewController = [storyboard instantiateViewControllerWithIdentifier:@"torrent_view"];
    self.torrentViewController.controller = self;

    // user notifications
    UNNotificationAction* actionShow = [UNNotificationAction actionWithIdentifier:@"actionShow"
                                                                            title:NSLocalizedString(@"Show", "notification button")
                                                                          options:UNNotificationActionOptionForeground];
    UNNotificationCategory* categoryShow = [UNNotificationCategory categoryWithIdentifier:@"categoryShow" actions:@[ actionShow ]
                                                                        intentIdentifiers:@[]
                                                                                  options:UNNotificationCategoryOptionNone];
    [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:[NSSet setWithObject:categoryShow]];
    [UNUserNotificationCenter.currentNotificationCenter
        requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
                      completionHandler:^(BOOL /*granted*/, NSError* _Nullable error) {
                          if (error.code > 0)
                          {
                              NSLog(@"UserNotifications not configured: %@", error.localizedDescription);
                          }
                      }];
    
    [self fixDocumentsDirectory];
    [self transmissionInitialize];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {

    BOOL isMagnetUrl = [self isMagnet:url];
    if (isMagnetUrl && [UIApplication.sharedApplication.topViewController isKindOfClass:[WebViewController class]]) {
        return NO;
    }
    
    if (isMagnetUrl) {
        return [self openURL:[url absoluteString]];
    }
    
    BOOL shouldOpenInPlace = [options[UIApplicationOpenURLOptionsOpenInPlaceKey] boolValue];
    return [self openFilePathURL:url shouldOpenInPlace:shouldOpenInPlace];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    //remove all torrent downloads
    [self.fSession invalidateAndCancel];
    [self updateTorrentHistory];
    //complete cleanup
    tr_sessionClose(self.fLib);
}

- (tr_session*)sessionHandle {
    return self.fLib;
}

void onStartQueue(tr_session* /*session*/, tr_torrent* tor, void* vself)
{
    auto* controller = (__bridge AppDelegate*)(vself);
    tr_torrentView(tor);
    auto const hashstr = @(tr_torrentView(tor).hash_string);

    dispatch_async(dispatch_get_main_queue(), ^{
        auto* const torrent = [controller torrentForHash:hashstr];
        [torrent startQueue];
    });
}

void onIdleLimitHit(tr_session* /*session*/, tr_torrent* tor, void* vself)
{
    auto* const controller = (__bridge AppDelegate*)(vself);
    auto const hashstr = @(tr_torrentView(tor).hash_string);

    dispatch_async(dispatch_get_main_queue(), ^{
        auto* const torrent = [controller torrentForHash:hashstr];
        [torrent idleLimitHit];
    });
}

void onRatioLimitHit(tr_session* /*session*/, tr_torrent* tor, void* vself)
{
    auto* const controller = (__bridge AppDelegate*)(vself);
    auto const hashstr = @(tr_torrentView(tor).hash_string);

    dispatch_async(dispatch_get_main_queue(), ^{
        auto* const torrent = [controller torrentForHash:hashstr];
        [torrent ratioLimitHit];
    });
}

void onMetadataCompleted(tr_session* /*session*/, tr_torrent* tor, void* vself)
{
    auto* const controller = (__bridge AppDelegate*)(vself);
    auto const hashstr = @(tr_torrentView(tor).hash_string);

    dispatch_async(dispatch_get_main_queue(), ^{
        auto* const torrent = [controller torrentForHash:hashstr];
        [torrent metadataRetrieved];
    });
}

void onTorrentCompletenessChanged(tr_torrent* tor, tr_completeness status, bool wasRunning, void* vself)
{
    auto* const controller = (__bridge AppDelegate*)(vself);
    auto const hashstr = @(tr_torrentView(tor).hash_string);

    dispatch_async(dispatch_get_main_queue(), ^{
        auto* const torrent = [controller torrentForHash:hashstr];
        [torrent completenessChange:status wasRunning:wasRunning controller:controller];
    });
}

- (void)transmissionInitialize {
    
    [NSUserDefaults.standardUserDefaults
        registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"Defaults" ofType:@"plist"]]];
    
    _fDefaults = NSUserDefaults.standardUserDefaults;

    //checks for old version speeds of -1
    if ([_fDefaults integerForKey:@"UploadLimit"] < 0)
    {
        [_fDefaults removeObjectForKey:@"UploadLimit"];
        [_fDefaults setBool:NO forKey:@"CheckUpload"];
    }
    if ([_fDefaults integerForKey:@"DownloadLimit"] < 0)
    {
        [_fDefaults removeObjectForKey:@"DownloadLimit"];
        [_fDefaults setBool:NO forKey:@"CheckDownload"];
    }
    
    auto settings = tr_sessionGetDefaultSettings();

    BOOL const usesSpeedLimitSched = [_fDefaults boolForKey:@"SpeedLimitAuto"];
    if (!usesSpeedLimitSched)
    {
        tr_variantDictAddBool(&settings, TR_KEY_alt_speed_enabled, [_fDefaults boolForKey:@"SpeedLimit"]);
    }

    tr_variantDictAddInt(&settings, TR_KEY_alt_speed_up, [_fDefaults integerForKey:@"SpeedLimitUploadLimit"]);
    tr_variantDictAddInt(&settings, TR_KEY_alt_speed_down, [_fDefaults integerForKey:@"SpeedLimitDownloadLimit"]);

    tr_variantDictAddBool(&settings, TR_KEY_alt_speed_time_enabled, [_fDefaults boolForKey:@"SpeedLimitAuto"]);
    tr_variantDictAddInt(&settings, TR_KEY_alt_speed_time_begin, [PrefViewController dateToTimeSum:[_fDefaults objectForKey:@"SpeedLimitAutoOnDate"]]);
    tr_variantDictAddInt(&settings, TR_KEY_alt_speed_time_end, [PrefViewController dateToTimeSum:[_fDefaults objectForKey:@"SpeedLimitAutoOffDate"]]);
    tr_variantDictAddInt(&settings, TR_KEY_alt_speed_time_day, [_fDefaults integerForKey:@"SpeedLimitAutoDay"]);

    tr_variantDictAddInt(&settings, TR_KEY_speed_limit_down, [_fDefaults integerForKey:@"DownloadLimit"]);
    tr_variantDictAddBool(&settings, TR_KEY_speed_limit_down_enabled, [_fDefaults boolForKey:@"CheckDownload"]);
    tr_variantDictAddInt(&settings, TR_KEY_speed_limit_up, [_fDefaults integerForKey:@"UploadLimit"]);
    tr_variantDictAddBool(&settings, TR_KEY_speed_limit_up_enabled, [_fDefaults boolForKey:@"CheckUpload"]);
    
    //hidden prefs
    //TODO: Alex
    if ([_fDefaults objectForKey:@"BindAddressIPv4"])
    {
        tr_variantDictAddStr(&settings, TR_KEY_bind_address_ipv4, [_fDefaults stringForKey:@"BindAddressIPv4"].UTF8String);
    }
    if ([_fDefaults objectForKey:@"BindAddressIPv6"])
    {
        tr_variantDictAddStr(&settings, TR_KEY_bind_address_ipv6, [_fDefaults stringForKey:@"BindAddressIPv6"].UTF8String);
    }
    
    tr_variantDictAddBool(&settings, TR_KEY_blocklist_enabled, [_fDefaults boolForKey:@"BlocklistNew"]);
    if ([_fDefaults objectForKey:@"BlocklistURL"])
        tr_variantDictAddStr(&settings, TR_KEY_blocklist_url, [_fDefaults stringForKey:@"BlocklistURL"].UTF8String);
    tr_variantDictAddBool(&settings, TR_KEY_dht_enabled, [_fDefaults boolForKey:@"DHTGlobal"]);
    tr_variantDictAddStr(
        &settings,
        TR_KEY_download_dir,
                         [self defaultDownloadDir].stringByExpandingTildeInPath.UTF8String);
    tr_variantDictAddBool(&settings, TR_KEY_download_queue_enabled, [_fDefaults boolForKey:@"Queue"]);
    tr_variantDictAddInt(&settings, TR_KEY_download_queue_size, [_fDefaults integerForKey:@"QueueDownloadNumber"]);
    tr_variantDictAddInt(&settings, TR_KEY_idle_seeding_limit, [_fDefaults integerForKey:@"IdleLimitMinutes"]);
    tr_variantDictAddBool(&settings, TR_KEY_idle_seeding_limit_enabled, [_fDefaults boolForKey:@"IdleLimitCheck"]);
    tr_variantDictAddStr(
        &settings,
        TR_KEY_incomplete_dir,
                         [self defaultDownloadDir].stringByExpandingTildeInPath.UTF8String); //TODO: Alex
    tr_variantDictAddBool(&settings, TR_KEY_incomplete_dir_enabled, [_fDefaults boolForKey:@"UseIncompleteDownloadFolder"]); //TODO: Alex
    tr_variantDictAddBool(&settings, TR_KEY_lpd_enabled, [_fDefaults boolForKey:@"LocalPeerDiscoveryGlobal"]);
    tr_variantDictAddInt(&settings, TR_KEY_message_level, TR_LOG_DEBUG);
    tr_variantDictAddInt(&settings, TR_KEY_peer_limit_global, [_fDefaults integerForKey:@"PeersTotal"]);
    tr_variantDictAddInt(&settings, TR_KEY_peer_limit_per_torrent, [_fDefaults integerForKey:@"PeersTorrent"]);
    
    BOOL const randomPort = [_fDefaults boolForKey:@"RandomPort"];
    tr_variantDictAddBool(&settings, TR_KEY_peer_port_random_on_start, randomPort);
    if (!randomPort)
    {
        tr_variantDictAddInt(&settings, TR_KEY_peer_port, [_fDefaults integerForKey:@"BindPort"]);
    }

    //hidden pref
    if ([_fDefaults objectForKey:@"PeerSocketTOS"])
    {
        tr_variantDictAddStr(&settings, TR_KEY_peer_socket_tos, [_fDefaults stringForKey:@"PeerSocketTOS"].UTF8String);
    }

    tr_variantDictAddBool(&settings, TR_KEY_pex_enabled, [_fDefaults boolForKey:@"PEXGlobal"]);
    tr_variantDictAddBool(&settings, TR_KEY_port_forwarding_enabled, [_fDefaults boolForKey:@"NatTraversal"]);
    tr_variantDictAddBool(&settings, TR_KEY_queue_stalled_enabled, [_fDefaults boolForKey:@"CheckStalled"]);
    tr_variantDictAddInt(&settings, TR_KEY_queue_stalled_minutes, [_fDefaults integerForKey:@"StalledMinutes"]);
    tr_variantDictAddReal(&settings, TR_KEY_ratio_limit, [_fDefaults floatForKey:@"RatioLimit"]);
    tr_variantDictAddBool(&settings, TR_KEY_ratio_limit_enabled, [_fDefaults boolForKey:@"RatioCheck"]);
    // set encryption mode
    tr_encryption_mode encryptionMode = TR_ENCRYPTION_PREFERRED;
    if ([_fDefaults boolForKey:@"EncryptionRequire"])
        encryptionMode = TR_ENCRYPTION_REQUIRED;
    else if (![_fDefaults boolForKey:@"EncryptionPrefer"])
        encryptionMode = TR_CLEAR_PREFERRED;
    tr_variantDictAddInt(&settings, TR_KEY_encryption, encryptionMode);

    tr_variantDictAddBool(&settings, TR_KEY_rename_partial_files, [_fDefaults boolForKey:@"RenamePartialFiles"]);
    tr_variantDictAddBool(&settings, TR_KEY_rpc_authentication_required, [_fDefaults boolForKey:@"RPCAuthorize"]);
    tr_variantDictAddBool(&settings, TR_KEY_rpc_enabled, [_fDefaults boolForKey:@"RPC"]);
    tr_variantDictAddInt(&settings, TR_KEY_rpc_port, [_fDefaults integerForKey:@"RPCPort"]);
    tr_variantDictAddStr(&settings, TR_KEY_rpc_username, [_fDefaults stringForKey:@"RPCUsername"].UTF8String);
    if ([_fDefaults objectForKey:@"RPCPassword"])
        tr_variantDictAddStr(&settings, TR_KEY_rpc_password, [_fDefaults stringForKey:@"RPCPassword"].UTF8String);
    tr_variantDictAddBool(&settings, TR_KEY_rpc_whitelist_enabled, [_fDefaults boolForKey:@"RPCUseWhitelist"]);
    tr_variantDictAddBool(&settings, TR_KEY_rpc_host_whitelist_enabled, [_fDefaults boolForKey:@"RPCUseHostWhitelist"]);
    tr_variantDictAddBool(&settings, TR_KEY_seed_queue_enabled, [_fDefaults boolForKey:@"QueueSeed"]);
    tr_variantDictAddInt(&settings, TR_KEY_seed_queue_size, [_fDefaults integerForKey:@"QueueSeedNumber"]);
    tr_variantDictAddBool(&settings, TR_KEY_start_added_torrents, [_fDefaults boolForKey:@"AutoStartDownload"]);
    tr_variantDictAddBool(&settings, TR_KEY_utp_enabled, [_fDefaults boolForKey:@"UTPGlobal"]);
    
    tr_variantDictAddBool(&settings, TR_KEY_script_torrent_done_enabled, [_fDefaults boolForKey:@"DoneScriptEnabled"]);
    NSString* prefs_string = [_fDefaults stringForKey:@"DoneScriptPath"];
    if (prefs_string != nil)
    {
        tr_variantDictAddStr(&settings, TR_KEY_script_torrent_done_filename, prefs_string.UTF8String);
    }

    // TODO: Add to GUI
    if ([_fDefaults objectForKey:@"RPCHostWhitelist"])
    {
        tr_variantDictAddStr(&settings, TR_KEY_rpc_host_whitelist, [_fDefaults stringForKey:@"RPCHostWhitelist"].UTF8String);
    }
    
    initUnits();
    
    _fLib = tr_sessionInit([[self configDir] cStringUsingEncoding:NSASCIIStringEncoding], YES, settings);
    
    tr_sessionSetIdleLimitHitCallback(_fLib, onIdleLimitHit, (__bridge void*)(self));
    tr_sessionSetQueueStartCallback(_fLib, onStartQueue, (__bridge void*)(self));
    tr_sessionSetRatioLimitHitCallback(_fLib, onRatioLimitHit, (__bridge void*)(self));
    tr_sessionSetMetadataCallback(_fLib, onMetadataCompleted, (__bridge void*)(self));
    tr_sessionSetCompletenessCallback(_fLib, onTorrentCompletenessChanged, (__bridge void*)(self));
    
    _fTorrents = [[NSMutableArray alloc] init];
    _fDisplayedTorrents = [[NSMutableArray alloc] init];
    _fTorrentHashes = [[NSMutableDictionary alloc] init];
    
    NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    _fSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    
    tr_sessionSetAltSpeedFunc(_fLib, altSpeedToggledCallback, (__bridge void*)(self));
    if (usesSpeedLimitSched)
    {
        [_fDefaults setBool:tr_sessionUsesAltSpeed(_fLib) forKey:@"SpeedLimit"];
    }

    tr_sessionSetRPCCallback(_fLib, rpcCallback, (__bridge void*)(self));

    _wifiPausedHashes = [[NSMutableSet alloc] init];
    [self startNetworkMonitoring];

    [self loadTorrentHistory];
    
    //observe notifications
    NSNotificationCenter* nc = NSNotificationCenter.defaultCenter;

    [nc addObserver:self selector:@selector(torrentFinishedDownloading:) name:@"TorrentFinishedDownloading" object:nil];

    [nc addObserver:self selector:@selector(torrentRestartedDownloading:) name:@"TorrentRestartedDownloading" object:nil];

    [nc addObserver:self selector:@selector(torrentFinishedSeeding:) name:@"TorrentFinishedSeeding" object:nil];
}

#pragma mark -

- (Torrent*)torrentForHash:(NSString*)hash
{
    NSParameterAssert(hash != nil);

    __block Torrent* torrent = nil;
    [self.fTorrents enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(Torrent* obj, NSUInteger /*idx*/, BOOL* stop) {
        if ([obj.hashString isEqualToString:hash])
        {
            torrent = obj;
            *stop = YES;
        }
    }];
    return torrent;
}

- (void)rpcCallback:(tr_rpc_callback_type)type forTorrentStruct:(struct tr_torrent*)torrentStruct
{
    @autoreleasepool
    {
        //get the torrent
        __block Torrent* torrent = nil;
        if (torrentStruct != NULL && (type != TR_RPC_TORRENT_ADDED && type != TR_RPC_SESSION_CHANGED && type != TR_RPC_SESSION_CLOSE))
        {
            [self.fTorrents enumerateObjectsWithOptions:NSEnumerationConcurrent
                                             usingBlock:^(Torrent* checkTorrent, NSUInteger /*idx*/, BOOL* stop) {
                                                 if (torrentStruct == checkTorrent.torrentStruct)
                                                 {
                                                     torrent = checkTorrent;
                                                     *stop = YES;
                                                 }
                                             }];

            if (!torrent)
            {
                NSLog(@"No torrent found matching the given torrent struct from the RPC callback!");
                return;
            }
        }
    }
}

- (void)loadTorrentHistory {
    auto* const session = self.fLib;

    //load previous transfers
    tr_ctor* ctor = tr_ctorNew(session);
    tr_ctorSetPaused(ctor, TR_FORCE, true); // paused by default; unpause below after checking state history
    auto const n_torrents = tr_sessionLoadTorrents(session, ctor);
    tr_ctorFree(ctor);

    // process the loaded torrents
    auto torrents = std::vector<tr_torrent*>{};
    torrents.resize(n_torrents);
    tr_sessionGetAllTorrents(session, std::data(torrents), std::size(torrents));
    for (auto* tor : torrents)
    {
        NSString* location;
        if (tr_torrentGetDownloadDir(tor) != NULL)
        {
            location = @(tr_torrentGetDownloadDir(tor));
        }
        
        Torrent* torrent = [[Torrent alloc] initWithTorrentStruct:tor location:location lib:self.fLib];
        [torrent changeDownloadFolderBeforeUsing:[self defaultDownloadDir] determinationType:TorrentDeterminationAutomatic];
        [self.fTorrents addObject:torrent];
        self.fTorrentHashes[torrent.hashString] = torrent;
    }
    
    //update previous transfers state by recreating a torrent from history
    //and comparing to torrents already loaded via tr_sessionLoadTorrents
    NSArray * history = [NSArray arrayWithContentsOfFile: [self transferPlist]];

    if (!history)
    {
        //old version saved transfer info in prefs file
        if ((history = [self.fDefaults arrayForKey:@"History"]))
        {
            [self.fDefaults removeObjectForKey:@"History"];
        }
    }

    if (history)
    {
        // theoretical max without doing a lot of work
        NSMutableArray* waitToStartTorrents = [NSMutableArray
            arrayWithCapacity:(history.count > 0 ? history.count - 1 : 0)];

        Torrent* t = [[Torrent alloc] init];
        for (NSDictionary* historyItem in history)
        {
            NSString* hash = historyItem[@"TorrentHash"];
            if ([self.fTorrentHashes.allKeys containsObject:hash])
            {
                Torrent* torrent = self.fTorrentHashes[hash];
                [t setResumeStatusForTorrent:torrent withHistory:historyItem forcePause:NO];

                NSNumber* waitToStart;
                if ((waitToStart = historyItem[@"WaitToStart"]) && waitToStart.boolValue)
                {
                    [waitToStartTorrents addObject:torrent];
                }
            }
        }

        //now that all are loaded, let's set those in the queue to waiting
        for (Torrent* torrent in waitToStartTorrents)
        {
            [torrent startTransfer];
        }
    }
}

- (NSUInteger)torrentsCount
{
    return [_fTorrents count];
}

- (Torrent*)torrentAtIndex:(NSInteger)index
{
    return [_fTorrents objectAtIndex:index];
}

- (void)torrentFinishedDownloading:(NSNotification*)notification
{
    Torrent* torrent = notification.object;

    if ([notification.userInfo[@"WasRunning"] boolValue])
    {

        NSString* title = NSLocalizedString(@"Download Complete", "notification title");
        NSString* body = torrent.name;
        NSString* location = torrent.dataLocation;
        NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:torrent.hashString forKey:@"Hash"];
        if (location)
        {
            userInfo[@"Location"] = location;
        }

        NSString* identifier = [@"Download Complete " stringByAppendingString:torrent.hashString];
        UNMutableNotificationContent* content = [UNMutableNotificationContent new];
        content.title = title;
        content.body = body;
        content.categoryIdentifier = @"categoryShow";
        content.userInfo = userInfo;

        UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:nil];
        [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
        
        [self postFinishMessage:[NSString stringWithFormat:NSLocalizedString(@"%@ download finished.", nil), title]];
    }

    [self fullUpdateUI];
}

- (void)torrentRestartedDownloading:(NSNotification*)notification
{
    [self fullUpdateUI];
}

- (void)torrentFinishedSeeding:(NSNotification*)notification
{
    Torrent* torrent = notification.object;

    NSString* title = NSLocalizedString(@"Seeding Complete", "notification title");
    NSString* body = torrent.name;
    NSString* location = torrent.dataLocation;
    NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:torrent.hashString forKey:@"Hash"];
    if (location)
    {
        userInfo[@"Location"] = location;
    }

    NSString* identifier = [@"Seeding Complete " stringByAppendingString:torrent.hashString];
    UNMutableNotificationContent* content = [UNMutableNotificationContent new];
    content.title = title;
    content.body = body;
    content.categoryIdentifier = @"categoryShow";
    content.userInfo = userInfo;

    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];

    //removing from the list calls fullUpdateUI
    if (torrent.removeWhenFinishSeeding)
    {
        [self removeTorrents:@[ torrent ] deleteData:NO];
    }
    else
    {

        [self fullUpdateUI];
    }
}

- (void)fullUpdateUI {
    [self updateTorrentHistory];
}

- (void)updateTorrentHistory
{
    NSMutableArray* history = [NSMutableArray arrayWithCapacity:self.fTorrents.count];

    for (Torrent* torrent in self.fTorrents)
    {
        [history addObject:torrent.history];
        self.fTorrentHashes[torrent.hashString] = torrent;
    }

    NSString* historyFile = [self transferPlist];
    [history writeToFile:historyFile atomically:YES];
}

- (void)altSpeedToggledCallbackIsLimited:(NSDictionary*)dict
{
    BOOL const isLimited = [dict[@"Active"] boolValue];

    [self.fDefaults setBool:isLimited forKey:@"SpeedLimit"];

    if (![dict[@"ByUser"] boolValue])
    {
        NSString* title = isLimited ? NSLocalizedString(@"Speed Limit Auto Enabled", "notification title") :
                                      NSLocalizedString(@"Speed Limit Auto Disabled", "notification title");
        NSString* body = NSLocalizedString(@"Bandwidth settings changed", "notification description");

        NSString* identifier = @"Bandwidth settings changed";
        UNMutableNotificationContent* content = [UNMutableNotificationContent new];
        content.title = title;
        content.body = body;

        UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:nil];
        [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
    }
}

- (void)removeTorrents:(NSArray<Torrent*>*)torrents deleteData:(BOOL)deleteData afterDelay:(NSTimeInterval)delay {
    __weak AppDelegate *wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [wself removeTorrents:torrents deleteData:deleteData];
    });
}

- (void)removeTorrents:(NSArray<Torrent*>*)torrents deleteData:(BOOL)deleteData {
    //miscellaneous
    for (Torrent* torrent in torrents)
    {
        //don't want any of these starting then stopping
        if (torrent.waitingToStart)
        {
            [torrent stopTransfer];
        }
    }

    //#5106 - don't try to remove torrents that have already been removed (fix for a bug, but better safe than crash anyway)
    NSIndexSet* indexesToRemove = [torrents indexesOfObjectsWithOptions:NSEnumerationConcurrent
                                                            passingTest:^BOOL(Torrent* torrent, NSUInteger /*idx*/, BOOL* /*stop*/) {
                                                                return [self.fTorrents indexOfObjectIdenticalTo:torrent] != NSNotFound;
                                                            }];
    if (torrents.count != indexesToRemove.count)
    {
        NSLog(
            @"trying to remove %ld transfers, but %ld have already been removed",
            torrents.count,
            torrents.count - indexesToRemove.count);
        torrents = [torrents objectsAtIndexes:indexesToRemove];

        if (indexesToRemove.count == 0)
        {
            [self fullUpdateUI];
            return;
        }
    }

    [self.fTorrents removeObjectsInArray:torrents];
    
    //do here if we're not doing it at the end of the animation
    for (Torrent* torrent in torrents)
    {
        [torrent closeRemoveTorrent:deleteData];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationTorrentsRemoved object:self userInfo:nil];
}

- (void)fixDocumentsDirectory
{
    BOOL isDir, exists;
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    NSLog(@"Using documents directory %@", [self documentsDirectory]);
    
    NSArray *directories = [NSArray arrayWithObjects:[self documentsDirectory], [self configDir], [self torrentsPath], [self defaultDownloadDir], nil];
    
    for (NSString *d in directories) {
        exists = [fileManager fileExistsAtPath:d isDirectory:&isDir];
        if (exists && !isDir) {
            [fileManager removeItemAtPath:d error:nil];
            [fileManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }
        if (!exists) {
            [fileManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }
    }
}

- (BOOL)openURL:(NSString*)urlString
{
    if ([self isMagnetUrlString:urlString])
    {
        [self openMagnet:urlString];
        return YES;
    }
    else
    {
        if ([urlString rangeOfString:@"://"].location == NSNotFound)
        {
            if ([urlString rangeOfString:@"."].location == NSNotFound)
            {
                NSInteger beforeCom;
                if ((beforeCom = [urlString rangeOfString:@"/"].location) != NSNotFound)
                {
                    urlString = [NSString stringWithFormat:@"http://www.%@.com/%@",
                                                           [urlString substringToIndex:beforeCom],
                                                           [urlString substringFromIndex:beforeCom + 1]];
                }
                else
                {
                    urlString = [NSString stringWithFormat:@"http://www.%@.com/", urlString];
                }
            }
            else
            {
                urlString = [@"http://" stringByAppendingString:urlString];
            }
        }

        NSURL* url = [NSURL URLWithString:urlString];
        if (url == nil)
        {
            NSLog(@"Detected non-URL string \"%@\". Ignoring.", urlString);
            return NO;
        }

        [self.fSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask*>* _Nonnull tasks) {
            for (NSURLSessionTask* task in tasks)
            {
                if ([task.originalRequest.URL isEqual:url])
                {
                    NSLog(@"Already downloading %@", url);
                    return;
                }
            }
            NSURLSessionDataTask* download = [self.fSession dataTaskWithURL:url];
            [download resume];
        }];
    }
    return YES;
}

- (void)openMagnet:(NSString*)address
{
    tr_torrent* duplicateTorrent;
    if ((duplicateTorrent = tr_torrentFindFromMagnetLink(self.fLib, address.UTF8String)))
    {
        NSString* name = @(tr_torrentName(duplicateTorrent));
        [self duplicateOpenMagnetAlert:address transferName:name];
        return;
    }

    //determine download location
    NSString* location = nil;
    if ([self.fDefaults boolForKey:@"DownloadLocationConstant"])
    {
        location = [self.fDefaults stringForKey:@"DownloadFolder"].stringByExpandingTildeInPath;
    }

    Torrent* torrent;
    if (!(torrent = [[Torrent alloc] initWithMagnetAddress:address location:location lib:self.fLib]))
    {
        [self invalidOpenMagnetAlert:address];
        return;
    }
    
    if ([self.fDefaults boolForKey:@"AutoStartDownload"])
    {
        [torrent startTransfer];
    }
    
    [torrent update];
    [self.fTorrents addObject:torrent];
    
    if (!self.fAddingTransfers)
    {
        self.fAddingTransfers = [[NSMutableSet alloc] init];
    }
    [self.fAddingTransfers addObject:torrent];

    [[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewTorrentAdded object:self userInfo:nil];
    [self fullUpdateUI];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(nonnull NSURLSession*)session
              dataTask:(nonnull NSURLSessionDataTask*)dataTask
    didReceiveResponse:(nonnull NSURLResponse*)response
     completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSString* suggestedName = response.suggestedFilename;
    if ([suggestedName.pathExtension caseInsensitiveCompare:@"torrent"] == NSOrderedSame)
    {
        completionHandler(NSURLSessionResponseBecomeDownload);
        return;
    }
    completionHandler(NSURLSessionResponseCancel);

    NSString* message = [NSString
        stringWithFormat:NSLocalizedString(@"It appears that the file \"%@\" from %@ is not a torrent file.", "Download not a torrent -> message"),
                         suggestedName,
                         dataTask.originalRequest.URL.absoluteString.stringByRemovingPercentEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Torrent download failed", "Download not a torrent -> title") message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", "Download not a torrent -> button") style:UIAlertActionStyleDefault handler:nil]];
        
        [[[UIApplication sharedApplication] topViewController] presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)URLSession:(nonnull NSURLSession*)session
                 dataTask:(nonnull NSURLSessionDataTask*)dataTask
    didBecomeDownloadTask:(nonnull NSURLSessionDownloadTask*)downloadTask
{
    // Required delegate method to proceed with  NSURLSessionResponseBecomeDownload.
    // nothing to do
}

- (void)URLSession:(nonnull NSURLSession*)session
                 downloadTask:(nonnull NSURLSessionDownloadTask*)downloadTask
    didFinishDownloadingToURL:(nonnull NSURL*)location
{
    NSString* path = [[self torrentsPath] stringByAppendingPathComponent:downloadTask.response.suggestedFilename.lastPathComponent];
    NSError* error;
    [NSFileManager.defaultManager moveItemAtPath:location.path toPath:path error:&error];
    if (error)
    {
        [self URLSession:session task:downloadTask didCompleteWithError:error];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self openFiles:@[ path ] addType:AddTypeURL forcePath:nil];

        //delete the torrent file after opening
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    });
}

- (void)URLSession:(nonnull NSURLSession*)session
                    task:(nonnull NSURLSessionTask*)task
    didCompleteWithError:(nullable NSError*)error
{
    if (!error || error.code == NSURLErrorCancelled)
    {
        // no errors or we already displayed an alert
        return;
    }

    NSString* urlString = task.currentRequest.URL.absoluteString;
    if ([urlString rangeOfString:@"magnet:" options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound)
    {
        // originalRequest was a redirect to a magnet
        [self performSelectorOnMainThread:@selector(openMagnet:) withObject:urlString waitUntilDone:NO];
        return;
    }

    NSString* message = [NSString
        stringWithFormat:NSLocalizedString(@"The torrent could not be downloaded from %@: %@.", "Torrent download failed -> message"),
                         task.originalRequest.URL.absoluteString.stringByRemovingPercentEncoding,
                         error.localizedDescription];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Torrent download failed", "Download not a torrent -> title") message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", "Download not a torrent -> button") style:UIAlertActionStyleDefault handler:nil]];
        
        [[[UIApplication sharedApplication] topViewController] presentViewController:alertController animated:YES completion:nil];
    });
}
 
- (BOOL)openFilePathURL:(NSURL *)url shouldOpenInPlace:(BOOL)shouldOpenInPlace {
    NSString* path = [[self torrentsPath] stringByAppendingPathComponent:url.lastPathComponent];
    NSError* error;
    if (shouldOpenInPlace) {
        [url startAccessingSecurityScopedResource];
        [NSFileManager.defaultManager copyItemAtURL:url toURL:[NSURL fileURLWithPath:path] error:&error];
        [url stopAccessingSecurityScopedResource];
        if (error) {
            return NO;
        }
    }
    else {
        [NSFileManager.defaultManager moveItemAtPath:[url path] toPath:path error:&error];
        if (error) {
            return NO;
        }
    }
    
    [self openFiles:@[ path ] addType:AddTypeURL forcePath:nil];

    //delete the torrent file after opening
    [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    
    return YES;
}

//TODO: Alex forcePath
- (void)openFiles:(NSArray<NSString*>*)filenames addType:(AddType)type forcePath:(NSString*)path
{
    BOOL deleteTorrentFile, canToggleDelete = NO;
    switch (type)
    {
    case AddTypeCreated:
        deleteTorrentFile = NO;
        break;
    case AddTypeURL:
        deleteTorrentFile = YES;
        break;
    default:
        deleteTorrentFile = [self.fDefaults boolForKey:@"DeleteOriginalTorrent"];
        canToggleDelete = YES;
    }

    for (NSString* torrentPath in filenames)
    {
        auto metainfo = tr_torrent_metainfo{};
        if (!metainfo.parse_torrent_file(torrentPath.UTF8String)) // invalid torrent
        {
            if (type != AddTypeAuto)
            {
                [self invalidOpenAlert:torrentPath.lastPathComponent];
            }
            continue;
        }

        auto foundTorrent = tr_torrentFindFromMetainfo(self.fLib, &metainfo);
        if (foundTorrent != nullptr) // dupe torrent
        {
            if (tr_torrentHasMetadata(foundTorrent))
            {
                [self duplicateOpenAlert:@(metainfo.name().c_str())];
            }
            // foundTorrent is a magnet, fill it with file's metainfo
            else if (!tr_torrentSetMetainfoFromFile(foundTorrent, &metainfo, torrentPath.UTF8String))
            {
                [self duplicateOpenAlert:@(metainfo.name().c_str())];
            }
            continue;
        }

        //determine download location
        NSString* location;
        if (path)
        {
            location = path.stringByExpandingTildeInPath;
        }
        else if ([self.fDefaults boolForKey:@"DownloadLocationConstant"])
        {
            location = [self.fDefaults stringForKey:@"DownloadFolder"].stringByExpandingTildeInPath;
        }
        else if (type != AddTypeURL)
        {
            location = torrentPath.stringByDeletingLastPathComponent;
        }
        else
        {
            location = nil;
        }

        Torrent* torrent;
        if (!(torrent = [[Torrent alloc] initWithPath:torrentPath location:location
                                    deleteTorrentFile:deleteTorrentFile
                                                  lib:self.fLib]))
        {
            continue;
        }


        //verify the data right away if it was newly created
        if (type == AddTypeCreated)
        {
            [torrent resetCache];
        }
                
        if ([self.fDefaults boolForKey:@"AutoStartDownload"])
        {
            [torrent startTransfer];
        }
        
        [torrent update];
        [self.fTorrents addObject:torrent];
        
        if (!self.fAddingTransfers)
        {
            self.fAddingTransfers = [[NSMutableSet alloc] init];
        }
        [self.fAddingTransfers addObject:torrent];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationNewTorrentAdded object:self userInfo:nil];
    }

    [self fullUpdateUI];
}

- (NSString*)defaultDownloadDir
{
    return [[self documentsDirectory] stringByAppendingPathComponent:@"downloads"];
}

- (NSString*)transferPlist
{
   return [[self documentsDirectory] stringByAppendingPathComponent:@"Transfer.plist"];
}

- (NSString*)torrentsPath
{
   return [[self documentsDirectory] stringByAppendingPathComponent:@"torrents"];
}

- (NSString*)configDir
{
   return [[self documentsDirectory] stringByAppendingPathComponent:@"config"];
}

- (NSString*)documentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

- (void)setGlobalUploadSpeedLimit:(NSInteger)kbytes
{
    [_fDefaults setInteger:kbytes forKey:@"UploadLimit"];
    tr_sessionSetSpeedLimit_KBps(self.fLib, TR_UP, (unsigned int)[_fDefaults integerForKey:@"UploadLimit"]);
}

- (void)setGlobalUploadSpeedLimitEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"UploadLimitEnabled"];
    tr_sessionLimitSpeed(self.fLib, TR_UP, [_fDefaults boolForKey:@"UploadLimitEnabled"]);
}

- (void)setGlobalDownloadSpeedLimitEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"DownloadLimitEnabled"];
    tr_sessionLimitSpeed(self.fLib, TR_DOWN, [_fDefaults boolForKey:@"DownloadLimitEnabled"]);
}

- (BOOL)globalUploadSpeedLimitEnabled
{
    return tr_sessionIsSpeedLimited(self.fLib, TR_UP);
}

- (BOOL)globalDownloadSpeedLimitEnabled
{
    return tr_sessionIsSpeedLimited(self.fLib, TR_DOWN);
}

- (void)setGlobalDownloadSpeedLimit:(NSInteger)kbytes
{
    [_fDefaults setInteger:kbytes forKey:@"DownloadLimit"];
    tr_sessionSetSpeedLimit_KBps(self.fLib, TR_DOWN, (unsigned int)[self.fDefaults integerForKey:@"DownloadLimit"]);
}

- (NSInteger)globalDownloadSpeedLimit
{
    return tr_sessionGetSpeedLimit_KBps(self.fLib, TR_DOWN);
}

- (NSInteger)globalUploadSpeedLimit
{
    return tr_sessionGetSpeedLimit_KBps(self.fLib, TR_UP);
}

- (void)setGlobalMaximumConnections:(NSInteger)c
{
    [_fDefaults setInteger:c forKey:@"PeersTotal"];
    tr_sessionSetPeerLimit(self.fLib, c);
}

- (NSInteger)globalMaximumConnections
{
    return tr_sessionGetPeerLimit(self.fLib);
}

- (void)setConnectionsPerTorrent:(NSInteger)c
{
    [_fDefaults setInteger:c forKey:@"PeersTorrent"];
    tr_sessionSetPeerLimitPerTorrent(self.fLib, c);
}

- (NSInteger)connectionsPerTorrent
{
    return tr_sessionGetPeerLimitPerTorrent(self.fLib);
}

#pragma mark - Encryption

- (void)setEncryptionMode:(tr_encryption_mode)mode
{
    [_fDefaults setBool:(mode != TR_CLEAR_PREFERRED) forKey:@"EncryptionPrefer"];
    [_fDefaults setBool:(mode == TR_ENCRYPTION_REQUIRED) forKey:@"EncryptionRequire"];
    tr_sessionSetEncryption(self.fLib, mode);
}

- (tr_encryption_mode)encryptionMode
{
    return tr_sessionGetEncryption(self.fLib);
}

#pragma mark - Seeding limits

- (void)setRatioLimitEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"RatioCheck"];
    tr_sessionSetRatioLimited(self.fLib, enabled);
}

- (BOOL)ratioLimitEnabled
{
    return tr_sessionIsRatioLimited(self.fLib);
}

- (void)setRatioLimit:(CGFloat)limit
{
    [_fDefaults setFloat:limit forKey:@"RatioLimit"];
    tr_sessionSetRatioLimit(self.fLib, limit);
}

- (CGFloat)ratioLimit
{
    return tr_sessionGetRatioLimit(self.fLib);
}

- (void)setIdleLimitEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"IdleLimitCheck"];
    tr_sessionSetIdleLimited(self.fLib, enabled);
}

- (BOOL)idleLimitEnabled
{
    return tr_sessionIsIdleLimited(self.fLib);
}

- (void)setIdleLimitMinutes:(NSInteger)minutes
{
    [_fDefaults setInteger:minutes forKey:@"IdleLimitMinutes"];
    tr_sessionSetIdleLimit(self.fLib, (uint16_t)minutes);
}

- (NSInteger)idleLimitMinutes
{
    return tr_sessionGetIdleLimit(self.fLib);
}

#pragma mark - Queue

- (void)setDownloadQueueEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"Queue"];
    tr_sessionSetQueueEnabled(self.fLib, TR_DOWN, enabled);
}

- (BOOL)downloadQueueEnabled
{
    return tr_sessionGetQueueEnabled(self.fLib, TR_DOWN);
}

- (void)setDownloadQueueSize:(NSInteger)size
{
    [_fDefaults setInteger:size forKey:@"QueueDownloadNumber"];
    tr_sessionSetQueueSize(self.fLib, TR_DOWN, (size_t)size);
}

- (NSInteger)downloadQueueSize
{
    return (NSInteger)tr_sessionGetQueueSize(self.fLib, TR_DOWN);
}

- (void)setSeedQueueEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"QueueSeed"];
    tr_sessionSetQueueEnabled(self.fLib, TR_UP, enabled);
}

- (BOOL)seedQueueEnabled
{
    return tr_sessionGetQueueEnabled(self.fLib, TR_UP);
}

- (void)setSeedQueueSize:(NSInteger)size
{
    [_fDefaults setInteger:size forKey:@"QueueSeedNumber"];
    tr_sessionSetQueueSize(self.fLib, TR_UP, (size_t)size);
}

- (NSInteger)seedQueueSize
{
    return (NSInteger)tr_sessionGetQueueSize(self.fLib, TR_UP);
}

#pragma mark - Peer discovery

- (void)setDHTEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"DHTGlobal"];
    tr_sessionSetDHTEnabled(self.fLib, enabled);
}

- (BOOL)dhtEnabled
{
    return tr_sessionIsDHTEnabled(self.fLib);
}

- (void)setPEXEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"PEXGlobal"];
    tr_sessionSetPexEnabled(self.fLib, enabled);
}

- (BOOL)pexEnabled
{
    return tr_sessionIsPexEnabled(self.fLib);
}

- (void)setUTPEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"UTPGlobal"];
    tr_sessionSetUTPEnabled(self.fLib, enabled);
}

- (BOOL)utpEnabled
{
    return tr_sessionIsUTPEnabled(self.fLib);
}

- (void)setLPDEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"LocalPeerDiscoveryGlobal"];
    tr_sessionSetLPDEnabled(self.fLib, enabled);
}

- (BOOL)lpdEnabled
{
    return tr_sessionIsLPDEnabled(self.fLib);
}

#pragma mark - Blocklist

- (void)setBlocklistEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"BlocklistNew"];
    tr_blocklistSetEnabled(self.fLib, enabled);
}

- (BOOL)blocklistEnabled
{
    return tr_blocklistIsEnabled(self.fLib);
}

- (void)setBlocklistURL:(NSString *)url
{
    [_fDefaults setObject:url forKey:@"BlocklistURL"];
    tr_blocklistSetURL(self.fLib, url.UTF8String);
}

- (NSString *)blocklistURL
{
    char const *url = tr_blocklistGetURL(self.fLib);
    return url ? [NSString stringWithUTF8String:url] : @"";
}

#pragma mark - Remote access (RPC)

- (void)setRPCEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"RPC"];
    tr_sessionSetRPCEnabled(self.fLib, enabled);
}

- (BOOL)rpcEnabled
{
    return tr_sessionIsRPCEnabled(self.fLib);
}

- (void)setRPCPort:(NSInteger)port
{
    [_fDefaults setInteger:port forKey:@"RPCPort"];
    tr_sessionSetRPCPort(self.fLib, (uint16_t)port);
}

- (NSInteger)rpcPort
{
    return tr_sessionGetRPCPort(self.fLib);
}

- (void)setRPCAuthEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"RPCAuthorize"];
    tr_sessionSetRPCPasswordEnabled(self.fLib, enabled);
}

- (BOOL)rpcAuthEnabled
{
    return tr_sessionIsRPCPasswordEnabled(self.fLib);
}

- (void)setRPCUsername:(NSString *)username
{
    [_fDefaults setObject:username forKey:@"RPCUsername"];
    tr_sessionSetRPCUsername(self.fLib, username.UTF8String);
}

- (NSString *)rpcUsername
{
    char const *name = tr_sessionGetRPCUsername(self.fLib);
    return name ? [NSString stringWithUTF8String:name] : @"";
}

- (void)setRPCPassword:(NSString *)password
{
    [_fDefaults setObject:password forKey:@"RPCPassword"];
    tr_sessionSetRPCPassword(self.fLib, password.UTF8String);
}

- (NSString *)rpcPassword
{
    return [_fDefaults stringForKey:@"RPCPassword"] ?: @"";
}

#pragma mark - Wifi-only

- (void)setWifiOnlyEnabled:(BOOL)enabled
{
    [_fDefaults setBool:enabled forKey:@"WiFiOnlyDownloading"];
    if (!enabled && self.wifiPausedHashes.count > 0)
        [self resumeWifiPausedTorrents];
}

- (BOOL)wifiOnlyEnabled
{
    return [_fDefaults boolForKey:@"WiFiOnlyDownloading"];
}

- (void)startNetworkMonitoring
{
    nw_path_monitor_t monitor = nw_path_monitor_create();
    nw_path_monitor_set_queue(monitor, dispatch_get_main_queue());

    __weak AppDelegate *wself = self;
    nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
        [wself handleNetworkPathUpdate:path];
    });

    nw_path_monitor_start(monitor);
    self.pathMonitor = monitor;
}

- (void)handleNetworkPathUpdate:(nw_path_t)path
{
    if (!self.wifiOnlyEnabled)
        return;

    BOOL hasWifi = nw_path_uses_interface_type(path, nw_interface_type_wifi);

    if (!hasWifi) {
        for (Torrent *torrent in self.fTorrents) {
            if (torrent.isActive) {
                [self.wifiPausedHashes addObject:torrent.hashString];
                [torrent stopTransfer];
            }
        }
        if (self.wifiPausedHashes.count > 0)
            [self postMessage:@"Torrents paused — no wifi connection"];
    } else {
        [self resumeWifiPausedTorrents];
    }
}

- (void)resumeWifiPausedTorrents
{
    if (self.wifiPausedHashes.count == 0)
        return;

    for (Torrent *torrent in self.fTorrents) {
        if ([self.wifiPausedHashes containsObject:torrent.hashString])
            [torrent startTransfer];
    }
    [self.wifiPausedHashes removeAllObjects];
}


- (void)invalidOpenAlert:(NSString*)filename
{
    if (![self.fDefaults boolForKey:@"WarningInvalidOpen"])
    {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString
                                                                                      stringWithFormat:NSLocalizedString(@"\"%@\" is not a valid torrent file.", "Open invalid alert -> title"), filename] message:NSLocalizedString(@"The torrent file cannot be opened because it contains invalid data.", "Open invalid alert -> message") preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", "Open invalid alert -> button") style:UIAlertActionStyleDefault handler:nil]];
    
    __weak AppDelegate *wself = self;

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Don't Show Again", "Open invalid alert -> Don't show again button") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [wself.fDefaults setBool:NO forKey:@"WarningInvalidOpen"];
    }]];
    
    [UIApplication.sharedApplication.topViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)invalidOpenMagnetAlert:(NSString*)address
{
    if (![self.fDefaults boolForKey:@"WarningInvalidOpen"])
    {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Adding magnetized transfer failed.", "Magnet link failed -> title") message:[NSString stringWithFormat:NSLocalizedString(
                                                                                                                                                                                                                                  @"There was an error when adding the magnet link \"%@\"."
                                                                                                                                                                                                                                   " The transfer will not occur.",
                                                                                                                                                                                                                                  "Magnet link failed -> message"),
                                                                                                                                                                                                                              address] preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", "Magnet link failed -> button") style:UIAlertActionStyleDefault handler:nil]];
    
    __weak AppDelegate *wself = self;

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Don't Show Again", "Magnet link failed -> Don't show again button") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [wself.fDefaults setBool:NO forKey:@"WarningInvalidOpen"];
    }]];
    
    [UIApplication.sharedApplication.topViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)duplicateOpenAlert:(NSString*)name
{
    if (![self.fDefaults boolForKey:@"WarningDuplicate"])
    {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString
                                                                                      stringWithFormat:NSLocalizedString(@"A transfer of \"%@\" already exists.", "Open duplicate alert -> title"), name] message:NSLocalizedString(
                                                                                                                                                                                                                                    @"The transfer cannot be added because it is a duplicate of an already existing transfer.",
                                                                                                                                                                                                                                    "Open duplicate alert -> message") preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", "Move inside itself alert -> button") style:UIAlertActionStyleDefault handler:nil]];
    
    __weak AppDelegate *wself = self;

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Don't Show Again", "Move inside itself alert -> Don't show again button") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [wself.fDefaults setBool:NO forKey:@"WarningDuplicate"];
    }]];
    
    [UIApplication.sharedApplication.topViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)duplicateOpenMagnetAlert:(NSString*)address transferName:(NSString*)name
{
    if (![self.fDefaults boolForKey:@"WarningDuplicate"])
    {
        return;
    }
    
    NSString *alertTitle = name ? [NSString
                                   stringWithFormat:NSLocalizedString(@"A transfer of \"%@\" already exists.", "Open duplicate magnet alert -> title"), name] : NSLocalizedString(@"Magnet link is a duplicate of an existing transfer.", "Open duplicate magnet alert -> title");
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alertTitle message:[NSString
                                                                                                         stringWithFormat:NSLocalizedString(
                                                                                                                              @"The magnet link  \"%@\" cannot be added because it is a duplicate of an already existing transfer.",
                                                                                                                              "Open duplicate magnet alert -> message"),
                                                                                                                          address] preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", "Open duplicate magnet alert -> button") style:UIAlertActionStyleDefault handler:nil]];
    
    __weak AppDelegate *wself = self;

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Don't Show Again", "Open duplicate magnet alert -> Don't show again button") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [wself.fDefaults setBool:NO forKey:@"WarningDuplicate"];
    }]];
    
    [UIApplication.sharedApplication.topViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)postError:(NSString *)err_msg
{
    // fix alertbanner getting stuck
    UIApplication *application = [UIApplication sharedApplication];
    UIApplicationState appCurrentState = [application applicationState];
    if(appCurrentState == UIApplicationStateActive)
    {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.window style:ALAlertBannerStyleFailure position:ALAlertBannerPositionUnderNavBar title:err_msg];
        banner.secondsToShow = 3.5f;
        banner.showAnimationDuration = 0.25f;
        banner.hideAnimationDuration = 0.2f;
        [banner show];
    }
}

- (void)postMessage:(NSString*)msg
{
    // fix alertbanner getting stuck
    UIApplication *application = [UIApplication sharedApplication];
    UIApplicationState appCurrentState = [application applicationState];
    if(appCurrentState == UIApplicationStateActive)
    {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.window style:ALAlertBannerStyleNotify position:ALAlertBannerPositionUnderNavBar title:msg];
        banner.secondsToShow = 3.5f;
        banner.showAnimationDuration = 0.25f;
        banner.hideAnimationDuration = 0.2f;
        [banner show];
    }
}

- (void)postFinishMessage:(NSString*)msg
{
    // fix alertbanner getting stuck
    UIApplication *application = [UIApplication sharedApplication];
    UIApplicationState appCurrentState = [application applicationState];
    if(appCurrentState == UIApplicationStateActive)
    {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.window style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionUnderNavBar title:msg subtitle:msg];
        [banner show];
    }
}

- (BOOL)isMagnet:(NSURL *)url {
    return [self isMagnetUrlString:[url absoluteString]];
}

- (BOOL)isMagnetUrlString:(NSString *)urlString {
    return [urlString rangeOfString:@"magnet:" options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound;
}


@end
