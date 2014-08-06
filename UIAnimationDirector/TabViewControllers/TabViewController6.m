//
//  TabViewController6.m
//  UIAnimationDirector
//
//  Created by shenme on 13-7-30.
//  Copyright (c) 2013年 王 乾元. All rights reserved.
//

#import "TabViewController6.h"

@interface TabViewController6 ()

@end

@implementation TabViewController6

- (id)init
{
    if (self = [super init])
    {
        DO_NOT_USE_IOS_7_LAYOUT(self)
    }
    
    return self;
}

- (void)dealloc
{
    [_animationDirector release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_animationDirector stop];
    [_animationDirector removeFromSuperview];
    [_animationDirector release];
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script6" ofType:@"adscript"];
    _animationDirector = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationDirector.delegate = self;
    _animationDirector.frame = self.view.bounds;
    [_animationDirector compile];
    [self.view addSubview:_animationDirector];
    [_animationDirector run:1.0];
}

- (void)marqueeTextConfigureLabel:(UIAnimationDirector*)sender label:(UIADMarqueeLabel*)label object:(UIADObject*)object newLine:(BOOL)newLine
{
    label.textColor = [UIColor whiteColor];
    if (newLine)
    {
        label.font = [UIFont boldSystemFontOfSize:14.0f];
    }
    else
    {
        label.font = [UIFont systemFontOfSize:14.0f];
    }
}

@end