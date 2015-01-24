#import "AppDelegate.h"
#import "ViewController.h"

#import "GCDWebServer.h"
#import "GCDWebServerRequest.h"
#import "GCDWebServerDataResponse.h"

#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.httpServer = [[GCDWebServer alloc] init];

    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    [self.httpServer addGETHandlerForBasePath:@"/" directoryPath:webPath indexFilename:@"index.html" cacheAge:3600 allowRangeRequests:NO];

    [self.httpServer addHandlerForMethod:@"GET" path:@"/songs" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         GCDWebServerDataResponse *res;

         if (self.library) {
             res = [[GCDWebServerDataResponse alloc] initWithText:self.library];
         } else {
             res = [[GCDWebServerDataResponse alloc] initWithText:@"{'error': 'not ready'}"];
         }

         res.contentType = @"application/json";
         completionBlock(res);
     }];

    [self.httpServer addHandlerForMethod:@"GET" pathRegex:@"/play/(.*)" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         NSArray *captures = [request attributeForKey:GCDWebServerRequestAttribute_RegexCaptures];
         NSNumber *persistentID = @(strtoull([captures[0] UTF8String], NULL, 0));

         MPMediaPropertyPredicate *predicate = [MPMediaPropertyPredicate predicateWithValue:persistentID forProperty:MPMediaEntityPropertyPersistentID];
         MPMediaQuery *query = [[MPMediaQuery alloc] init];
         [query addFilterPredicate:predicate];

         NSString *responseString;
         if (query.items.count) {
             MPMediaItem *song = [query.items objectAtIndex:0];
             [self.musicPlayer stop];
             [self.musicPlayer setNowPlayingItem:song];
             [self.musicPlayer play];
             responseString = @"{}";
         } else {
             responseString = @"{'error': 'not found'}";
         }

         GCDWebServerDataResponse *res = [[GCDWebServerDataResponse alloc] initWithText:responseString];
         res.contentType = @"application/json";
         completionBlock(res);
     }];

    [self.httpServer addHandlerForMethod:@"GET" path:@"/next" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         [self.musicPlayer skipToNextItem];
         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{}]);
     }];

    [self.httpServer addHandlerForMethod:@"GET" path:@"/previous" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         [self.musicPlayer skipToPreviousItem];
         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{}]);
     }];

    [self.httpServer addHandlerForMethod:@"GET" path:@"/toggle_play" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         NSString *responseState = @"unknown";
         MPMusicPlaybackState playbackState = self.musicPlayer.playbackState;
         if (playbackState == MPMusicPlaybackStatePlaying) {
             [self.musicPlayer pause];
             responseState = @"paused";
         } else if (playbackState == MPMusicPlaybackStatePaused || playbackState == MPMusicPlaybackStateStopped) {
             [self.musicPlayer play];
             responseState = @"playing";
         }

         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{@"state": responseState}]);
     }];

    [self.httpServer addHandlerForMethod:@"GET" pathRegex:@"/volume/(.*)" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         NSArray *captures = [request attributeForKey:GCDWebServerRequestAttribute_RegexCaptures];
         float volume = [captures[0] integerValue] / 100.0;
         [self.musicPlayer setVolume:volume];
         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{}]);
     }];

    [self.httpServer addHandlerForMethod:@"GET" path:@"/status" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         NSString *state;
         switch (self.musicPlayer.playbackState) {
             case MPMusicPlaybackStateStopped:
             case MPMusicPlaybackStatePaused:
                 state = @"paused";
                 break;
             case MPMusicPlaybackStatePlaying:
                 state = @"playing";
                 break;
             default:
                 state = @"unknown";
                 break;
         }

         MPMediaItem *nowPlaying = [self.musicPlayer nowPlayingItem];
         NSDictionary *status = @{
                                  @"volume": @(self.musicPlayer.volume * 100),
                                  @"state": state,
                                  @"title": [nowPlaying valueForKey:MPMediaItemPropertyTitle],
                                  @"album": [nowPlaying valueForKey:MPMediaItemPropertyAlbumTitle],
                                  @"artist": [nowPlaying valueForKey:MPMediaItemPropertyArtist],
                                  };

         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:status]);
     }];

    [self.httpServer startWithPort:8989 bonjourName:@"kasrak.Jukebox"];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    

    self.musicPlayer = [MPMusicPlayerController systemMusicPlayer];
    [self.musicPlayer setQueueWithQuery:[MPMediaQuery songsQuery]];
    [self.musicPlayer setShuffleMode:MPMusicShuffleModeSongs];
    [self.musicPlayer setRepeatMode:MPMusicRepeatModeAll];
    
    [self performSelectorInBackground:@selector(scanLibrary) withObject:self];
    
    return YES;
}

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
    self.library = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

@end
