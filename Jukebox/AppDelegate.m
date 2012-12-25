//
//  AppDelegate.m
//  Jukebox
//
//  Created by Kasra Kyanzadeh on 2012-12-24.
//  Copyright (c) 2012 Kasra. All rights reserved.
// 

#import "AppDelegate.h"
#import "ViewController.h"
#import "RoutingHTTPServer.h"

#import <MediaPlayer/MPMediaQuery.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    library = nil;
    
    httpServer = [[RoutingHTTPServer alloc] init];
    [httpServer setPort:8989];
    NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    [httpServer setDocumentRoot:webPath];
    
    [httpServer handleMethod:@"GET" withPath:@"/songs" block:^(RouteRequest *req, RouteResponse *res) {
        if (library) {
            [res setHeader:@"Content-type" value:@"application/json"];
            [res respondWithString:library];
        } else {
            [res respondWithString:@"NOT READY"];
        }
    }];
    
    [httpServer handleMethod:@"GET" withPath:@"/play/*" block:^(RouteRequest *req, RouteResponse *res) {
        NSArray *wildcards = [req.params objectForKey:@"wildcards"];
        unsigned long long ull = strtoull([[wildcards objectAtIndex:0] UTF8String], NULL, 0);
        NSNumber *persistentID = [NSNumber numberWithUnsignedLongLong:ull];
        
        MPMediaPropertyPredicate *predicate = [MPMediaPropertyPredicate predicateWithValue:persistentID forProperty:MPMediaEntityPropertyPersistentID];
        MPMediaQuery *query = [[MPMediaQuery alloc] init];
        [query addFilterPredicate:predicate];
        
        if (query.items.count) {
            MPMediaItem *song = [query.items objectAtIndex:0];
            [player stop];
            [player setNowPlayingItem:song];
            [player play];
            [res respondWithString:[NSString stringWithFormat:@"PLAYING"]];
        } else {
            [res respondWithString:[NSString stringWithFormat:@"NOT FOUND %@", persistentID]];
        }
    }];
    
    NSError *err;
    if ([httpServer start:&err]) {
        NSLog(@"Started server on port %hu", httpServer.listeningPort);
    } else {
        NSLog(@"Error starting server: %@", err);
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    

    player = [MPMusicPlayerController iPodMusicPlayer];
    [player setQueueWithQuery:[MPMediaQuery songsQuery]];
    [player setShuffleMode:MPMusicShuffleModeSongs];
    [player setRepeatMode:MPMusicRepeatModeAll];
    [player stop];
    
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
                         [item valueForProperty:MPMediaItemPropertyPersistentID],
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
    library = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [httpServer stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [httpServer start:nil];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [httpServer stop];
}

@end
