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
    NSMutableArray *hexArray;
    NSMutableArray *northWestHexArray;
    NSMutableArray *southWestHexArray;
    NSMutableArray *southEastHexArray;
    NSMutableArray *northEastHexArray;
    NSMutableArray *hexUnlockedArray;
    NSMutableArray *hexInViewArray;
    
    NSMutableArray *centerLATs;
    NSMutableArray *centerLONGs;
    int indexOfCenterHex;
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
    
    // Create a GMSCameraPosition that tells the map to display the
    // coordinate user location at zoom level 6.
    
    self.mapView_.delegate = self;
    self.mapView_.myLocationEnabled = YES;
    self.mapView_.mapType = kGMSTypeHybrid;
    self.mapView_.settings.rotateGestures = false;
    [self.mapView_ setMinZoom:5 maxZoom:25];
    
    hexArray = [[NSMutableArray alloc]init];
    northWestHexArray = [[NSMutableArray alloc]init];
    southWestHexArray = [[NSMutableArray alloc]init];
    southEastHexArray = [[NSMutableArray alloc]init];
    northEastHexArray = [[NSMutableArray alloc]init];
    hexUnlockedArray = [[NSMutableArray alloc]init];
    hexInViewArray = [[NSMutableArray alloc]init];

    [self setCameraToUserLoc];
    
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
    
    //[self addHexagons];
}
- (IBAction)ZoomOut:(id)sender {
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                                            longitude:self.mapView_.myLocation.coordinate.longitude
                                 
                                                                 zoom:1];
    self.mapView_.camera = camera;
}

-(void)addHexagons{
    float oneMileLat = 0.01449275362319;
    float oneMileLong = 0.01445671659053;
    
    float width = (100 * oneMileLat);
    float height = (100 * oneMileLong);
    float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
    float topMidHeights = height - botMidHeights;
    
    int hexCounter;
    hexCounter = 0;
    
    NSMutableArray *centerArray = [[NSMutableArray alloc] init];
    NSMutableArray *centerArrayLAT = [[NSMutableArray alloc] init];
    NSMutableArray *centerArrayLONG = [[NSMutableArray alloc] init];
    
    CLLocationCoordinate2D topH = CLLocationCoordinate2DMake(0, 0); //INITIALIZES VARIABLE

    for (int x = -90; topH.latitude <= 90; x++) {//PERFORM AS UNTILL IT HITS THE LAST LATITUDE (-90 --> 90)
        
        float OddHexWidth;
        if (x%2 == 0) {//IF IT IS ODD ADD MORE WIDTH (in order for hex to be touching borders)
            OddHexWidth = 0;
        }else{
            OddHexWidth = width/2;
        }
        CLLocationCoordinate2D topRightH = CLLocationCoordinate2DMake(0, 0); //INITIALIZES VARIABLE
        
        for (int i =-180 ; topRightH.longitude <= 180; i++) {//PERFORM AS UNTILL IT HITS THE LAST LONGTITUDE (-180 --> 180)

            GMSMutablePath *hexH = [[GMSMutablePath path] init];
            
            float latCoords = (topMidHeights*x);//INCREASE THE LAT COORD
            float longCoords = OddHexWidth+(width*i);//INCREASE THE LONG COORD
            
            CLLocationCoordinate2D bottomH = CLLocationCoordinate2DMake(    height-height+  latCoords,  longCoords+     (width / 2));
            CLLocationCoordinate2D bottomLeftH = CLLocationCoordinate2DMake(botMidHeights+  latCoords,  longCoords+     0);
            CLLocationCoordinate2D topLeftH = CLLocationCoordinate2DMake(   topMidHeights+  latCoords,  longCoords+     0);
                                   topH = CLLocationCoordinate2DMake(       height+         latCoords,  longCoords+     (width / 2));
                                   topRightH = CLLocationCoordinate2DMake(  topMidHeights+  latCoords,  longCoords+     width);
            CLLocationCoordinate2D bottomRightH = CLLocationCoordinate2DMake(botMidHeights+ latCoords,  longCoords+     width);
            
            [hexH addCoordinate:bottomH];
            [hexH addCoordinate:bottomLeftH];
            [hexH addCoordinate:topLeftH];
            [hexH addCoordinate:topH];
            [hexH addCoordinate:topRightH];
            [hexH addCoordinate:bottomRightH];

            GMSPolygon *polygon2 = [GMSPolygon polygonWithPath:hexH];
            polygon2.title = [NSString stringWithFormat:@"%i", i];
            
            [hexArray addObject:polygon2];
            
            if (topH.latitude > 0 && topH.longitude < 0) {// IF IT IS IN THE NORTHEAST HEMI
                [northEastHexArray addObject:polygon2];
            }else if (topH.latitude > 0 && topH.longitude >= 0) {// IF IT IS IN THE NORTHWEST HEMI
                [northWestHexArray addObject:polygon2];
            }else if (topH.latitude <= 0 && topH.longitude < 0) {// IF IT IS IN THE SOUTHEAST HEMI
                [southEastHexArray addObject:polygon2];
            }else if (topH.latitude > 0 && topH.longitude >= 0) {// IF IT IS IN THE SOUTHWEST HEMI
                [southWestHexArray addObject:polygon2];
            }
            
            //find rect that encloses all coords
            
            float maxLat = -200;
            float maxLong = -200;
            float minLat = 999999;
            float minLong = 999999;
            
            for (int i=0 ; i< hexH.count; i++) {
                CLLocationCoordinate2D location = [hexH coordinateAtIndex:i];
                
                if (location.latitude < minLat) {
                    minLat = location.latitude;
                }
                
                if (location.longitude < minLong) {
                    minLong = location.longitude;
                }
                
                if (location.latitude > maxLat) {
                    maxLat = location.latitude;
                }
                
                if (location.longitude > maxLong) {
                    maxLong = location.longitude;
                }
            }
            
            //Center point
            if (topH.latitude > 80 && topH.latitude <= 90) {
                CLLocationCoordinate2D center = CLLocationCoordinate2DMake((maxLat + minLat) * 0.5, (maxLong + minLong) * 0.5);
                [centerArrayLAT addObject:[NSNumber numberWithDouble:center.latitude]];
                [centerArrayLONG addObject:[NSNumber numberWithDouble:center.longitude]];
            }
            
            hexCounter++;
        }
    }
    //[self getHexsInView];
    NSArray *data1 = centerArrayLAT;
    NSArray *data2 = centerArrayLONG;
    // Stitch together a postObject and send this async to Parse
    PFObject *postObject = [PFObject objectWithClassName:@"HexPolygonMap"];
    [postObject addObject:data1 forKey:@"Latitude"];
    [postObject addObject:data2 forKey:@"Longitude"];
    
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

    NSLog(@"THERE ARE %i HEXAGONS ON THIS MAP",hexCounter);
}

-(void)getHexsInView{
    //ADD A WAITING FEATURE FOR EVERYTHIN TO LOAD!!!
    
    // Create the polygon, and assign it to the map.
    int unlockedHexsInViewCounter;
    unlockedHexsInViewCounter=0;
    
    CGPoint point = self.mapView_.center;
    CLLocationCoordinate2D centerCoord = [self.mapView_.projection coordinateForPoint:point];
    
    NSArray *hexArraySearch;
    
    if (centerCoord.latitude >= 0 && centerCoord.longitude <= 0) {// IF IT IS IN THE NORTHEAST HEMI
        hexArraySearch = [NSArray arrayWithArray:northEastHexArray];
    }else if (centerCoord.latitude >= 0 && centerCoord.longitude >= 0) {// IF IT IS IN THE NORTHWEST HEMI
        hexArraySearch = [NSArray arrayWithArray:northWestHexArray];
    }else if (centerCoord.latitude <= 0 && centerCoord.longitude <= 0) {// IF IT IS IN THE SOUTHEAST HEMI
        hexArraySearch = [NSArray arrayWithArray:southEastHexArray];
    }else if (centerCoord.latitude >= 0 && centerCoord.longitude >= 0) {// IF IT IS IN THE SOUTHWEST HEMI
        hexArraySearch = [NSArray arrayWithArray:southWestHexArray];
    }
    
    CLLocationCoordinate2D topLeftCoord = self.mapView_.projection.visibleRegion.farLeft;
    CLLocationCoordinate2D topRightCoord = self.mapView_.projection.visibleRegion.farRight;
    CLLocationCoordinate2D botLeftCoord = self.mapView_.projection.visibleRegion.nearLeft;
    CLLocationCoordinate2D botRightCoord = self.mapView_.projection.visibleRegion.nearRight;
    
    bool allHexsInView = false;
    
    bool TopLeftHex = false;
    bool BotLeftHex = false;
    bool TopRightHex = false;
    bool BotRightHex = false;
    
    for (int x = 0; x < hexInViewArray.count; x++) {
        GMSPolygon *hexPolygon = hexInViewArray[x];
        
        if (GMSGeometryContainsLocation(topLeftCoord, hexPolygon.path, YES)) {
            TopLeftHex = true;
        } else if (GMSGeometryContainsLocation(topRightCoord, hexPolygon.path, YES)) {
            TopRightHex = true;
        } else if (GMSGeometryContainsLocation(botLeftCoord, hexPolygon.path, YES)) {
            BotLeftHex = true;
        } else if (GMSGeometryContainsLocation(botRightCoord, hexPolygon.path, YES)) {
            BotRightHex = true;
        }
    }
    
    if (TopLeftHex && TopRightHex && BotLeftHex && BotRightHex) {
        allHexsInView = true;
    }
    
    if (allHexsInView == false) {
        for (int i = 0; i < hexArraySearch.count; i++) {
            GMSPolygon *hexPolygon = hexArraySearch[i];
            CLLocationCoordinate2D hexBot = [hexPolygon.path coordinateAtIndex:0];
            CLLocationCoordinate2D hexTop = [hexPolygon.path coordinateAtIndex:3];
            CLLocationCoordinate2D hexLeft = [hexPolygon.path coordinateAtIndex:1];
            CLLocationCoordinate2D hexRight = [hexPolygon.path coordinateAtIndex:4];
            
            if ([self.mapView_.projection containsCoordinate:hexBot] || [self.mapView_.projection containsCoordinate:hexTop] || [self.mapView_.projection containsCoordinate:hexLeft] || [self.mapView_.projection containsCoordinate:hexRight]) {
                if (!hexPolygon) {//ADD IN TO CHECK IF IT IS A UNLOCKED HEXAGON
                    hexPolygon.fillColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.4];
                    hexPolygon.strokeColor = [UIColor blueColor];
                    hexPolygon.strokeWidth = 1;
                    hexPolygon.map = self.mapView_;
                    unlockedHexsInViewCounter++;
                }else{
                    hexPolygon.fillColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
                    hexPolygon.strokeColor = [UIColor redColor];
                    hexPolygon.strokeWidth = 1;
                    hexPolygon.map = self.mapView_;
                }
                [hexInViewArray addObject:hexPolygon];
            }
        }
    }
    NSLog(@"USER HAS %i UNLOCKED HEXS IN VIEW", unlockedHexsInViewCounter);
}

- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position{
    /*CGPoint point = self.mapView_.center;
    CLLocationCoordinate2D centerCoord = [self.mapView_.projection coordinateForPoint:point];
    
    NSArray *hexArraySearch;
    
    if (centerCoord.latitude >= 0 && centerCoord.longitude <= 0) {// IF IT IS IN THE NORTHEAST HEMI
        hexArraySearch = [NSArray arrayWithArray:northEastHexArray];
    }else if (centerCoord.latitude >= 0 && centerCoord.longitude >= 0) {// IF IT IS IN THE NORTHWEST HEMI
        hexArraySearch = [NSArray arrayWithArray:northWestHexArray];
    }else if (centerCoord.latitude <= 0 && centerCoord.longitude <= 0) {// IF IT IS IN THE SOUTHEAST HEMI
        hexArraySearch = [NSArray arrayWithArray:southEastHexArray];
    }else if (centerCoord.latitude >= 0 && centerCoord.longitude >= 0) {// IF IT IS IN THE SOUTHWEST HEMI
        hexArraySearch = [NSArray arrayWithArray:southWestHexArray];
    }
    GMSPolygon *hexPoly = hexArraySearch[30]; //GET A POLYGON AND SEE IF IT IS ALREADY ON THE MAP
    if (hexPoly.map != self.mapView_) {
        [self getHexsInView];
    }*/
}

-(void)addRects{
    float oneMileLat = 0.01449275362319;
    float oneMileLong = 0.01445671659053;
    
    // Create a rectangular path
    GMSMutablePath *rect = [GMSMutablePath path];
    float latCoord = (4 * oneMileLat);
    float longCoord = (5 * oneMileLong);
    CLLocationCoordinate2D bottomRight = CLLocationCoordinate2DMake(0, -180);
    CLLocationCoordinate2D bottomLeft = CLLocationCoordinate2DMake(0, -170);
    CLLocationCoordinate2D topLeft = CLLocationCoordinate2DMake(10, -170);
    CLLocationCoordinate2D topRight = CLLocationCoordinate2DMake(10, -180);
    
    [rect addCoordinate:bottomRight];
    [rect addCoordinate:bottomLeft];
    [rect addCoordinate:topLeft];
    [rect addCoordinate:topRight];
    
    // Create the polygon, and assign it to the map.
    GMSPolygon *polygon = [GMSPolygon polygonWithPath:rect];
    polygon.fillColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:1];
    polygon.strokeColor = [UIColor redColor];
    polygon.strokeWidth = 5;
    polygon.map = self.mapView_;
    
    double length = bottomRight.longitude - bottomLeft.longitude;
    if (length < 1) {
        length*=-1;
    }
    CLLocationCoordinate2D topRightL = CLLocationCoordinate2DMake(0, 0); //INITIALIZES VARIABLE
    
    for (int i =1 ; topRightL.longitude <= 180; i++) {
        GMSMutablePath *rect1 = [[GMSMutablePath path] init];
        
        CLLocationCoordinate2D bottomRightL = CLLocationCoordinate2DMake(bottomRight.latitude, bottomRight.longitude + (length * (i)));
        CLLocationCoordinate2D bottomLeftL = CLLocationCoordinate2DMake(bottomLeft.latitude, bottomLeft.longitude + (length * (i)));;
        CLLocationCoordinate2D topLeftL = CLLocationCoordinate2DMake(topLeft.latitude, topLeft.longitude - length + (length*(i+1)));
        topRightL = CLLocationCoordinate2DMake(topRight.latitude, topRight.longitude - length + (length*(i+1)));
        
        [rect1 addCoordinate:bottomRightL];
        [rect1 addCoordinate:bottomLeftL];
        [rect1 addCoordinate:topLeftL];
        [rect1 addCoordinate:topRightL];
        
        NSLog(@"\nBot Left Latitude: %f\n", bottomLeftL.latitude);
        NSLog(@"\nTop Left Latitude: %f\n", topLeftL.latitude);
        
        // Create the polygon, and assign it to the map.
        GMSPolygon *polygon2 = [GMSPolygon polygonWithPath:rect1];
        polygon2.fillColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];
        polygon2.strokeColor = [UIColor redColor];
        polygon2.strokeWidth = 5;
        polygon2.map = self.mapView_;
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
        [self loadPlotHexs];
    }];
    // The InBackground methods are asynchronous, so any code after this will run
    // immediately.  Any code that depends on the query result should be moved
    // inside the completion block above.
}

-(void)loadPlotHexs{
    int coordLatRangeIndex=0;
    float userLat = self.mapView_.myLocation.coordinate.latitude;
    if (userLat > -90 & userLat <= -80){
        coordLatRangeIndex=-90;
    }else if (userLat > -80 & userLat <= -70){
        coordLatRangeIndex=-80;
    }else if (userLat > -70 & userLat <= -60){
        coordLatRangeIndex=-70;
    }else if (userLat > -60 & userLat <= -50){
        coordLatRangeIndex=-60;
    }else if (userLat > -50 & userLat <= -40){
        coordLatRangeIndex=-50;
    }else if (userLat > -40 & userLat <= -30){
        coordLatRangeIndex=-40;
    }else if (userLat > -30 & userLat <= -20){
        coordLatRangeIndex=-30;
    }else if (userLat > -20 & userLat <= -10){
        coordLatRangeIndex=-20;
    }else if (userLat > -10 & userLat <= 0){
        coordLatRangeIndex=-10;
    }else if (userLat > 0 & userLat <= 10){
        coordLatRangeIndex=0;
    }else if (userLat > 10 & userLat <= 20){
        coordLatRangeIndex=10;
    }else if (userLat > 20 & userLat <= 30){
        coordLatRangeIndex=20;
    }else if (userLat > 30 & userLat <= 40){
        coordLatRangeIndex=30;
    }else if (userLat > 40 & userLat <= 50){
        coordLatRangeIndex=40;
    }else if (userLat > 50 & userLat <= 60){
        coordLatRangeIndex=50;
    }else if (userLat > 60 & userLat <= 70){
        coordLatRangeIndex=60;
    }else if (userLat > 70 & userLat <= 80){
        coordLatRangeIndex=70;
    }else if (userLat > 80 & userLat <= 90){
        coordLatRangeIndex=80;
    }
    PFQuery *query = [PFQuery queryWithClassName:@"HexPolygonMap"];
    [query whereKey:@"Index" equalTo:[NSNumber numberWithInt:30]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK", nil];
            [alertView show];
        }else{
            for (int i = 0; i < objects.count; i++) {//ERROR HERE IT NEEDS TO RETRIVE THE RIGHT ROW & OBJECT
                PFObject *centerPointHexArray = objects[i];
                NSArray *centerLATsTemp = [centerPointHexArray objectForKey:@"Latitude"];
                NSArray *centerLONGsTemp = [centerPointHexArray objectForKey:@"Longitude"];
                centerLATs = [[NSMutableArray alloc] initWithArray:[centerLATsTemp objectAtIndex:0]];
                centerLONGs = [[NSMutableArray alloc] initWithArray:[centerLONGsTemp objectAtIndex:0]];
                
                CLLocationDistance shortestDistance = 999999;
                indexOfCenterHex=0;
                for (int x = 0; x < centerLATs.count; x++) {
                    CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake([centerLATs[x] doubleValue], [centerLONGs[x] doubleValue]);
                    CLLocation *hexCenterLoc = [[CLLocation alloc] initWithLatitude:coordTemp.latitude longitude:coordTemp.longitude];
                    CLLocationDistance distance = [hexCenterLoc getDistanceFrom: self.mapView_.myLocation];
                    if ((double)shortestDistance > (double)distance) {
                        shortestDistance = distance;
                        indexOfCenterHex = x;
                    }
                }
            }
        }
        //ADD THE POLYGON USING THE INDEX
        [self addHex];
    }];
}

-(void)addHex{
    CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake([centerLATs[indexOfCenterHex] doubleValue], [centerLONGs[indexOfCenterHex] doubleValue]);
    
    float oneMileLat = 0.01449275362319;
    float oneMileLong = 0.01445671659053;
    
    float width = (100 * oneMileLat);
    float height = (100 * oneMileLong);
    float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
    float topMidHeights = height - botMidHeights;
    
    GMSMutablePath *hexH = [[GMSMutablePath path] init];
    
    float latCoords = coordTemp.latitude;//INCREASE THE LAT COORD
    float longCoords = coordTemp.longitude;//INCREASE THE LONG COORD
    
    CLLocationCoordinate2D bottomH = CLLocationCoordinate2DMake(    height-height+  latCoords,  longCoords+     (width / 2));
    CLLocationCoordinate2D bottomLeftH = CLLocationCoordinate2DMake(botMidHeights+  latCoords,  longCoords+     0);
    CLLocationCoordinate2D topLeftH = CLLocationCoordinate2DMake(   topMidHeights+  latCoords,  longCoords+     0);
    CLLocationCoordinate2D topH = CLLocationCoordinate2DMake(       height+         latCoords,  longCoords+     (width / 2));
    CLLocationCoordinate2D topRightH = CLLocationCoordinate2DMake(  topMidHeights+  latCoords,  longCoords+     width);
    CLLocationCoordinate2D bottomRightH = CLLocationCoordinate2DMake(botMidHeights+ latCoords,  longCoords+     width);
    
    [hexH addCoordinate:bottomH];
    [hexH addCoordinate:bottomLeftH];
    [hexH addCoordinate:topLeftH];
    [hexH addCoordinate:topH];
    [hexH addCoordinate:topRightH];
    [hexH addCoordinate:bottomRightH];
    
    GMSPolygon *polygon2 = [GMSPolygon polygonWithPath:hexH];
    polygon2.fillColor = [UIColor blueColor];
    polygon2.map = self.mapView_;
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
    [self setCameraToUserLoc];
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

-(void)setCameraToUserLoc{
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                                            longitude:self.mapView_.myLocation.coordinate.longitude
                                 
                                                                 zoom:6];
    self.mapView_.camera = camera;
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
