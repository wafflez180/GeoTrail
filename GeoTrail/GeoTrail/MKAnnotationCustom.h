//
//  MKAnnotationCustom.h
//  MapExample
//
//  Created by Harlan Kellaway on 11/5/14.
//  Copyright (c) 2014 ___HARLANKELLAWAY___. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MKAnnotationCustom : NSObject <MKAnnotation>

// MKAnnotation properties
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *subtitle;

- (id)initWithName:(NSString*)name coordinate:(CLLocationCoordinate2D)coordinate;

@end
