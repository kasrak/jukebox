#import <UIKit/UIKit.h>

@class ViewController;
@class GCDWebServer;
@class MPMusicPlayerController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) GCDWebServer *httpServer;
@property (copy, nonatomic) NSString *library;
@property (strong, nonatomic) MPMusicPlayerController *musicPlayer;

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@end
