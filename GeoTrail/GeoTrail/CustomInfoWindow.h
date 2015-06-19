//
//  CustomInfoWindow.h
//  GeoTrail
//
//  Created by Arthur Araujo on 6/19/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CustomInfoWindow : UIView

@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *viewsLabel;
@property (weak, nonatomic) IBOutlet UILabel *likesLabel;
@property (nonatomic) CLLocationCoordinate2D coordinate;

@end
