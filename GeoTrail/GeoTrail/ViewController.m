//
//  ViewController.m
//  SnapTrail
//
//  Created by Arthur Araujo on 4/12/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <Parse/Parse.h>
#import <GoogleMaps/GoogleMaps.h>

#import "ViewController.h"

BOOL initialZoomComplete = NO;

@interface ViewController ()

@property (retain) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) IBOutlet UIImageView *CameraView;
@property (strong, nonatomic) AVCaptureSession *capturesession;
@property (weak, nonatomic) IBOutlet UIButton *CameraButton;
@property (weak, nonatomic) IBOutlet GMSMapView *mapView_;
@end

@implementation ViewController{
    CLLocationManager *locationManager;
    
    // test data
    NSMutableArray *testCoordinates;
    CLLocationCoordinate2D caltrainSanFranciscoCoordinates;
    CLLocationCoordinate2D appleStoreSanFranciscoCoordinates;
    
    float milesSpanRegion;
    bool camViewPosBack; //MAKE NSUSERDEFAULT LATER
    bool hideStatusBar;
    UIImage *currentImageTaken;
    PFObject *postedPictures;
    PFUser *user;
    NSArray *contactNamesArray;
    NSArray *contactIDsArray;
    CLLocationCoordinate2D currentUserLoc;
}

- (IBAction)PostPicture:(id)sender {
    // Data prep:
    UIImage *picture = currentImageTaken;
    NSData* data = UIImageJPEGRepresentation(picture, 0.5f);
    PFFile *imageFile = [PFFile fileWithData:data];
    CLLocationCoordinate2D userLocationCoords = self.mapView_.myLocation.coordinate;
    PFGeoPoint *currentPoint = [PFGeoPoint geoPointWithLatitude:userLocationCoords.latitude
                                                      longitude:userLocationCoords.longitude];
    
    PFUser *currentUser = [PFUser currentUser];
    
    // Stitch together a postObject and send this async to Parse
    PFObject *postObject = [PFObject objectWithClassName:@"PostedPictures"];
    postObject[@"User"] = currentUser;
    postObject[@"location"] = currentPoint;
    postObject[@"picture"] = imageFile;
    
    // Use PFACL to restrict future modifications to this object.
    PFACL *readOnlyACL = [PFACL ACL];
    [readOnlyACL setPublicReadAccess:YES];
    [readOnlyACL setPublicWriteAccess:NO];
    postObject.ACL = readOnlyACL;
    
    [postObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error) {
            NSLog(@"Couldn't save!");
            NSLog(@"%@", error);
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"error"]
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"Ok", nil];
            [alertView show];
            return;
        }
        if (succeeded) {
            NSLog(@"Successfully saved!");
            NSLog(@"%@", postObject);
        } else {
            NSLog(@"Failed to save.");
        }
    }];
    
    
    
    [self TappedOnBackToMain:sender];
}

- (IBAction)TappedOnCameraButton:(id)sender {
    if (hideStatusBar == FALSE) {//IF IT IS ON MAIN PAIGE
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController setToolbarHidden:YES animated:YES];
        hideStatusBar = true;
        //REMOVES THE STATUS BAR
        [self prefersStatusBarHidden];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
        [_capturesession startRunning];
        currentImageTaken = nil;
        _CameraView.image = currentImageTaken;
        [UIView animateWithDuration:0.3 animations:^{
            self.mapView_.alpha = 0;
        } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
            self.mapView_.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
        }];
    }else{//IF IT IS PRESS IN CAMERA VIEW: TAKE PICTURE
        if (_capturesession.running) {
            [_capturesession stopRunning];
            UIGraphicsBeginImageContextWithOptions(_CameraView.frame.size, YES, 4);
            
            [_CameraView drawViewHierarchyInRect:_CameraView.frame afterScreenUpdates:YES];
            
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            currentImageTaken = image;
        }
    }
}
- (IBAction)TappedOnBackToMain:(id)sender {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController setToolbarHidden:NO animated:YES];
    hideStatusBar = FALSE;
    //RETRACTS THE STATUS BAR
    [self prefersStatusBarHidden];
    [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    [_capturesession stopRunning];
    self.mapView_.alpha = 0;
    self.mapView_.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.mapView_.alpha = 1;
    }];
}

-(BOOL)prefersStatusBarHidden{
    if (hideStatusBar) {
        return YES;
    }else{
        return NO;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    initialZoomComplete = NO;
    
    // Create a GMSCameraPosition that tells the map to display the
    // coordinate -33.86,151.20 at zoom level 6.
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:-33.86
                                                            longitude:151.20
                                                                 zoom:6];
    self.mapView_.camera = camera;
    self.mapView_.myLocationEnabled = YES;
    
    // Creates a marker in the center of the map.
    GMSMarker *marker = [[GMSMarker alloc] init];
    marker.position = CLLocationCoordinate2DMake(-33.86, 151.20);
    marker.title = @"Sydney";
    marker.snippet = @"Australia";
    marker.map = self.mapView_;
    
    [self setUpAVCaptureSession];
        
    camViewPosBack = true;
    hideStatusBar = false;
    
    //ASKS USER TO LOGIN/ SIGN UP
    if (!PFUser.currentUser) {
        UIAlertController *loginAlert = [UIAlertController alertControllerWithTitle:@"Sign Up / Login" message:@"Please sign up or login" preferredStyle:UIAlertControllerStyleAlert];
        
        [loginAlert addTextFieldWithConfigurationHandler:^(UITextField *textField){
            textField.placeholder = @"Your username";
        }];
        [loginAlert addTextFieldWithConfigurationHandler:^(UITextField *textField){
            textField.placeholder = @"Your password";
            textField.secureTextEntry = true;
        }];
        [loginAlert addAction:[UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            NSArray *textFields = loginAlert.textFields;
            UITextField *userName = textFields[0];
            UITextField *password = textFields[1];
            
            user = [PFUser user];
            user.username = userName.text;
            user.password = password.text;
            [user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (error) {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"error"]
                                                                        message:nil
                                                                       delegate:self
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:@"OK", nil];
                    [alertView show];
                    return;
                }
                
                // Success!
                PFUser *userID = [PFUser currentUser];
                if (userID != nil) {
                    [self uploadPostsOnMap:userID :@"You"];//SET UP ALL CURRENT USER'S PICTURES
                    [self loadContacts];
                }
            }];
        }]];
        [self presentViewController:loginAlert animated:true completion:nil];
    }
    
    //SET UP ALL USER INFORMATION:
    PFUser *userID = [PFUser currentUser];
    if (userID != nil) {
        [self uploadPostsOnMap:userID :@"You"];//SET UP ALL CURRENT USER'S PICTURES
        [self loadContacts];
    }
}

-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay{
    
    MKPolygonView *polyView = [[MKPolygonView alloc]initWithOverlay:overlay];
    
    polyView.fillColor = [UIColor greenColor];
    [polyView setAlpha:.3];
    
    return polyView;
}

- (IBAction)TappedRefresh:(id)sender {
    PFUser *userID = [PFUser currentUser];
    if (userID != nil) {
        [self uploadPostsOnMap:userID :@"You"];//SET UP ALL CURRENT USER'S PICTURES
        [self loadContacts];
    }
}

-(void)uploadPostsOnMap: (PFUser *)posterUser :(NSString *)Username{
    PFQuery *query = [PFQuery queryWithClassName:@"PostedPictures"];
    [query whereKey:@"User" equalTo:posterUser];// "user" must be pointer in the PostedPictures (table) get all the pictures that was posted by the user
    NSMutableArray *tempPostedPictureLocations = [NSMutableArray array];
    [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
        if (!error) {
            for (NSInteger i = 0; i <PFObjects.count; i++) {
                PFObject *thePostedPicture = PFObjects[i];
                
                PFGeoPoint *pictureLocation = [thePostedPicture objectForKey:@"location"];
                //PFFile *picture = [thePostedPicture objectForKey:@"picture"];
                
                CLLocationCoordinate2D picCoords = CLLocationCoordinate2DMake(pictureLocation.latitude, pictureLocation.longitude);
                
                //ADD THE LOCATION TO THE PICTURES LOCATIONS ARRAY

                [tempPostedPictureLocations addObject:[NSValue valueWithMKCoordinate:picCoords]];
                /*
                [picture getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
                    if (!error) {
                        UIImage *image = [UIImage imageWithData:data];
                        //ADD THE IMAGE TO THE PICTURES ARRAY
                        [PFPostedPictures addObject:image];
                    }
                }];*/
                
                NSLog(@"\nPic Coordinates: \n%f\n%f", pictureLocation.latitude, pictureLocation.longitude);
            }
        }
        //CODE EXECUTES AFTER THE ABOVE CODE IS CALLED
        [self plot:tempPostedPictureLocations: Username];
    }];
    // The InBackground methods are asynchronous, so any code after this will run
    // immediately.  Any code that depends on the query result should be moved
    // inside the completion block above.
}

//GET TO WORK TO ADD THE PICTURE LOCATIONS!!!

-(void)loadContacts{
    PFQuery *query = [PFQuery queryWithClassName:@"_User"];
    [query whereKey:@"username" equalTo:[[PFUser currentUser] username]]; // "user" must be pointer in the PostedPictures (table) get all the pictures that was posted by the user
    [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK", nil];
            [alertView show];
        }else{
            for (NSInteger i = 0; i < PFObjects.count; i++) {
                PFObject *thePostedPicture = PFObjects[i];
                NSArray *contacts = [thePostedPicture objectForKey:@"Contacts"];
                
                contactNamesArray = contacts;
            }
        }
        [self loadContactIDs];
    }];
}

-(void)loadContactIDs{
    PFQuery *query = [PFQuery queryWithClassName:@"_User"];
    contactIDsArray = nil;
    NSMutableArray *temp = [NSMutableArray array];
    
    for (int n = 0; n < contactNamesArray.count; n++) {
        [query whereKey:@"username" equalTo:contactNamesArray[n]]; // "user" must be pointer in the PostedPictures (table) get all the pictures that was posted by the user
        [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
            if (error) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                    message:nil
                                                                   delegate:self
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:@"OK", nil];
                [alertView show];
            }else{
                for (NSInteger i = 0; i < PFObjects.count; i++) {
                    [temp addObject:PFObjects[i]];
                }
            }
            contactIDsArray = [NSArray arrayWithArray:temp];
            
            [self uploadPostsOnMap: contactIDsArray[n]: contactNamesArray[n]];//SET UP ALL CURRENT USER'S PICTURES
        }];
    }
}

# pragma mark - Helper methods

- (void)plot:(NSArray *)objectsToPlot :(NSString *)Username
{
    // add all annotations
    // NOTE: coordinateValue can be any type from which a CLLocationCoordinate2D can be determined
    for (NSValue *coordinateValue in objectsToPlot)
    {
        // make CLLocationCoordinate2D
        CLLocationCoordinate2D coordinate = coordinateValue.MKCoordinateValue;
        
        GMSMarker *marker = [[GMSMarker alloc] init];
        marker.position = coordinate;
        marker.appearAnimation = kGMSMarkerAnimationPop;
        marker.icon = [UIImage imageNamed:@"pin.png"];
        // add annotation
        marker.title = Username;
        marker.snippet = @"In-Range";
        marker.map = self.mapView_;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Camera Still Image Methods (NOT USEFUL AS OF NOW)

-(void)setUpAVCaptureSession{
    _capturesession = [[AVCaptureSession alloc] init];
    [_capturesession setSessionPreset:AVCaptureSessionPresetPhoto];
    AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if ( [_capturesession canAddInput:deviceInput] ){
        [_capturesession addInput:deviceInput];
    }
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_capturesession];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    CALayer *rootLayer = self.view.layer;
    [rootLayer setMasksToBounds:YES];
    [previewLayer setFrame:self.view.frame];
    [rootLayer insertSublayer:previewLayer atIndex:0];
    
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
    for(NSInteger i = 0; i < _capturesession.outputs.count; i++){
        if(_capturesession.outputs[i] == [self stillImageOutput]) {
            [_capturesession removeOutput:[self stillImageOutput]];
        }
    }
    [self setStillImageOutput:[[AVCaptureStillImageOutput alloc] init]];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
    [[self stillImageOutput] setOutputSettings:outputSettings];
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in [[self stillImageOutput] connections]) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    
    [_capturesession addOutput:[self stillImageOutput]];
    
}

- (void)captureStillImage
{
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
                                                                 NSLog(@"attachements: %@", exifAttachments);
                                                             } else {
                                                                 NSLog(@"no attachments");
                                                             }
                                                             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
                                                             UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                             [self saveImage:image];
                                                             image = nil;
                                                             [[NSNotificationCenter defaultCenter] postNotificationName:@"imageCapturedSuccessfully" object:nil];
                                                         }];
}

-(void)saveImage:(UIImage*)image{
    currentImageTaken = image;
    _CameraView.image = currentImageTaken;
    [_capturesession stopRunning];
}
//////////////////////////////CAPTURING STILL IMAGES USING CAPTURESESSION (NOT IN USE!)/////////

@end
