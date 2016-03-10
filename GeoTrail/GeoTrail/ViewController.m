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

#import <Firebase/Firebase.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <GoogleMaps/GoogleMaps.h>
#import "Contact.h"
#import "TabBarController.h"

#import "ViewController.h"

BOOL initialZoomComplete = NO;

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *picView;
@property (weak, nonatomic) IBOutlet GMSMapView *mapView_;
@property (weak, nonatomic) IBOutlet UIButton *nextPicButton;
@property (weak, nonatomic) IBOutlet UIButton *goToUserLocButton;

@end

const double ONE_MILE_IN_METERS = 1609.344;
#define EARTH_EQUATORIAL_RADIUS (6378137.0)
#define WGS84_CONSTANT (0.99664719)
#define degreesToRadians(x) (M_PI * (x) / 180.0)

@implementation ViewController{
    CLLocationManager *locationManager;
    
    int currentRange;
    float milesSpanRegion;
    bool hideStatusBar;
    //PFObject *postedPictures;
    GMSMarker *prevMarker;
    int prevInfoWindowMarkerIndex;
    NSMutableArray *contactsArray;
    NSMutableArray *contactIDsArray;
    NSMutableArray *contactUnlockedHexsArray;
    CLLocationCoordinate2D currentUserLoc;
    NSMutableArray *postedPictureLocations;
    NSMutableArray *hexArray;
    NSMutableArray *northWestHexArray;
    NSMutableArray *southWestHexArray;
    NSMutableArray *southEastHexArray;
    NSMutableArray *northEastHexArray;
    //NSMutableArray *userUnlockedHexsArray;
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
    int userUnlockedHexsCount;
    int counter;
    CLLocation *closestHexCenter;
    //Hex Info
    CLLocationCoordinate2D bottomLeft;
    CLLocationCoordinate2D topLeft;
    CLLocationCoordinate2D bottomRight;
    CLLocationCoordinate2D topRight;
    
    
    //ALL FIREBASE USER INFO
    Firebase *firebaseRef;
    FAuthData *currentUser;
    NSMutableArray *unlockedHexsLatitude;
    NSMutableArray *unlockedHexsLongitude;
    
    //Facebook
    FBSDKLoginManager *facebookLoginManager;
}
- (IBAction)TappedRefresh:(id)sender {
    [self loadDataOnScreen];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self initArrays];
        [self setMapViewCustomizations];

    _picView.alpha = 0;
    
//    [loginButton addTarget:self
//                                 action:@selector(logIntoFacebook)
//                       forControlEvents:UIControlEventTouchUpInside];
    
    //[self addHexagons];
    [self logIntoFacebook];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self setCameraToUserLoc];
    [self loadDataOnScreen];
}

-(void)initArrays{
    contactUnlockedHexsArray = [[NSMutableArray alloc] init];
    unlockedHexsLatitude = [[NSMutableArray alloc]init];
    unlockedHexsLongitude = [[NSMutableArray alloc]init];
    contactsArray = [[NSMutableArray alloc] init];
    contactIDsArray = [[NSMutableArray alloc] init];
    hexArray = [[NSMutableArray alloc]init];
    northWestHexArray = [[NSMutableArray alloc]init];
    southWestHexArray = [[NSMutableArray alloc]init];
    southEastHexArray = [[NSMutableArray alloc]init];
    northEastHexArray = [[NSMutableArray alloc]init];
    hexInViewArray = [[NSMutableArray alloc]init];
    shadedHexCentersOnMap = [[NSMutableArray alloc]init];
    postedPictureLocations = [[NSMutableArray alloc]init];
    infoWindows = [[NSMutableArray alloc] init];
    GMSMarkersArray = [[NSMutableArray alloc]init];
}

-(void)setMapViewCustomizations{
    GMSCameraPosition *camera = [GMSCameraPosition
                                 cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                 longitude:self.mapView_.myLocation.coordinate.longitude
                                 zoom:11];
    //self.mapView_ = [GMSMapView mapWithFrame:self.view.bounds camera:camera];
    self.mapView_.delegate = self;
    self.mapView_.myLocationEnabled = YES;
    self.mapView_.mapType = kGMSTypeNormal;
    self.mapView_.settings.rotateGestures = false;
    self.mapView_.buildingsEnabled = true;
    [self.mapView_ setBackgroundColor:[UIColor purpleColor]];
    self.mapView_.indoorEnabled = false;
    [self.mapView_ setMinZoom:5 maxZoom:25];
}

-(void)logIntoFacebook{
    firebaseRef = [[Firebase alloc] initWithUrl:@"https://incandescent-inferno-4410.firebaseio.com/"];
    
    if(facebookLoginManager == nil){
        facebookLoginManager = [[FBSDKLoginManager alloc] init];
    }
    
    [facebookLoginManager logInWithReadPermissions:@[@"email",@"public_profile",@"user_friends"]
                                    handler:^(FBSDKLoginManagerLoginResult *facebookResult, NSError *facebookError) {
                                        if (facebookError) {
                                            NSLog(@"Facebook login failed. Error: %@", facebookError);
                                        } else if (facebookResult.isCancelled) {
                                            NSLog(@"Facebook login got cancelled.");
                                        } else {
                                            NSString *accessToken = [[FBSDKAccessToken currentAccessToken] tokenString];
                                            [firebaseRef authWithOAuthProvider:@"facebook" token:accessToken
                                                   withCompletionBlock:^(NSError *error, FAuthData *authData) {
                                                       if (error) {
                                                           NSLog(@"Login failed. %@", error);
                                                       } else {
                                                           NSLog(@"Logged in! %@", authData);
                                                           currentUser = authData;
                                                           TabBarController *tabBarController = (TabBarController *)self.tabBarController;
                                                           tabBarController.currentUser = currentUser;
                                                           tabBarController.firebaseRef = firebaseRef;
                                                           [self checkUserData];
                                                           [self loadDataOnScreen];
                                                       }
                                                   }];
                                        }
                                    }];
}

-(void)setUpNewUser{
    NSLog(@"Creating new user...");
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSDictionary *newUser = @{
                              @"fullName": currentUser.providerData[@"displayName"],
                              @"userName": @"Temp",
                              @"uid":currentUser.uid,
                              @"email":currentUser.providerData[@"email"],
                              @"unlockedHexsLatitude": [NSArray arrayWithObject:@"Temp"],
                              @"unlockedHexsLongitude": [NSArray arrayWithObject:@"Temp"],
                              @"contacts":[NSArray arrayWithObject:@"Temp"],
                              @"dateAccountCreated": date
                              };

    NSDictionary *users = @{
                            currentUser.uid: newUser
                            };
    
    Firebase *tempRef = [firebaseRef childByAppendingPath:@"users"];
    [tempRef setValue: users];
    NSLog(@"Created user: %@",newUser);
}

-(void)checkUserData{
    // Get a reference to our postedpictures
    Firebase* tempRef = [firebaseRef childByAppendingPath:[NSString stringWithFormat:@"users/%@", currentUser.uid]];
    
    [tempRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if(snapshot.value != [NSNull null]){
            NSLog(@"%@", snapshot.value);
            unlockedHexsLatitude = (NSMutableArray *)[snapshot.value[@"unlockedHexsLatitude"] array];
            unlockedHexsLongitude = (NSMutableArray *)[snapshot.value[@"unlockedHexsLongitude"] array];
        }else{
            [self setUpNewUser];
        }
    } withCancelBlock:^(NSError *error) {
        NSLog(@"checkUserData: %@", error.description);
    }];
}

-(void)loadDataOnScreen{
    [self loadHexsOnMap];
    //Load user's data onto map
    [self uploadUserDataOnMap];
    //SET UP ALL CURRENT USER'S PICTURES
    [self loadContactList];
}

- (void)mapView:(GMSMapView *)mapView didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate{
    
}

-(void)uploadUserDataOnMap{
    Firebase* tempRef = [firebaseRef childByAppendingPath:@"postedpictures"];
    [tempRef queryEqualToValue:currentUser.uid childKey:@"owner"];
    [tempRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        // make CLLocationCoordinate2D
        if(snapshot.value != [NSNull null]){
            NSLog(@"%@",snapshot.value);
            NSNumber *latitude = snapshot.value[@"latitude"];
            NSNumber *longitude = snapshot.value[@"longitude"];
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
            CLLocation *coordinateValue = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
            
            //MAKE SURE THE MARKER ISN't ON THE MAP ALREADY AND MAKE SURE IT IS IN AN UNLOCKED HEX
            if ([self isCoordInUnlockedHex:coordinateValue] && ![self isMarkerOnMap:coordinateValue]) {
                NSNumber *likes = snapshot.value[@"likes"];
                NSNumber *views = snapshot.value[@"views"];
                NSArray *whoLiked = snapshot.value[@"whoLiked"];
                NSArray *whoViewed = snapshot.value[@"whoViewed"];
                NSString *objectID = snapshot.key;
                NSDate *dateCreated = (NSDate *)snapshot.value[@"dateCreated"] ;
                
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
                
                //Converts string to the image
                NSString* picString = snapshot.value[@"image"];
                
                NSData* data=[picString dataUsingEncoding:NSUTF8StringEncoding];
                UIImage *image = [[UIImage alloc]initWithData:data];
                [infoWindow.image setImage:image];
                infoWindow.usernameLabel.text = snapshot.value[@"displayName"];
                infoWindow.usernameImageLabel.text = snapshot.value[@"displayName"];
                infoWindow.likesLabel.text = [NSString stringWithFormat:@"%@", likes];
                infoWindow.likesImageLabel.text = [NSString stringWithFormat:@"%@", likes];
                infoWindow.viewsLabel.text = [NSString stringWithFormat:@"%@", views];
                infoWindow.viewsImageLabel.text = [NSString stringWithFormat:@"%@", views];
                infoWindow.hexCountLabel.text = [NSString stringWithFormat:@"%@",snapshot.value[@"unlockedHexs"]];
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
            }
        }else{
            NSLog(@"checkUserData: snapshot.value == null");
        }
    } withCancelBlock:^(NSError *error) {
        NSLog(@"uploadUserDataOnMap: %@", error.description);
    }];
}

-(void)uploadContactDataOnMap{
    // Get a reference to our postedpictures
    Firebase* tempRef = [firebaseRef childByAppendingPath:@"postedpictures"];
    
    //Share contacts to tabBarController to be accessed by other classes
    TabBarController *tabBarController = (TabBarController *)self.tabBarController;
    tabBarController.contactsArray = contactsArray;
    tabBarController.contactIDsArray = contactIDsArray;
    
    //Go through each contact and get their posted pictures
    for(int i = 0; i < contactIDsArray.count; i++){
        // Attach a block to read the data at our postedpictures reference
        
        //Get the posted pictures from the owner that matches with the contact ID
        //BACKEND: PostedPicture.owner == contactID then grab that pic
        [tempRef queryEqualToValue:contactIDsArray[i] childKey:@"owner"];
        [tempRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            NSLog(@"%@", snapshot.value);
            [self setCameraToUserLoc];
            
            // make CLLocationCoordinate2D
            NSNumber *latitude = snapshot.value[@"latitude"];
            NSNumber *longitude = snapshot.value[@"longitude"];
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
            CLLocation *coordinateValue = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
            
            //MAKE SURE THE MARKER ISN't ON THE MAP ALREADY AND MAKE SURE IT IS IN AN UNLOCKED HEX
            if ([self isCoordInUnlockedHex:coordinateValue] && ![self isMarkerOnMap:coordinateValue]) {
                NSNumber *likes = snapshot.value[@"likes"];
                NSNumber *views = snapshot.value[@"views"];
                NSArray *whoLiked = snapshot.value[@"whoLiked"];
                NSArray *whoViewed = snapshot.value[@"whoViewed"];
                NSString *objectID = snapshot.key;
                NSDate *dateCreated = (NSDate *)snapshot.value[@"dateCreated"] ;
                
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
                infoWindow.usernameLabel.text = snapshot.value[@"displayName"];
                infoWindow.usernameImageLabel.text = snapshot.value[@"displayName"];
                infoWindow.likesLabel.text = [NSString stringWithFormat:@"%@", likes];
                infoWindow.likesImageLabel.text = [NSString stringWithFormat:@"%@", likes];
                infoWindow.viewsLabel.text = [NSString stringWithFormat:@"%@", views];
                infoWindow.viewsImageLabel.text = [NSString stringWithFormat:@"%@", views];
                infoWindow.hexCountLabel.text = [NSString stringWithFormat:@"%@",snapshot.value[@"unlockedHexs"]];
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
            }
            
        } withCancelBlock:^(NSError *error) {
            NSLog(@"uploadContactDataOnMap: %@", error.description);
        }];
    }
    [self loadHexsOnMap];
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

-(void)loadHexsOnMap{
    //ADD THE POLYGON USING THE INDEX
    CLLocation *userLoc = self.mapView_.myLocation;
    if(userLoc != nil){
        if ([self isInNewHex]) {
            [self addNewHex];
        }
        userUnlockedHexsCount = (int)unlockedHexsLatitude.count;
        [self drawUnlockedHexs];
    }else{
        NSLog(@"self.mapView.Location is nil");
    }
}
-(void)addNewHex{
    [unlockedHexsLatitude addObject:[NSNumber numberWithDouble: closestHexCenter.coordinate.latitude]];
    [unlockedHexsLongitude addObject:[NSNumber numberWithDouble: closestHexCenter.coordinate.longitude]];
    Firebase* tempRef = [firebaseRef childByAppendingPath:[NSString stringWithFormat:@"users/%@", currentUser.uid]];
    NSDictionary *post = @{
                           @"unlockedHexsLatitude": [NSArray arrayWithArray:unlockedHexsLatitude],
                           @"unlockedHexsLongitude": [NSArray arrayWithArray:unlockedHexsLongitude]
                           };
    [tempRef updateChildValues: post];
}

-(BOOL)isInNewHex{
    closestHexCenter = [self closestHexCenter];
    GMSMarker *marker = [GMSMarker markerWithPosition:closestHexCenter.coordinate];
    marker.opacity = 1;
    marker.icon = [UIImage imageNamed:@"PicCircle"];
    marker.map = self.mapView_;
    
    BOOL isInNewHex = true;
    //Go through the unlockedHexs, if they are less than 100 meters of a known unlockedHex it is not a new Hex
    for (int i = 0; i < unlockedHexsLatitude.count; i++) {
        CLLocation *unlockedHexLoc = [[CLLocation alloc]initWithLatitude:[unlockedHexsLatitude[i] doubleValue] longitude:[unlockedHexsLongitude[i] doubleValue]];
        if ([unlockedHexLoc distanceFromLocation:closestHexCenter]<100) {
            isInNewHex = false;
        }
    }
    return isInNewHex;
}

-(CLLocation*)closestHexCenter{
    CLLocation *userLoc = self.mapView_.myLocation;
    
    double currentLat = -90;
    double currentLong = self.mapView_.myLocation.coordinate.longitude;
    BOOL findingClosestLat=true;
    
    for(int i = 0; i <= 1; i++){
        //Reset values
        double prevDistance = 9999999999999.9;
        BOOL distanceIsShrinking = true;
        //Increase lat & long seperately by 5 miles from 0 until it is closest to userLoc
        while (distanceIsShrinking) {
            if (findingClosestLat) {//If finding closest latitude
                currentLat = [self IncrLatByOneMileLatitude:currentLat];
            }else{//If finding closest longitude
                currentLong = [self IncrLongByOneMileLatitude:currentLat Longitude:currentLong];
            }
            CLLocation *currentLoc = [[CLLocation alloc]initWithLatitude:currentLat longitude:currentLong];
            double distanceInMiles = [currentLoc distanceFromLocation:userLoc]/ONE_MILE_IN_METERS;
            if (prevDistance < distanceInMiles) {
                distanceIsShrinking = false;
                if (findingClosestLat) {
                    currentLat = [self DecrLatByOneMileLatitude:currentLat];
                    currentLong = -180;
                }else{
                    currentLong = [self DecrLongByOneMileLatitude:currentLat Longitude:currentLong];
                }
                findingClosestLat = false;
            }else{
                prevDistance = distanceInMiles;
            }
        }
    }
    
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLong];
}

-(double)IncrLatByOneMileLatitude:(double)latitude{
    //1 mile in latitude 0.01455445222
    double oneMileInLatDegrees = 0.01455445222;
    //Demonstrate closest hex center
    return latitude+=(oneMileInLatDegrees*1);
}

-(double)DecrLatByOneMileLatitude:(double)latitude{
    //1 mile in latitude 0.01455445222
    double oneMileInLatDegrees = 0.01455445222;
    //Demonstrate closest hex center
    GMSMarker *marker = [[GMSMarker alloc] init];
    marker.opacity = 0.2;
    marker.position = CLLocationCoordinate2DMake(latitude-(oneMileInLatDegrees*1), self.mapView_.myLocation.coordinate.longitude);
    marker.icon = [UIImage imageNamed:@"PicCircle"];
    marker.map = self.mapView_;
    return latitude-=(oneMileInLatDegrees*1);
}

-(double)IncrLongByOneMileLatitude:(double)latitude Longitude:(double)longitude{
    //1 mile in longitude ONE_MILE_IN_METERS/(111,320*cos(longitude))
    //http://stackoverflow.com/questions/6633850/calculate-new-coordinate-x-meters-and-y-degree-away-from-one-coordinate
    double OneMileInMeters = ONE_MILE_IN_METERS*0.9;
    
    double distanceRadians = (OneMileInMeters/1000) / 6371.0;
    //6,371 = Earth's radius in km
    double bearingRadians = [self radiansFromDegrees:90];
    double fromLatRadians = [self radiansFromDegrees:latitude];
    double fromLonRadians = [self radiansFromDegrees:longitude];
    
    double toLatRadians = asin( sin(fromLatRadians) * cos(distanceRadians)
                               + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians) );
    
    double toLonRadians = fromLonRadians + atan2(sin(bearingRadians)
                                                 * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians)
                                                 - sin(fromLatRadians) * sin(toLatRadians));
    
    // adjust toLonRadians to be in the range -180 to +180...
    toLonRadians = fmod((toLonRadians + 3*M_PI), (2*M_PI)) - M_PI;
    
    CLLocationCoordinate2D result;
    result.latitude = [self degreesFromRadians:toLatRadians];
    result.longitude = [self degreesFromRadians:toLonRadians];
    
    //Demonstrate closest hex center
    return result.longitude;
}

- (double)radiansFromDegrees:(double)degrees{
    return degrees * (M_PI/180.0);
}

- (double)degreesFromRadians:(double)radians{
    return radians * (180.0/M_PI);
}

-(double)DecrLongByOneMileLatitude:(double)latitude Longitude:(double)longitude{
    //1 mile in longitude ONE_MILE_IN_METERS/(111,320*cos(longitude))
    //http://stackoverflow.com/questions/6633850/calculate-new-coordinate-x-meters-and-y-degree-away-from-one-coordinate
    double OneMileInMeters = ONE_MILE_IN_METERS*0.9;
    
    double distanceRadians = (OneMileInMeters/1000) / 6371.0;
    //6,371 = Earth's radius in km
    double bearingRadians = [self radiansFromDegrees:-90];
    double fromLatRadians = [self radiansFromDegrees:latitude];
    double fromLonRadians = [self radiansFromDegrees:longitude];
    
    double toLatRadians = asin( sin(fromLatRadians) * cos(distanceRadians)
                               + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians) );
    
    double toLonRadians = fromLonRadians + atan2(sin(bearingRadians)
                                                 * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians)
                                                 - sin(fromLatRadians) * sin(toLatRadians));
    
    // adjust toLonRadians to be in the range -180 to +180...
    toLonRadians = fmod((toLonRadians + 3*M_PI), (2*M_PI)) - M_PI;
    
    CLLocationCoordinate2D result;
    result.latitude = [self degreesFromRadians:toLatRadians];
    result.longitude = [self degreesFromRadians:toLonRadians];

    //Demonstrate closest hex center
    GMSMarker *marker = [[GMSMarker alloc] init];
    marker.opacity = 0.5;
    marker.position = CLLocationCoordinate2DMake(result.latitude,result.longitude);
    marker.icon = [UIImage imageNamed:@"PicCircle"];
    marker.map = self.mapView_;
    return result.longitude;
}

-(void)drawUnlockedHexs{
    for (int i = 0; i < unlockedHexsLatitude.count; i++) {
        CLLocationCoordinate2D currentHexCenter = CLLocationCoordinate2DMake([unlockedHexsLatitude[i] doubleValue], [unlockedHexsLongitude[i] doubleValue]);
        
        //THESE ARE 5 MILE HEXAGONS
        float width = fabs(currentHexCenter.longitude - [self IncrLongByOneMileLatitude:currentHexCenter.latitude Longitude:currentHexCenter.longitude]);
        float height = fabs(currentHexCenter.latitude - [self IncrLatByOneMileLatitude:currentHexCenter.latitude]);
        float botMidHeights = height / 4;//CHANGING THE NUMBER (4) CHANGES THE LENGTH OF RIGHT AND LEFT SIDES
        float topMidHeights = height - botMidHeights;
        
        GMSMutablePath *hexH = [[GMSMutablePath path] init];
        
        float latCoords = currentHexCenter.latitude - (height / 2);//INCREASE THE LAT COORD
        float longCoords = currentHexCenter.longitude - (width / 2);//INCREASE THE LONG COORD//
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
            polygon2.fillColor = [[self colorWithHexString:@"BABABA"] colorWithAlphaComponent:0.8];
            polygon2.strokeColor = [self colorWithHexString:@"7E8C8D"];
            polygon2.strokeWidth = 6;
            polygon2.zIndex = 10;
            polygon2.map = self.mapView_;
        });
        [self drawBackground];
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

- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position{
    //Check if the user goes over bounds
    //if ((mapView.projection.visibleRegion.farLeft.latitude > topLeft.latitude)||(mapView.projection.visibleRegion.farLeft.longitude > topLeft.longitude)||(mapView.projection.visibleRegion.farRight.latitude > topRight.latitude)||(mapView.projection.visibleRegion.farRight.longitude > topRight.longitude)||(mapView.projection.visibleRegion.nearLeft.latitude > bottomLeft.latitude)||(mapView.projection.visibleRegion.nearLeft.longitude > bottomLeft.longitude)||(mapView.projection.visibleRegion.nearRight.latitude > bottomRight.latitude)||(mapView.projection.visibleRegion.nearRight.longitude > bottomRight.longitude)) {
        
    //}
}

-(void)setMapViewBounds{
    double lowestLat=999999999;
    double highestLat=-999999999;
    double lowestLong=999999999;
    double highestLong=-999999999;
    //Find the borders of the unlocked Hexs
    for (int i = 0; i < unlockedHexsLatitude.count; i++) {
        if (lowestLat > [unlockedHexsLatitude[i] doubleValue]) {
            lowestLat = [unlockedHexsLatitude[i] doubleValue];
        }
        if (highestLat < [unlockedHexsLatitude[i] doubleValue]) {
            highestLat = [unlockedHexsLatitude[i] doubleValue];
        }
        if (lowestLong > [unlockedHexsLongitude[i] doubleValue]) {
            lowestLong = [unlockedHexsLongitude[i] doubleValue];
        }
        if (highestLong < [unlockedHexsLongitude[i] doubleValue]) {
            highestLong = [unlockedHexsLongitude[i] doubleValue];
        }
    }
    double lowestLatWithPadding=[self DecrLatByOneMileLatitude:lowestLat];
    double higestLatWithPadding=[self IncrLatByOneMileLatitude:highestLat];
    double lowestLongWithPadding=[self DecrLongByOneMileLatitude:[self DecrLatByOneMileLatitude:lowestLat] Longitude:lowestLong];
    double highestLongWithPadding=[self IncrLongByOneMileLatitude:[self IncrLatByOneMileLatitude:highestLat] Longitude:highestLong];
    
    //Make each coordinate a corner of the hex(s)
    bottomLeft = CLLocationCoordinate2DMake(lowestLatWithPadding, lowestLongWithPadding);
    topLeft = CLLocationCoordinate2DMake(higestLatWithPadding, lowestLongWithPadding);
    topRight = CLLocationCoordinate2DMake(higestLatWithPadding, highestLongWithPadding);
    bottomRight = CLLocationCoordinate2DMake(lowestLatWithPadding, highestLongWithPadding);

    NSLog(@"Lowest Lat: %f", lowestLat);
    NSLog(@"Lowest Long: %f", lowestLong);
    
    GMSMutablePath *backgroundPath = [[GMSMutablePath path] init];
    [backgroundPath addCoordinate:bottomLeft];
    [backgroundPath addCoordinate:topLeft];
    [backgroundPath addCoordinate:topRight];
    [backgroundPath addCoordinate:bottomRight];
    GMSPolygon *background = [GMSPolygon polygonWithPath:backgroundPath];
    background.fillColor = [[self colorWithHexString:@"454545"] colorWithAlphaComponent:0.8];
    background.zIndex = 0;
    background.map = self.mapView_;
}

-(void)drawBackground{
    [self setMapViewBounds];
    double lowestLat=999999999;
    double highestLat=0;
    double lowestLong=999999999;
    double highestLong=0;
    //Find the borders of the unlocked Hexs
    for (int i = 0; i < unlockedHexsLatitude.count; i++) {
        if (lowestLat > [unlockedHexsLatitude[i] doubleValue]) {
            lowestLat = [unlockedHexsLatitude[i] doubleValue];
        }
        if (highestLat < [unlockedHexsLatitude[i] doubleValue]) {
            highestLat = [unlockedHexsLatitude[i] doubleValue];
        }
        if (lowestLong > [unlockedHexsLongitude[i] doubleValue]) {
            lowestLong = [unlockedHexsLongitude[i] doubleValue];
        }
        if (highestLong < [unlockedHexsLongitude[i] doubleValue]) {
            highestLong = [unlockedHexsLongitude[i] doubleValue];
        }
    }
    double latTenMilePadding;
    double longTenMilesPadding;
    CLLocationCoordinate2D bottomLeft = CLLocationCoordinate2DMake(lowestLat,  lowestLong);
    CLLocationCoordinate2D topLeft = CLLocationCoordinate2DMake(highestLat,  lowestLong);
    CLLocationCoordinate2D topRight = CLLocationCoordinate2DMake(highestLat,  highestLong);
    CLLocationCoordinate2D bottomRight = CLLocationCoordinate2DMake(lowestLat,  highestLong);
    GMSMutablePath *backgroundPath = [[GMSMutablePath path] init];
    [backgroundPath addCoordinate:bottomLeft];
    [backgroundPath addCoordinate:topLeft];
    [backgroundPath addCoordinate:topRight];
    [backgroundPath addCoordinate:bottomRight];
    GMSPolygon *background = [GMSPolygon polygonWithPath:backgroundPath];
    background.fillColor = [[self colorWithHexString:@"454545"] colorWithAlphaComponent:0.8];
    background.map = self.mapView_;
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
    for (int i = 0; i < unlockedHexsLatitude.count; i++) {
        CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake([unlockedHexsLatitude[i] doubleValue], [unlockedHexsLongitude[i] doubleValue]);
        if (fabs(center.coordinate.latitude - coordTemp.latitude) <= 0.01 && fabs(center.coordinate.longitude - coordTemp.longitude) <= 0.01) {
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

-(void)loadContactList{
    // Get a reference to our users
    Firebase* tempRef = [firebaseRef childByAppendingPath:[NSString stringWithFormat:@"users/%@", currentUser.uid]];
    
    // Attach a block to read the data at our users reference
    [tempRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if(snapshot.value != [NSNull null]){
            contactIDsArray = [NSMutableArray arrayWithArray:snapshot.value[@"contacts"]];
            [self loadContactListData];
        }else{
            NSLog(@"checkUserData: snapshot.value == null");
        }
    } withCancelBlock:^(NSError *error) {
        NSLog(@"loadContactList: %@", error.description);
    }];
}

-(void)loadContactListData{
    //Go through each contact and get their data
    for(int i = 0; i < contactIDsArray.count; i++){
        // Attach a block to read the data at our users
        if (![contactIDsArray[i]  isEqual: @"Temp"]) {
            //Get the contact that matches with the contactID
            Firebase* tempRef = [firebaseRef childByAppendingPath:[NSString stringWithFormat:@"users/%@", contactIDsArray[i]]];
            [tempRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                //TO DO: ADD EVERY VALUE OF CONTACT
                Contact *currentContact = [[Contact alloc] initWithName:snapshot.value[@"displayName"] uid:snapshot.key  unlockedHexsLatitude:[snapshot.value[@"unlockedHexsLatitude"] doubleValue]unlockedHexsLongitude: [snapshot.value[@"unlockedHexsLongitude"] doubleValue]];
                [contactsArray addObject:currentContact];
                //After the last contact is loaded, load their data onto the map
                if (i == (int)contactsArray.count) {
                    [self uploadContactDataOnMap];
                }
            } withCancelBlock:^(NSError *error) {
                NSLog(@"loadContactListData: %@", error.description);
            }];
        }
    }
}

# pragma mark - Info Window Methods
/*
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
            if([PFUser currentUser].username == Username){
                marker.icon = [UIImage imageNamed:@"PicCircle"];
            }else{
                marker.icon = [UIImage imageNamed:@"PicCircle"];
            }
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
}*/

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
    for (int i = 0; i < unlockedHexsLatitude.count; i++) {
        CLLocationCoordinate2D coordTemp = CLLocationCoordinate2DMake([unlockedHexsLatitude[i] doubleValue], [unlockedHexsLongitude[i] doubleValue]);
        CLLocation *hexCenter = [[CLLocation alloc] initWithLatitude:coordTemp.latitude longitude:coordTemp.longitude];
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
-(void)viewedPicture{
    /*
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
    }];*/
}
/*

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
*/

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
                                 zoom:15];
    [self.mapView_ setCamera:camera];
}

-(void)setCameraToUserLocAnimated{
    GMSCameraPosition *camera = [GMSCameraPosition
                                 cameraWithLatitude:self.mapView_.myLocation.coordinate.latitude
                                 longitude:self.mapView_.myLocation.coordinate.longitude
                                 zoom:15];
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



@end
