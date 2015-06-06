//
//  ViewController.h
//  fishackathon
//
//  Created by Stephen Bussey on 6/6/15.
//  Copyright (c) 2015 Stephen Bussey. All rights reserved.
//
#import <opencv2/opencv.hpp>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) AVCaptureStillImageOutput* stillImageOutput;

@end

