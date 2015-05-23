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
    
    int currentRange;
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
    
    NSMutableArray *hexCentersOnMap;
    
    NSMutableArray *centerCoords;
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

- (IBAction)ZoomOut:(id)sender {
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                                            longitude:self.mapView_.myLocation.coordinate.longitude
                                 
                                                                 zoom:1];
    self.mapView_.camera = camera;
}

- (IBAction)TappedRefresh:(id)sender {
    PFUser *userID = [PFUser currentUser];
    if (userID != nil) {
        [self uploadDataOnMap:userID :@"You"];//SET UP ALL CURRENT USER'S PICTURES
        [self loadContacts];
    }
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
    hexCentersOnMap = [[NSMutableArray alloc]init];

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
                    [self uploadDataOnMap:userID :@"You"];//SET UP ALL CURRENT USER'S PICTURES
                    [self loadContacts];
                }
            }];
        }]];
        [self presentViewController:loginAlert animated:true completion:nil];
    }
    
    PFUser *userID = [PFUser currentUser];
    if (userID != nil) {
        [self uploadDataOnMap:userID :@"You"];//SET UP ALL CURRENT USER'S PICTURES
        [self loadContacts];
    }
    //[self addHexagons];
}

- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position{

}

-(void)uploadDataOnMap: (PFUser *)posterUser :(NSString *)Username{
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

#pragma mark Hexagon Methods

-(void)loadPlotHexs{
    int coordLatRangeIndex=0;
    double userLong = self.mapView_.myLocation.coordinate.longitude;
    double userLat = self.mapView_.myLocation.coordinate.latitude;

    PFQuery *query = [PFQuery queryWithClassName:@"hexPosCoords"];
    
    PFGeoPoint *tempGeo = [PFGeoPoint geoPointWithLatitude:userLat longitude:userLong];
    
    [query whereKey:@"h" nearGeoPoint:tempGeo withinMiles:10];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK", nil];
            [alertView show];
        }else{
             NSLog(@"OBJECT COUNT: %lu", (unsigned long)objects.count);
            
            centerCoords = [[NSMutableArray alloc]init];
            
            CLLocationDistance shortestDistance = 999999;

            for (int i = 0; i < objects.count; i++) {//ERROR HERE IT NEEDS TO RETRIVE THE CORRECT ROW & OBJECT
                PFObject *centerPointHexArray = objects[i];
                PFGeoPoint *centerGeoPoints = [centerPointHexArray objectForKey:@"h"];
                
                indexOfCenterHex=0;
                
                CLLocation *coordinate = [[CLLocation alloc] initWithLatitude:centerGeoPoints.latitude longitude:centerGeoPoints.longitude];
                [centerCoords addObject:coordinate];
                
                CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake(centerGeoPoints.latitude, centerGeoPoints.longitude);
                NSLog(@"\nLAT: %f\n LONG: %f\n", coordTemp.latitude, coordTemp.longitude);

                CLLocation *hexCenterLoc = [[CLLocation alloc] initWithLatitude:coordTemp.latitude longitude:coordTemp.longitude];
                CLLocationDistance distance = [hexCenterLoc getDistanceFrom: self.mapView_.myLocation];
                if (shortestDistance  > distance) {
                    shortestDistance = distance;
                    indexOfCenterHex = i;
                }
            }
        }
        //ADD THE POLYGON USING THE INDEX
        [self addUnlockedHexs];
    }];
}

-(void)addUnlockedHexs{
    
    CLLocationCoordinate2D coordTemp = [centerCoords[indexOfCenterHex] coordinate];
    
    float oneMileLat = 0.01449275362319;
    float oneMileLong = 0.01445671659053;
    
    float width = (10 * oneMileLat);
    float height = (10 * oneMileLong);
    float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
    float topMidHeights = height - botMidHeights;
    
    GMSMutablePath *hexH = [[GMSMutablePath path] init];
    
    float latCoords = coordTemp.latitude - (height / 2);//INCREASE THE LAT COORD
    float longCoords = coordTemp.longitude - (width / 2);//INCREASE THE LONG COORD
    
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
    polygon2.fillColor = [[UIColor blueColor] colorWithAlphaComponent:0.75];
    polygon2.map = self.mapView_;
    
    CLLocation *towerLocation = [[CLLocation alloc] initWithLatitude:coordTemp.latitude longitude:coordTemp.longitude];
    [hexCentersOnMap addObject:towerLocation];
    [self getSurroundingHexs];
}

-(void)getSurroundingHexs{
    CLLocationCoordinate2D coordTemp = [centerCoords[indexOfCenterHex] coordinate];
    
    for (int i = 0; i <= 6; i++) {
        float oneMileLat = 0.01449275362319;
        float oneMileLong = 0.01445671659053;
        
        float width = (10 * oneMileLat);
        float height = (10 * oneMileLong);
        float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
        float topMidHeights = height - botMidHeights;
        
        GMSMutablePath *hexH = [[GMSMutablePath path] init];
        
        float latCoords;
        float longCoords;
        if (i == 6) {//THE BOTTOM LEFT HEX
            latCoords = coordTemp.latitude - (height * 1.25);//INCREASE THE LAT COORD
            longCoords = coordTemp.longitude - (width);//INCREASE THE LONG COORD
        }else if (i == 5) {//THE BOTTOM RIGHT HEX
            latCoords = coordTemp.latitude - (height * 1.25);//INCREASE THE LAT COORD
            longCoords = coordTemp.longitude;//INCREASE THE LONG COORD
        }else if (i == 4){//THE TOP LEFT HEX
            latCoords = coordTemp.latitude + (height / 4);//INCREASE THE LAT COORD
            longCoords = coordTemp.longitude - (width);//INCREASE THE LONG COORD
        }else if (i == 3){//THE TOP RIGHT HEX
            latCoords = coordTemp.latitude + (height / 4);//INCREASE THE LAT COORD
            longCoords = coordTemp.longitude;//INCREASE THE LONG COORD
        }else if (i == 2){//THE LEFT HEX
            latCoords = coordTemp.latitude - (height / 2);//INCREASE THE LAT COORD
            longCoords = coordTemp.longitude - (width * 1.5);//INCREASE THE LONG COORD
        }else if (i == 1){//THE RIGHT HEX
            latCoords = coordTemp.latitude - (height / 2);//INCREASE THE LAT COORD
            longCoords = coordTemp.longitude + (width / 2);//INCREASE THE LONG COORD
        }
        
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
        
        CLLocationCoordinate2D center = [self getCenterOfHex:hexH];
        
        if ([self checkIfCenterIsOnMap:center] == false) {
            GMSPolygon *polygon2 = [GMSPolygon polygonWithPath:hexH];
            polygon2.fillColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
            polygon2.strokeWidth = 1;
            polygon2.strokeColor = [UIColor blackColor];
            polygon2.map = self.mapView_;
            
            CLLocation *towerLocation = [[CLLocation alloc] initWithLatitude:center.latitude longitude:center.longitude];
            [hexCentersOnMap addObject:towerLocation];
        }
    }
}

-(CLLocationCoordinate2D)getCenterOfHex:(GMSMutablePath *)hexH{
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
    
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake((maxLat + minLat) * 0.5, (maxLong + minLong) * 0.5);
    return center;
}

-(BOOL)checkIfCenterIsOnMap:(CLLocationCoordinate2D)center{
    bool isTaken = false;
    for (int i =0; i < hexCentersOnMap.count; i++) {
        if (center.latitude == [hexCentersOnMap[i] coordinate].latitude && center.longitude == [hexCentersOnMap[i] coordinate].longitude) {
            isTaken = true;
            break;
        }
    }
    return isTaken;
}

//GET TO WORK TO ADD THE PICTURE LOCATIONS!!!

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


#pragma mark Loading Contacts Methods

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
            
            [self uploadDataOnMap: contactIDsArray[n]: contactNamesArray[n]];//SET UP ALL CURRENT USER'S PICTURES
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
                                 
                                                                 zoom:10];
    self.mapView_.camera = camera;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UPLOAD HEXAGONS TO THE SERVER
-(void)addHexagons{
    float oneMileLat = 0.01449275362319;
    float oneMileLong = 0.01445671659053;
    
    float width = (5 * oneMileLat);
    float height = (5 * oneMileLong);
    float botMidHeights = height / 4.0;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
    float topMidHeights = height - botMidHeights;
    
    int hexCounter;
    hexCounter = 0;
    
    NSMutableArray *centerJSONArray = [[NSMutableArray alloc] init];
    
    CLLocationCoordinate2D topH = CLLocationCoordinate2DMake(-90, -180); //INITIALIZES VARIABLE
    
    int latSave=0;//-90 to -89 CAN GO TO 89 only
    
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
            
            float latCoords = -90+(topMidHeights*x);//INCREASE THE LAT COORD (the distance between hex's)
            float longCoords = -180+(OddHexWidth+(width*i));//INCREASE THE LONG COORD
            
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
            
            //Center point
            
            currentRange = -80;
            
            CLLocationCoordinate2D center = [self getCenterOfHex:hexH];
            NSNumber *latStr = [NSNumber numberWithDouble:center.latitude];
            NSNumber *longStr = [NSNumber numberWithDouble:center.longitude];
            if (center.latitude <= 90 && center.latitude >= -90 && center.longitude >= -180 && center.longitude <=180) {
            NSDictionary *location = [NSDictionary dictionaryWithObjectsAndKeys:
                                                @"GeoPoint", @"__type",
                                                longStr,@"longitude",
                                                latStr,@"latitude",
                                                nil];
            NSDictionary *tempJsonDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    location,@"h",
                                                    nil];
                if (center.latitude <= 0 && center.latitude >= -90) {
                        [centerJSONArray addObject:tempJsonDictionary];
                }
            
            hexCounter++;
            }
        }
    }// ONLY UNCOMMENT TO UPLOAD ALL THE HEXS TO THE SERVER
    //[self getHexsInView];
    
    NSLog(@"THERE ARE %i HEXAGONS ON THIS MAP",hexCounter);
    
    [self writeToTextFile:centerJSONArray];
}

//Method writes a string to a text file
-(void) writeToTextFile:(NSMutableArray *)centerJSONArray{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:centerJSONArray options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"jsonData as string:\n%@", jsonString);
    //get the documents directory:
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSLog(@"%@",documentsDirectory);
    //make a file name to write the data to using the documents directory:
    NSString *fileName = [NSString stringWithFormat:@"%@/textfileCoords%i.txt",
                          documentsDirectory, currentRange];
    //create content - four lines of text
    NSString *content = jsonString;
    //save content to the documents directory
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    
    
}
////////////////////////////////////////////////////

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
