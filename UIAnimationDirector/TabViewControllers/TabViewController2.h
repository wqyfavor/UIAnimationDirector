//
//  TabViewController2.h
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIAnimationDirector.h"

@interface TabViewController2 : UIViewController<UIAnimationDirectorDelegate>
{
    UITextView* _textView;
    UIAnimationDirector* _animationDirector;
    NSTimeInterval _startTime;
    double _timeRatio;
}

@end
