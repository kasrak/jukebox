@class ViewController;
@class JukeboxHTTPServer;
@class MPMusicPlayerController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) JukeboxHTTPServer *httpServer;
@property (strong, nonatomic) MPMusicPlayerController *musicPlayer;

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@end
