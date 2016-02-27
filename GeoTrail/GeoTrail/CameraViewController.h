//
//  CameraViewController.h
//  GeoTrail
//
//  Created by Arthur Araujo on 6/25/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

@interface CameraViewController : UIViewController <CLLocationManagerDelegate>
-(void)setUserLocation:(CLLocationCoordinate2D)userLocation;
@end
