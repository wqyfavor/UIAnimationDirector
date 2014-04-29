//
//  TabViewController3.m
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import "TabViewController3.h"

@implementation TabViewController3

- (id)init
{
    if (self = [super init])
    {
        self.title = @"Example3";
    }
    
    return self;
}

- (void)dealloc
{
    [_snowCountLabel release];
    [_more release];
    [_less release];
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
    
    _snowCount = 100; // 主要用来控制下雪速度的，并不是真正最后雪花数目
    
    [_snowCountLabel removeFromSuperview];
    [_snowCountLabel release];
    _snowCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 3, 100, 20)];
    _snowCountLabel.font = [UIFont systemFontOfSize:11];
    _snowCountLabel.backgroundColor = [UIColor clearColor];
    _snowCountLabel.textColor = [UIColor redColor];
    [self.view addSubview:_snowCountLabel];
    
    [_more removeFromSuperview];
    [_more release];
    _more = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _more.frame = CGRectMake(5, 30, 30, 30);
    [_more setTitle:@"+" forState:UIControlStateNormal];
    [_more setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_more addTarget:self action:@selector(more) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_more];
    
    [_less removeFromSuperview];
    [_less release];
    _less = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    _less.frame = CGRectMake(5, 70, 30, 30);
    [_less setTitle:@"-" forState:UIControlStateNormal];
    [_less setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_less addTarget:self action:@selector(less) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_less];

    [_animationDirector removeFromSuperview];
    [_animationDirector release];
    NSString* file = [[NSBundle mainBundle] pathForResource:@"Script3" ofType:@"adscript"];
    _animationDirector = [[UIAnimationDirector alloc] initWithScriptFile:file];
    _animationDirector.frame = self.view.bounds;
    _animationDirector.delegate = self;
    _animationDirector.scriptInvokeResponder = self; // 设置此属性，脚本里的调用才会关联到这个对象上
    [_animationDirector compile];
    [self.view addSubview:_animationDirector];
    [self.view sendSubviewToBack:_animationDirector]; // 保证显示在按钮下面
    [_animationDirector run:1.0];
}

- (void)more
{
    if (_snowCount < 200)
    {
        _snowCount += 20;
    }
    
    [_animationDirector.program registerMacro:@"MAX_SNOW" value:[NSNumber numberWithDouble:_snowCount]];
}

- (void)less
{
    if (_snowCount > 20)
    {
        _snowCount -= 20;
    }
    
    [_animationDirector.program registerMacro:@"MAX_SNOW" value:[NSNumber numberWithDouble:_snowCount]];
}

- (void)shouldRegisterMacros:(UIAnimationDirector*)sender
{
    [_animationDirector.program registerMacro:@"MAX_SNOW" value:[NSNumber numberWithDouble:_snowCount]];
}

- (void)printSnowCount:(NSArray*)parameters
{
    UIADPropertyValue* value = [parameters objectAtIndex:0];
    int param = lrint([value.numberValue doubleValue]);
    _snowCountLabel.text = [NSString stringWithFormat:@"total:%d", param];
}

@end
