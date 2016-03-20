//
//  CustomInfoWindow.h
//  GeoTrail
//
//  Created by Arthur Araujo on 6/19/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "ViewController.h"

@interface HexButtonXIB : UIView <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *picCounterLabel;
@property (nonatomic) int picCounter;
@property (nonatomic) CLLocationCoordinate2D coordinate;

@end
