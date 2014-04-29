//
//  TabViewController4.m
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import "TabViewController4.h"
#import "UIAnimationDirector.h"

@implementation TabViewController4

- (id)init
{
    if (self = [super init])
    {
        self.title = @"Example4";
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
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script4" ofType:@"adscript"];
    _animationDirector = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationDirector.frame = self.view.bounds;
    [_animationDirector compile];
    [self.view addSubview:_animationDirector];
    [self.view sendSubviewToBack:_animationDirector]; // 保证显示在按钮下面
    [_animationDirector run:1.0];
}

@end
