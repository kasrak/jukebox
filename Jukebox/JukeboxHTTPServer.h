@class MPMusicPlayerController;

@interface JukeboxHTTPServer : NSObject

@property (copy, nonatomic) NSString *library; // TODO: refactor.
@property (strong, nonatomic) MPMusicPlayerController *musicPlayer; // TODO: refactor.

- (void)startWithPort:(NSUInteger)port;

- (NSURL *)serverURL;

@end