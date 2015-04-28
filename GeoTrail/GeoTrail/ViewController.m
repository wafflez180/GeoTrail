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

#import "ViewController.h"
#import "MKAnnotationCustom.h"

BOOL initialZoomComplete = NO;

@interface ViewController ()

@property (retain) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) IBOutlet UIImageView *CameraView;
@property (strong, nonatomic) AVCaptureSession *capturesession;
@property (weak, nonatomic) IBOutlet UIButton *CameraButton;
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
}

- (IBAction)PostPicture:(id)sender {
    // Data prep:
    UIImage *picture = currentImageTaken;
    NSData* data = UIImageJPEGRepresentation(picture, 0.5f);
    PFFile *imageFile = [PFFile fileWithData:data];
    CLLocationCoordinate2D userLocationCoords = _mapView.userLocation.coordinate;
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
            self.mapView.alpha = 0;
        } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
            self.mapView.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
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
    self.mapView.alpha = 0;
    self.mapView.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.mapView.alpha = 1;
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
    
    // set up mapView
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeHybrid;
    self.mapView.showsUserLocation = YES;
    
    // remove existing annotations
    for (id<MKAnnotation> annotation in self.mapView.annotations)
    {
        [self.mapView removeAnnotation:annotation];
    }
    
    // set up location manager
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    
    // set up test data
    testCoordinates = [NSMutableArray array];
    
    caltrainSanFranciscoCoordinates = CLLocationCoordinate2DMake(37.776439, -122.394323);
    appleStoreSanFranciscoCoordinates = CLLocationCoordinate2DMake(37.785857, -122.40654);
    
    [testCoordinates addObject:[NSValue valueWithMKCoordinate:caltrainSanFranciscoCoordinates]];
    [testCoordinates addObject:[NSValue valueWithMKCoordinate:appleStoreSanFranciscoCoordinates]];
    milesSpanRegion = 3.5;//THE REGIONS VIEW AT DEFAULT IN FUTURE: MAKE REGION EXPAN TO UNLOCKED AREA
    [self setUpLocation];
    
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
                PFFile *picture = [thePostedPicture objectForKey:@"picture"];
                
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



-(void)resetRegion{
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(self.mapView.region.center, (milesSpanRegion * 1609.344), (milesSpanRegion * 1609.344));
    //1609.344 is one Mile in Meters
    
    [self.mapView setRegion:viewRegion animated:YES];
    
    [locationManager startUpdatingLocation];
}

- (void)setUpLocation
{
    // prompt for location allowing
    if ([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
    {
        [locationManager requestAlwaysAuthorization];
    }
    else
    {
        // TODO: Else case should provide set-up for iOS 7 devices
    }
    
    [locationManager startUpdatingLocation];
}

#pragma mark - CLLocationManagerDelegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [locationManager stopUpdatingLocation];
    
    if(!initialZoomComplete)
    {
        CLLocation *location = [locationManager location];
        CLLocationCoordinate2D coordinate = [location coordinate];
        
        float longitude = coordinate.longitude;
        float latitude = coordinate.latitude;
        
        CLLocationCoordinate2D zoomLocation;
        zoomLocation.latitude = latitude;
        zoomLocation.longitude= longitude;
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(zoomLocation, (milesSpanRegion * 1609.344), (milesSpanRegion * 1609.344));
        //1609.344 is one Mile in Meters
        
        [self.mapView setRegion:viewRegion animated:NO];
        
        [locationManager startUpdatingLocation];
        
        initialZoomComplete = YES;
    }
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [locationManager stopUpdatingLocation];
    
    // TODO: Notify user that location was not found
}

#pragma mark - MKMapViewDelegate methods

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    // If it's the user location, just return nil COMMENTED OUT -----------------------------
//    if ([annotation isKindOfClass:[MKUserLocation class]])
//        return nil;
    
    // Handle any custom annotations.
    if ([annotation isKindOfClass:[MKAnnotationCustom class]])
    {
        // Try to dequeue an existing annotation view first
        MKAnnotationView *annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"CustomAnnotationViewIdentifier"];
        
        if (!annotationView)
        {
            // If an existing pin view was not available, create one.
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"CustomAnnotationViewIdentifier"];
            annotationView.canShowCallout = YES;
            
            // set pin image
            UIImage *pinImage = [UIImage imageNamed:@"pin.png"];
            annotationView.image = pinImage;
            
            // set callout
            /*UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            annotationView.rightCalloutAccessoryView = rightButton;*/
        }
        else
        {
            annotationView.annotation = annotation;
        }
        
        return annotationView;
    }
    
    return nil;
}
// USER PRESSED ON THE ANNOTATION
- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    [mapView setCenterCoordinate:[view.annotation coordinate] animated:YES];
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
        bool alreadyTaken;
        alreadyTaken = false;
        for (int i = 0; i < _mapView.annotations.count; i++) {
            MKAnnotationCustom *temp = _mapView.annotations[i];
            if (coordinate.longitude == temp.coordinate.longitude && coordinate.latitude == temp.coordinate.latitude) {
                alreadyTaken = true;
            }
        }
            MKAnnotationCustom *annotation = [[MKAnnotationCustom alloc] initWithName:Username
                                                                           coordinate:coordinate];
            // add annotation
            [self.mapView addAnnotation:annotation];
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
