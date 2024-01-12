//
//  main.m
//  TransmissionPlus
//
//  Created by Alex Svitlov on 04/12/2023.
//  Copyright © 2023 The Transmission Project. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#include <libtransmission/transmission.h>

#include <libtransmission/utils.h>

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        auto const init_mgr = tr_lib_init();

        tr_locale_set_global("");
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
