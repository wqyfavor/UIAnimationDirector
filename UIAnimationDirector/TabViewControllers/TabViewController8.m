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
    int _phase;
    UIScrollView* _contentScrollView;
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
    
    UISwipeGestureRecognizer* swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipe:)];
    swipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipe];
    
    _contentScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _contentScrollView.userInteractionEnabled = NO;
    _contentScrollView.showsHorizontalScrollIndicator = NO;
    _contentScrollView.showsVerticalScrollIndicator = NO;
    _contentScrollView.bounces = NO;
    _contentScrollView.pagingEnabled = YES;
    _contentScrollView.backgroundColor = [UIColor clearColor];
    [_contentScrollView setContentSize:CGSizeMake(self.view.bounds.size.width * 3, self.view.bounds.size.height)];
    [self.view addSubview:_contentScrollView];
    UIImageView* imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"example8_bg.jpg"]];
    imageView.frame = CGRectMake(0, 0, self.view.bounds.size.width * 3, self.view.bounds.size.height);
    [_contentScrollView addSubview:imageView];
    [_contentScrollView setContentSize:CGSizeMake(self.view.bounds.size.width * 3, self.view.bounds.size.height)];
    
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script8" ofType:@"adscript"];
    _animationView = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationView.scriptInvokeResponder = self;
    _animationView.frame = self.view.bounds;
    _animationView.backgroundColor = [UIColor clearColor];
    [_animationView compile];
    [self.view addSubview:_animationView];
    [_animationView run:1.0];
}

- (void)onSwipe:(UISwipeGestureRecognizer*)gesture
{
    if (gesture.state == UIGestureRecognizerStateRecognized)
    {
        if (_phase == 0)
        {
            _phase = 1;
            [UIView animateWithDuration:0.7 animations:^{
                _contentScrollView.contentOffset = CGPointMake(_contentScrollView.bounds.size.width, 0);
            }];
            [_animationView.program executeEvent:@"frame2" arguments:nil context:nil];
        }
        else if (_phase == 1)
        {
            _phase = 2;
            [UIView animateWithDuration:1.3 animations:^{
                _contentScrollView.contentOffset = CGPointMake(_contentScrollView.bounds.size.width * 2, 0);
            }];
            [_animationView.program executeEvent:@"frame3" arguments:nil context:nil];
        }
    }
}

- (void)scrollOut
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"exit" message:@"exit" delegate:nil cancelButtonTitle:@"cancel" otherButtonTitles:nil];
    [alert show];
}

@end
