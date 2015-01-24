@class JukeboxHTTPServer;

@interface ViewController : UIViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil __attribute__((unavailable("use initWithNibName:bundle:musicPlayer:httpServer:")));

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil musicPlayer:(MPMusicPlayerController *)musicPlayer httpServer:(JukeboxHTTPServer *)httpServer;

@end
