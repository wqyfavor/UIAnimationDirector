//
//  TabViewController8.m
//  UIAnimationDirector
//
//  Created by shenmo on 14-6-4.
//  Copyright (c) 2014年 王 乾元. All rights reserved.
//

#import "TabViewController8.h"
#import "UIAnimationDirector.h"

@interface TabViewController8 ()
{
    UIAnimationDirector* _animationView;
}

@end

@implementation TabViewController8

- (id)init
{
    if (self = [super init])
    {
        self.title = @"Example8";
        DO_NOT_USE_IOS_7_LAYOUT(self)
    }
    
    return self;
}

- (void)dealloc
{
    [_animationView release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];
    
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script8" ofType:@"adscript"];
    _animationView = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationView.frame = self.view.bounds;
    _animationView.backgroundColor = [UIColor clearColor];
    [_animationView compile];
    [self.view addSubview:_animationView];
    [_animationView run:1.0];
}

@end
