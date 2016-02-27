
//
//  CustomInfoWindow.m
//  GeoTrail
//
//  Created by Arthur Araujo on 6/19/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import "CustomInfoWindow.h"
#import "ViewController.h"

@implementation CustomInfoWindow{

}


- (IBAction)doubleTappedWindow:(id)sender {
//    NSLog(@"Double Tapped");
    [self.mainView likedPicture];
}

@end
