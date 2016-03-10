//
//  ViewController+Contact.m
//  GeoTrail
//
//  Created by Arthur Araujo on 2/28/16.
//  Copyright © 2016 Arthur Araujo. All rights reserved.
//

#import "Contact.h"

@implementation Contact{
    
}

- (void)viewDidLoad {
    
}
-(id)initWithName:(NSString *)name uid:(NSString *)uid unlockedHexsLatitude:(double)unlockedHexsLatitude unlockedHexsLongitude:(double)unlockedHexsLongitude{
    self = [super init];
    if (self) {
        self.userName = name;
        self.uid = uid;
        self.unlockedHexsLatitude = unlockedHexsLatitude;
        self.unlockedHexsLongitude = unlockedHexsLatitude;
    }
    return self;
}

@end
