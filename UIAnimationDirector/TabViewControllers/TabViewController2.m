//
//  TabViewController2.m
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import "TabViewController2.h"

#import <mach/mach_time.h>

@implementation TabViewController2

- (id)init
{
    if (self = [super init])
    {
        self.title = @"Example2";
    }
    
    return self;
}

- (void)dealloc
{
    [_textView release];
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
    
    [_textView removeFromSuperview];
    [_textView release];
    _textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height / 2)];
    _textView.editable = NO;
    [self.view addSubview:_textView];
    
    [_animationDirector stop];
    [_animationDirector removeFromSuperview];
    [_animationDirector release];
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script2" ofType:@"adscript"];
    _animationDirector = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationDirector.frame = CGRectMake(0, _textView.frame.size.height, _textView.frame.size.width, self.view.bounds.size.height - _textView.frame.size.height);
    _animationDirector.delegate = self;
    _animationDirector.scriptInvokeResponder = self; // 设置此属性，脚本里的调用才会关联到这个对象上
    [_animationDirector compile];
    [self.view addSubview:_animationDirector];
    [self.view sendSubviewToBack:_animationDirector]; // 保证显示在按钮下面
    [_animationDirector run:1.0];
}

- (void)didAnimationBegin:(UIAnimationDirector*)sender startTime:(NSTimeInterval)startTime timeRatio:(double)timeRatio
{
    _startTime = startTime;
    _timeRatio = timeRatio;
}

- (void)triggerEvent:(NSArray*)parameters
{
    UIADPropertyValue* value = [parameters objectAtIndex:0];
    double param = [value.numberValue doubleValue];
    NSTimeInterval now = mach_absolute_time() * _timeRatio - _startTime;
    _textView.text = [NSString stringWithFormat:@"%@\n%f@%f", _textView.text, param, now];
}

@end
