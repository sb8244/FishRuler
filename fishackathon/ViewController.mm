//
//  ViewController.m
//  fishackathon
//
//  Created by Stephen Bussey on 6/6/15.
//  Copyright (c) 2015 Stephen Bussey. All rights reserved.
//

#import "ViewController.hh"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UITextField *nameField;

// [0 initial] [1 light] [2 dark]
@property int lineState;
@property bool recording;
@property int clicks;
@property (weak, nonatomic) NSTimer *timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repeatableSetup)
                                                 name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];

    [self repeatableSetup];
}

- (void) repeatableSetup {
    self.videoCamera = [[CvVideoCamera alloc] init];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = YES;
    self.videoCamera.delegate = self;
    
    [self.videoCamera start];
    
    [self.startStopButton setTitle:@"Stop" forState: UIControlStateSelected];
    [self.startStopButton setTitle:@"Start" forState: UIControlStateNormal];
    [self.nameField addTarget:self.nameField
                       action:@selector(resignFirstResponder)
             forControlEvents:UIControlEventEditingDidEndOnExit];
    
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"outputVolume"]) {
        [self clicked:nil];
    }
}

- (IBAction)clicked:(id)sender {
    self.recording = !self.recording;
    
    if (self.recording) {
        self.clicks = 0;
        self.lineState = 0;
        [self.startStopButton setSelected:true];
        [self.label setText: @"0 cm"];
        [self turnFlashlight:YES];
    } else {
        [self.startStopButton setSelected:false];
        [self.label setText: @"Not Measuring"];
        [self turnFlashlight:NO];
        
        if (self.clicks > 0) {
            [self recordFish:self.clicks];
        }
    }
    
    NSLog(@"Click: %d", self.recording ? 1 : 0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) didClick {
    self.clicks++;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.label setText: [NSString stringWithFormat: @"%d cm", self.clicks]];
    }];
}

- (void) recordFish:(int) clicks {
    NSLog(@"Record Fish Length: %d", clicks);
    
    [PFGeoPoint geoPointForCurrentLocationInBackground:^(PFGeoPoint *geoPoint, NSError *error) {
        NSLog(@"Got Location %@", geoPoint);
        PFObject *testObject = [PFObject objectWithClassName:@"FishRecord"];
        testObject[@"length"] = @(clicks);
        testObject[@"name"] = [self.nameField text];
        
        if (!error) {
            NSLog(@"User is currently at %f, %f", geoPoint.latitude, geoPoint.longitude);
            testObject[@"location"] = geoPoint;
        }
        
        [testObject saveInBackground];
    }];
}

- (void)processImage:(cv::Mat &)image {
    if (!self.recording) {
        return;
    }
    
    int Y = 0;
    int avgCount = 0;
    
    for (int r = image.rows / 2 - 10; r <= image.rows / 2 + 10; r++) {
        for (int c = image.cols / 2 - 10; c <= image.cols / 2 + 10; c++) {
            cv::Vec3b yuvPixel = image.at<cv::Vec3b>(image.rows/2, image.cols/2);
            Y += yuvPixel[0];
            avgCount++;
        }
    }
    
    Y /= avgCount;
    
    NSLog(@"%d", Y);
    
    if (Y > 120) {
        if (self.lineState == 2) { // It was dark now it's light
            self.lineState = 1;
            [self didClick];
            NSLog(@"Now light: %d", self.clicks);
        } else if(self.lineState == 0) {
            self.lineState = 1;
        }
    } else if (Y < 80) {
        if (self.lineState == 1) { // It was light now it's dark
            self.lineState = 2;
            [self didClick];
            NSLog(@"Now dark: %d", self.clicks);
        } else if(self.lineState == 0) {
            self.lineState = 2;
        }
    }
}

- (void)turnFlashlight:(bool) on
{
    AVCaptureDevice * captDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([captDevice hasFlash]&&[captDevice hasTorch]) {
        [captDevice lockForConfiguration:nil];
        [captDevice setTorchMode: (on ? AVCaptureTorchModeOn : AVCaptureTorchModeOff)];
        [captDevice unlockForConfiguration];
    }
}

- (IBAction)nameEditingBegin:(UITextView *)textView {
    if ([textView.text isEqualToString:@"Name"]) {
        textView.text = @"";
    }
}

- (IBAction)nameEditingEnd:(UITextField *)textView {
    if ([textView.text isEqualToString:@""]) {
        textView.text = @"Name";
    }
}

@end
