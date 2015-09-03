//
//  CustomInfoWindow.h
//  GeoTrail
//
//  Created by Arthur Araujo on 6/19/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CustomInfoWindow : UIView <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIVisualEffectView *imageBG;
@property (weak, nonatomic) IBOutlet UIImageView *messageBox;
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *usernameImageLabel;
@property (weak, nonatomic) IBOutlet UILabel *hexCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *viewsImageLabel;
@property (weak, nonatomic) IBOutlet UILabel *likesImageLabel;
@property (weak, nonatomic) IBOutlet UILabel *viewsLabel;
@property (weak, nonatomic) IBOutlet UILabel *likesLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (weak, nonatomic) IBOutlet UIImageView *image;

@end
