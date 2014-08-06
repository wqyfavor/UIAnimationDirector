//
//  TabViewController10.m
//  UIAnimationDirector
//
//  Created by shenmo on 14-8-6.
//  Copyright (c) 2014年 王 乾元. All rights reserved.
//

#import "TabViewController10.h"
#import "UIAnimationDirector.h"

@interface TabViewController10 () <UIAnimationDirectorDelegate>

@end

@implementation TabViewController10

- (void)dealloc
{
    [_animationDirector release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];
    
    if (_animationDirector)
    {
        [_animationDirector stop];
        [_animationDirector removeFromSuperview];
        [_animationDirector release];
    }
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script10" ofType:@"adscript"];
    _animationDirector = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationDirector.frame = self.view.bounds;
    _animationDirector.delegate = self;
    [_animationDirector compile];
    [self.view addSubview:_animationDirector];
    
    if (_animationDirector.resourcesReady)
        [_animationDirector run:1.0f];
}

- (void)didEndDownloadingResources:(UIAnimationDirector*)sender success:(BOOL)success
{
    if (success)
        [_animationDirector run:1.0f];
}

@end
