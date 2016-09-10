//
//  CameraViewController.m
//  GeoTrail
//
//  Created by Arthur Araujo on 6/25/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import "CameraViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "ViewController.h"
#import "TabBarController.h"

@import Firebase;

@interface CameraViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageOutputView;
@property (retain) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) IBOutlet UIImageView *CameraView;
@property (weak, nonatomic) IBOutlet UIButton *CameraButton;
@property (nonatomic) CLLocationCoordinate2D userLocation;
@property (weak, nonatomic) IBOutlet UIButton *retakePicButton;
@property (weak, nonatomic) IBOutlet UIButton *postPicButton;
@end

@implementation CameraViewController{
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_capturesession;
    UIImage *currentImageTaken;
    NSData *currentImageData;
    bool camViewPosBack; //MAKE NSUSERDEFAULT LATER
    NSString *userUID;
    FIRStorage *firebaseRef;
    NSNumber *currentHexLat;
    NSNumber *currentHexLong;
}

- (void)viewDidLoad {
    [self setUpAVCaptureSession];
    self.navigationController.navigationBarHidden = true;
    
    TabBarController *tabBarController = (TabBarController *)self.tabBarController;
    userUID = tabBarController.currentUser.uid;
    firebaseRef = tabBarController.firebaseRef;
    currentHexLat = tabBarController.currentHexLat;
    currentHexLong = tabBarController.currentHexLong;
    
    _imageOutputView.image = nil;
    self.retakePicButton.hidden = true;
    self.postPicButton.hidden = true;
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

-(void)setUserUID:(NSString *)uid{
    userUID = uid;
}

- (IBAction)retakePicture:(id)sender {
    _imageOutputView.image = nil;
    self.retakePicButton.hidden = true;
    self.postPicButton.hidden = true;
}

- (IBAction)PostPicture:(id)sender {
    _CameraView.image = currentImageTaken;
    
    // using base64StringFromData method, we are able to convert data to string
    //NSString *imageString = [[NSString alloc] initWithData:currentImageData encoding:NSUTF8StringEncoding];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM/dd/yyyy HH:mm"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSDictionary *post = @{
                           @"owner": userUID,
                           @"imageData": currentImageData.base64Encoding,
                           @"latitude": currentHexLat,
                           @"longitude": currentHexLong,
                           @"likes": [NSNumber numberWithInt:0],
                           @"views":[NSNumber numberWithInt:0],
                           @"whoLiked": [NSArray arrayWithObject:@"Temp"],
                           @"whoViewed": [NSArray arrayWithObject:@"Temp"],
                           @"whoLikedIDs": [NSArray arrayWithObject:@"Temp"],
                           @"whoViewedIDs": [NSArray arrayWithObject:@"Temp"],
                           @"dateCreated": date
                           };

//    Firebase *picsRef = [firebaseRef childByAppendingPath: @"postedpictures"];
    FIRDatabaseReference *postedpicsRef = [[FIRDatabase database] referenceWithPath:[firebaseRef.reference.fullPath stringByAppendingString:@"postedpictures"]];
    
    postedpicsRef = [postedpicsRef childByAutoId];
    //NSLog(@"Posted To: \n%@",picsRef);

    [postedpicsRef setValue: post];
    
    _imageOutputView.image = nil;
    self.retakePicButton.hidden = true;
    self.postPicButton.hidden = true;
    
    //SET UP A "POSTED :)" MESSAGE WHEN FINSIHED
}

- (IBAction)TappedOnCameraButton:(id)sender {
    //if (hideStatusBar == FALSE) {//IF IT IS ON MAIN PAIGE
        
  //  }else{//IF IT IS PRESS IN CAMERA VIEW: TAKE PICTURE
        if (_capturesession.running) {
            [self captureStillImage];
        }
  //  }
}

-(void)setUpAVCaptureSession{
    //-- Setup Capture Session.
    _capturesession = [[AVCaptureSession alloc] init];
    
    //-- Creata a video device and input from that Device.  Add the input to the capture session.
    AVCaptureDevice * videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(videoDevice == nil){
        assert(0);
        //DECLARE THAT THE USER'S CAMERA CAN NOT BE USED (NOT AVALIABLE OR SOME SORT)
    }
    
    //-- Add the device to the session.
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice
                                                                        error:&error];
    if(error)
        assert(0);
    
    [_capturesession addInput:input];
    
    //-- Configure the preview layer
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_capturesession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [_previewLayer setFrame:CGRectMake(0, 0,
                                       self.view.bounds.size.width,
                                       self.view.bounds.size.height)];
    
    //-- Add the layer to the view that should display the camera input
    [self.CameraView.layer addSublayer:_previewLayer];
    
    [_capturesession setSessionPreset:AVCaptureSessionPresetHigh];
    
    //-- Start the camera
    [_capturesession startRunning];
    
    [self addStillImageOutput];
    [self fixPhotoOrientation];
}

-(void)fixPhotoOrientation
{
    [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
}

//CHANGE FOR FRONT CAMERA
- (void)frontCamera {
    AVCaptureDevice *theDevice;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionFront) {
            theDevice = device;
        }
    }
    AVCaptureDevice *device = theDevice;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //REMOVE THE INPIT
    AVCaptureInput* currentCameraInput = [_capturesession.inputs objectAtIndex:0];
    [_capturesession removeInput:currentCameraInput];
    //ADD NEW INPUT
    if ([_capturesession canAddInput:deviceInput]){
        [_capturesession addInput:deviceInput];
    }
}
//CHANGE FOR BACK CAMERA
- (void)backCamera {
    AVCaptureDevice *theDevice;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionBack) {
            theDevice = device;
        }
    }
    AVCaptureDevice *device = theDevice;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //REMOVE THE INPIT
    AVCaptureInput* currentCameraInput = [_capturesession.inputs objectAtIndex:0];
    [_capturesession removeInput:currentCameraInput];
    //ADD NEW INPUT
    if ([_capturesession canAddInput:deviceInput]){
        [_capturesession addInput:deviceInput];
    }
}

- (IBAction)changeCamView:(id)sender {
    if(camViewPosBack){//IF IT IS ALREADY ON REAR VIEW
        [self frontCamera];
        camViewPosBack = false;
    }else{//IF IT IS ALREADY ON FRONT VIEW
        [self backCamera];
        camViewPosBack = true;
    }
}

//////////////////////////////CAPTURING STILL IMAGES USING CAPTURESESSION (NOT IN USE!)/////////
- (void)addStillImageOutput
{
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [_stillImageOutput setOutputSettings:outputSettings];
    [_capturesession addOutput:_stillImageOutput];
}

- (void)captureStillImage
{
    [self fixPhotoOrientation];
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in [[self stillImageOutput] connections]) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    
    NSLog(@"about to request a capture from: %@", [self stillImageOutput]);
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:videoConnection
                                                         completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
                                                             CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
                                                             if (exifAttachments) {
                                                                 //NSLog(@"attachements: %@", exifAttachments);
                                                                 NSLog(@"Took picture successfully!");
                                                             } else {
                                                                 NSLog(@"no attachments");
                                                             }
                                                             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
                                                             currentImageData = imageData;
                                                             UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                             currentImageTaken = image;
                                                             image = nil;
                                                             [[NSNotificationCenter defaultCenter] postNotificationName:@"imageCapturedSuccessfully" object:nil];
                                                             
                                                             [_imageOutputView setHidden:FALSE];
                                                             
                                                             _imageOutputView.image = currentImageTaken;
                                                             self.retakePicButton.hidden = false;
                                                             self.postPicButton.hidden = false;
                                                         }];
}

//////////////////////////////CAPTURING STILL IMAGES USING CAPTURESESSION (NOT IN USE!)/////////

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
