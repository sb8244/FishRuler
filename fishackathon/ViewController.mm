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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSArray *devices = [AVCaptureDevice devices];
    
    AVCaptureDevice *backCamera;
    
    for (AVCaptureDevice *device in devices) {
        if  ([device.localizedName isEqualToString: @"Back Camera"]) {
            backCamera = device;
        }
    }
    
    if (backCamera) {
        [self setupCaptureSession:backCamera];
        [self captureNow:backCamera];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) setupCaptureSession: (AVCaptureDevice *) device {
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer    alloc] initWithSession:session];
    [self.view.layer addSublayer:captureVideoPreviewLayer];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handle the error appropriately.
        NSLog(@"ERROR: trying to open camera: %@", error);
    }
    [session addInput:input];
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    [session addOutput:self.stillImageOutput];
    
    [session startRunning];
}

-(void) captureNow: (AVCaptureDevice *) device {
    dispatch_queue_t imageQueue = dispatch_queue_create("Image Queue",NULL);
    
    dispatch_async(imageQueue, ^{
        AVCaptureConnection *videoConnection = nil;
        for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
            for (AVCaptureInputPort *port in [connection inputPorts]) {
                if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                    videoConnection = connection;
                    break;
                }
            }
            if (videoConnection) { break; }
        }
        
        NSLog(@"about to request a capture from: %@", self.stillImageOutput);
        __weak typeof(self) weakSelf = self;
        
        if ([device lockForConfiguration:nil]) {
            [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            [device setTorchMode:AVCaptureTorchModeOn];
            [device setVideoZoomFactor: 1.6];
            [device unlockForConfiguration];
        }
        
        sleep(1);
        
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
            
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
            
            [self processImage: image];
            
            [weakSelf.imageView setImage: image];
            
            if ([device lockForConfiguration:nil]) {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device unlockForConfiguration];
            }
        }];
    });
}

-(void) processImage: (UIImage *) image {
    dispatch_queue_t processQueue = dispatch_queue_create("Process Queue",NULL);
    
    dispatch_async(processQueue, ^{
        
        CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
        const UInt8* data = CFDataGetBytePtr(pixelData);
        
        NSLog(@"Start");
        
        CGPoint hotspot;
        CGFloat hotspotBrightness = 0.0;
        UIColor * hotspotColor;
        
        // Locate the hotspot where the flash reflects on the tape
        for (int w = 0; w < image.size.width; w++) {
            for (int h = 0; h < image.size.height; h++) {
                UIColor * color = [self pixelColorInImage:image data:data atX:w atY:h];
                
                const CGFloat *components = CGColorGetComponents(color.CGColor);
                
                CGFloat R = components[0];
                CGFloat G = components[1];
                CGFloat B = components[2];
                
                CGFloat Y = (R+R+B+G+G+G)/6;
                
                if (Y > hotspotBrightness) {
                    hotspot = CGPointMake(w, h);
                    hotspotBrightness = Y;
                    hotspotColor = color;
                }
            }
        }
        
        // Get the 4 colors at 100 pixels up and 100 pixels down of the center
        UIColor * a = [self pixelColorInImage:image data:data atX:(image.size.width / 2 - 100) atY:(image.size.height / 2 - 100)];
        UIColor * b = [self pixelColorInImage:image data:data atX:(image.size.width / 2 - 100) atY:(image.size.height / 2 + 100)];
        UIColor * c = [self pixelColorInImage:image data:data atX:(image.size.width / 2 + 100) atY:(image.size.height / 2 - 100)];
        UIColor * d = [self pixelColorInImage:image data:data atX:(image.size.width / 2 + 100) atY:(image.size.height / 2 + 100)];
        
        NSArray * colors = @[a, b, c, d];
        
        CGFloat red   = [self average:colors pos:0];
        CGFloat green = [self average:colors pos:1];
        CGFloat blue  = [self average:colors pos:2];
        
        UIColor * averageColor = [UIColor colorWithRed:red
                                                 green:green
                                                 blue:blue
                                                 alpha:1.0f];
        
        NSLog(@"%@", [self hexStringFromColor: averageColor]);
        
        CFRelease(pixelData);
    });
}

- (UIColor*)pixelColorInImage:(UIImage*)image data:(const UInt8*)data atX:(int)x atY:(int)y {
    int pixelInfo = ((image.size.width  * y) + x ) * 4; // 4 bytes per pixel
    
    UInt8 red   = data[pixelInfo + 0];
    UInt8 green = data[pixelInfo + 1];
    UInt8 blue  = data[pixelInfo + 2];
    UInt8 alpha = data[pixelInfo + 3];
    
    return [UIColor colorWithRed:red/255.0f
                           green:green/255.0f
                            blue:blue/255.0f
                           alpha:alpha/255.0f];
}

- (CGFloat) average:(NSArray*) colors pos:(int)pos {
    CGFloat avg = 0.0;
    
    for (UIColor * color in colors) {
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        
        avg += components[pos];
    }
    
    return avg / colors.count;
}

- (NSString *)hexStringFromColor:(UIColor *)color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255)];
}

@end
