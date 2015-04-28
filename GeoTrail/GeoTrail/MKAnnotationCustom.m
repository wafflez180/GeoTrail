//
//  MKAnnotationCustom.m
//  MapExample
//
//  Created by Harlan Kellaway on 11/5/14.
//  Copyright (c) 2014 ___HARLANKELLAWAY___. All rights reserved.
//

#import "MKAnnotationCustom.h"

@implementation MKAnnotationCustom

- (id)initWithName:(NSString *)name coordinate:(CLLocationCoordinate2D)coordinate
{
    self = [super init];
    
    if (self)
    {
        if ([name isKindOfClass:[NSString class]])
        {
            _title = name;
        }
        else
        {
            _title = @"No Name";
        }
        
        _coordinate = coordinate;
    }
    
    return self;
}

@end
