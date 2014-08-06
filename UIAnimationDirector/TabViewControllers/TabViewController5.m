//
//  TabViewController5.h
//  UIAnimationDirector
//
//  Created by 王 乾元 on 5/15/13.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import "TabViewController5.h"
#import "UIAnimationDirector.h"

#define IS_IPHONE           (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_5         (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 568.0f)

@interface TabViewController5()
{
    UIScrollView* _backgroundScrollView;
    UIScrollView* _contentScrollView;
    UIAnimationDirector* _animationView;
    BOOL _switchedView;
}

@end

@implementation TabViewController5

- (void)dealloc
{
    [_backgroundScrollView release];
    [_contentScrollView release];
    [_animationView release];
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
    
    self.view.backgroundColor = [UIColor clearColor];
    
    UIImageView* backgroundImage = nil;
    if (IS_IPHONE_5)
    {
        UIImage* image = [UIImage imageNamed:@"guide_bg_1136.jpg"];
        backgroundImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, self.view.bounds.size.height)];
        backgroundImage.image = image;
    }
    else
    {
        UIImage* image = [UIImage imageNamed:@"guide_bg_960.jpg"];
        backgroundImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, self.view.bounds.size.height)];
        backgroundImage.image = image;
    }
    
    [_backgroundScrollView removeFromSuperview];
    [_backgroundScrollView release];
    _backgroundScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _backgroundScrollView.showsHorizontalScrollIndicator = NO;
    _backgroundScrollView.showsVerticalScrollIndicator = NO;
    _backgroundScrollView.bounces = NO;
    [_backgroundScrollView addSubview:backgroundImage];
    [_backgroundScrollView setContentSize:CGSizeMake(backgroundImage.frame.size.width, self.view.bounds.size.height)];
    [self.view addSubview:_backgroundScrollView];
    
    [_contentScrollView removeFromSuperview];
    [_contentScrollView release];
    _contentScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _contentScrollView.showsHorizontalScrollIndicator = NO;
    _contentScrollView.showsVerticalScrollIndicator = NO;
    _contentScrollView.bounces = NO;
    _contentScrollView.pagingEnabled = YES;
    _contentScrollView.backgroundColor = [UIColor clearColor];
    [_contentScrollView setContentSize:CGSizeMake(self.view.bounds.size.width * 2, self.view.bounds.size.height)];
    _contentScrollView.delegate = self;
    [self.view addSubview:_contentScrollView];
    
    [_animationView stop];
    [_animationView removeFromSuperview];
    [_animationView release];
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script5" ofType:@"adscript"];
    _animationView = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationView.frame = self.view.bounds;
    _animationView.backgroundColor = [UIColor clearColor];
    _animationView.scriptInvokeResponder = self;
    [_animationView compile];
    [_contentScrollView addSubview:_animationView];
    [_animationView run:1.0];
    
    [self performSelector:@selector(startFlashIcons) withObject:nil afterDelay:1.5f];
}

- (void)startFlashIcons
{
    UIADPropertyValue* param = [[UIADPropertyValue alloc] init];
    param.type = UIAD_PROPERTY_VALUE_NUMBER;
    param.numberValue = [NSNumber numberWithDouble:1.0f];
    [_animationView.program executeEvent:@"flashIcon" arguments:[NSArray arrayWithObject:param] context:nil]; // 调用脚本里的方法
}

- (void)scroll
{
    [UIView animateWithDuration:0.5f
                     animations:^ {
                          _contentScrollView.contentOffset = CGPointMake(self.view.frame.size.width, 0);
                     }
                     completion:^(BOOL finished) {
                         [self scrollViewDidEndDecelerating:_contentScrollView];
                     }];
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // 让背景跟着动
    _backgroundScrollView.contentOffset = CGPointMake((_backgroundScrollView.contentSize.width - _backgroundScrollView.frame.size.width) * (scrollView.contentOffset.x / scrollView.frame.size.width), 0);
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (!_switchedView && _contentScrollView.contentOffset.x > _contentScrollView.frame.size.width / 2)
    {        
        [_animationView.program executeEvent:@"switchedView" arguments:nil context:nil]; // 调用脚本里的方法
        _switchedView = YES;
        
        UISwipeGestureRecognizer* swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(enterFollowRecommend)];
        swipe.direction = UISwipeGestureRecognizerDirectionUp;
        [_animationView addGestureRecognizer:swipe];
    }
}

@end
