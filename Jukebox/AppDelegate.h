//
//  AppDelegate.h
//  Jukebox
//
//  Created by Kasra Kyanzadeh on 2012-12-24.
//  Copyright (c) 2012 Kasra. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ViewController;
@class RoutingHTTPServer;
@class MPMusicPlayerController;

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    RoutingHTTPServer *httpServer;
    NSString *library;
    MPMusicPlayerController *player;
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@end
