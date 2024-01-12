

#import "UIApplication+TopViewControllerUtil.h"


@implementation UIApplication (TopViewControllerUtil)


- (UIViewController *)topViewController {
    UIViewController *topController = ((UIWindow *)[self.windows objectAtIndex:0]).rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}


@end
