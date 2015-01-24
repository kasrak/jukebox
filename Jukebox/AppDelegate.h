#import <UIKit/UIKit.h>

@class ViewController;
@class GCDWebServer;
@class MPMusicPlayerController;

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    GCDWebServer *httpServer;
    NSString *library;
    MPMusicPlayerController *player;
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@end
