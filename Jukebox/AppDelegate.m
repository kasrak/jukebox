#import "AppDelegate.h"
#import "ViewController.h"
#import "JukeboxHTTPServer.h"

#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.musicPlayer = [MPMusicPlayerController systemMusicPlayer];
    [self.musicPlayer setQueueWithQuery:[MPMediaQuery songsQuery]];
    [self.musicPlayer setShuffleMode:MPMusicShuffleModeSongs];
    [self.musicPlayer setRepeatMode:MPMusicRepeatModeAll];

    self.httpServer = [[JukeboxHTTPServer alloc] init];
    self.httpServer.musicPlayer = self.musicPlayer;
    [self.httpServer startWithPort:8989];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil musicPlayer:self.musicPlayer httpServer:self.httpServer];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];

    [self performSelectorInBackground:@selector(scanLibrary) withObject:self];
    
    return YES;
}

// TODO: this doesn't belong here.
- (void)scanLibrary {
    MPMediaQuery *query = [MPMediaQuery songsQuery];
    
    NSMutableDictionary *songs = [NSMutableDictionary dictionaryWithCapacity:query.items.count/8];
    
    for (MPMediaItem *item in query.items) {
        NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
        if (!artist) {
            artist = @"Unknown";
        }
        
        NSString *album = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
        if (!album) {
            album = @"Unknown";
        }
        
        NSArray *song = [NSArray arrayWithObjects:
                         [item valueForProperty:MPMediaItemPropertyTitle],
                         [NSString stringWithFormat:@"%@", [item valueForProperty:MPMediaItemPropertyPersistentID]],
                         nil];
        
        NSMutableDictionary *albumDict = [songs objectForKey:artist];
        if (albumDict) {
            NSMutableArray *songList = [albumDict objectForKey:album];
            if (songList) {
                [songList addObject:song];
            } else {
                [albumDict setObject:[NSMutableArray arrayWithObject:song] forKey:album];
            }
        } else {
            [songs setObject:[NSMutableDictionary dictionaryWithObject:
                              [NSMutableArray arrayWithObject:song] forKey:album] forKey:artist];
        }
    }
    
    NSData *json = [NSJSONSerialization dataWithJSONObject:songs options:NSJSONWritingPrettyPrinted error:nil];
    self.httpServer.library = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

@end
