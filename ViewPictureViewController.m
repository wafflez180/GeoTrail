//
//  ViewPictureViewController.m
//  GeoTrail
//
//  Created by Arthur Araujo on 5/23/15.
//  Copyright (c) 2015 Arthur Araujo. All rights reserved.
//

#import "ViewPictureViewController.h"

@interface ViewPictureViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *picture;

@end

@implementation ViewPictureViewController{
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UISwipeGestureRecognizer *up = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(PerformAction:)];
    up.direction = UISwipeGestureRecognizerDirectionUp ;
    [self.view addGestureRecognizer:up];
}
- (IBAction)tappedGoback:(id)sender {
    [self goBackToMain];
}

-(void)PerformAction:(UISwipeGestureRecognizer *)sender {
    if(sender.direction == UISwipeGestureRecognizerDirectionUp) {
        NSLog(@"UP GESTURE");
        // Perform your code here
        [self goBackToMain];
    }
}

-(void)goBackToMain{
    [self performSegueWithIdentifier:@"goBackToMain" sender:self];
}

- (IBAction)tappedImage:(id)sender {
    NSLog(@"Swiped");
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setPicture: (UIImage *)image{
    [_picture setImage:image];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
