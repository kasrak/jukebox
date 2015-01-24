#import <UIKit/UIKit.h>

@interface ViewController : UIViewController {
    IBOutlet UILabel *ipLabel;
    IBOutlet UILabel *currentSongLabel;
    IBOutlet UILabel *currentArtistLabel;
    IBOutlet UIButton *playButton;
    IBOutlet UISlider *volumeSlider;

    MPMusicPlayerController *player;
}

@property (retain, nonatomic) IBOutlet UILabel *ipLabel;
@property (retain, nonatomic) IBOutlet UILabel *currentSongLabel;
@property (retain, nonatomic) IBOutlet UILabel *currentArtistLabel;
@property (retain, nonatomic) IBOutlet UIButton *playButton;
@property (retain, nonatomic) IBOutlet UISlider *volumeSlider;

- (IBAction)playTapped:(id)sender;
- (IBAction)nextTapped:(id)sender;
- (IBAction)prevTapped:(id)sender;
- (IBAction)volumeSlid:(id)sender;

- (void)playbackStateChanged:(id)sender;
- (void)nowPlayingItemChanged:(id)sender;
- (void)volumeChanged:(id)sender;

@end
