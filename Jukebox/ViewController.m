#import <arpa/inet.h>
#import <ifaddrs.h>
#import <MediaPlayer/MediaPlayer.h>

#import "ViewController.h"
#import "JukeboxHTTPServer.h"

@interface ViewController ()

@property (strong, nonatomic) MPMusicPlayerController *musicPlayer;
@property (strong, nonatomic) JukeboxHTTPServer *httpServer; // TODO: should these be weak?

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

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil musicPlayer:(MPMusicPlayerController *)musicPlayer httpServer:(JukeboxHTTPServer *)httpServer {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
        return nil;
    }

    self.musicPlayer = musicPlayer;
    self.httpServer = httpServer;

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // TODO: move this into a UIView subclass.
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    volumeView.tintColor = [UIColor whiteColor];
    volumeView.showsVolumeSlider = YES;
    volumeView.showsRouteButton = YES;
    volumeView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:volumeView];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[volumeView]-|" options:0 metrics:nil views:@{@"volumeView": volumeView}]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[volumeView(30)]-20-|" options:0 metrics:nil views:@{@"volumeView": volumeView}]];

    [self playbackStateChanged:nil];
    [self nowPlayingItemChanged:nil];
    [self.ipLabel setText:[[self.httpServer serverURL] absoluteString]];

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
