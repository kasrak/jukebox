#import "JukeboxHTTPServer.h"

#import "GCDWebServer.h"
#import "GCDWebServerRequest.h"
#import "GCDWebServerDataResponse.h"

#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MediaPlayer.h>

@interface JukeboxHTTPServer ()

@property (nonatomic, strong) GCDWebServer *server;

@end

@implementation JukeboxHTTPServer

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.server = [self createServer];

    return self;
}

- (GCDWebServer *)createServer {
    GCDWebServer *server = [[GCDWebServer alloc] init];

    NSString *staticPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    [server addGETHandlerForBasePath:@"/" directoryPath:staticPath indexFilename:@"index.html" cacheAge:3600 allowRangeRequests:NO];

    [server addHandlerForMethod:@"GET" path:@"/songs" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
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

    [server addHandlerForMethod:@"GET" pathRegex:@"/play/(.*)" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
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

    [server addHandlerForMethod:@"GET" path:@"/next" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         [self.musicPlayer skipToNextItem];
         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{}]);
     }];

    [server addHandlerForMethod:@"GET" path:@"/previous" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         [self.musicPlayer skipToPreviousItem];
         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{}]);
     }];

    [server addHandlerForMethod:@"GET" path:@"/toggle_play" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
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

    [server addHandlerForMethod:@"GET" pathRegex:@"/volume/(.*)" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
     ^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
         NSArray *captures = [request attributeForKey:GCDWebServerRequestAttribute_RegexCaptures];
         float volume = [captures[0] integerValue] / 100.0;
         [self.musicPlayer setVolume:volume];
         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:@{}]);
     }];

    [server addHandlerForMethod:@"GET" path:@"/status" requestClass:[GCDWebServerRequest class] asyncProcessBlock:
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

    return server;
}

- (void)startWithPort:(NSUInteger)port {
    [self.server startWithPort:port bonjourName:@"kasrak.Jukebox"];
}

- (NSURL *)serverURL {
    return [self.server serverURL];
}

@end
