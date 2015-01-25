#import "JukeboxHTTPServer.h"

#import "GCDWebServer.h"
#import "GCDWebServerRequest.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerStreamedResponse.h"

#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MediaPlayer.h>

@interface JukeboxHTTPServer ()

@property (nonatomic, strong) GCDWebServer *server;
@property (nonatomic, strong) NSMapTable *listeners;

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
                                  @"title": nilToNull([nowPlaying valueForKey:MPMediaItemPropertyTitle]),
                                  @"album": nilToNull([nowPlaying valueForKey:MPMediaItemPropertyAlbumTitle]),
                                  @"artist": nilToNull([nowPlaying valueForKey:MPMediaItemPropertyArtist]),
                                  };

         completionBlock([[GCDWebServerDataResponse alloc] initWithJSONObject:status]);
     }];

    self.listeners = [NSMapTable weakToStrongObjectsMapTable];
    [server addHandlerForMethod:@"GET" path:@"/events" requestClass:[GCDWebServerRequest class] processBlock:
     ^GCDWebServerResponse *(GCDWebServerRequest *request) {
         return [GCDWebServerStreamedResponse responseWithContentType:@"text/event-stream" asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock completionBlock) {

             if (![self.listeners objectForKey:request]) {
                 // TODO: remove from listeners when connection closes?
                 GCDWebServerBodyReaderCompletionBlock blockCopy = [completionBlock copy];
                 [self.listeners setObject:blockCopy forKey:request];
             }
         }];
     }];

    return server;
}

- (void)startWithPort:(NSUInteger)port {
    [self.server startWithPort:port bonjourName:@"kasrak.Jukebox"];
}

- (void)notifyEvent:(NSString *)event message:(NSString *)message {
    NSData *data = [[NSString stringWithFormat:@"event: %@\ndata: %@\n\n", event, message] dataUsingEncoding:NSUTF8StringEncoding];

    NSLog(@"Notifying %lu listeners...", (unsigned long)self.listeners.count);

    // TODO: if message has newlines, need to start each line with "data:"

    for (GCDWebServerRequest *key in self.listeners) {
        GCDWebServerBodyReaderCompletionBlock block = [self.listeners objectForKey:key];
        block(data, nil);
    }
}

- (NSURL *)serverURL {
    return [self.server serverURL];
}

@end
