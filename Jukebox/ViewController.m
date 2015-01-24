#import <arpa/inet.h>
#import <ifaddrs.h>
#import <MediaPlayer/MediaPlayer.h>

#import "ViewController.h"

@interface ViewController ()

@property (strong, nonatomic) MPMusicPlayerController *musicPlayer;

@property (weak, nonatomic) IBOutlet UILabel *ipLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentSongLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentArtistLabel;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIImageView *artworkImageView;

- (IBAction)playTapped:(id)sender;
- (IBAction)nextTapped:(id)sender;
- (IBAction)prevTapped:(id)sender;

- (void)playbackStateChanged:(id)sender;
- (void)nowPlayingItemChanged:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    volumeView.tintColor = [UIColor whiteColor];
    volumeView.showsVolumeSlider = YES;
    volumeView.showsRouteButton = YES;
    volumeView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:volumeView];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[volumeView]-|" options:0 metrics:nil views:@{@"volumeView": volumeView}]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[volumeView(30)]-20-|" options:0 metrics:nil views:@{@"volumeView": volumeView}]];
    [self.view exerciseAmbiguityInLayout];

    self.musicPlayer = [MPMusicPlayerController systemMusicPlayer];

    [self playbackStateChanged:nil];
    [self nowPlayingItemChanged:nil];
    [self.ipLabel setText:[self getIPAddress]];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter
     addObserver: self
     selector:    @selector (playbackStateChanged:)
     name:        MPMusicPlayerControllerPlaybackStateDidChangeNotification
     object:      self.musicPlayer];

    [notificationCenter
     addObserver: self
     selector:    @selector (nowPlayingItemChanged:)
     name:        MPMusicPlayerControllerNowPlayingItemDidChangeNotification
     object:      self.musicPlayer];

    [self.musicPlayer beginGeneratingPlaybackNotifications];
}

- (void)dealloc {
    [self.musicPlayer endGeneratingPlaybackNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)getIPAddress {
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

- (void)playbackStateChanged:(id)sender {
    if (self.musicPlayer.playbackState == MPMusicPlaybackStatePlaying) {
        [self.playButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
    } else if (self.musicPlayer.playbackState == MPMusicPlaybackStatePaused || self.musicPlayer.playbackState == MPMusicPlaybackStateStopped) {
        [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    }
}

- (void)nowPlayingItemChanged:(id)sender {
    MPMediaItem *nowPlaying = [self.musicPlayer nowPlayingItem];
    self.artworkImageView.image = [[nowPlaying valueForKey:MPMediaItemPropertyArtwork] imageWithSize:self.artworkImageView.bounds.size];
    [self.currentSongLabel setText:[nowPlaying valueForKey:MPMediaItemPropertyTitle]];
    [self.currentArtistLabel setText:[nowPlaying valueForKey:MPMediaItemPropertyArtist]];
}

- (IBAction)playTapped:(id)sender {
    MPMusicPlaybackState playbackState = self.musicPlayer.playbackState;
    if (playbackState == MPMusicPlaybackStatePlaying) {
        [self.musicPlayer pause];
    } else if (playbackState == MPMusicPlaybackStatePaused || playbackState == MPMusicPlaybackStateStopped) {
        [self.musicPlayer play];
    }
}

- (IBAction)nextTapped:(id)sender {
    [self.musicPlayer skipToNextItem];
}

- (IBAction)prevTapped:(id)sender {
    [self.musicPlayer skipToPreviousItem];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
