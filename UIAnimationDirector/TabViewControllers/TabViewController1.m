//
//  TabViewController1.m
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import "TabViewController1.h"
#import "UIAnimationDirector.h"

@implementation TabViewController1

- (id)init
{
    if (self = [super init])
    {
        self.title = @"Example1";
    }
    
    return self;
}

- (void)dealloc
{
    [_animationDirector release];
    [_btnRunDot5xSpeed release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];
    
    [_btnRunDot5xSpeed removeFromSuperview];
    [_btnRunDot5xSpeed release];
    _btnRunDot5xSpeed = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 130, 40)];
    [_btnRunDot5xSpeed setTitle:@"0.5倍速" forState:UIControlStateNormal];
    [_btnRunDot5xSpeed addTarget:self action:@selector(runDot5xSpeed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnRunDot5xSpeed];
    
    [_btnRun1xSpeed removeFromSuperview];
    [_btnRun1xSpeed release];
    _btnRun1xSpeed = [[UIButton alloc] initWithFrame:CGRectMake(100, 150, 130, 40)];
    [_btnRun1xSpeed setTitle:@"1.0倍速" forState:UIControlStateNormal];
    [_btnRun1xSpeed addTarget:self action:@selector(run1xSpeed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnRun1xSpeed];
    
    [_btnRun2xSpeed removeFromSuperview];
    [_btnRun2xSpeed release];
    _btnRun2xSpeed = [[UIButton alloc] initWithFrame:CGRectMake(100, 200, 130, 40)];
    [_btnRun2xSpeed setTitle:@"2.0倍速" forState:UIControlStateNormal];
    [_btnRun2xSpeed addTarget:self action:@selector(run2xSpeed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnRun2xSpeed];
}

- (void)runAnimation:(double)speed
{
    if (_animationDirector)
    {
        [_animationDirector stop];
        [_animationDirector removeFromSuperview];
        [_animationDirector release];
    }
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script1" ofType:@"adscript"];
    _animationDirector = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationDirector.frame = self.view.bounds;
    [_animationDirector compile];
    [self.view addSubview:_animationDirector];
    [self.view sendSubviewToBack:_animationDirector]; // 保证显示在按钮下面
    [_animationDirector run:speed];
}

- (void)runDot5xSpeed
{
    [self runAnimation:0.5];
}

- (void)run1xSpeed
{
    [self runAnimation:1.0];
}

- (void)run2xSpeed
{
    [self runAnimation:2.0];
}

@end