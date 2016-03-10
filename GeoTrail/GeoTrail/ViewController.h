//
//  ViewController.h
//  SnapTrail
//
//  Created by Arthur Araujo on 4/12/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

@interface ViewController : UIViewController <CLLocationManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate, FBSDKLoginButtonDelegate>

-(void)likedPicture;

@end

