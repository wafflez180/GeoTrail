//
//  ViewController.m
//  SnapTrail
//
//  Created by Arthur Araujo on 4/12/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import "CustomInfoWindow.h"
#import "CameraViewController.h"
#import <MapKit/MapKit.h>

#import <Parse/Parse.h>
#import <GoogleMaps/GoogleMaps.h>

#import "ViewController.h"

BOOL initialZoomComplete = NO;

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *picView;
@property (weak, nonatomic) IBOutlet GMSMapView *mapView_;
@property (weak, nonatomic) IBOutlet UIButton *nextPicButton;
@property (weak, nonatomic) IBOutlet UIButton *goToUserLocButton;

@end


@implementation ViewController{
    CLLocationManager *locationManager;
    
    int currentRange;
    float milesSpanRegion;
    bool hideStatusBar;
    PFObject *postedPictures;
    PFUser *user;
    GMSMarker *prevMarker;
    int prevInfoWindowMarkerIndex;
    NSMutableArray *contactNamesArray;
    NSMutableArray *contactIDsArray;
    NSMutableArray *contactUnlockedHexsArray;
    CLLocationCoordinate2D currentUserLoc;
    NSMutableArray *PFFilePictureArray;
    NSMutableArray *postedPictureLocations;
    NSMutableArray *hexArray;
    NSMutableArray *northWestHexArray;
    NSMutableArray *southWestHexArray;
    NSMutableArray *southEastHexArray;
    NSMutableArray *northEastHexArray;
    NSMutableArray *userUnlockedHexsArray;
    NSMutableArray *hexInViewArray;
    NSMutableArray *shadedHexCentersOnMap;
    NSMutableArray *infoWindows;
    NSMutableArray *GMSMarkersArray;
    
    CustomInfoWindow *currentInfoWindow;
    
    int _originalY;
    int _originalNavBarY;
    BOOL _deleteOnDragRelease;
    BOOL viewingPic;
    BOOL draggedPicUp;
    CGPoint initialTouchLocation;
    UIView *_infoWindowView;
    
    NSMutableArray *centerCoords;
    
    int indexOfCenterHex;
    int userUnlockedHexs;
}
- (IBAction)TappedRefresh:(id)sender {
    PFUser *userID = [PFUser currentUser];
    if (userID != nil) {
        [self loadPlotHexs];
        [self uploadDataOnMap:userID :@"You": [NSNumber numberWithInt:userUnlockedHexs]];//SET UP ALL CURRENT USER'S PICTURES
        [self loadUserContacts];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Create a GMSCameraPosition that tells the map to display the
    // coordinate user location at zoom level 6.
    
    self.mapView_.delegate = self;
    [self.mapView_ setMyLocationEnabled:TRUE];
    self.mapView_.mapType = kGMSTypeNormal;
    self.mapView_.settings.rotateGestures = false;
    [self.mapView_ setBuildingsEnabled:FALSE];
    [self.mapView_ setBackgroundColor:[UIColor purpleColor]];
    [self.mapView_ setIndoorEnabled:FALSE];
    [self.mapView_ setMinZoom:5 maxZoom:25];
    
    contactUnlockedHexsArray = [[NSMutableArray alloc] init];
    contactIDsArray = [[NSMutableArray alloc] init];
    hexArray = [[NSMutableArray alloc]init];
    northWestHexArray = [[NSMutableArray alloc]init];
    southWestHexArray = [[NSMutableArray alloc]init];
    southEastHexArray = [[NSMutableArray alloc]init];
    northEastHexArray = [[NSMutableArray alloc]init];
    userUnlockedHexsArray = [[NSMutableArray alloc]init];
    hexInViewArray = [[NSMutableArray alloc]init];
    shadedHexCentersOnMap = [[NSMutableArray alloc]init];
    PFFilePictureArray = [[NSMutableArray alloc]init];
    postedPictureLocations = [[NSMutableArray alloc]init];
    infoWindows = [[NSMutableArray alloc] init];
    GMSMarkersArray = [[NSMutableArray alloc]init];
    
    _picView.alpha = 0;

    [self setCameraToUserLoc];
    
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
                    [self uploadDataOnMap:userID :@"You":[NSNumber numberWithInt:userUnlockedHexs]];//SET UP ALL CURRENT USER'S PICTURES
                    [self loadUserContacts];
                }
            }];
        }]];
        [self presentViewController:loginAlert animated:true completion:nil];
    }
    
    PFUser *userID = [PFUser currentUser];
    if (userID != nil) {
        [self uploadDataOnMap:userID :@"You":[NSNumber numberWithInt:userUnlockedHexs]];//SET UP ALL CURRENT USER'S PICTURES
        [self loadUserContacts];
    }
    //[self addHexagons];
}

- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position{

}

- (void)mapView:(GMSMapView *)mapView didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate{
    
}

-(void)uploadDataOnMap: (PFUser *)posterUser :(NSString *)Username :(NSNumber *)unlockedHexs{
    PFQuery *query = [PFQuery queryWithClassName:@"PostedPictures"];
    NSLog(@"%@",Username);
    [query whereKey:@"UserID" equalTo:posterUser.objectId];// "user" must be pointer in the PostedPictures (table) get all the pictures that was posted by the user
    NSMutableArray *tempPostedPictureLocations = [[NSMutableArray alloc] init];
    NSMutableArray *tempPostedPictureLikes = [[NSMutableArray alloc] init];
    NSMutableArray *tempPostedPictureViews = [[NSMutableArray alloc] init];
    NSMutableArray *tempPostedPictureWhoLiked = [[NSMutableArray alloc]init];
    NSMutableArray *tempPostedPictureWhoViewed = [[NSMutableArray alloc]init];
    NSMutableArray *tempPostedPictureTimeCreated = [[NSMutableArray alloc]init];
    NSMutableArray *objectIDArray = [[NSMutableArray alloc]init];
    
    NSLog(@"\nUPLOAD DATA ON MAP: %@",Username);
    [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
        if (!error) {
            for (NSInteger i = 0; i <PFObjects.count; i++) {
                PFObject *thePostedPicture = PFObjects[i];
                
                PFGeoPoint *pictureLocation = [thePostedPicture objectForKey:@"location"];
                PFFile *picture = [thePostedPicture objectForKey:@"picture"];
                NSNumber *likes = [thePostedPicture objectForKey:@"Likes"];
                NSNumber *views = [thePostedPicture objectForKey:@"Views"];
                NSString *objectID = [thePostedPicture valueForKey:@"objectId"];
                NSArray *whoViewed = [thePostedPicture objectForKey:@"UsersWhoViewed"];
                NSDate *dateCreated = [thePostedPicture valueForKey:@"createdAt"];
                if ([views intValue] == 0) {
                    whoViewed = [[NSArray alloc] init];
                }else{
                    whoViewed = [thePostedPicture objectForKey:@"UsersWhoViewed"];
                }
                NSArray *whoLiked;
                if ([likes intValue] == 0) {
                    whoLiked = [[NSArray alloc] init];
                }else{
                    whoLiked = [thePostedPicture objectForKey:@"UsersWhoLiked"];
                }
                
               // NSLog(@"\nPicture Coords:\nX: %f\nY: %f", pictureLocation.latitude, pictureLocation.longitude);
                CLLocation *picCoords = [[CLLocation alloc] initWithLatitude:pictureLocation.latitude longitude:pictureLocation.longitude];
                
                //ADD THE LOCATION TO THE PICTURES LOCATIONS ARRAY
                [tempPostedPictureLocations addObject:picCoords];
                [tempPostedPictureLikes addObject:likes];
                [tempPostedPictureWhoLiked addObject:whoLiked];
                [tempPostedPictureWhoViewed addObject:whoViewed];
                [tempPostedPictureViews addObject:views];
                [tempPostedPictureTimeCreated addObject:dateCreated];
                [objectIDArray addObject:objectID];
                
                [postedPictureLocations addObject:pictureLocation];
                [PFFilePictureArray addObject:picture];
                
               // NSLog(@"\nPic Coordinates: \n%f\n%f", pictureLocation.latitude, pictureLocation.longitude);
            }
        }else{
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
        //CODE EXECUTES AFTER THE ABOVE CODE IS CALLED
        [self loadPlotHexs];

        [self plot:tempPostedPictureLocations:Username:tempPostedPictureLikes:tempPostedPictureWhoLiked:tempPostedPictureViews:tempPostedPictureWhoViewed:tempPostedPictureTimeCreated:unlockedHexs:objectIDArray];
    }];
    // The InBackground methods are asynchronous, so any code after this will run
    // immediately.  Any code that depends on the query result should be moved
    // inside the completion block above.
}

#pragma mark MAPVIEW BUTTONS

- (IBAction)pressedPin:(id)sender {
    [_mapView_ setSelectedMarker:prevMarker];
    CLLocation *userLoc = [[CLLocation alloc] initWithLatitude:self.mapView_.myLocation.coordinate.latitude longitude:self.mapView_.myLocation.coordinate.longitude];
    CLLocationDirection distance = 0.0;
    int closestMarkerIndex=0;
    
    for(int i = 0; i < GMSMarkersArray.count; i++){
        GMSMarker *marker = GMSMarkersArray[i];
        CLLocation *coord = [[CLLocation alloc] initWithLatitude:marker.position.latitude longitude:marker.position.longitude];
        //MAKE SURE THE MARKER IS IN AN UNLOCKED HEX AND IS ON THE MAP
        if ([self isCoordInUnlockedHex:coord] && [self isMarkerOnMap:coord]) {
            CLLocation *coord = [[CLLocation alloc] initWithLatitude:marker.position.latitude longitude:marker.position.longitude];
            if (i == 0) {
                distance = [coord distanceFromLocation:userLoc];
            }else{
                CLLocationDistance newDistance = [coord distanceFromLocation:userLoc];
                if (newDistance < distance) {//IF THE MARKER IS CLOSE THAN PREVIOUS MARKER THAN MAKE IT THE CLOSEST MARKER
                    distance = newDistance;
                    closestMarkerIndex=i;
                }
            }
        }
    }
    _mapView_.selectedMarker = GMSMarkersArray[closestMarkerIndex];
}

- (IBAction)pressedCompass:(id)sender {
    [self setCameraToUserLocAnimated];
}

#pragma mark Hexagon Methods

-(void)loadPlotHexs{
    int coordLatRangeIndex=0;
    double userLong = self.mapView_.myLocation.coordinate.longitude;
    double userLat = self.mapView_.myLocation.coordinate.latitude;
    
    PFQuery *query;
    if (userLat >= 0) {
        query = [PFQuery queryWithClassName:@"hexPosCoords"];
    }else{
        query = [PFQuery queryWithClassName:@"hexNegCoords"];
    }
    
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
            // NSLog(@"OBJECT COUNT: %lu", (unsigned long)objects.count);
            
            centerCoords = [[NSMutableArray alloc]init];
            
            CLLocationDistance shortestDistance = 999999;

            for (int i = 0; i < objects.count; i++) {//ERROR HERE IT NEEDS TO RETRIVE THE CORRECT ROW & OBJECT
                PFObject *centerPointHexArray = objects[i];
                PFGeoPoint *centerGeoPoints = [centerPointHexArray objectForKey:@"h"];
                
                indexOfCenterHex=0;
                
                CLLocation *coordinate = [[CLLocation alloc] initWithLatitude:centerGeoPoints.latitude longitude:centerGeoPoints.longitude];
                [centerCoords addObject:coordinate];
                
                CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake(centerGeoPoints.latitude, centerGeoPoints.longitude);
                //NSLog(@"\nLAT: %f\n LONG: %f\n", coordTemp.latitude, coordTemp.longitude);

                CLLocation *hexCenterLoc = [[CLLocation alloc] initWithLatitude:coordTemp.latitude longitude:coordTemp.longitude];
                CLLocationDistance distance = [hexCenterLoc getDistanceFrom: self.mapView_.myLocation];
                if (shortestDistance  > distance) {
                    shortestDistance = distance;
                    indexOfCenterHex = i;
                }
            }
        }
        //ADD THE POLYGON USING THE INDEX
        [self checkUnlockedHexs];
    }];
}

-(void)checkUnlockedHexs{
    PFQuery *query = [PFUser query];
    [query whereKey:@"username" equalTo:[[PFUser currentUser] username]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if(error){
            
        }else{
            PFObject *theUser;
            for (int x = 0; x < objects.count; x++) {
                if (objects[x] == [PFUser currentUser]) {
                    theUser = objects[x];
                }
            }
            NSMutableArray *unlockedHexs = [[NSMutableArray alloc]initWithArray:[theUser objectForKey:@"UnlockedHexs"]];
            double currentHexLat = [centerCoords[indexOfCenterHex] coordinate].latitude;
            double currentHexLong = [centerCoords[indexOfCenterHex] coordinate].longitude;
            //GO THROUGH ARRAY AND CHECK IF CURRENT HEX ISN'T IN THE ARRAY
            bool currentHexIsNew = true;
            for (int i = 0; i < unlockedHexs.count; i++) {
                PFGeoPoint *unlockedHex = unlockedHexs[i];
                //IF THE CURRENT HEXAGON THE USER IS IN IS IN THE ARRAY THEN DON'T ADD IT
                if (fabs(currentHexLat - unlockedHex.latitude) <= 0.00001 && fabs(currentHexLong - unlockedHex.longitude) <= 0.00001) {
                    currentHexIsNew = false;
                }
            }
            if (currentHexIsNew) {
                /*-40.959770
                 2015-11-14 18:55:21.480 GeoTrail[3634:1229629] -74.057976-*/
                PFGeoPoint *newHex = [PFGeoPoint geoPointWithLatitude:currentHexLat longitude:currentHexLong];
                [unlockedHexs addObject:newHex];
                [[PFUser currentUser] addObject:newHex forKey:@"UnlockedHexs"];
                [[PFUser currentUser] saveInBackground];
                
            }
            userUnlockedHexsArray = [NSMutableArray arrayWithArray:unlockedHexs];
            userUnlockedHexs = (int)userUnlockedHexsArray.count;
            [self loadUnlockedHexs];
        }
    }];
}

-(void)loadUnlockedHexs{
    for (int i = 0; i < userUnlockedHexsArray.count; i++) {
        PFGeoPoint *geoPoint = userUnlockedHexsArray[i];
        CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake(geoPoint.latitude, geoPoint.longitude);
        
        //THESE ARE 5 MILE HEXAGONS
        float width = 0.072464;
        float height = 0.072464;
        float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
        float topMidHeights = height - botMidHeights;
        
        GMSMutablePath *hexH = [[GMSMutablePath path] init];
        
        float latCoords = coordTemp.latitude - (height / 2);//INCREASE THE LAT COORD
        float longCoords = coordTemp.longitude - (width / 2);//INCREASE THE LONG COORD//
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
        dispatch_async(dispatch_get_main_queue(), ^{
            // make some UI changes
            GMSPolygon *polygon2 = [GMSPolygon polygonWithPath:hexH];
            polygon2.fillColor = [UIColor clearColor];
            polygon2.strokeColor = [self colorWithHexString:@"6F6F6F"];
            polygon2.strokeWidth = 4;
            polygon2.map = self.mapView_;
        });
        [self getSurroundingHexs];
    }
}

-(GMSPolygon *)getHexPolygon:(CLLocation *)hexCenter{
    CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake(hexCenter.coordinate.latitude, hexCenter.coordinate.longitude);
    
    //THESE ARE 5 MILE HEXAGONS
    float width = 0.072464;
    float height = 0.072464;
    
    float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
    float topMidHeights = height - botMidHeights;
    
    GMSMutablePath *hexH = [[GMSMutablePath path] init];
    
    float latCoords = coordTemp.latitude - (height / 2);//INCREASE THE LAT COORD
    float longCoords = coordTemp.longitude - (width / 2);//INCREASE THE LONG COORD//
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
    GMSPolygon *polygon = [GMSPolygon polygonWithPath:hexH];
    return polygon;
}

-(void)getSurroundingHexs{
    for (int i = 0; i < userUnlockedHexsArray.count; i++) {
        PFGeoPoint *geoPoint = userUnlockedHexsArray[i];
        CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake(geoPoint.latitude, geoPoint.longitude);
        
        for (int i = 0; i <= 6; i++) {
            //THESE ARE 5 MILE HEXAGONS
            float width = 0.072464;
            float height = 0.072464;
            
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
            
            CLLocation *center = [self getCenterOfHex:hexH];
            
            //NSLog(@"%f", center.latitude);
            //NSLog(@"%f", center.longitude);
            if (![self checkIfCenterIsOnMap:center]) {
                CLLocation *hexCenter = center;
                [shadedHexCentersOnMap addObject:hexCenter];
                dispatch_async(dispatch_get_main_queue(), ^{
                    GMSPolygon *polygon2 = [GMSPolygon polygonWithPath:hexH];
                    polygon2.fillColor = [[self colorWithHexString:@"929292"] colorWithAlphaComponent:0.2];
                    polygon2.strokeWidth = 1;
                    polygon2.strokeColor = [[self colorWithHexString:@"929292"] colorWithAlphaComponent:0.3];
                    polygon2.map = self.mapView_;
                });
            }
        }
    }
}

-(CLLocation*)getCenterOfHex:(GMSMutablePath *)hexH{
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
    
        CLLocationCoordinate2D coordCenter = CLLocationCoordinate2DMake((maxLat + minLat) * 0.5, (maxLong + minLong) * 0.5);
        CLLocation *center = [[CLLocation alloc] initWithLatitude:coordCenter.latitude longitude:coordCenter.longitude];
    return center;
}

-(BOOL)checkIfCenterIsOnMap:(CLLocation *)center{
    bool isTaken = false;
    for (int i =0; i < shadedHexCentersOnMap.count; i++) {
        CLLocation *coord = shadedHexCentersOnMap[i];
        if (fabs(center.coordinate.latitude - coord.coordinate.latitude) <= 0.01 && fabs(center.coordinate.longitude - coord.coordinate.longitude) <= 0.01) {
            isTaken = true;
        }
    }
    for (int i =0; i < userUnlockedHexsArray.count; i++){
        PFGeoPoint *geoPoint = userUnlockedHexsArray[i];
        if (fabs(center.coordinate.latitude - geoPoint.latitude) <= 0.01 && fabs(center.coordinate.longitude - geoPoint.longitude) <= 0.01) {
            isTaken = true;
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

-(void)loadUserContacts{
    PFQuery *query = [PFUser query];
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
                //NSLog(@"Added Contact");
                contactNamesArray = [NSMutableArray arrayWithArray:contacts];
            }
        }
        [self loadUserContactIDs];
    }];
}

-(void)loadUserContactIDs{
    PFQuery *query = [PFUser query];
    NSArray *array = [NSArray arrayWithArray:contactNamesArray];
    [query whereKey:@"username" containedIn:array]; // "user" must be pointer in the PostedPictures (table) get all the pictures that was posted by the user
    [query findObjectsInBackgroundWithBlock:^(NSArray *PFObjects, NSError *error) {
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error userInfo][@"Error"]
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK", nil];
            [alertView show];
        }else{
            //ADDS A CONTACT ID FROM THE CONTACT LIST TO AN ARRAY
            for (NSInteger i = 0; i < PFObjects.count; i++) {
                [contactIDsArray addObject:PFObjects[i]];
                //GET THE USER'S UNLOCKED HEXS NUMBER
                PFObject *object = PFObjects[i];
                NSArray *unlockedHexs = [object objectForKey:@"UnlockedHexs"];
                NSNumber *numHexs = [NSNumber numberWithLong:unlockedHexs.count];
                [contactUnlockedHexsArray addObject:numHexs];
                NSLog(@"%@",numHexs);
                //NSLog(@"%@", [PFObjects[i] objectForKey:@"username"]);
                [self uploadDataOnMap: contactIDsArray[i]: contactNamesArray[i]: contactUnlockedHexsArray[i]];//SET UP ALL CURRENT USER'S PICTURES
            }
        }
    }];
}

# pragma mark - Info Window Methods

- (void)plot:(NSArray *)objectsToPlot :(NSString *)Username :(NSArray*)LikesArray :(NSArray*)WhoLikedArray  :(NSArray*)ViewsArray :(NSArray*)WhoViewedArray : (NSArray*)dateCreatedArray :(NSNumber *)unlockedHexs :(NSArray *)objectIDArray {
    
    [self setCameraToUserLoc];
    // add all annotations
    // NOTE: coordinateValue can be any type from which a CLLocationCoordinate2D can be determined
    int counter = 0;

    for (CLLocation *coordinateValue in objectsToPlot)
    {
        // make CLLocationCoordinate2D
        CLLocationCoordinate2D coordinate = coordinateValue.coordinate;
        
        //MAKE SURE THE MARKER ISN't ON THE MAP ALREADY AND MAKE SURE IT IS IN AN UNLOCKED HEX
        if ([self isCoordInUnlockedHex:coordinateValue] && ![self isMarkerOnMap:coordinateValue]) {
            NSNumber *likes = LikesArray[counter];
            NSNumber *views = ViewsArray[counter];
            NSArray *whoLiked = WhoLikedArray[counter];
            NSArray *whoViewed = WhoViewedArray[counter];
            NSString *objectID = objectIDArray[counter];
            NSDate *dateCreated = dateCreatedArray[counter];
            
            GMSMarker *marker = [[GMSMarker alloc] init];
            marker.opacity = 0.9;
            marker.position = coordinate;
            marker.appearAnimation = kGMSMarkerAnimationPop;
            marker.icon = [UIImage imageNamed:@"PicCircle"];
            //        // add annotation
            //        marker.title = Username;
            //        marker.snippet = @"In-Range\nLikes: 125\nViews: 320";
            CustomInfoWindow *infoWindow =  [[[NSBundle mainBundle] loadNibNamed:@"InfoWindow" owner:self options:nil] objectAtIndex:0];
            
            NSDate *currentDate = [NSDate date];
            NSInteger secondsBetweenDates = [self secondsBetweenDates:currentDate andDate:dateCreated];
            NSInteger minutesBetweenDates = [self minutesBetweenDates:currentDate andDate:dateCreated];
            NSInteger hoursBetweenDates = [self hoursBetweenDates:currentDate andDate:dateCreated];
            NSInteger daysBetweenDates = [self daysBetweenDates:dateCreated andDate:currentDate];
            
            if(secondsBetweenDates < 60){
                infoWindow.timeLabel.text = [NSString stringWithFormat:@"%i Seconds ago", (int)secondsBetweenDates];
            }else if(minutesBetweenDates < 60){
                infoWindow.timeLabel.text = [NSString stringWithFormat:@"%i Minutes ago", (int)minutesBetweenDates];
            }else if(hoursBetweenDates < 24){
                infoWindow.timeLabel.text = [NSString stringWithFormat:@"%i Hours ago", (int)hoursBetweenDates];
            }else{
                infoWindow.timeLabel.text = [NSString stringWithFormat:@"%i Days ago", (int)daysBetweenDates];
            }
            infoWindow.usernameLabel.text = Username;
            infoWindow.usernameImageLabel.text = Username;
            infoWindow.likesLabel.text = [NSString stringWithFormat:@"%@", likes];
            infoWindow.likesImageLabel.text = [NSString stringWithFormat:@"%@", likes];
            infoWindow.viewsLabel.text = [NSString stringWithFormat:@"%@", views];
            infoWindow.viewsImageLabel.text = [NSString stringWithFormat:@"%@", views];
            infoWindow.hexCountLabel.text = [NSString stringWithFormat:@"%@",unlockedHexs];
            infoWindow.usersWhoLiked = [NSMutableArray arrayWithArray:whoLiked];
            infoWindow.usersWhoViewed = [NSMutableArray arrayWithArray:whoViewed];
            infoWindow.objectID = objectID;
            infoWindow.likesLabel.adjustsFontSizeToFitWidth = YES;
            infoWindow.viewsLabel.adjustsFontSizeToFitWidth = YES;
            infoWindow.usernameLabel.adjustsFontSizeToFitWidth = YES;
            infoWindow.coordinate = coordinate;
            [infoWindows addObject:infoWindow];
            marker.map = self.mapView_;
            [GMSMarkersArray addObject:marker];//MAKE SURE IT GETS RESET WHEN NEW MARKERS APPEAR IN THE SAME SPOT
            counter++;
        }
    }
}

- (NSInteger)secondsBetweenDates:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSTimeInterval distanceBetweenDates = [fromDateTime timeIntervalSinceDate:toDateTime];
    
    return distanceBetweenDates;
}

- (NSInteger)minutesBetweenDates:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSTimeInterval distanceBetweenDates = [fromDateTime timeIntervalSinceDate:toDateTime];
    double secondsInAnMinute = 60;
    NSInteger minutesBetweenDates = distanceBetweenDates / secondsInAnMinute;
    
    return minutesBetweenDates;
}

- (NSInteger)hoursBetweenDates:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSTimeInterval distanceBetweenDates = [fromDateTime timeIntervalSinceDate:toDateTime];
    double secondsInAnHour = 3600;
    NSInteger hoursBetweenDates = distanceBetweenDates / secondsInAnHour;
    
    return hoursBetweenDates;
}

- (NSInteger)daysBetweenDates:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSDate *fromDate;
    NSDate *toDate;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&fromDate
                 interval:NULL forDate:fromDateTime];
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&toDate
                 interval:NULL forDate:toDateTime];
    
    NSDateComponents *difference = [calendar components:NSCalendarUnitDay
                                               fromDate:fromDate toDate:toDate options:0];
    
    return [difference day];
}

-(bool)isCoordInUnlockedHex:(CLLocation *)coord{
    bool isInUnlockedHex = NO;
    for (int i = 0; i < userUnlockedHexsArray.count; i++) {
        PFGeoPoint *geoPoint = userUnlockedHexsArray[i];
        CLLocation *hexCenter = [[CLLocation alloc] initWithLatitude:geoPoint.latitude longitude:geoPoint.longitude];
        GMSPolygon *hexPoly = [self getHexPolygon:hexCenter];
        if (GMSGeometryContainsLocation(coord.coordinate, hexPoly.path, YES)) {
            return YES;
            break;
        }
    }
    return isInUnlockedHex;
}

-(bool)isMarkerOnMap:(CLLocation *)coord{
    bool isOnMap=false;
    for (int i = 0; i < GMSMarkersArray.count; i++) {
        GMSMarker *marker = GMSMarkersArray[i];
        if ((fabs(marker.position.latitude - coord.coordinate.latitude) < 0.00001) && (fabs(marker.position.longitude - coord.coordinate.longitude) < 0.00001)) {
            return true;
            break;
        }
    }
    return isOnMap;
}

- (UIView *)mapView:(GMSMapView *)mapView markerInfoWindow:(GMSMarker *)marker {
    //RESET THE PREVIOUSLY SELECTED MARKER
    prevMarker.icon = [UIImage imageNamed:@"PicCircle"];
    prevMarker.zIndex = 1;
    //MOVE THE PREVIOUS WINDOW OUT
    CustomInfoWindow *iWindow = infoWindows[prevInfoWindowMarkerIndex];
    [iWindow setCenter:CGPointMake(iWindow.center.x,iWindow.center.y*10)];

    for (int i = 0; i < infoWindows.count; i++) {
        CustomInfoWindow *window = infoWindows[i];
        CLLocationCoordinate2D coord = window.coordinate;
        if(coord.latitude == marker.position.latitude && coord.longitude == marker.position.longitude){
            marker.icon = [UIImage imageNamed:@"PicCircleSelected"]; // REPLACE WITH SELECTED ICON
            //TURN THIS INTO AN ANIMATION
            marker.zIndex = 99999; //MAKE THE ICON IN FRONT OF THE SCREEN
            prevMarker = marker;
            prevInfoWindowMarkerIndex = i;
            
            [self DrawInInfoWindow:i];
            return nil;
        }
    }
    int index = infoWindows.count;
    
    [self DrawInInfoWindow:index];
    return nil;
}

-(void)DrawInInfoWindow:(int)index{
    //PUT THE XIB INTO A UIVIEW AND CONFIGURE WITH TO DEVICE
    
    //[currentInfoWindow removeFromSuperview]; //REMOVE THE PREVIOUS INFO WINDOW
    
    viewingPic = false;
    
    CustomInfoWindow *window = infoWindows[index];
    
    currentInfoWindow = window;
    
    [currentInfoWindow setAlpha:1.0];
    
    [window.imageBG setUserInteractionEnabled:true];
    
    // add a pan recognizer
    UIGestureRecognizer* recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    recognizer.delegate = self;
    [window addGestureRecognizer:recognizer];
    /////////////////////////////////////////
    int hiddenY = _mapView_.frame.size.height + 5 + window.frame.size.height;
    int desiredY = _mapView_.frame.size.height - (window.messageBox.frame.size.height + self.tabBarController.tabBar.frame.size.height - 2);
    
    window.mainView = self;
    [self.view addSubview:window];
    
    [window setFrame:CGRectMake(window.frame.origin.x, hiddenY, _mapView_.bounds.size.width, self.view.bounds.size.height)];
        
    //CHANGE THE HEIGHT OF THE imageBG to the size of the phone
    CGRect imageBGrect = currentInfoWindow.imageBG.frame;
    imageBGrect.size.height = self.mapView_.bounds.size.height;
    currentInfoWindow.imageBG.frame = imageBGrect;
    //RESIZE THE XIB TO THE SIZE OF THE CONTENT INSIDE (messagebox & imageGBG)
    CGRect currentWindowRect = currentInfoWindow.frame;
    currentWindowRect.size.height = currentInfoWindow.messageBox.bounds.size.height + currentInfoWindow.imageBG.frame.size.height;
    currentInfoWindow.frame = currentWindowRect;
    //ANIMATE UIVIEW IN
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.2];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    
    //SET THE FRAME WIDTH TO THE Phone WIDTH AND THE HEIGHT TO THE PHONE HEIGHT + MESSAGEBOX
    currentInfoWindow.frame = CGRectMake(window.frame.origin.x, desiredY, _mapView_.bounds.size.width, window.bounds.size.height);

    [UIView commitAnimations];
}

- (void)LoadPicture{
    CLLocationCoordinate2D selectedMarkerLoc = _mapView_.selectedMarker.position;
    
    PFFile *picture;
    bool foundPic = false;
    int index=0;
    for (int i = 0; i < postedPictureLocations.count; i++) {
        if (foundPic == false) {
            PFGeoPoint *tempGeo = postedPictureLocations[i];
            CLLocationCoordinate2D tempLoc = CLLocationCoordinate2DMake(tempGeo.latitude, tempGeo.longitude);
            if (tempLoc.latitude == selectedMarkerLoc.latitude && tempLoc.longitude == selectedMarkerLoc.longitude) {
                index = i;
                foundPic = true;//ADD THE LIKES AND THE VIEWS IN HERE
            }
        }
    }
    picture = PFFilePictureArray[index];
    [picture getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (!error) {
            UIImage *image = [UIImage imageWithData:data];
            currentInfoWindow.image.image = nil;
            currentInfoWindow.image.image = image;
        }
    }];
}

-(void)viewedPicture{
    NSLog(@"User Viewed Picture");
    NSLog(@"%@", currentInfoWindow.objectID);
    //SEND TO BACKEND SERVER
    PFQuery *query = [PFQuery queryWithClassName:@"PostedPictures"];
    [query getObjectInBackgroundWithId:currentInfoWindow.objectID block:^(PFObject *thePicture, NSError *error) {
        if (!error) {
            // Found the picture
            int numViews = [currentInfoWindow.viewsImageLabel.text intValue];
            PFUser *currentUser = [PFUser currentUser];
            NSString *username = [currentUser username];
            NSLog(username);
            if ([self userViewedPic:username]) {
                //Do nothing
            }else{
                //Add user to views, increment views
                numViews++;
                //Add user to viewed array
                [currentInfoWindow.usersWhoViewed addObject: username];
            }
            NSLog(@"Views: %i",numViews);
            currentInfoWindow.viewsImageLabel.text = [NSString stringWithFormat:@"%i",numViews];
            currentInfoWindow.viewsLabel.text = [NSString stringWithFormat:@"%i",numViews];
            
            thePicture[@"Views"] = [NSNumber numberWithInt:numViews];
            thePicture[@"UsersWhoViewed"] = [currentInfoWindow.usersWhoViewed copy];
            
            // Save
            [thePicture saveInBackground];
        } else {
            // Did not find any picture for the objectID
            NSLog(@"Error: %@", error);
        }
    }];}

-(void)likedPicture{
    NSLog(@"User Liked Picture");
    NSLog(@"%@", currentInfoWindow.objectID);
    //SEND TO BACKEND SERVER
    PFQuery *query = [PFQuery queryWithClassName:@"PostedPictures"];
    [query getObjectInBackgroundWithId:currentInfoWindow.objectID block:^(PFObject *thePicture, NSError *error) {
        if (!error) {
            // Found the picture
            int numLikes = [currentInfoWindow.likesImageLabel.text intValue];
            PFUser *currentUser = [PFUser currentUser];
            NSString *username = [currentUser username];
            
            if ([self userLikedPic:username]) {
                //Unliked the pic
                numLikes--;
                //Remove user from liked array
                [self removeUserFromArray:username];
            }else{
                //Like the pic
                numLikes++;
                //Add user to liked array
                [currentInfoWindow.usersWhoLiked addObject: username];
            }
            NSLog(@"Likes: %i",numLikes);
            
            currentInfoWindow.likesImageLabel.text = [NSString stringWithFormat:@"%i",numLikes];
            currentInfoWindow.likesLabel.text = [NSString stringWithFormat:@"%i",numLikes];
            
            thePicture[@"Likes"] = [NSNumber numberWithInt:numLikes];
            thePicture[@"UsersWhoLiked"] = [currentInfoWindow.usersWhoLiked copy];
            
            // Save
            [thePicture saveInBackground];
        } else {
            // Did not find any picture for the objectID
            NSLog(@"Error: %@", error);
        }
    }];
}

-(BOOL)userLikedPic :(NSString *)username{
    for(int i = 0; i < currentInfoWindow.usersWhoLiked.count; i++){
        if([username isEqualToString:currentInfoWindow.usersWhoLiked[i]]){
            return true;
        }
    }
    return false;
}

-(BOOL)userViewedPic :(NSString *)username{
    for(int i = 0; i < currentInfoWindow.usersWhoViewed.count; i++){
        if([username isEqualToString:currentInfoWindow.usersWhoViewed[i]]){
            return true;
        }
    }
    return false;
}


-(void)removeUserFromArray:(NSString *)username{
    int index=-1;
    for(int i = 0; i < currentInfoWindow.usersWhoLiked.count; i++){
        if([username isEqualToString:currentInfoWindow.usersWhoLiked[i]]){
            index = i;
        }
    }
    [currentInfoWindow.usersWhoLiked removeObjectAtIndex:index];
}

#pragma mark - horizontal pan gesture methods
-(BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint translation = [gestureRecognizer translationInView:currentInfoWindow];
    // Check for vertical gesture
    if (fabs(translation.y) > fabs(translation.x)) {
        return YES;
    }
    return NO;
}

-(void)handlePan:(UIPanGestureRecognizer *)recognizer {
    // 1
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        // if the gesture has just started, record the current centre location
        initialTouchLocation = [recognizer locationInView: currentInfoWindow];
        _originalY = currentInfoWindow.frame.origin.y;
        _originalNavBarY = self.navigationController.navigationBar.frame.origin.y;
        if (!draggedPicUp) {
            //LOAD IN ALL OF THE DATA
            [self LoadPicture];
        }
    }
    
    // 2
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        // translate the center
        CGPoint translation = [recognizer translationInView:currentInfoWindow];
        CGRect rect = currentInfoWindow.frame;
        
        //NSLog(@"Translation: %f", translation.y);
        //NSLog(@"Info Window Y: %f", currentInfoWindow.frame.origin.y);
        
        if (CGRectContainsPoint(currentInfoWindow.messageBox.frame, initialTouchLocation) ) {
            //IF THE USER TOUCHES THE MESSAGEBOX
            draggedPicUp = true;

            rect.origin.y = translation.y + _originalY;
            currentInfoWindow.frame = rect;
            
            // Change values of other objects during drag
            float percentage = (translation.y/ _originalY) * -1;
            
            //CHANGE NAV BAR HEIGHT
            CGRect navBarRect = self.navigationController.navigationBar.frame;
            navBarRect.origin.y = (-(navBarRect.size.height + 20) * percentage) + _originalNavBarY;
            self.navigationController.navigationBar.frame = navBarRect;
            //CHANGE TAB BAR ALPHA
            [self.tabBarController.tabBar setAlpha:(1.f - percentage)];
            currentInfoWindow.imageBG.alpha = 1;
        }else if(draggedPicUp){
            //IF THE USER TOUCHES THE IMAGEVIEW
            if ((translation.y + _originalY ) <= rect.origin.y) {//WHEN USER SWIPES UP
                rect.origin.y = translation.y + _originalY;
            }
            currentInfoWindow.frame = rect;
            
            //RESET MARKER
            [_mapView_ setSelectedMarker:nil];
            prevMarker.icon = [UIImage imageNamed:@"PicCircle"];
            prevMarker.zIndex = 1;
        }
    }
    
    // 3
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (CGRectContainsPoint(currentInfoWindow.messageBox.frame, initialTouchLocation) ) {
            //IF THE USER TOUCHES THE MESSAGEBOX
            _mapView_.userInteractionEnabled = false;
            //NSLog(@"Swiped Up");
            //////////////////////////////////ANIMATIONS/////////////////////////////////
            //currentInfoWindow.alpha = 0.0;
            [self viewedPicture];
            [UIView beginAnimations:nil context:nil];
            [UIView setAnimationDuration:0.2];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            
            CGRect infoWindowRect = currentInfoWindow.frame;
            infoWindowRect.origin.y = (-currentInfoWindow.messageBox.frame.size.height) + 1;
            currentInfoWindow.frame = infoWindowRect;
            
            [self.navigationController setNavigationBarHidden:YES animated:YES];
            [self.tabBarController.tabBar setAlpha:0.0];
            
            [UIView commitAnimations];
            /////////////////////////////////////////////////////////////////////////////
        }else if (draggedPicUp){
            //IF THE USER TOUCHES THE IMAGEVIEW
            if (currentInfoWindow.frame.origin.y < ((-currentInfoWindow.messageBox.frame.size.height) + 1)) {//IF USER SWIPED UP
                draggedPicUp = false;
                _mapView_.userInteractionEnabled = true;
                
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationDuration:0.2];
                [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
                
                CGRect infoWindowRect = currentInfoWindow.frame;
                infoWindowRect.origin.y = -(self.view.center.y * 2);
                currentInfoWindow.frame = infoWindowRect;
                
                [self.navigationController setNavigationBarHidden:NO animated:YES];
                [self.tabBarController.tabBar setAlpha:1.0];
                
                [UIView commitAnimations];
            }else{
                
            }
        }
    }
}

# pragma mark - Helper Methods

-(void)setCameraToUserLoc{
    GMSCameraPosition *camera = [GMSCameraPosition
                                 cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                 longitude:self.mapView_.myLocation.coordinate.longitude
                                 zoom:11];
    self.mapView_.camera = camera;
}

-(void)setCameraToUserLocAnimated{
    GMSCameraPosition *camera = [GMSCameraPosition
                                 cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                 longitude:self.mapView_.myLocation.coordinate.longitude
                                 zoom:11];
    [self.mapView_ animateToCameraPosition:camera];
}

-(UIColor*)colorWithHexString:(NSString*)hex
{
    NSString *cString = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    // String should be 6 or 8 characters
    if ([cString length] < 6) return [UIColor grayColor];
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];
    
    if ([cString length] != 6) return  [UIColor grayColor];
    
    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];
    
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float) r / 255.0f)
                           green:((float) g / 255.0f)
                            blue:((float) b / 255.0f)
                           alpha:1.0f];
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
            
            CLLocation *center = [self getCenterOfHex:hexH];
            NSNumber *latStr = [NSNumber numberWithDouble:center.coordinate.latitude];
            NSNumber *longStr = [NSNumber numberWithDouble:center.coordinate.longitude];
            if (center.coordinate.latitude <= 90 && center.coordinate.latitude >= -90 && center.coordinate.longitude >= -180 && center.coordinate.longitude <=180) {
            NSDictionary *location = [NSDictionary dictionaryWithObjectsAndKeys:
                                                @"GeoPoint", @"__type",
                                                longStr,@"longitude",
                                                latStr,@"latitude",
                                                nil];
            NSDictionary *tempJsonDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                    location,@"h",
                                                    nil];
                if (center.coordinate.latitude <= 0 && center.coordinate.latitude >= -90) {
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
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    if ([[segue identifier] isEqualToString:@"SegueToCamera"])
    {
        // Get reference to the destination view controller
        CameraViewController *vc = [segue destinationViewController];
        
        // Pass any objects to the view controller here, like...
        CLLocationCoordinate2D coord = [self.mapView_ myLocation].coordinate;
        [vc setUserLocation:coord];
    }
}


@end
