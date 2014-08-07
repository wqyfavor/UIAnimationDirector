//
//  UIAnimationDirector.h
//  QQMSFContact
//
//  Created by bruiswang on 12-10-9.
//
//

#import <Foundation/Foundation.h>
#import "UIAnimationDirector+Operation.h"

@class UIAnimationDirector;

@protocol UIAnimationDirectorDelegate <NSObject>
@optional
- (void)didAnimationBegin:(UIAnimationDirector*)sender startTime:(NSTimeInterval)startTime timeRatio:(double)timeRatio;
- (void)didAnimationFinish:(UIAnimationDirector*)sender;          // 动画执行完，注意，这个回调只是动画时间线里的操作都被执行了，不代表动画真正执行完
- (void)didAnimationExecutionFail:(UIAnimationDirector*)sender;   // 动画执行失败
- (void)shouldRegisterExternalObjects:(UIAnimationDirector*)sender scene:(NSString*)scene;     // 注册外部对象到某个场景里
- (void)shouldRegisterMacros:(UIAnimationDirector*)sender;
- (void)didBeginDownloadingResources:(UIAnimationDirector*)sender;  // 运行前下载所需资源，上层程序可以接收此回调时开始转菊花
- (void)didEndDownloadingResources:(UIAnimationDirector*)sender success:(BOOL)success;      // 资源下载完成，可能成功或失败
- (void)didObjectEntityCreated:(UIAnimationDirector*)sender object:(UIADObject*)object;     // 脚本对象实例创建回调
- (void)marqueeTextConfigureLabel:(UIAnimationDirector*)sender label:(UIADMarqueeLabel*)label object:(UIADObject*)object newLine:(BOOL)newLine; // 滚动字幕，支持用户修改label的样式
@end

@interface UIAnimationDirector : UIView<UIADOperationDelegate, UIADProgramDelegate>
{
    BOOL _compiled;
    BOOL _running;
    BOOL _resourcesReady;
    
    double _speed;
    
    UIADProgram* _program;
    UIADOperationContext* _context;
    
    id<UIAnimationDirectorDelegate> _delegate;        // UIAnimationDirector的回调
    NSObject* _scriptInvokeResponder;
}

@property (nonatomic, readonly) UIADProgram* program;
@property (nonatomic, readonly) BOOL compiled;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) BOOL resourcesReady;
@property (nonatomic, readonly) double speed;
@property (nonatomic, readonly) UIADOperationContext* context;

@property (nonatomic, assign) id<UIAnimationDirectorDelegate> delegate;
@property (nonatomic, assign) NSObject* scriptInvokeResponder;

- (id)initWithScript:(NSString*)script;
- (id)initWithScriptFile:(NSString*)file;

- (void)loadScript:(NSString*)script;
- (void)loadScriptFromFile:(NSString*)file;
- (void)compile;
- (void)run:(double)speed; // 以speed速度运行动画，一般为1
- (void)stop;

// 对对象target执行一行脚本script，delegate是响应CAAnimation回调的对象
+ (BOOL)executeOperationWithTarget:(UIADEntity*)target script:(NSString*)script delegate:(id)delegate;

@end

@interface UIView (UIANIMATION_DIRECTOR)

+ (UIADScene*)getDefaultScene; // 用于执行UIView动画的默认的scene，可以用来设置图片资源的位置等

- (void)executeAnimationScript:(NSString*)script;
- (void)executeAnimationScript:(NSString*)script delegate:(id)delegate;

@end
