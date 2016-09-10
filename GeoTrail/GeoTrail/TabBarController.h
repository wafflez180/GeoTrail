//
//  UITabBarController+TabBarController.h
//  GeoTrail
//
//  Created by Arthur Araujo on 2/28/16.
//  Copyright © 2016 Arthur Araujo. All rights reserved.
//

#import <UIKit/UIKit.h>

@import Firebase;

@interface TabBarController : UITabBarController

@property (strong,nonatomic) FIRUser *currentUser;
@property (strong,nonatomic) NSMutableArray *contactsArray;
@property (strong,nonatomic) NSMutableArray *contactIDsArray;
@property (strong,nonatomic) FIRStorage *firebaseRef;
@property (strong,nonatomic) NSNumber *currentHexLat;
@property (strong,nonatomic) NSNumber *currentHexLong;

@end
