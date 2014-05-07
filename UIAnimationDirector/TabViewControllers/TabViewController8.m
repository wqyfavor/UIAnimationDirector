//
//  TabViewController8.m
//  UIAnimationDirector
//
//  Created by shenmo on 14-5-4.
//  Copyright (c) 2014年 王 乾元. All rights reserved.
//

#import "TabViewController8.h"
#import "UIAnimationDirector.h"

@interface TabViewController8 ()
{
    UIScrollView* _contentView;
    UIAnimationDirector* _animationView;
    UIAnimationDirector* _animationView2;
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
    [_contentView release];
    [_animationView release];
    [super dealloc];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor blackColor];
    
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script8" ofType:@"adscript"];
    _animationView = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationView.frame = self.view.bounds;
    _animationView.backgroundColor = [UIColor clearColor];
    [_animationView compile];
    [self.view addSubview:_animationView];
    [_animationView run:1.0];
    
    _contentView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _contentView.showsHorizontalScrollIndicator = YES;
    _contentView.showsVerticalScrollIndicator = NO;
    _contentView.bounces = YES;
    _contentView.pagingEnabled = YES;
    _contentView.backgroundColor = [UIColor clearColor];
    [_contentView setContentSize:CGSizeMake(self.view.bounds.size.width * 5, self.view.bounds.size.height)];
    _contentView.delegate = self;
    [self.view addSubview:_contentView];
    
//    NSString* file2 = [[NSBundle mainBundle] pathForResource:@"Script7_2" ofType:@"adscript"];
//    _animationView2 = [[UIAnimationDirector alloc] initWithScriptFile:file2];
//    _animationView2.frame = CGRectMake(0, self.view.bounds.size.height - 70, self.view.bounds.size.width, 20);
//    _animationView2.backgroundColor = [UIColor clearColor];
//    [_animationView2 compile];
//    [self.view addSubview:_animationView2];
//    [_animationView2 run:1.0];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    double progress = scrollView.contentOffset.x / (scrollView.contentSize.width - scrollView.frame.size.width);
    if (progress < 0)
        progress = 0;
    if (progress > 1)
        progress = 1;
    
    [_animationView.program setTimeOffset:progress * 4 forObjectsByKey:@"move"];
    [_animationView2.program setTimeOffset:progress * 4 forObjectsByKey:@"move"];
}

@end
