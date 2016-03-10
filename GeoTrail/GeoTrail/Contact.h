//
//  ViewController+Contact.h
//  GeoTrail
//
//  Created by Arthur Araujo on 2/28/16.
//  Copyright © 2016 Arthur Araujo. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

@interface Contact : NSObject

-(id)initWithName:(NSString *)name uid:(NSString *)uid unlockedHexsLatitude:(double)unlockedHexsLatitude unlockedHexsLongitude:(double)unlockedHexsLongitude;

@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *uid;
@property (nonatomic) double unlockedHexsLatitude;
@property (nonatomic) double unlockedHexsLongitude;

@end