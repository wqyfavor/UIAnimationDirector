//
//  TabViewController3.h
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIAnimationDirector.h"

@interface TabViewController3 : UIViewController<UIAnimationDirectorDelegate>
{
    int _snowCount;
    UIAnimationDirector* _animationDirector;
    UIButton* _more;
    UIButton* _less;
    UILabel* _snowCountLabel;
}

@end
