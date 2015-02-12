//
//  UIAnimationDirector+Parser.h
//  mPaas
//
//  Created by bruiswang on 12-10-9.
//
//

#import <UIKit/UIKit.h>

@class UIADProgram;
@class UIADOperation;
@class UIADScene;

// 异常比较简单，只要告诉哪一行没编过去就行了
@interface UIADParserException : NSException
{
    int _errorLine;
    NSString* _errorInfo;
}

@property int errorLine;
@property (nonatomic, retain) NSString* errorInfo;

- (id)initWithLine:(int)errorLine;
- (id)withInformation:(NSString*)info;

@end

@interface UIADParser : NSObject
{
    NSString* _script;
    UIADProgram* _program;
}

@property (nonatomic, retain) UIADProgram* program;

- (id)initWithScript:(NSString*)script;
- (void)parse;

+ (UIADScene*)getDefaultScene;
+ (UIADOperation*)parseAssignmentOperationWithTarget:(UIView*)target script:(NSString*)script; // 解析一条赋值脚本并返回operation，对target进行操作的operation

@end
