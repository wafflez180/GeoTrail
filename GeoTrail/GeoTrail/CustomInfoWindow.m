
//
//  CustomInfoWindow.m
//  GeoTrail
//
//  Created by Arthur Araujo on 6/19/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import "CustomInfoWindow.h"

@implementation CustomInfoWindow{
    BOOL dragging;
    int startLocY;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

/*
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    
    if (CGRectContainsPoint(_messageBox.frame, touchLocation)) {
        dragging = YES;
        startLocY = touchLocation.y;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    
    if (dragging) {
        int infoWindowY = touchLocation.y - startLocY;
        
        CGRect rect = self.frame;
        rect.origin.y += infoWindowY;

        
        self.superview.frame = rect;
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    
    if (CGRectContainsPoint(_messageBox.frame, touchLocation)) {
        dragging = false;
    }
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    
    if (CGRectContainsPoint(_messageBox.frame, touchLocation)) {
        dragging = false;
    }
}*/
@end
