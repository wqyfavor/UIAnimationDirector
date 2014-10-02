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
    UIImageView* _animateView;
    UIButton* _button;
}

@end

@implementation TabViewController9

- (void)dealloc
{
    [_imageView1 release];
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
    
    _button = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
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
    [_imageView1 executeAnimationScript:@"animate:(key:\"transform.rotation\", duration:1.5, by:2 * PI)"];
    [_button executeAnimationScript:@"animateGroup:(duration:0.15, animations:[(key:\"transform.scale\", values:[1, 1.1, 0.9, 1], keyTimes:[0, 0.6, 0.8, 1]), (key:\"opacity\", from:0, to:1)])"];

    [UIView getDefaultScene].resourceType = UIAD_RESOURCE_PATH;
    [UIView getDefaultScene].mainPath = @"res/resource/tmall/";
    [_animateView executeAnimationScript:@"movie:(images:[\"guide_410_cat2_2_%d\", [1, 5]], interval:0.14, repeat:1)"];
}

@end
