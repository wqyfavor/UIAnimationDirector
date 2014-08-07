//
//  TabViewController9.m
//  UIAnimationDirector
//
//  Created by shenmo on 14-8-6.
//  Copyright (c) 2014年 王 乾元. All rights reserved.
//

#import "TabViewController9.h"
#import "UIAnimationDirector.h"

@interface TabViewController9 ()
{
    UIImageView* _imageView1;
    UIImageView* _imageView2;
    UIImageView* _animateView;
    UIButton* _button;
}

@end

@implementation TabViewController9

- (void)dealloc
{
    [_imageView1 release];
    [_imageView2 release];
    [_button release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];
    
    _imageView1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"btn_video.png"]];
    _imageView1.frame = CGRectMake(50, 50, _imageView1.image.size.width, _imageView1.image.size.height);
    [self.view addSubview:_imageView1];
    
    _imageView2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"btn_video.png"]];
    _imageView2.frame = CGRectMake(150, 50, _imageView1.image.size.width, _imageView1.image.size.height);
    [self.view addSubview:_imageView2];
    
    _button = [UIButton buttonWithType:UIButtonTypeCustom];
    [_button setImage:[UIImage imageNamed:@"btn_nor.png"] forState:UIControlStateNormal];
    [_button setImage:[UIImage imageNamed:@"btn_press.png"] forState:UIControlStateHighlighted];
    _button.frame = CGRectMake((self.view.bounds.size.width - 100) / 2, 200, 100, 30);
    [_button addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_button];
    
    _animateView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_animateView];
}

- (void)onButtonClick:(id)sender
{
    [UIView getDefaultScene].resourceType = UIAD_RESOURCE_MAIN_BUNDLE;
    [_imageView1 executeAnimationScript:@"animate:(key:\"transform.rotation\", duration:1.5, by:2 * PI)"];
    [_imageView2 executeAnimationScript:@"transit:(image:\"btn_lbs.png\", duration:0.7, transition:\"flipLeft\")"];
    
    [_button executeAnimationScript:@"animateGroup:(duration:0.15, animations:[(key:\"transform.scale\", values:[1, 1.1, 0.9, 1], keyTimes:[0, 0.6, 0.8, 1]), (key:\"opacity\", from:0, to:1)])"];
    
/*
    CABasicAnimation* ani1 = [[CABasicAnimation alloc] init];
    ani1.keyPath = @"transform.rotation";
    ani1.duration = 1.5;
    ani1.byValue = [NSNumber numberWithDouble:2 * M_PI];
    [_imageView1.layer addAnimation:ani1 forKey:@"ani1"];
    [ani1 release];
    
    //
    NSInteger transition = UIViewAnimationTransitionFlipFromLeft;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationTransition:transition forView:_imageView2 cache:YES];
    [UIView setAnimationDuration:0.7];
    _imageView2.layer.contents = (id)[UIImage imageNamed:@"btn_lbs.png"].CGImage;
    [UIView commitAnimations];
    
    //
    CAAnimationGroup* group = [[CAAnimationGroup alloc] init];
    group.duration = 0.15;
    
    CAKeyframeAnimation* keyAni = [[CAKeyframeAnimation alloc] init];
    keyAni.keyPath = @"transform.scale";
    keyAni.values = @[@1, @1.1, @0.9, @1];
    keyAni.keyTimes = @[@0, @0.6, @0.8, @1];
    
    CABasicAnimation* ani2 = [[CABasicAnimation alloc] init];
    ani2.keyPath = @"opacity";
    ani2.fromValue = [NSNumber numberWithDouble:0.0f];
    ani2.toValue = [NSNumber numberWithDouble:1.0f];
    group.animations = @[keyAni, ani2];
    [_button.layer addAnimation:group forKey:@"groupAni"];
    [group release];
    [keyAni release];
    [ani2 release];
 */
    
    [UIView getDefaultScene].resourceType = UIAD_RESOURCE_PATH;
    [UIView getDefaultScene].mainPath = @"res/resource/tmall/";
    [_animateView executeAnimationScript:@"movie:(images:[\"guide_410_cat2_2_%d\", [1, 5]], interval:0.14, repeat:1)"];
}

@end
