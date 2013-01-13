//
//  ViewController.m
//  Jukebox
//
//  Created by Kasra Kyanzadeh on 2012-12-24.
//  Copyright (c) 2012 Kasra. All rights reserved.
//

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <MediaPlayer/MediaPlayer.h>

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize ipLabel, currentSongLabel, currentArtistLabel, playButton;

- (void)viewDidLoad
{
    [super viewDidLoad];
    player = [MPMusicPlayerController iPodMusicPlayer];

    [self playbackStateChanged:nil];
    [self nowPlayingItemChanged:nil];
    [ipLabel setText:[self getIPAddress]];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter
     addObserver: self
     selector:    @selector (playbackStateChanged:)
     name:        MPMusicPlayerControllerPlaybackStateDidChangeNotification
     object:      player];

    [notificationCenter
     addObserver: self
     selector:    @selector (nowPlayingItemChanged:)
     name:        MPMusicPlayerControllerNowPlayingItemDidChangeNotification
     object:      player];

    [player beginGeneratingPlaybackNotifications];
}

- (void)dealloc
{
    [player endGeneratingPlaybackNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)getIPAddress
{
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    NSString *wifiAddress = nil;
    NSString *cellAddress = nil;
    
    // retrieve the current interfaces - returns 0 on success
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            sa_family_t sa_type = temp_addr->ifa_addr->sa_family;
            if(sa_type == AF_INET || sa_type == AF_INET6) {
                NSString *name = [NSString stringWithUTF8String:temp_addr->ifa_name];
                NSString *addr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)]; // pdp_ip0
                // NSLog(@"NAME: \"%@\" addr: %@", name, addr); // see for yourself
                
                if([name isEqualToString:@"en0"]) {
                    // Interface is the wifi connection on the iPhone
                    wifiAddress = addr;
                } else
                    if([name isEqualToString:@"pdp_ip0"]) {
                        // Interface is the cell connection on the iPhone
                        cellAddress = addr;
                    }
            }
            temp_addr = temp_addr->ifa_next;
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    NSString *addr = wifiAddress ? wifiAddress : cellAddress;
    return addr ? addr : @"0.0.0.0";
}

- (void)playbackStateChanged:(id)sender
{
    if (player.playbackState == MPMusicPlaybackStatePlaying) {
        [playButton setTitle:@"Pause" forState:UIControlStateNormal];
    } else if (player.playbackState == MPMusicPlaybackStatePaused || player.playbackState == MPMusicPlaybackStateStopped) {
        [playButton setTitle:@"Play" forState:UIControlStateNormal];
    }
}

- (void)nowPlayingItemChanged:(id)sender
{
    MPMediaItem *nowPlaying = [player nowPlayingItem];
    [currentSongLabel setText:[nowPlaying valueForKey:MPMediaItemPropertyTitle]];
    [currentArtistLabel setText:[nowPlaying valueForKey:MPMediaItemPropertyArtist]];
}

- (IBAction)playTapped:(id)sender
{
    if (player.playbackState == MPMusicPlaybackStatePlaying) {
        [player pause];
    } else if (player.playbackState == MPMusicPlaybackStatePaused || player.playbackState == MPMusicPlaybackStateStopped) {
        [player play];
    }
}

- (IBAction)nextTapped:(id)sender
{
    [player skipToNextItem];
}

- (IBAction)prevTapped:(id)sender
{
    [player skipToPreviousItem];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
