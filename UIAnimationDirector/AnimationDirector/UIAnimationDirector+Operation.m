//
//  UIAnimationDirector+Operation.m
//  QQMSFContact
//
//  Created by bruiswang on 12-10-10.
//
//

#import "UIAnimationDirector+Operation.h"
#import "UIADExtensions.h"

#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach/mach_time.h>

void setLastError(UIADOperationContext* context, NSString* error)
{
    [context.lastError setString:error];
}

void clearLastError(UIADOperationContext* context)
{
    [context.lastError setString:@""];
}

#pragma mark UIADOperationContext

@implementation UIADOperationContext

@synthesize now = _now;
@synthesize evaluateAllowObject = _evaluateAllowObject;
@synthesize operationWithTarget = _operationWithTarget;
@synthesize animationDelegate = _animationDelegate;
@synthesize speed = _speed;
@synthesize mainView = _mainView;
@synthesize program = _program;
@synthesize scene = _scene;
@synthesize invokeResponder = _invokeResponder;
@synthesize operation = _operation;
@synthesize functionEvent = _functionEvent;
@synthesize animation = _animation;
@synthesize startEvent = _startEvent;
@synthesize stopEvent = _stopEvent;
@synthesize startEventArgs = _startEventArgs;
@synthesize stopEventArgs = _stopEventArgs;
@synthesize scriptFilePath = _scriptFilePath;
@synthesize lastError = _lastError;

- (void)dealloc
{
    [_startEventArgs release];
    [_stopEventArgs release];
    [_forLoopVariables release];
    [_scriptFilePath release];
    [_lastError release];
    [super dealloc];
}

@end

#pragma mark -

@class UIADAnimationDelegate;

@interface UIADProgram(PRIVATE)
- (BOOL)executeEvent2:(UIADFunctionEvent*)event arguments:(NSArray*)arguments context:(UIADOperationContext*)context;
- (BOOL)executeEvent:(NSString *)name arguments:(NSArray *)arguments delegate:(UIADAnimationDelegate*)delegate context:(UIADOperationContext*)context;
@end

// 用于CAAnimation的delegate回调。每个动画创建一个
@interface UIADAnimationDelegate : NSObject
{
    UIADProgram* _program;
    NSString* _animationKey;
    
    NSString* _startEvent;
    NSString* _stopEvent;
    NSArray* _startEventArgs;
    NSArray* _stopEventArgs;
    
    UIADOperationContext* _context;
}

@property (nonatomic, assign) UIADProgram* program;
@property (nonatomic, retain) NSString* animationKey;
@property (nonatomic, retain) NSString* startEvent;
@property (nonatomic, retain) NSString* stopEvent;
@property (nonatomic, retain) NSArray* startEventArgs;
@property (nonatomic, retain) NSArray* stopEventArgs;
@property (nonatomic, assign) UIADOperationContext* context;

@end

@implementation UIADAnimationDelegate

@synthesize program = _program;
@synthesize animationKey = _animationKey;
@synthesize startEvent = _startEvent;
@synthesize stopEvent = _stopEvent;
@synthesize startEventArgs = _startEventArgs;
@synthesize stopEventArgs = _stopEventArgs;
@synthesize context = _context;

- (void)dealloc
{
    [_animationKey release];
    [_startEvent release];
    [_stopEvent release];
    [_startEventArgs release];
    [_stopEventArgs release];
    [super dealloc];
}

#pragma mark CAAnimationDelegate

- (void)animationDidStart:(CAAnimation *)anim
{
    if (_program && _startEvent)
    {
        [_program executeEvent:_startEvent arguments:_startEventArgs context:_context];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (_program && _stopEvent)
    {
        [_program executeEvent:_stopEvent arguments:_stopEventArgs delegate:self context:_context];
    }
}

@end

@interface UIADTapGestureDelegate : NSObject
{
    UIADProgram* _program;
    NSString* _tapEvent;
    
    NSArray* _arguments;
    UIADOperationContext* _context;
}

@property (nonatomic, assign) UIADProgram* program;
@property (nonatomic, retain) NSString* tapEvent;
@property (nonatomic, retain) NSArray* arguments;
@property (nonatomic, assign) UIADOperationContext* context;

@end

@implementation UIADTapGestureDelegate

@synthesize program = _program;
@synthesize tapEvent = _tapEvent;
@synthesize arguments = _arguments;
@synthesize context = _context;

- (void)dealloc
{
    [_tapEvent release];
    [_arguments release];
    [super dealloc];
}

- (void)onTap:(UIGestureRecognizer *)gestureRecognizer
{
    if (_program && _tapEvent && gestureRecognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_program executeEvent:_tapEvent arguments:_arguments context:_context];
    }
}

@end

@class UIADResourceDownloader;

@interface UIADProgram(Private)

+ (NSString *)cachePathForUrl:(NSString*)url;
- (void)downloadResourceFailed:(UIADResourceDownloader*)downloader;
- (void)downloadResourceSucceeded:(UIADResourceDownloader*)downloader;

- (UIADAnimationDelegate*)addAnimationEvents:(NSString*)animation context:(UIADOperationContext*)context;
- (UIADTapGestureDelegate*)addTapGestureEvent:(NSString*)event arguments:(NSArray*)arguments entity:(UIADEntity*)entity context:(UIADOperationContext*)context;

@end

@interface UIADResourceDownloader : NSObject
{
    BOOL _succeeded;
    UIADProgram* _delegate;
    NSString* _url;
    NSURLConnection* _connection;
    NSMutableData* _data;
}

@property (nonatomic, readonly) BOOL succeeded;
@property (nonatomic, retain) NSString* url;
@property (nonatomic, assign) UIADProgram* delegate;

- (id)initWithUrl:(NSString*)url;
- (BOOL)start;
- (void)cancel;

@end

@implementation UIADResourceDownloader

@synthesize succeeded = _succeeded;
@synthesize url = _url;
@synthesize delegate = _delegate;

- (id)initWithUrl:(NSString*)url
{
    if (self = [super init])
    {
        _url = [url retain];
    }
    return self;
}

- (void)dealloc
{
    [_url release];
    if (_connection)
    {
        [_connection cancel];
        [_connection release];
    }
    [_data release];
    [super dealloc];
}

- (BOOL)start
{
    NSURLRequest* request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:_url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    [request release];
    
    if (_connection)
    {
        _data = [[NSMutableData alloc] initWithCapacity:50 * 1024];
        if (_data)
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    else
    {
        return NO;
    }
}

- (void)cancel
{
    [_connection cancel];
    [_connection release];
    _connection = nil;
    [_data release];
    _data = nil;
}

- (void)respondFailure
{
    [_connection release];
    _connection = nil;
    [_data release];
    _data = nil;
    [_delegate downloadResourceFailed:self];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass: [NSHTTPURLResponse class]])
    {
        NSInteger statusCode = [(NSHTTPURLResponse*) response statusCode];
        if (statusCode != 200)
        {
            [self respondFailure];
        }
    }
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
    [_connection release];
    _connection = nil;
    
    // 将图片写到文件里
    BOOL result = [_data writeToFile:[UIADProgram cachePathForUrl:_url] atomically:NO];
    [_data release];
    _data = nil;
    if (result)
    {
        _succeeded = YES;
        [_delegate downloadResourceSucceeded:self];
    }
    else
    {
        [_delegate downloadResourceFailed:self];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self respondFailure];
}

@end

@implementation UIADProgram

@synthesize status = _status;
@synthesize infiniteRunloop = _infiniteRunloop;
@synthesize timeLines = _timeLines;
@synthesize durativeTimeLines = _durativeTimeLines;
@synthesize functionEvents = _functionEvents;
@synthesize localVariables = _localVariables;
@synthesize booleanEvaluators = _booleanEvaluators;
@synthesize forLoopEvaluators = _forLoopEvaluators;
@synthesize scenes = _scenes;
@synthesize animationDelegates = _animationDelegates;
@synthesize macros = _macros;
@synthesize consts = _consts;
@synthesize delegate = _delegate;

- (id)init
{
    if (self = [super init])
    {
        _timeLines = [[NSMutableArray alloc] initWithCapacity:50];
        _durativeTimeLines = [[NSMutableArray alloc] initWithCapacity:10];
        _functionEvents = [[NSMutableDictionary alloc] initWithCapacity:10];
        _localVariables = [[NSMutableDictionary alloc] initWithCapacity:20];
        _booleanEvaluators = [[NSMutableArray alloc] initWithCapacity:10];
        _forLoopEvaluators = [[NSMutableArray alloc] initWithCapacity:10];
        _scenes = [[NSMutableArray alloc] initWithCapacity:3];
        _animationDelegates = [[NSMutableArray alloc] initWithCapacity:20];
        _eventPipelines = [[NSMutableArray alloc] initWithCapacity:10];
        _gestureDelegates = [[NSMutableArray alloc] initWithCapacity:20];
        _macros = [[NSMutableDictionary alloc] initWithCapacity:20];
        _consts = [[NSMutableDictionary alloc] initWithCapacity:20];
        _manually = [[NSMutableDictionary alloc] initWithCapacity:20];
        _downloadResources = [[NSMutableArray alloc] initWithCapacity:20];
    }
    
    return self;
}

- (void)dealloc
{
    [self reset];
    
    [_timeLines release];
    [_durativeTimeLines release];
    [_functionEvents release];
    [_localVariables release];
    [_booleanEvaluators release];
    [_forLoopEvaluators release];
    [_scenes release];
    [_eventPipelines release];
    
    for (UIADAnimationDelegate* delegate in _animationDelegates)
    {
        delegate.program = nil;
    }
    [_animationDelegates release];
    [_gestureDelegates release];
    [_macros release];
    [_consts release];
    [_manually release];
    [_downloadResources release];
    [self cancelDownloads];
    [_downloaders release];
    
    [super dealloc];
}

- (void)addScene:(UIADScene*)scene
{
    [_scenes addObject:scene];
}

- (UIADTimeLine*)getTimeLine:(NSTimeInterval)time
{
    for (UIADTimeLine* timeLine in _timeLines)
    {
        if (fabs(timeLine.time - time) <= UIAD_TIME_LINE_PRECISION)
        {
            return timeLine;
        }
    }
    
    // 没找到
    UIADTimeLine* newTimeLine = [[UIADTimeLine alloc] initWithTime:time];
    if ([_timeLines count] == 0 || (time >= ((UIADTimeLine*)[_timeLines lastObject]).time))
    {
        // 直接添加到最后
        [_timeLines addObject:newTimeLine];
    }
    else
    {
        // 找位置insert
        for (int i = 0; i < [_timeLines count]; i ++)
        {
            if (time < ((UIADTimeLine*)[_timeLines objectAtIndex:i]).time)
            {
                [_timeLines insertObject:newTimeLine atIndex:i];
                break;
            }
        }
    }
    return [newTimeLine autorelease];
}

- (UIADTimeLine*)getDurativeTimeLine:(NSTimeInterval)time duration:(NSTimeInterval)duration
{
    UIADTimeLine* newTimeLine = [[UIADTimeLine alloc] initWithTime:time duration:duration runtime:YES];
    [_durativeTimeLines addObject:newTimeLine];
    _activeDurativeTimeLine ++;
    return [newTimeLine autorelease];
}

NSInteger compareTimeLine(id t1, id t2, void* context)
{
    UIADTimeLine* timeLine1 = (UIADTimeLine*)t1;
    UIADTimeLine* timeLine2 = (UIADTimeLine*)t2;
    return timeLine1.time <= timeLine2.time ? -1 : 1;
}

- (void)sort
{
    // 不需要排序了，创建timeLine里已经做了插入排序
    //[_timeLines sortUsingFunction:compareTimeLine context:NULL];
}

- (void)reset
{
    _current = 0;
    _status = UIAD_PROGRAM_STATUS_IDLE;
    _finishBufferTime = 0;
    
    for (UIADScene* scene in _scenes)
    {
        [scene reset];
    }
    
    for (UIADTimeLine* timeLine in _timeLines)
    {
        [timeLine reset];
    }
    
    // 把运行时生成的durative time line移除。比如object的movie方法会生成运行时的time line
    for (int i = [_durativeTimeLines count] - 1; i >= 0; i --)
    {
        UIADTimeLine* timeLine = [_durativeTimeLines objectAtIndex:i];
        if (timeLine.runtime)
        {
            // 这个time line是运行时产生的，将其remove掉
            [_durativeTimeLines removeObjectAtIndex:i];
        }
    }
    for (UIADTimeLine* timeLine in _durativeTimeLines)
    {
        [timeLine reset];
    }
    _activeDurativeTimeLine = [_durativeTimeLines count];
    
    // 如果某个timeLine里的operations为空了，将其移除，产生空timeline的原因是运行时添加了事件，上面对每个timeLine进行reset把这些事件移除了
    for (int i = [_timeLines count] - 1; i >= 0; i --)
    {
        UIADTimeLine* timeLine = [_timeLines objectAtIndex:i];
        if ([timeLine.operations count] == 0)
        {
            [_timeLines removeObjectAtIndex:i];
        }
    }
    
    for (UIADBooleanEvaluator* evaluator in _booleanEvaluators)
    {
        [evaluator reset];
    }
    
    [_localVariables removeAllObjects];
    
    // 由于动画代理事件是运行时解析出来的，所以reset应该清空
    for (UIADAnimationDelegate* delegate in _animationDelegates)
    {
        delegate.program = nil; // 之前的动画可能还在执行，因为CAAnimation.delegate会对对象进行retain，所以不用担心野指针，只要让之前的UIADAnimationDelegate不处理即可
    }
    [_animationDelegates removeAllObjects];
    
    [_eventPipelines removeAllObjects];
    
    [_gestureDelegates removeAllObjects];
    
    [_macros removeAllObjects];
    
    [_manually removeAllObjects];
}

- (BOOL)finished:(NSTimeInterval)now
{
    BOOL finished = !_infiniteRunloop && (_current >= [_timeLines count] && [_eventPipelines count] == 0) && (_activeDurativeTimeLine == 0) && ([_animationDelegates count] == 0);
    if (finished)
    {
        if (_status == UIAD_PROGRAM_STATUS_RUNNING)
        {
            // 加一个时间缓冲
            _finishBufferTime = now;
            _status = UIAD_PROGRAM_STATUS_FINISH_BUFFER;
            return NO;
        }
        else if (_status == UIAD_PROGRAM_STATUS_FINISH_BUFFER)
        {
            if (now - _finishBufferTime > UIAD_FINISH_BUFFER_TIME)
            {
                _status = UIAD_PROGRAM_STATUS_FINISHED;
            }
            return NO;
        }
    }
    
    return finished;
}

- (UIADScene*)sceneWithName:(NSString*)name
{
    if (name && [name length] > 0)
    {
        for (UIADScene* scene in _scenes)
        {
            if ([scene.name isEqualToString:name])
            {
                return scene;
            }
        }
    }
    
    return nil;
}

- (BOOL)addFunctionEvent:(UIADFunctionEvent*)event
{
    if ([_functionEvents objectForKey:event.name])
    {
        return NO;
    }
    
    [_functionEvents setObject:event forKey:event.name];
    return YES;
}

- (UIADBooleanEvaluator*)addBooleanEvaluator:(UIADBooleanEvaluator*)superEvaluator expression:(NSString*)expression referenceObject:(UIADReferenceObject*)referenceObject
{
    UIADBooleanEvaluator* evaluator = [[UIADBooleanEvaluator alloc] initWithIndex:[_booleanEvaluators count] superIndex:(superEvaluator ? superEvaluator.index : UIAD_NO_PRECONDITION) expression:expression referenceObject:referenceObject];
    [_booleanEvaluators addObject:evaluator];
    return [evaluator autorelease];
}

- (UIADBooleanEvaluator*)getBooleanEvaluator:(int)index
{
    if (index >= 0 && index < [_booleanEvaluators count])
    {
        return [_booleanEvaluators objectAtIndex:index];
    }
    return nil;
}

- (UIADForLoopEvaluator*)addForLoopEvaluator:(UIADPropertyValue*)arguments referenceObject:(UIADReferenceObject*)referenceObject
{
    UIADForLoopEvaluator* evaluator = [[UIADForLoopEvaluator alloc] initWithArguments:arguments referenceObject:referenceObject];
    [_forLoopEvaluators addObject:evaluator];
    return [evaluator autorelease];
}

- (void)setLocalVariable:(NSString*)name value:(id)value
{
    [_localVariables setObject:value forKey:name];
}

- (id)getLocalVariable:(NSString*)name
{
    return [_localVariables objectForKey:name];
}

- (UIADAnimationDelegate*)addAnimationEvents:(NSString*)animation context:(UIADOperationContext*)context
{
    UIADAnimationDelegate* delegate = [[UIADAnimationDelegate alloc] init];
    delegate.context = context;
    
    if (context.startEvent)
    {
        if ([_functionEvents objectForKey:context.startEvent.stringValue] == nil)
        {
            [delegate release];
            return nil;
        }
        
        delegate.startEvent = context.startEvent.stringValue;
        delegate.startEventArgs = context.startEventArgs;
    }
    
    if (context.stopEvent)
    {
        if ([_functionEvents objectForKey:context.stopEvent.stringValue] == nil)
        {
            [delegate release];
            return nil;
        }
        
        delegate.stopEvent = context.stopEvent.stringValue;
        delegate.stopEventArgs = context.stopEventArgs;
    }
    
    delegate.program = self;
    delegate.animationKey = animation;
    [_animationDelegates addObject:delegate];
    return [delegate autorelease];
}

- (UIADTapGestureDelegate*)addTapGestureEvent:(NSString*)event arguments:(NSArray*)arguments entity:(UIADEntity*)entity context:(UIADOperationContext*)context
{
    if ([_functionEvents objectForKey:event] == nil)
    {
        return nil;
    }
    
    UIADTapGestureDelegate* delegate = [[UIADTapGestureDelegate alloc] init];
    delegate.program = self;
    delegate.tapEvent = event;
    delegate.arguments = arguments;
    delegate.context = context;
    [_gestureDelegates addObject:delegate];
    
    // 移除之前的recognizers
    while ([entity.gestureRecognizers count] > 0)
    {
        [entity removeGestureRecognizer:[entity.gestureRecognizers lastObject]];
    }
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:delegate action:@selector(onTap:)];
    [entity addGestureRecognizer:tap];
    [tap release];
    return [delegate autorelease];
}

- (NSArray*)getExecutableLines:(NSTimeInterval)time modification:(NSTimeInterval*)modification
{
    if (_status == UIAD_PROGRAM_STATUS_IDLE)
    {
        _status = UIAD_PROGRAM_STATUS_RUNNING;
    }
    
    NSMutableArray* executableLines = [[NSMutableArray alloc] initWithCapacity:10];
    for (int i = _current; i < [_timeLines count]; i ++)
    {
        UIADTimeLine* line = [_timeLines objectAtIndex:i];
        
        if (line.time <= time)
        {
            if ([executableLines count] == 0 && modification)
            {
                // 修正主timer时间
                *modification = time - line.time; // 把主timer时间调慢modification
            }
            
            [executableLines addObject:line];
        }
        else
        {
            break;
        }
    }
    _current += [executableLines count];
    
    // durative time lines
    for (UIADTimeLine* line in _durativeTimeLines)
    {
        if (!line.inactive && (line.time <= time))
        {
            if (line.time + line.duration >= time)
            {
                line.localTime = time - line.time;
                [executableLines addObject:line];
            }
            else
            {
                // 为保证最后一帧也被执行
                line.localTime = line.duration;
                line.inactive = YES;
                _activeDurativeTimeLine --;
                [executableLines addObject:line];
            }
        }
    }
    
    // 搜pipelines
    if ([_eventPipelines count] > 0)
    {
        NSArray* copied = [NSArray arrayWithArray:_eventPipelines];
        for (UIADFunctionEvent* event in copied)
        {
            if (event.status == UIAD_FUNCTION_EVENT_IDLE)
            {
                // idle的事件，就启动它
                [event trigger:time];
            }

            NSArray* operations = [event getExecutableLines:time];
            [executableLines addObjectsFromArray:operations];
            
            [event finished:time]; // 调用一下，如果结束了，会置state
        }
        
        // 移除已经执行完的事件
        for (int i = [_eventPipelines count] - 1; i >= 0; i --)
        {
            if (((UIADFunctionEvent*)[_eventPipelines objectAtIndex:i]).status == UIAD_FUNCTION_EVENT_FINISHED)
            {
                [_eventPipelines removeObjectAtIndex:i];
            }
        }
    }
    
    return [executableLines autorelease];
}

- (BOOL)executeEvent:(NSString*)name arguments:(NSArray*)arguments context:(UIADOperationContext*)context
{
    @synchronized(self)
    {
        // 把event的操作添加到主timeLine里
        UIADFunctionEvent* event = [_functionEvents objectForKey:name];
        if (event)
        {
            // 把event拷贝一份，添加到_eventPipelines里
            UIADFunctionEvent* copied = [event duplicateEvent];
            copied.runtimeArguments = arguments;
            if (![copied decideSubVariableTimeEventTime:context])
            {
                return NO;
            }
            [_eventPipelines addObject:copied];
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)executeEvent2:(UIADFunctionEvent*)event arguments:(NSArray*)arguments context:(UIADOperationContext*)context
{
    UIADFunctionEvent* copied = [event duplicateEvent];
    copied.runtimeArguments = arguments;
    if (![copied decideSubVariableTimeEventTime:context])
    {
        return NO;
    }
    [_eventPipelines addObject:copied];
    return YES;
}

- (BOOL)executeEvent:(NSString *)name arguments:(NSArray*)arguments delegate:(UIADAnimationDelegate*)delegate context:(UIADOperationContext*)context
{
    [_animationDelegates removeObject:delegate];
    
    @synchronized(self)
    {
        // 把event的操作添加到主timeLine里
        UIADFunctionEvent* event = [_functionEvents objectForKey:name];
        if (event)
        {
            // 把event拷贝一份，添加到_eventPipelines里
            UIADFunctionEvent* copied = [event duplicateEvent];
            copied.runtimeArguments = arguments;
            if (![copied decideSubVariableTimeEventTime:context])
            {
                return NO;
            }
            [_eventPipelines addObject:copied];
            return YES;
        }
    }
    
    return NO;
}

- (void)registerMacro:(NSString*)name value:(id)value
{
    if (value)
    {
        [_macros setObject:value forKey:name];
    }
}

- (BOOL)registerConst:(NSString*)name value:(id)value
{
    if (value && [_consts objectForKey:name] == nil)
    {
        [_consts setObject:value forKey:name];
        return YES;
    }
    return NO;
}

- (void)addManuallyManipulatedObject:(UIADObject*)object forKey:(NSString*)key
{
    object.entity.layer.speed = 0;
    
    NSMutableArray* array = [_manually objectForKey:key];
    if (array == nil)
    {
        array = [NSMutableArray arrayWithCapacity:5];
        [_manually setObject:array forKey:key];
    }
    if ([array indexOfObject:object] == NSNotFound)
    {
        [array addObject:object];
    }
}

- (void)setTimeOffset:(CFTimeInterval)value forObjectsByKey:(NSString*)key
{
    NSMutableArray* array = [_manually objectForKey:key];
    if (array)
    {
        for (UIADObject* object in array)
        {
            object.entity.layer.timeOffset = value;
        }
    }
}

//- (BOOL)registerExternalObject:(UIView*)object name:(NSString*)name scene:(NSString*)scene
//{
//    // 找到scene
//    UIADScene* sceneInst = [self sceneWithName:scene];
//    if (sceneInst)
//    {
//        UIADObject* adObj = [sceneInst objectWithNameNoCreate:name];
//        if (adObj != nil)
//        {
//            [adObj replaceEntity:object];
//            return YES;
//        }
//    }
//    
//    return NO;
//}

+ (NSString *)cachePathForUrl:(NSString*)url
{
    const char *str = [url UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString* filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString* path = [[paths objectAtIndex:0] stringByAppendingString:@"/UIAnimationDirector/"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    return [path stringByAppendingString:filename];
}

- (void)downloadResourceFailed:(UIADResourceDownloader*)downloader
{
    [self cancelDownloads];
    if (_delegate && [_delegate respondsToSelector:@selector(didEndDownloadingResources:success:)])
    {
        [_delegate didEndDownloadingResources:self success:NO];
    }
}

- (void)downloadResourceSucceeded:(UIADResourceDownloader*)downloader
{
    // 检查是否都已经成功
    for (UIADResourceDownloader* downloader in _downloaders)
    {
        if (!downloader.succeeded)
        {
            return;
        }
    }
    
    // 都已经成功
    [_downloaders release];
    _downloaders = nil;
    if (_delegate && [_delegate respondsToSelector:@selector(didEndDownloadingResources:success:)])
    {
        [_delegate didEndDownloadingResources:self success:YES];
    }
}

- (void)verifyImageFromURL:(NSString*)location
{
    if ([location hasPrefix:@"http://"])
    {
        NSString* cachePath = [UIADProgram cachePathForUrl:location];
        if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath])
        {
            [_downloadResources addObject:location];
        }
    }
}

- (void)cancelDownloads
{
    for (UIADResourceDownloader* downloader in _downloaders)
    {
        [downloader cancel];
    }
    [_downloaders removeAllObjects];
}

- (BOOL)isResourcesReady
{
    if ([_downloadResources count])
    {
        if (_downloaders)
        {
            [self cancelDownloads];
            [_downloaders release];
        }
        _downloaders = [[NSMutableArray alloc] initWithCapacity:[_downloadResources count]];
        
        for (NSString* url in _downloadResources)
        {
            UIADResourceDownloader* downloader = [[UIADResourceDownloader alloc] initWithUrl:url];
            downloader.delegate = self;
            [_downloaders addObject:downloader];
            [downloader release];
        }
        
        BOOL success = YES;
        for (UIADResourceDownloader* downloader in _downloaders)
        {
            if (![downloader start])
            {
                success = NO;
                break;
            }
        }
        
        if (!success)
        {
            [self downloadResourceFailed:nil];
        }
        else if (_delegate && [_delegate respondsToSelector:@selector(didBeginDownloadingResources:)])
        {
            [_delegate didBeginDownloadingResources:self];
        }
        
        return NO;
    }
    
    return YES;
}

@end

@implementation UIADTimeLine

@synthesize inactive = _inactive;
@synthesize runtime = _runtime;
@synthesize time = _time;
@synthesize duration = _duration;
@synthesize localTime = _localTime;
@synthesize operations = _operations;
@synthesize functionEvent = _functionEvent;

- (id)initWithTime:(NSTimeInterval)time
{
    if (self = [super init])
    {
        _time = time;
        _operations = [[NSMutableArray alloc] initWithCapacity:30];
    }
    
    return self;
}

- (id)initWithTime:(NSTimeInterval)time capacity:(int)capacity
{
    if (self = [super init])
    {
        _time = time;
        _operations = [[NSMutableArray alloc] initWithCapacity:capacity];
    }
    
    return self;
}

- (id)initWithTime:(NSTimeInterval)time duration:(NSTimeInterval)duration runtime:(BOOL)runtime
{
    if (self = [super init])
    {
        _time = time;
        _duration = duration;
        _runtime = runtime;
        _operations = [[NSMutableArray alloc] initWithCapacity:5];
    }
    return self;
}

- (void)dealloc
{
    for (UIADOperation* op in _operations)
    {
        op.invalid = YES;
        op.timeLine = nil;
    }
    [_operations release];
    [super dealloc];
}

- (UIADOperation*)addOperation:(int)type parameters:(NSDictionary*)parameters line:(int)line runtime:(BOOL)runtime precondition:(int)precondition
{
    UIADOperation* operation = [[UIADOperation alloc] initWithType:type parameters:parameters timeLine:self line:line runtime:runtime precondition:precondition];
    [_operations addObject:operation];
    return [operation autorelease];
}

- (void)reset
{
    _inactive = NO;
    _localTime = 0.0f;
    for (int i = [_operations count] - 1; i >= 0; i --)
    {
        UIADOperation* operation = [_operations objectAtIndex:i];
        if (operation.runtime)
        {
            // 这个操作是运行时产生的，将其remove掉
            [_operations removeObjectAtIndex:i];
        }
    }
}

- (UIADTimeLine*)duplicateTimeLine
{
    UIADTimeLine* result = [[UIADTimeLine alloc] initWithTime:_time capacity:[_operations count]];
    result.functionEvent = _functionEvent;
    result.duration = _duration;
    for (UIADOperation* op in _operations)
    {
        UIADOperation* dupOp = [op duplicateOperation];
        dupOp.timeLine = result;
        [result.operations addObject:dupOp];
    }
    return [result autorelease];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"UIADTimeLine at time:%f", _time];
}

@end

@implementation UIADOperation

@synthesize line = _line;
@synthesize runtime = _runtime;
@synthesize invalid = _invalid;
@synthesize type = _type;
@synthesize parameters = _parameters;
@synthesize timeLine = _timeLine;
@synthesize precondition = _precondition;
@synthesize forLoopConditions = _forLoopConditions;

- (id)initWithType:(int)type parameters:(NSDictionary*)parameters timeLine:(UIADTimeLine*)timeLine line:(int)line runtime:(BOOL)runtime precondition:(int)precondition
{
    if (self = [super init])
    {
        _line = line;
        _runtime = runtime;
        _type = type;
        _parameters = [parameters retain];
        _timeLine = timeLine; // assign，不retain
        _precondition = precondition;
    }
    
    return self;
}

- (void)dealloc
{
    [_parameters release];
    [_forLoopConditions release];
    [super dealloc];
}

- (UIADScene*)getScene
{
    return [_parameters objectForKey:@"scene"];
}

- (BOOL)executeOnce:(UIADOperationContext*)context
{
    if (_type == UIAD_OPERATION_SCENE)
    {
        UIADObjectBase* object = [_parameters objectForKey:@"object"];
        
        if (object && [object isKindOfClass:[UIADScene class]])
        {
            UIADScene* scene = (UIADScene*)object;
            if (scene.entity == nil)
            {
                if (context.functionEvent)
                {
                    setLastError(context, @"Cannot initialize scene in an event function.");
                    return NO;
                }
                
                scene.entity = [UIADImageEntity createDefaultEntity];
                scene.entity.frame = context.mainView.bounds; // scene默认充满整个容器
                [context.mainView addSubview:scene.entity];
                [context.mainView didSceneEntityCreated:scene];
            }
            
            return YES;
        }
    }
    else if (_type == UIAD_OPERATION_ASSIGN)
    {
        context.scene = [_parameters objectForKey:@"scene"];
        UIADObjectBase* object = [_parameters objectForKey:@"object"];
        UIADObjectBase* destObject = [object getObject:context];
        if (destObject)
        {
            NSString* name = [_parameters objectForKey:@"name"];
            UIADPropertyValue* value = [_parameters objectForKey:@"value"];
            return [destObject setPropertyValue:name value:value context:context];
        }
    }
    else if (_type == UIAD_OPERATION_ASSIGN_VAR)
    {
        context.scene = [_parameters objectForKey:@"scene"];
        UIADVariableAssignment* assignment = [_parameters objectForKey:@"assignment"];
        return [assignment performAssignment:context];
    }
    else if (_type == UIAD_OPERATION_VARIABLE_EVENT)
    {
        context.scene = [_parameters objectForKey:@"scene"];
        UIADFunctionEvent* event = [_parameters objectForKey:@"subEvent"];
        NSArray* arguments = [_parameters objectForKey:@"arguments"];
        return [context.program executeEvent2:event arguments:arguments context:context];
    }
    
    return NO;
}

- (BOOL)execute:(UIADOperationContext*)context
{
    if (_invalid)
    {
        return NO;
    }
    
    context.operation = self;
    context.animation = nil;
    context.stopEvent = nil;
    context.startEvent = nil;
    context.startEventArgs = nil;
    context.stopEventArgs = nil;
    context.forLoopVariables = nil;
    
    if (_timeLine)
    {
        context.functionEvent = _timeLine.functionEvent;
    }
    else
    {
        context.functionEvent = nil;
    }
    
    // 判断是否要执行
    if (_precondition != UIAD_NO_PRECONDITION)
    {
        BOOL precondition;
        UIADBooleanEvaluator* evaluator = context.functionEvent ? [context.functionEvent getBooleanEvaluator:_precondition] : [context.program getBooleanEvaluator:_precondition];
        
        if (evaluator == nil || ![evaluator getValue:context pValue:&precondition])
        {
            return NO;
        }
        
        if (!precondition)
        {
            // 如果先决条件都不成立，自己不需要执行了
            return YES;
        }
    }
    
    if (_forLoopConditions && [_forLoopConditions count] > 0)
    {
        // 调用第一个循环，如果有多重循环，会依次调用
        context.forLoopVariables = [NSMutableDictionary dictionaryWithCapacity:[_forLoopConditions count]];
        UIADForLoopEvaluator* first = [_forLoopConditions objectAtIndex:0];
        return [first execute:self context:context];
    }
    else
    {
        return [self executeOnce:context];
    }
}

- (UIADOperation*)duplicateOperation
{
    UIADOperation* duplicated = [[[UIADOperation alloc] initWithType:_type parameters:_parameters timeLine:_timeLine line:_line runtime:_runtime precondition:_precondition] autorelease];
    duplicated.forLoopConditions = _forLoopConditions;
    return duplicated;
}

@end

#pragma mark -

@implementation UIView(UIADEntity)

+ (UIADEntity*)createDefaultEntity
{
    UIADEntity* entity = [[UIADEntity alloc] initWithFrame:CGRectZero];
    entity.userInteractionEnabled = YES;
    entity.backgroundColor = [UIColor clearColor];
    return [entity autorelease];
}

@end

@implementation UIADImageEntity

@synthesize image = _image;

+ (UIADImageEntity*)createDefaultEntity
{
    UIADImageEntity* entity = [[UIADImageEntity alloc] initWithFrame:CGRectZero];
    entity.userInteractionEnabled = YES;
    entity.backgroundColor = [UIColor clearColor];
    return [entity autorelease];
}

- (void)dealloc
{
    [_image release];
    [super dealloc];
}

- (void)setImage:(UIImage *)image
{
    [_image release];
    _image = [image retain];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    if (_image)
    {
        [_image drawInRect:rect];
    }
}

@end

@implementation UIADMarqueeLabel

@synthesize marqueeIndex = _marqueeIndex;
@synthesize minAlpha = _minAlpha;

- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    
    CGRect frame = self.frame;
    self.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, [font lineHeight]);
}

@end

@implementation UIADObjectBase

- (BOOL)isValidPropertyName:(NSString*)str
{
    return NO;
}

- (BOOL)isValidPropertyValueForProperty:(NSString*)name value:(UIADPropertyValue*)value
{
    return NO;
}

- (BOOL)setPropertyValue:(NSString*)name value:(UIADPropertyValue*)value context:(UIADOperationContext*)context
{
    return NO;
}

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    return self;
}

@end

@implementation UIADTimeObject

@synthesize absoluteTime = _absoluteTime;

@end

@implementation UIADScene

@synthesize name = _name;
@synthesize objects = _objects;
@synthesize entity = _entity;
@synthesize resourceType = _resourceType;
@synthesize mainPath = _mainPath;

@synthesize defaultFillMode = _defaultFillMode;
@synthesize defaultTimingFunction = _defaultTimingFunction;
@synthesize defaultRemovedOnCompletion = _defaultRemovedOnCompletion;
@synthesize defaultDuration = _defaultDuration;

- (id)initWithAbsoluteTime:(NSTimeInterval)absoluteTime name:(NSString*)name
{
    if (self = [super init])
    {
        _name = [name retain];
        _resourceType = UIAD_RESOURCE_MAIN_BUNDLE; // 默认是main bundle里
        _absoluteTime = absoluteTime;
        _objects = [[NSMutableDictionary alloc] initWithCapacity:10];
        _defaultFillMode = [kCAFillModeRemoved copy]; // iOS SDK default value
        _defaultTimingFunction = [kCAMediaTimingFunctionDefault copy];
        _defaultRemovedOnCompletion = YES; // iOS SDK default value
        _defaultDuration = 0.25;
        _defaultImageScale = 1.0f;
    }
    
    return self;
}

- (void)dealloc
{
    [_name release];
    [_objects release];
    [_entity release];
    [_mainPath release];
    [_defaultFillMode release];
    [_defaultTimingFunction release];
    [super dealloc];
}

- (UIADObject*)objectWithName:(NSString*)name
{
    UIADObject* object = [_objects objectForKey:name];
    if (object == nil)
    {
        object = [[[UIADObject alloc] initWithName:name scene:self] autorelease];
        [_objects setObject:object forKey:name];
    }
    
    return object;
}

- (UIADObject*)objectWithNameNoCreate:(NSString *)name
{
    return [_objects objectForKey:name];
}

- (UIImage*)getImageFile:(NSString*)fileName context:(UIADOperationContext*)context
{
    UIImage* image = nil;
    if ([fileName hasPrefix:@"http://"])
    {
        image = [UIImage imageWithContentsOfFile:[UIADProgram cachePathForUrl:fileName]];
    }
    else if ([fileName hasPrefix:@"./"])
    {
        if (context.scriptFilePath)
        {
            image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@%@", context.scriptFilePath, [fileName substringFromIndex:2]]];
        }
    }
    else if (_resourceType == UIAD_RESOURCE_MAIN_BUNDLE)
    {
        image = [UIImage imageNamed:fileName];
    }
    else if (_resourceType == UIAD_RESOURCE_PATH)
    {
        NSString* fullName = [NSString stringWithFormat:@"%@%@", _mainPath, fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullName])
        {
            image = [UIImage imageWithContentsOfFile:fullName];
        }
        else
        {
            fullName = [NSString stringWithFormat:@"%@%@.png", _mainPath, fileName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullName])
            {
                image = [UIImage imageWithContentsOfFile:fullName];
            }
            else
            {
                fullName = [NSString stringWithFormat:@"%@%@@2x.png", _mainPath, fileName];
                if ([[NSFileManager defaultManager] fileExistsAtPath:fullName])
                {
                    image = [UIImage imageWithContentsOfFile:fullName];
                }
            }
        }
    }
    else if (_resourceType == UIAD_RESOURCE_ABSOLUTE)
    {
        image = [UIImage imageWithContentsOfFile:fileName];
    }
    
    return image;
}

- (BOOL)getImageCapParameters:(UIADPropertyValue*)capValue capX:(NSInteger*)capX capY:(NSInteger*)capY object:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (capValue.type == UIAD_PROPERTY_VALUE_ARRAY && [capValue.arrayValue count] == 2)
    {
        UIADPropertyValue* firstValue = [capValue.arrayValue objectAtIndex:0];
        UIADPropertyValue* secondValue = [capValue.arrayValue objectAtIndex:1];
        if (firstValue.type == UIAD_PROPERTY_VALUE_NUMBER && secondValue.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            NSNumber* evalFirst = [firstValue evaluateNumberWithObject:object context:context];
            NSNumber* evalSecond = [secondValue evaluateNumberWithObject:object context:context];
            if (evalFirst && evalSecond)
            {
                if (capX && capY)
                {
                    *capX = [evalFirst integerValue];
                    *capY = [evalSecond integerValue];
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

- (void)reset
{
    NSArray* allObjects = [_objects allValues];
    for (int i = [allObjects count] - 1; i >= 0; i --)
    {
        UIADObject* object = [allObjects objectAtIndex:i];
        if (object.external)
        {
            // 外部物体删除
            [_objects removeObjectForKey:object.name];
        }
        else
        {
            [object reset];
        }
    }
    
    [_entity removeFromSuperview];
    [_entity release];
    _entity = nil;
}

- (BOOL)isValidPropertyName:(NSString*)str
{
    return [str isEqualToString:@"image"] || [str isEqualToString:@"backgroundColor"] || [str isEqualToString:@"resources"] ||
        [str isEqualToString:@"bringToFront"] || [str isEqualToString:@"sendToBack"] || [str isEqualToString:@"hide"] || [str isEqualToString:@"show"] ||
        [str isEqualToString:@"setDefaultFillMode"] || [str isEqualToString:@"setDefaultRemovedOnCompletion"] || [str isEqualToString:@"setDefaultTimingFunction"] ||
        [str isEqualToString:@"setDefaultDuration"] || [str isEqualToString:@"invoke"] || [str isEqualToString:@"event"] || [str isEqualToString:@"setInfiniteRunloop"] || [str isEqualToString:@"tapEvent"] || [str isEqualToString:@"setDefaultImageScale"];
}

- (BOOL)isValidPropertyValueForProperty:(NSString*)name value:(UIADPropertyValue*)value
{
    return ([name isEqualToString:@"image"] && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_ARRAY || value.type == UIAD_PROPERTY_VALUE_DICTIONARY)) ||
        ([name isEqualToString:@"backgroundColor"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
        ([name isEqualToString:@"resources"] && value.type == UIAD_PROPERTY_VALUE_STRING) ||
        ([name isEqualToString:@"bringToFront"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
        ([name isEqualToString:@"sendToBack"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
        ([name isEqualToString:@"hide"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
        ([name isEqualToString:@"show"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
        ([name isEqualToString:@"setDefaultFillMode"] && value.type == UIAD_PROPERTY_VALUE_STRING) ||
        ([name isEqualToString:@"setDefaultRemovedOnCompletion"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
        ([name isEqualToString:@"setDefaultTimingFunction"] && value.type == UIAD_PROPERTY_VALUE_STRING) ||
        ([name isEqualToString:@"setDefaultDuration"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
        (([name isEqualToString:@"invoke"] || [name isEqualToString:@"event"]) && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_ARRAY)) ||
        ([name isEqualToString:@"setInfiniteRunloop"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
        ([name isEqualToString:@"tapEvent"] && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_ARRAY)) ||
        ([name isEqualToString:@"setDefaultImageScale"] && value.type == UIAD_PROPERTY_VALUE_NUMBER);
}

- (BOOL)setPropertyValue:(NSString*)name value:(UIADPropertyValue*)value context:(UIADOperationContext*)context
{
    if (_entity == nil)
    {
        setLastError(context, @"Instance for scene not created.");
        return NO;
    }
    
    if ([name isEqualToString:@"resources"])
    {
        if ([value.stringValue isEqualToString:@"main bundle"])
        {
            _resourceType = UIAD_RESOURCE_MAIN_BUNDLE;
        }
        else if ([value.stringValue isEqualToString:@"absolute"])
        {
            _resourceType = UIAD_RESOURCE_ABSOLUTE;
        }
        else if ([value.stringValue hasPrefix:@"doc/"])
        {
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString* docPath = [paths objectAtIndex:0];
            
            _resourceType = UIAD_RESOURCE_PATH;
            _mainPath = [[docPath stringByAppendingFormat:@"/%@", [value.stringValue substringFromIndex:4]] retain];
        }
        else if ([value.stringValue hasPrefix:@"lib/"])
        {
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
            NSString* libPath = [paths objectAtIndex:0];
            
            _resourceType = UIAD_RESOURCE_PATH;
            _mainPath = [[libPath stringByAppendingFormat:@"/%@", [value.stringValue substringFromIndex:4]] retain];
        }
        else if ([value.stringValue hasPrefix:@"res/"])
        {
            _resourceType = UIAD_RESOURCE_PATH;
            _mainPath = [[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], [value.stringValue substringFromIndex:4]] retain];
        }
        else
        {
            _resourceType = UIAD_RESOURCE_PATH;
            _mainPath = [value.stringValue retain];
        }
        
        return YES;
    }
    else if ([name isEqualToString:@"image"])
    {
        if ([_entity isKindOfClass:[UIADImageEntity class]])
        {
            BOOL valid = NO, stretch = NO;
            NSInteger stretchCapX, stretchCapY;
            NSString* imageName = nil;
            
            if (value.type == UIAD_PROPERTY_VALUE_DICTIONARY)
            {
                stretch = YES;
                UIADPropertyValue* imageNameValue = [value.dictionaryValue objectForKey:@"image"];
                imageName = [imageNameValue evaluateFormatAsStringWithObject:nil context:context];
                
                UIADPropertyValue* stretchCapValue = [value.dictionaryValue objectForKey:@"stretchCap"];
                valid = [self getImageCapParameters:stretchCapValue capX:&stretchCapX capY:&stretchCapY object:nil context:context];
            }
            else
            {
                valid = YES;
                imageName = [value evaluateFormatAsStringWithObject:nil context:context];
            }

            if (imageName && valid)
            {
                UIImage* image = [self getImageFile:imageName context:context];
                if (image)
                {
                    if (stretch)
                    {
                        ((UIADImageEntity*)_entity).image = [image stretchableImageWithLeftCapWidth:stretchCapX topCapHeight:stretchCapY];
                    }
                    else
                    {
                        ((UIADImageEntity*)_entity).image = image;
                    }
                    return YES;
                }
            }
        }
    }
    else if ([name isEqualToString:@"backgroundColor"])
    {
        UIColor* color = [value evaluateArrayAsColorWithObject:nil context:context];
        if (color == nil)
        {
            return NO;
        }
        _entity.backgroundColor = color;
        return YES;
    }
    else if ([name isEqualToString:@"bringToFront"])
    {
        [_entity.superview bringSubviewToFront:_entity];
        return YES;
    }
    else if ([name isEqualToString:@"sendToBack"])
    {
        [_entity.superview sendSubviewToBack:_entity];
        return YES;
    }
    else if ([name isEqualToString:@"hide"])
    {
        _entity.hidden = YES;
        return YES;
    }
    else if ([name isEqualToString:@"show"])
    {
        _entity.hidden = NO;
        return YES;
    }
    else if ([name isEqualToString:@"setDefaultFillMode"])
    {
        [_defaultFillMode release];
        _defaultFillMode = [value.stringValue retain];
        return YES;
    }
    else if ([name isEqualToString:@"setDefaultRemovedOnCompletion"])
    {
        if ([value.numberValue doubleValue] == 1.0f)
        {
            _defaultRemovedOnCompletion = YES;
        }
        else if ([value.numberValue doubleValue] == 0.0f)
        {
            _defaultRemovedOnCompletion = NO;
        }
        else
        {
            return NO;
        }
        
        return YES;
    }
    else if ([name isEqualToString:@"setDefaultTimingFunction"])
    {
        [_defaultTimingFunction release];
        _defaultTimingFunction = [value.stringValue retain];
        return YES;
    }
    else if ([name isEqualToString:@"setDefaultDuration"])
    {
        _defaultDuration = [[value evaluateNumberWithObject:nil context:context] doubleValue];
        return YES;
    }
    else if ([name isEqualToString:@"invoke"])
    {
        // 调用外部方法
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            SEL selector = NSSelectorFromString(value.stringValue);
            if (context.invokeResponder && [context.invokeResponder respondsToSelector:selector])
            {
                [context.invokeResponder performSelector:selector];
                return YES;
            }
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
        {
            UIADPropertyValue* selectorName = [value.arrayValue objectAtIndex:0];
            UIADPropertyValue* parameter = [value.arrayValue objectAtIndex:1];
            if (selectorName.type == UIAD_PROPERTY_VALUE_STRING && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:", selectorName.stringValue]);
                if (context.invokeResponder && [context.invokeResponder respondsToSelector:selector])
                {
                    NSArray* arguments = [parameter evaluateArrayAsParameterArray:nil context:context];
                    [context.invokeResponder performSelector:selector withObject:arguments];
                    return YES;
                }
            }
        }
    }
    else if ([name isEqualToString:@"event"])
    {
        // 调用内部方法
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            return [context.program executeEvent:value.stringValue arguments:nil context:context];
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
        {
            UIADPropertyValue* eventName = [value.arrayValue objectAtIndex:0];
            UIADPropertyValue* eventArguments = [value.arrayValue objectAtIndex:1];
            if (eventName.type == UIAD_PROPERTY_VALUE_STRING && eventArguments.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                NSArray* arguments = [eventArguments evaluateArrayAsParameterArray:nil context:context];
                if (arguments)
                {
                    return [context.program executeEvent:eventName.stringValue arguments:arguments context:context];
                }
            }
        }
    }
    else if ([name isEqualToString:@"setInfiniteRunloop"])
    {
        if ([value.numberValue doubleValue] == 1.0f)
        {
            context.program.infiniteRunloop = YES;
            return YES;
        }
        else if ([value.numberValue doubleValue] == 0.0f)
        {
            context.program.infiniteRunloop = NO;
            return YES;
        }
    }
    else if ([name isEqualToString:@"tapEvent"])
    {
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            if ([context.program addTapGestureEvent:value.stringValue arguments:nil entity:_entity context:context])
            {
                return YES;
            }
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
        {
            UIADPropertyValue* eventName = [value.arrayValue objectAtIndex:0];
            UIADPropertyValue* eventParameters = [value.arrayValue objectAtIndex:1];
            if (eventName.type == UIAD_PROPERTY_VALUE_STRING && eventParameters.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                NSArray* arguments = [eventParameters evaluateArrayAsParameterArray:nil context:context];
                if (arguments)
                {
                    if ([context.program addTapGestureEvent:eventName.stringValue arguments:arguments entity:_entity context:context])
                    {
                        return YES;
                    }
                }
            }
        }
    }
    else if ([name isEqualToString:@"setDefaultImageScale"])
    {
        _defaultImageScale = [[value evaluateNumberWithObject:nil context:context] doubleValue];
        if (_defaultImageScale <= 0.0f)
        {
            _defaultImageScale = 1.0f;
        }
        return YES;
    }

    return NO;
}

@end

@implementation UIADEvent

@synthesize time = _time;

- (id)initWithTime:(NSTimeInterval)time absoluteTime:(NSTimeInterval)absoluteTime
{
    if (self = [super init])
    {
        _time = time;
        _absoluteTime = absoluteTime;
    }
    
    return self;
}

@end

@implementation UIADFunctionEvent

@synthesize variableTimeEventLine = _variableTimeEventLine;
@synthesize variableTimeEvent = _variableTimeEvent;
@synthesize status = _status;
@synthesize current = _current;
@synthesize name = _name;
@synthesize timeLines = _timeLines;
@synthesize durativeTimeLines = _durativeTimeLines;
@synthesize argumentIndex = _argumentIndex;
@synthesize runtimeArguments = _runtimeArguments;
@synthesize variableTimeEvents = _variableTimeEvents;
@synthesize localObjects = _localObjects;
@synthesize localVariables = _localVariables;
@synthesize booleanEvaluators = _booleanEvaluators;
@synthesize forLoopEvaluators = _forLoopEvaluators;

+ (int)isValidArguments:(NSArray*)arguments
{
    if ([arguments count] > 20)
    {
        return UIAD_FUNCTION_EVENT_ARGUMENT_TOO_MANY;
    }
    
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:[arguments count]];
    
    for (UIADPropertyValue* object in arguments)
    {
        if (object.type != UIAD_PROPERTY_VALUE_STRING)
        {
            return UIAD_FUNCTION_EVENT_ARGUMENT_INVALID;
        }
        
        if (![object.stringValue isValidPropertyName])
        {
            return UIAD_FUNCTION_EVENT_ARGUMENT_INVALID;
        }
        
        // 检查是否有重复
        for (id current in array)
        {
            if ([object.stringValue isEqual:current])
            {
                return UIAD_FUNCTION_EVENT_ARGUMENT_DUPLICATED;
            }
        }
        [array addObject:object.stringValue];
    }
    
    return UIAD_FUNCTION_EVENT_ARGUMENT_OK;
}

- (id)initWithName:(NSString*)name
{
    if (self = [super init])
    {
        _status = UIAD_FUNCTION_EVENT_IDLE;
        
        _time = 0.0f;
        _absoluteTime = 0.0f;
        
        _name = [name retain];
        _timeLines = [[NSMutableArray alloc] initWithCapacity:20];
        _durativeTimeLines = [[NSMutableArray alloc] initWithCapacity:10];
        
        _localObjects = [[NSMutableDictionary alloc] initWithCapacity:10];
        _localVariables = [[NSMutableDictionary alloc] initWithCapacity:10];
        _booleanEvaluators = [[NSMutableArray alloc] initWithCapacity:10];
        _forLoopEvaluators = [[NSMutableArray alloc] initWithCapacity:10];
    }
    
    return self;
}

- (id)initWithName:(NSString*)name arguments:(NSArray*)arguments
{
    if (self = [self initWithName:name])
    {
        // arguments应该是一个字符串数组，且里面无相同参数，每个参数都符合参数命名规则
        NSMutableDictionary* index = [NSMutableDictionary dictionaryWithCapacity:[arguments count]];
        for (int i = 0; i < [arguments count]; i ++)
        {
            UIADPropertyValue* arg = [arguments objectAtIndex:i];
            [index setObject:[NSNumber numberWithInt:i] forKey:arg.stringValue];
        }
        _argumentIndex = [index retain];
    }
    
    return self;
}

- (id)initAsVariableTimeEvent:(NSString*)expression superEvent:(UIADFunctionEvent*)superEvent sourceLine:(int)sourceLine
{
    // 用函数名存储表达式
    if (self = [self initWithName:expression])
    {
        _variableTimeEvent = YES;
        _variableTimeEventLine = sourceLine;
        _argumentIndex = [superEvent.argumentIndex retain];
        [superEvent addSubVariableTimeEvent:self];
    }
    
    return self;
}

- (void)dealloc
{
    [_name release];
    [_timeLines release];
    [_durativeTimeLines release];
    [_argumentIndex release];
    [_runtimeArguments release];
    [_variableTimeEvents release];
    NSArray* allValues = [_localObjects allValues];
    for (UIADObject* object in allValues)
    {
        object.functionEvent = nil;
    }
    [_localObjects release];
    [_localVariables release];
    [_booleanEvaluators release];
    [_forLoopEvaluators release];
    [super dealloc];
}

- (UIADTimeLine*)getTimeLine:(NSTimeInterval)time
{
    for (UIADTimeLine* timeLine in _timeLines)
    {
        if (fabs(timeLine.time - time) <= UIAD_TIME_LINE_PRECISION)
        {
            return timeLine;
        }
    }
    
    // 没找到
    UIADTimeLine* newTimeLine = [[UIADTimeLine alloc] initWithTime:time];
    if ([_timeLines count] == 0 || (time >= ((UIADTimeLine*)[_timeLines lastObject]).time))
    {
        // 直接添加到最后
        [_timeLines addObject:newTimeLine];
    }
    else
    {
        // 找位置insert
        for (int i = 0; i < [_timeLines count]; i ++)
        {
            if (time < ((UIADTimeLine*)[_timeLines objectAtIndex:i]).time)
            {
                [_timeLines insertObject:newTimeLine atIndex:i];
                break;
            }
        }
    }
    
    newTimeLine.functionEvent = self;
    return [newTimeLine autorelease];
}

- (UIADTimeLine*)getDurativeTimeLine:(NSTimeInterval)time duration:(NSTimeInterval)duration
{
    UIADTimeLine* newTimeLine = [[UIADTimeLine alloc] initWithTime:time duration:duration runtime:YES];
    [_durativeTimeLines addObject:newTimeLine];
    _activeDurativeTimeLine ++;
    return [newTimeLine autorelease];
}

- (UIADFunctionEvent*)duplicateEvent
{
    UIADFunctionEvent* result = [[UIADFunctionEvent alloc] initWithName:_name];
    result.argumentIndex = _argumentIndex;
    result.variableTimeEvents = _variableTimeEvents;
    result.forLoopEvaluators = _forLoopEvaluators;
    for (UIADTimeLine* sourceLine in _timeLines)
    {
        UIADTimeLine* dupLine = [sourceLine duplicateTimeLine];
        dupLine.functionEvent = result;
        [result.timeLines addObject:dupLine];
    }
    for (UIADTimeLine* sourceLine in _durativeTimeLines)
    {
        if (!sourceLine.runtime)
        {
            UIADTimeLine* dupLine = [sourceLine duplicateTimeLine];
            dupLine.functionEvent = result;
            [result.durativeTimeLines addObject:dupLine];
        }
    }
    for (UIADBooleanEvaluator* evaluator in _booleanEvaluators)
    {
        UIADBooleanEvaluator* dupEvaluator = [evaluator duplicateBooleanEvaluator];
        dupEvaluator.functionEvent = result;
        [result.booleanEvaluators addObject:dupEvaluator];
    }
    return [result autorelease];
}

- (BOOL)hasArgument:(NSString*)arg
{
    return [_argumentIndex objectForKey:arg] != nil;
}

- (id)argumentValue:(NSString*)argName
{
    if (_argumentIndex)
    {
        NSNumber* index = [_argumentIndex objectForKey:argName];
        if (index && [index intValue] < [_runtimeArguments count])
        {
            return [_runtimeArguments objectAtIndex:[index intValue]];
        }
    }
    
    return nil;
}

- (BOOL)finished:(NSTimeInterval)now
{
    BOOL finished = (_current >= [_timeLines count]) && (_activeDurativeTimeLine == 0);
    if (finished)
    {
        if (_status == UIAD_FUNCTION_EVENT_STARTED)
        {
            // 加一个时间缓冲
            _finishBufferTime = now;
            _status = UIAD_FUNCTION_EVENT_FINISH_BUFFER;
            return NO;
        }
        else if (_status == UIAD_FUNCTION_EVENT_FINISH_BUFFER)
        {
            if (now - _finishBufferTime > UIAD_FINISH_BUFFER_TIME)
            {
                _status = UIAD_FUNCTION_EVENT_FINISHED;
            }
            return NO;
        }
    }
    
    return finished;
}

- (void)trigger:(NSTimeInterval)time
{
    _status = UIAD_FUNCTION_EVENT_STARTED;
    _startTime = time;
    _activeDurativeTimeLine = [_durativeTimeLines count];
}

- (NSArray*)getExecutableLines:(NSTimeInterval)time
{
    time -= _startTime;
    NSMutableArray* executableLines = [[NSMutableArray alloc] initWithCapacity:10];
    for (int i = _current; i < [_timeLines count]; i ++)
    {
        UIADTimeLine* line = [_timeLines objectAtIndex:i];
        
        if (line.time <= time)
        {
            [executableLines addObject:line];
        }
        else
        {
            break;
        }
    }
    _current += [executableLines count];
    
    // durative time lines
    for (UIADTimeLine* line in _durativeTimeLines)
    {
        if (!line.inactive && (line.time <= time))
        {
            if (line.time + line.duration >= time)
            {
                line.localTime = time - line.time;
                [executableLines addObject:line];
            }
            else
            {
                // 为保证最后一帧也被执行
                line.localTime = line.duration;
                line.inactive = YES;
                _activeDurativeTimeLine --;
                [executableLines addObject:line];
            }
        }
    }
    
    return [executableLines autorelease];
}

- (UIADObject*)localObjectWithName:(NSString*)name context:(UIADOperationContext*)context allowCreate:(BOOL)allowCreate
{
    UIADObject* object = [_localObjects objectForKey:name];
    if (object == nil && allowCreate && context.scene)
    {
        object = [[[UIADObject alloc] initWithName:name scene:context.scene] autorelease];
        object.functionEvent = self;
        object.entity = [UIADImageEntity createDefaultEntity];
        [context.scene.entity addSubview:object.entity];
        [context.mainView didObjectEntityCreated:object];
        [_localObjects setObject:object forKey:name];
    }
    
    return object;
}

- (BOOL)removeLocalObject:(UIADObject*)object
{
    NSArray* keys = [_localObjects allKeysForObject:object];
    if ([keys count] == 1)
    {
        [_localObjects removeObjectForKey:[keys objectAtIndex:0]];
        return YES;
    }
    return NO;
}

- (void)addSubVariableTimeEvent:(UIADFunctionEvent*)subEvent
{
    if (_variableTimeEvents == nil)
    {
        _variableTimeEvents = [[NSMutableArray alloc] initWithCapacity:5];
    }
    
    [_variableTimeEvents addObject:subEvent];
}

- (BOOL)decideSubVariableTimeEventTime:(UIADOperationContext*)context
{
    UIADOperationContext* localContext = [[UIADOperationContext alloc] init];
    localContext.functionEvent = self;
    localContext.evaluateAllowObject = NO;
    localContext.program = context ? context.program : nil;
    localContext.now = context ? context.now : 0.0f;
    
    for (UIADFunctionEvent* subEvent in _variableTimeEvents)
    {
        // 计算要触发执行的时间
        NSNumber* value = [[UIADPropertyValue valueAsNumberWithString:subEvent.name] evaluateNumberWithObject:nil context:localContext]; // _name存的是表达式
        if (value && [value doubleValue] >= 0.0f)
        {
            UIADTimeLine* timeLine = [self getTimeLine:[value doubleValue]];
            [timeLine addOperation:UIAD_OPERATION_VARIABLE_EVENT parameters:[NSDictionary dictionaryWithObjectsAndKeys:subEvent, @"subEvent", _runtimeArguments, @"arguments", context.scene, @"scene", nil] line:subEvent.variableTimeEventLine runtime:YES precondition:UIAD_NO_PRECONDITION];
        }
        else
        {
            [localContext release];
            return NO;
        }
    }
    
    [localContext release];
    return YES;
}

- (UIADBooleanEvaluator*)addBooleanEvaluator:(UIADBooleanEvaluator*)superEvaluator expression:(NSString*)expression referenceObject:(UIADReferenceObject*)referenceObject
{
    UIADBooleanEvaluator* evaluator = [[UIADBooleanEvaluator alloc] initWithIndex:[_booleanEvaluators count] superIndex:(superEvaluator ? superEvaluator.index : UIAD_NO_PRECONDITION) expression:expression referenceObject:referenceObject];
    evaluator.functionEvent = self;
    [_booleanEvaluators addObject:evaluator];
    return [evaluator autorelease];
}

- (UIADForLoopEvaluator*)addForLoopEvaluator:(UIADPropertyValue*)arguments referenceObject:(UIADReferenceObject*)referenceObject
{
    UIADForLoopEvaluator* evaluator = [[UIADForLoopEvaluator alloc] initWithArguments:arguments referenceObject:referenceObject];
    [_forLoopEvaluators addObject:evaluator];
    return [evaluator autorelease];
}

- (UIADBooleanEvaluator*)getBooleanEvaluator:(int)index
{
    if (index >= 0 && index < [_booleanEvaluators count])
    {
        return [_booleanEvaluators objectAtIndex:index];
    }
    return nil;
}

- (void)setLocalVariable:(NSString*)name value:(id)value
{
    [_localVariables setObject:value forKey:name];
}

- (id)getLocalVariable:(NSString*)name
{
    return [_localVariables objectForKey:name];
}

@end

@implementation UIADBooleanEvaluator

@synthesize index = _index;
@synthesize expression = _expression;
@synthesize functionEvent = _functionEvent;
@synthesize referenceObject = _referenceObject;

- (id)initWithIndex:(int)index superIndex:(int)superIndex expression:(NSString*)expression referenceObject:(UIADReferenceObject*)referenceObject
{
    if (self = [super init])
    {
        _index = index;
        _superIndex = superIndex;
        _inner_value = UIAD_BOOL_UNDEFINED;
        _expression = [expression retain];
        _referenceObject = [referenceObject retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_expression release];
    [_referenceObject release];
    [super dealloc];
}

- (void)reset
{
    _inner_value = UIAD_BOOL_UNDEFINED;
}

- (UIADBooleanEvaluator*)duplicateBooleanEvaluator
{
    UIADBooleanEvaluator* result = [[UIADBooleanEvaluator alloc] initWithIndex:_index superIndex:_superIndex expression:_expression referenceObject:_referenceObject];
    result.functionEvent = _functionEvent;
    return [result autorelease];
}

- (BOOL)getValue:(UIADOperationContext*)context pValue:(BOOL*)pValue
{
    if (_inner_value == UIAD_BOOL_UNDEFINED)
    {
        // 计算
        if (_superIndex != UIAD_NO_PRECONDITION)
        {
            // 有先决条件时
            BOOL superValue;
            UIADBooleanEvaluator* superEvaluator = _functionEvent ? [_functionEvent getBooleanEvaluator:_superIndex] : [context.program getBooleanEvaluator:_superIndex];
            
            if (superEvaluator == nil || ![superEvaluator getValue:context pValue:&superValue])
            {
                return NO;
            }
            
            if (!superValue)
            {
                // 如果先决条件都不成立，自己肯定也不成立
                _inner_value = UIAD_BOOL_FALSE;
                *pValue = NO;
                return YES;
            }
        }
        
        // 计算自己的值
        UIADObject* destObject = nil;
        if (_referenceObject)
        {
            UIADObjectBase* theObject = [_referenceObject getObject:context];
            if (theObject && [theObject isKindOfClass:[UIADObject class]])
            {
                destObject = (UIADObject*)theObject;
            }
            else
            {
                return NO;
            }
        }
        
        NSNumber* value = [[UIADPropertyValue valueAsNumberWithString:_expression] evaluateNumberWithObject:destObject context:context];
        if (value && [value isKindOfClass:[NSBool class]])
        {
            _inner_value = [(NSBool*)value value] ? UIAD_BOOL_TRUE : UIAD_BOOL_FALSE;
        }
        else
        {
            return NO; // 解析失败
        }
    }

    *pValue = (BOOL)_inner_value;
    return YES;
}

@end

@implementation UIADVariableAssignment

@synthesize eventVariable = _eventVariable;
@synthesize name = _name;
@synthesize expression = _expression;
@synthesize referenceObject = _referenceObject;

- (id)initWithName:(NSString*)name expression:(NSString*)expression eventVariable:(BOOL)eventVariable referenceObject:(UIADReferenceObject*)referenceObject
{
    if (self = [super init])
    {
        _eventVariable = eventVariable;
        _name = [name retain];
        _expression = [expression retain];
        _referenceObject = [referenceObject retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_name release];
    [_expression release];
    [_referenceObject release];
    [super dealloc];
}

- (BOOL)performAssignment:(UIADOperationContext*)context
{
    UIADObject* destObject = nil;
    if (_referenceObject)
    {
        UIADObjectBase* theObject = [_referenceObject getObject:context];
        if (theObject && [theObject isKindOfClass:[UIADObject class]])
        {
            destObject = (UIADObject*)theObject;
        }
        else
        {
            return NO;
        }
    }
    
    NSNumber* value = [[UIADPropertyValue valueAsNumberWithString:_expression] evaluateNumberWithObject:destObject context:context];
    if (value)
    {
        if (_eventVariable)
        {
            if (context.functionEvent)
            {
                [context.functionEvent setLocalVariable:_name value:value];
            }
            else
            {
                return NO;
            }
        }
        else
        {
            [context.program setLocalVariable:_name value:value];
        }
        
        return YES;
    }
    else
    {
        return NO; // 解析失败
    }
}

@end

@implementation UIADForLoopEvaluator

@synthesize next = _next;
@synthesize arguments = _arguments;
@synthesize referenceObject = _referenceObject;

- (id)initWithArguments:(UIADPropertyValue*)arguments referenceObject:(UIADReferenceObject*)referenceObject
{
    if (self = [super init])
    {
        _arguments = [arguments retain];
        _referenceObject = [referenceObject retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_arguments release];
    [_referenceObject release];
    [super dealloc];
}

- (BOOL)execute:(UIADOperation*)operation context:(UIADOperationContext*)context
{
    setLastError(context, @"For loop execution error.");
    
    NSNumber* start = nil, *to = nil, *step = nil;
    
    UIADObject* destObject = nil;
    if (_referenceObject)
    {
        UIADObjectBase* theObject = [_referenceObject getObject:context];
        if (theObject && [theObject isKindOfClass:[UIADObject class]])
        {
            destObject = (UIADObject*)theObject;
        }
        else
        {
            return NO;
        }
    }
    
    UIADPropertyValue* argExpr = [_arguments.arrayValue objectAtIndex:0];
    UIADPropertyValue* rangeExpr = [_arguments.arrayValue objectAtIndex:1];
    if ([_arguments.arrayValue count] == 3)
    {
        UIADPropertyValue* stepExpr = [_arguments.arrayValue objectAtIndex:2];
        step = [stepExpr evaluateNumberWithObject:destObject context:context];
        if (step == nil)
        {
            return NO;
        }
    }
    else
    {
        step = [NSNumber numberWithDouble:1.0f];
    }
    
    UIADPropertyValue* startExpr = [rangeExpr.arrayValue objectAtIndex:0];
    UIADPropertyValue* toExpr = [rangeExpr.arrayValue objectAtIndex:1];
    start = [startExpr evaluateNumberWithObject:destObject context:context];
    if (start == nil)
    {
        return NO;
    }
    to = [toExpr evaluateNumberWithObject:destObject context:context];
    if (to == nil)
    {
        return NO;
    }
    
    // 检查一下参数，如果start < to，但是step <= 0；或start > to，但step >= 0，这两种都是无限循环，报错
    double dStart = [start doubleValue], dTo = [to doubleValue], dStep = [step doubleValue];
    if (dStart < dTo)
    {
        if (dStep <= 0.0f)
        {
            return NO;
        }
        
        while (dStart <= dTo)
        {
            [context.forLoopVariables setObject:[NSNumber numberWithDouble:dStart] forKey:argExpr.stringValue];
            if (_next)
            {
                [_next execute:operation context:context];
            }
            else
            {
                [operation executeOnce:context];
            }
            dStart += dStep;
        }
    }
    else if (dStart > dTo)
    {
        if (dStep >= 0.0f)
        {
            return NO;
        }
        
        while (dStart >= dTo)
        {
            [context.forLoopVariables setObject:[NSNumber numberWithDouble:dStart] forKey:argExpr.stringValue];
            if (_next)
            {
                [_next execute:operation context:context];
            }
            else
            {
                [operation executeOnce:context];
            }
            dStart += dStep;
        }
    }
    else
    {
        // start == to，执行一次好了
        [context.forLoopVariables setObject:start forKey:argExpr.stringValue];
        if (_next)
        {
            [_next execute:operation context:context];
        }
        else
        {
            [operation executeOnce:context];
        }
    }
    
    return YES;
}

@end

#pragma mark -

@interface UIADObject(Private)

- (BOOL)loadImage:(NSString*)imageName context:(UIADOperationContext*)context stretch:(BOOL)stretch capX:(NSInteger)capX capY:(NSInteger)capY;

@end

@implementation UIADReferenceObject

@synthesize name = _name;
@synthesize scene = _scene;

- (id)initWithName:(NSString*)name scene:(UIADScene*)scene
{
    if (self = [super init])
    {
        _name = [name retain];
        _scene = scene; // no retain
    }
    
    return self;
}

- (void)dealloc
{
    [_name release];
    [super dealloc];
}

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    // _name是参数名，需要根据这个参数名到context->functionEvent里取到传过来的参数
    if (context.functionEvent)
    {
        id argValue = [context.functionEvent argumentValue:_name];
        if (argValue && [argValue isKindOfClass:[UIADObject class]])
        {
            return argValue;
        }
    }
    
    return nil;
}

- (BOOL)isValidPropertyName:(NSString*)str
{
    return [str isEqualToString:@"image"] || [str isEqualToString:@"movie"] || [str isEqualToString:@"animate"] || [str isEqualToString:@"animateGroup"] || [str isEqualToString:@"anchor"] || [str isEqualToString:@"anchorZ"] || [str isEqualToString:@"center"] ||
    [str isEqualToString:@"rect"] || [str isEqualToString:@"origin"] || [str isEqualToString:@"size"] || [str isEqualToString:@"hide"] || [str isEqualToString:@"show"] || [str isEqualToString:@"alpha"] ||
    [str isEqualToString:@"backgroundColor"] || [str isEqualToString:@"parent"] || [str isEqualToString:@"bringToFront"] || [str isEqualToString:@"sendToBack"] || [str isEqualToString:@"flash"] ||
    [str isEqualToString:@"tapEvent"] || [str isEqualToString:@"free"] || [str isEqualToString:@"transit"] || [str isEqualToString:@"marqueeText"] || [str isEqualToString:@"setDefaultMarqueeTextDuration"] ||
    [str isEqualToString:@"marqueeTexts"] || [str isEqualToString:@"setMarqueeTextScaleFactor"] || [str isEqualToString:@"invoke"] || [str isEqualToString:@"event"];
}

- (BOOL)isValidPropertyValueForProperty:(NSString*)name value:(UIADPropertyValue*)value
{
    return ([name isEqualToString:@"image"] && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_ARRAY || value.type == UIAD_PROPERTY_VALUE_DICTIONARY)) ||
    ([name isEqualToString:@"movie"] && value.type == UIAD_PROPERTY_VALUE_DICTIONARY) ||
    ([name isEqualToString:@"animate"] && value.type == UIAD_PROPERTY_VALUE_DICTIONARY) ||
    ([name isEqualToString:@"animateGroup"] && value.type == UIAD_PROPERTY_VALUE_DICTIONARY) ||
    ([name isEqualToString:@"anchor"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
    ([name isEqualToString:@"anchorZ"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
    ([name isEqualToString:@"center"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
    ([name isEqualToString:@"rect"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
    ([name isEqualToString:@"origin"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
    ([name isEqualToString:@"size"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
    ([name isEqualToString:@"hide"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
    ([name isEqualToString:@"show"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
    ([name isEqualToString:@"alpha"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
    ([name isEqualToString:@"backgroundColor"] && value.type == UIAD_PROPERTY_VALUE_ARRAY) ||
    ([name isEqualToString:@"parent"] && [value isObject]) ||
    ([name isEqualToString:@"bringToFront"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
    ([name isEqualToString:@"sendToBack"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
    ([name isEqualToString:@"flash"] && value.type == UIAD_PROPERTY_VALUE_DICTIONARY) ||
    ([name isEqualToString:@"tapEvent"] && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_ARRAY)) ||
    ([name isEqualToString:@"free"] && value.type == UIAD_PROPERTY_VALUE_NONE) ||
    ([name isEqualToString:@"transit"] && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_DICTIONARY)) ||
    ([name isEqualToString:@"marqueeText"] && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_DICTIONARY)) ||
    ([name isEqualToString:@"setDefaultMarqueeTextDuration"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
    ([name isEqualToString:@"marqueeTexts"] && value.type == UIAD_PROPERTY_VALUE_DICTIONARY) ||
    ([name isEqualToString:@"setMarqueeTextScaleFactor"] && value.type == UIAD_PROPERTY_VALUE_NUMBER) ||
    (([name isEqualToString:@"invoke"] || [name isEqualToString:@"event"]) && (value.type == UIAD_PROPERTY_VALUE_STRING || value.type == UIAD_PROPERTY_VALUE_ARRAY));
}

@end

@implementation UIADFormatReferenceObject

@synthesize arguments = _arguments;

- (id)initWithName:(NSString *)name scene:(UIADScene *)scene arguments:(UIADPropertyValue*)arguments
{
    if (self = [super initWithName:name scene:scene])
    {
        _arguments = [arguments retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_arguments release];
    [super dealloc];
}

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    // 根据当前运行状态计算出format后的对象名
    NSString* formattedName = [UIADPropertyValue evaluateFormat:_name withArguments:_arguments object:nil context:context];
    if (formattedName && [formattedName length] > 0)
    {
        // 到scene去取物体，如果没有会创建，同时如果object的实体没创建，也要创建
        UIADObject* object = [context.scene objectWithName:formattedName];
        return [object getObject:context];
    }
    
    return nil;
}

@end

@implementation UIADLocalObject

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    // 到context.functionEvent里取物体
    if (context.functionEvent)
    {
        return [context.functionEvent localObjectWithName:_name context:context allowCreate:YES];
    }
    
    return nil;
}

@end

@implementation UIADFormatReferenceLocalObject

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    // 到context.functionEvent里取物体
    if (context.functionEvent)
    {
        // 根据当前运行状态计算出format后的对象名
        NSString* formattedName = [UIADPropertyValue evaluateFormat:_name withArguments:_arguments object:nil context:context];
        if (formattedName && [formattedName length] > 0)
        {
            // 如果functionEvent的对象列表里还没有这个物体，也会创建，并会创建实体
            return [context.functionEvent localObjectWithName:formattedName context:context allowCreate:YES];
        }
    }

    return nil;
}

@end

@implementation UIADObjectWithImage

@synthesize imageName = _imageName;

- (id)initWithName:(NSString *)name scene:(UIADScene *)scene imageName:(NSString*)imageName
{
    if (self = [super initWithName:name scene:scene])
    {
        _imageName = [imageName retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_imageName release];
    [super dealloc];
}

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    // 到scene去取物体，如果没有会创建，同时如果object的实体没创建，也要创建
    UIADObject* object = [context.scene objectWithName:_name];
    UIADObjectBase* result = [object getObject:context];
    
    if (result && [object loadImage:_imageName context:context stretch:NO capX:0 capY:0])
    {
        return result;
    }
    
    return nil;
}

@end

@implementation UIADLocalObjectWithImage

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    if (context.functionEvent)
    {
        UIADObject* result = [context.functionEvent localObjectWithName:_name context:context allowCreate:YES];
        if (result && [result loadImage:_imageName context:context stretch:NO capX:0 capY:0])
        {
            return result;
        }
    }
    
    return nil;
}

@end

@implementation UIADObject

@synthesize external = _external;
@synthesize entity = _entity;
@synthesize functionEvent = _functionEvent;
@synthesize marqueeTexts = _marqueeTexts;
@synthesize defaultMarqueeTextDuration = _defaultMarqueeTextDuration;
@synthesize marqueeTextScaleFactor = _marqueeTextScaleFactor;

- (id)init
{
    if (self = [super init])
    {
        _defaultMarqueeTextDuration = UIAD_MARQUEE_TEXT_DURATION;
        _marqueeTextScaleFactor = 1.0;
    }
    return self;
}

- (id)initWithName:(NSString*)name scene:(UIADScene*)scene
{
    if (self = [super initWithName:name scene:scene])
    {
        _defaultMarqueeTextDuration = UIAD_MARQUEE_TEXT_DURATION;
        _marqueeTextScaleFactor = 1.0;
    }
    
    return self;
}

- (id)initWithExternal:(NSString*)name scene:(UIADScene*)scene entity:(UIADEntity*)entity
{
    if (self = [super init])
    {
        _name = [name retain];
        _scene = scene;
        _entity = [entity retain];
        _external = YES;
        
        _defaultMarqueeTextDuration = UIAD_MARQUEE_TEXT_DURATION;
        _marqueeTextScaleFactor = 1.0;
    }
    
    return self;
}

- (void)dealloc
{
    [_entity release];
    [_marqueeTexts release];
    [super dealloc];
}

- (void)reset
{
    _sizeModified = NO;
    if (!_external)
    {
        [_entity removeFromSuperview];
    }
    [_entity release];
    _entity = nil;
    _marqueeTextIndex = 0;
    [_marqueeTexts release];
    _marqueeTexts = nil;
    _defaultMarqueeTextDuration = UIAD_MARQUEE_TEXT_DURATION;
}

- (void)replaceEntity:(UIADEntity*)entity
{
    UIView* superView = _entity.superview;
    if (!_external)
    {
        [_entity removeFromSuperview];
    }
    [_entity release];
    _entity = [entity retain];

    if (superView)
    {
        [superView addSubview:_entity];
    }
}

- (UIADObjectBase*)getObject:(UIADOperationContext*)context
{
    if (_entity == nil)
    {
        if (context.scene)
        {
            _entity = [[UIADImageEntity createDefaultEntity] retain];
            [context.scene.entity addSubview:_entity];
            [context.mainView didObjectEntityCreated:self];
        }
        else
        {
            return nil;
        }
    }
    
    return self;
}

- (BOOL)assignCAAnimationEventProperties:(UIADPropertyValue*)parameter context:(UIADOperationContext*)context start:(BOOL)start
{
    if (parameter.type == UIAD_PROPERTY_VALUE_STRING)
    {
        start ? (context.startEvent = parameter) : (context.stopEvent = parameter);
        return YES;
    }
    else if (parameter.type == UIAD_PROPERTY_VALUE_ARRAY && [parameter.arrayValue count] == 2)
    {
        UIADPropertyValue* eventName = [parameter.arrayValue objectAtIndex:0];
        UIADPropertyValue* eventParameters = [parameter.arrayValue objectAtIndex:1];
        if (eventName.type == UIAD_PROPERTY_VALUE_STRING && eventParameters.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            NSArray* args = [eventParameters evaluateArrayAsParameterArray:nil context:context];
            if (args)
            {
                start ? (context.startEvent = eventName) : (context.stopEvent = eventName);
                start ? (context.startEventArgs = args) : (context.stopEventArgs = args);
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)assignCAAnimationProperties:(CAAnimation*)animation parameters:(NSDictionary*)parameters useDefault:(BOOL)useDefault context:(UIADOperationContext*)context
{
    if (useDefault && _scene)
    {
        animation.fillMode = _scene.defaultFillMode;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:_scene.defaultTimingFunction];
        animation.removedOnCompletion = _scene.defaultRemovedOnCompletion;
        animation.duration = _scene.defaultDuration;
    }
    
    NSArray* keys = [parameters allKeys];
    for (NSString* key in keys)
    {
        UIADPropertyValue* parameter = [parameters objectForKey:key];
        if ([key isEqualToString:@"timingFunction"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            animation.timingFunction = [CAMediaTimingFunction functionWithName:parameter.stringValue];
        }
        else if ([key isEqualToString:@"removedOnCompletion"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            if ([parameter.numberValue doubleValue] == 1.0f)
            {
                animation.removedOnCompletion = YES;
            }
            else if ([parameter.numberValue doubleValue] == 0.0f)
            {
                animation.removedOnCompletion = NO;
            }
            else
            {
                return NO;
            }
        }
        else if ([key isEqualToString:@"beginTime"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            animation.beginTime = [[parameter evaluateNumberWithObject:self context:context] doubleValue] / context.speed;
        }
        else if ([key isEqualToString:@"duration"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            animation.duration = [[parameter evaluateNumberWithObject:self context:context] doubleValue] / context.speed;
        }
        else if ([key isEqualToString:@"speed"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            animation.speed = (float)([[parameter evaluateNumberWithObject:self context:context] doubleValue] * context.speed);
        }
        else if ([key isEqualToString:@"timeOffset"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            animation.timeOffset = [[parameter evaluateNumberWithObject:self context:context] doubleValue] / context.speed;
        }
        else if ([key isEqualToString:@"repeatCount"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            animation.repeatCount = (float)([[parameter evaluateNumberWithObject:self context:context] doubleValue]);
        }
        else if ([key isEqualToString:@"repeatDuration"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            animation.repeatDuration = [[parameter evaluateNumberWithObject:self context:context] doubleValue] / context.speed;
        }
        else if ([key isEqualToString:@"autoreverses"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            if ([parameter.numberValue doubleValue] == 1.0f)
            {
                animation.autoreverses = YES;
            }
            else if ([parameter.numberValue doubleValue] == 0.0f)
            {
                animation.autoreverses = NO;
            }
            else
            {
                return NO;
            }
        }
        else if ([key isEqualToString:@"fillMode"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            animation.fillMode = parameter.stringValue;
        }
        else if ([key isEqualToString:@"startEvent"] && (parameter.type == UIAD_PROPERTY_VALUE_STRING || parameter.type == UIAD_PROPERTY_VALUE_ARRAY))
        {
            // 动画开始时执行脚本里的event事件
            context.animation = animation;
            return [self assignCAAnimationEventProperties:parameter context:context start:YES];
        }
        else if ([key isEqualToString:@"stopEvent"] && (parameter.type == UIAD_PROPERTY_VALUE_STRING || parameter.type == UIAD_PROPERTY_VALUE_ARRAY))
        {
            // 动画结束时执行脚本里的event事件
            context.animation = animation;
            return [self assignCAAnimationEventProperties:parameter context:context start:NO];
        }
        else if ([key isEqualToString:@"manually"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            if (self.functionEvent)
            {
                setLastError(context, [NSString stringWithFormat:@"Only global objects can be manually manipulated."]);
                return NO;
            }
            if ([parameter.stringValue length])
            {
                [context.program addManuallyManipulatedObject:self forKey:parameter.stringValue];
            }
            else
            {
                return NO;
            }
        }
    }

    return YES;
}

- (BOOL)assignCAAnimationGroupProperties:(CAAnimationGroup*)animation parameters:(NSDictionary*)parameters context:(UIADOperationContext*)context
{
    return [self assignCAAnimationProperties:animation parameters:parameters useDefault:YES context:context];
}

- (BOOL)assignCAPropertyAnimationProperties:(CAPropertyAnimation*)animation parameters:(NSDictionary*)parameters useDefault:(BOOL)useDefault context:(UIADOperationContext*)context
{
    if (![self assignCAAnimationProperties:animation parameters:parameters useDefault:useDefault context:context])
    {
        return NO;
    }
    
    NSArray* keys = [parameters allKeys];
    for (NSString* key in keys)
    {
        UIADPropertyValue* parameter = [parameters objectForKey:key];
        if ([key isEqualToString:@"key"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            animation.keyPath = parameter.stringValue;
        }
        else if ([key isEqualToString:@"additive"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            if ([parameter.numberValue doubleValue] == 1.0f)
            {
                animation.additive = YES;
            }
            else if ([parameter.numberValue doubleValue] == 0.0f)
            {
                animation.additive = NO;
            }
            else
            {
                return NO;
            }
        }
        else if ([key isEqualToString:@"cumulative"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            if ([parameter.numberValue doubleValue] == 1.0f)
            {
                animation.cumulative = YES;
            }
            else if ([parameter.numberValue doubleValue] == 0.0f)
            {
                animation.cumulative = NO;
            }
            else
            {
                return NO;
            }
        }
    }
    
    return YES;
}

- (CABasicAnimation*)getBasicAnimation:(NSDictionary*)parameters useDefault:(BOOL)useDefault context:(UIADOperationContext*)context
{
    if (parameters == nil || ![parameters isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    
    CABasicAnimation* result = [[CABasicAnimation alloc] init];
    if (![self assignCAPropertyAnimationProperties:result parameters:parameters useDefault:useDefault context:context])
    {
        [result release];
        return nil;
    }
    
    BOOL evaluateValueAsColor = NO;
    if ([result.keyPath rangeOfString:@"color" options:NSCaseInsensitiveSearch].length > 0)
    {
        evaluateValueAsColor = YES;
    }
    
    NSArray* keys = [parameters allKeys];
    for (NSString* key in keys)
    {
        if ([key isEqualToString:@"from"] || [key isEqualToString:@"to"] || [key isEqualToString:@"by"])
        {
            UIADPropertyValue* parameter = [parameters objectForKey:key];
            id value = evaluateValueAsColor ? [parameter evaluateArrayAsColorWithObject:self context:context] : [parameter evaluateAsNSValueWithObject:self context:context];
            if (value == nil)
            {
                [result release];
                return nil;
            }
            if (evaluateValueAsColor)
            {
                value = (id)(((UIColor*)value).CGColor);
            }
            
            if ([key isEqualToString:@"from"])
            {
                result.fromValue = value;
            }
            else if ([key isEqualToString:@"to"])
            {
                result.toValue = value;
            }
            else if ([key isEqualToString:@"by"])
            {
                result.byValue = value;
            }
        }
    }
    
    return [result autorelease];
}

- (CAKeyframeAnimation*)getKeyframeAnimation:(NSDictionary*)parameters useDefault:(BOOL)useDefault context:(UIADOperationContext*)context
{
    if (parameters == nil || ![parameters isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    
    CAKeyframeAnimation* result = [[CAKeyframeAnimation alloc] init];
    if (![self assignCAPropertyAnimationProperties:result parameters:parameters useDefault:useDefault context:context])
    {
        [result release];
        return nil;
    }
    
    NSArray* keys = [parameters allKeys];
    for (NSString* key in keys)
    {
        UIADPropertyValue* parameter = [parameters objectForKey:key];
        if ([key isEqualToString:@"values"] && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            result.values = [parameter evaluateArrayAsNSValueArrayWithObject:self context:context];
        }
        else if ([key isEqualToString:@"keyTimes"] && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            result.keyTimes = [parameter evaluateArrayAsNSValueArrayWithObject:self context:context];
        }
        else if ([key isEqualToString:@"timingFunctions"] && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            NSArray* array = [parameter evaluateArrayAsNSValueArrayWithObject:self context:context];
            NSMutableArray* timingArray = [NSMutableArray arrayWithCapacity:[array count]];
            for (id obj in array)
            {
                if ([obj isKindOfClass:[NSString class]])
                {
                    [timingArray addObject:[CAMediaTimingFunction functionWithName:obj]];
                }
                else
                {
                    [result release];
                    return NO;
                }
            }
            
            result.timingFunctions = timingArray;
        }
        else if ([key isEqualToString:@"calculationMode"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            result.calculationMode = parameter.stringValue;
        }
        else if ([key isEqualToString:@"tensionValues"] && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            result.tensionValues = [parameter evaluateArrayAsNSValueArrayWithObject:self context:context];
        }
        else if ([key isEqualToString:@"continuityValues"] && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            result.continuityValues = [parameter evaluateArrayAsNSValueArrayWithObject:self context:context];
        }
        else if ([key isEqualToString:@"biasValues"] && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            result.biasValues = [parameter evaluateArrayAsNSValueArrayWithObject:self context:context];
        }
        else if ([key isEqualToString:@"rotationMode"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            result.rotationMode = parameter.stringValue;
        }
    }
    
    return [result autorelease];
}

- (CATransition*)getTransitionAnimation:(NSDictionary*)parameters useDefault:(BOOL)useDefault context:(UIADOperationContext*)context
{
    if (parameters == nil || ![parameters isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    
    CATransition* result = [[CATransition alloc] init];
    if (![self assignCAAnimationProperties:result parameters:parameters useDefault:useDefault context:context])
    {
        [result release];
        return nil;
    }
    
    NSArray* keys = [parameters allKeys];
    for (NSString* key in keys)
    {
        UIADPropertyValue* parameter = [parameters objectForKey:key];
        if ([key isEqualToString:@"type"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            result.type = parameter.stringValue;
        }
        else if ([key isEqualToString:@"subtype"] && parameter.type == UIAD_PROPERTY_VALUE_STRING)
        {
            result.subtype = parameter.stringValue;
        }
        else if ([key isEqualToString:@"startProgress"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            result.startProgress = [[parameter evaluateNumberWithObject:self context:context] doubleValue];
        }
        else if ([key isEqualToString:@"endProgress"] && parameter.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            result.endProgress = [[parameter evaluateNumberWithObject:self context:context] doubleValue];
        }
    }
    
    return [result autorelease];
}

- (CAAnimationGroup*)getAnimationGroup:(NSDictionary*)parameters context:(UIADOperationContext*)context
{
    if (parameters == nil || ![parameters isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    
    UIADPropertyValue* animations = [parameters objectForKey:@"animations"];
    if (animations == nil || !(animations.type == UIAD_PROPERTY_VALUE_ARRAY))
    {
        return nil;
    }
    
    NSMutableArray* CAAnimationArray = [NSMutableArray arrayWithCapacity:[animations.arrayValue count]];
    CAAnimationGroup* result = [[CAAnimationGroup alloc] init];
    // 解析出各动画
    for (UIADPropertyValue* animation in animations.arrayValue)
    {
        if (animation.type != UIAD_PROPERTY_VALUE_DICTIONARY)
        {
            [result release];
            return nil;
        }
        
        CAAnimation* caAnimation = nil;
        // 判断是KeyFrameAnimation还是BasicAnimation
        if ([animation.dictionaryValue objectForKey:@"values"])
        {
            caAnimation = [self getKeyframeAnimation:animation.dictionaryValue useDefault:NO context:context];
        }
        else if ([animation.dictionaryValue objectForKey:@"type"])
        {
            caAnimation = [self getTransitionAnimation:animation.dictionaryValue useDefault:NO context:context];
        }
        else
        {
            caAnimation = [self getBasicAnimation:animation.dictionaryValue useDefault:NO context:context];
        }
        
        if (caAnimation == nil)
        {
            [result release];
            return nil;
        }
        
        [CAAnimationArray addObject:caAnimation];
    }
    
    result.animations = CAAnimationArray;
    
    // CAAnimationGroup的各属性
    if (![self assignCAAnimationGroupProperties:result parameters:parameters context:context])
    {
        [result release];
        return nil;
    }
    
    return [result autorelease];
}

- (BOOL)loadImage:(NSString*)imageName context:(UIADOperationContext*)context stretch:(BOOL)stretch capX:(NSInteger)capX capY:(NSInteger)capY
{
    UIImage* image = [_scene getImageFile:imageName context:context];
    if (image)
    {
        _resourceImageSize = image.size;
        if (stretch)
        {
            ((UIADImageEntity*)_entity).image = [image stretchableImageWithLeftCapWidth:capX topCapHeight:capY];
        }
        else
        {
            ((UIADImageEntity*)_entity).image = image;
        }
        
        if (!_sizeModified)
        {
            // 潜规则，设置对象的image属性后，如果对象的尺寸从未设置过，自动调整到图片的尺寸
            _entity.frame = CGRectMake(_entity.frame.origin.x, _entity.frame.origin.y, image.size.width * _scene.defaultImageScale, image.size.height * _scene.defaultImageScale);
            _sizeModified = YES;
        }
        return YES;
    }
    return NO;
}

- (NSString*)getAnimationUniqueSignature:(int)line
{
    struct mach_timebase_info timebase;
    mach_timebase_info(&timebase);
    double timebase_ratio = ((double)timebase.numer / (double)timebase.denom) * 1.0e-9;
    NSTimeInterval time = mach_absolute_time() * timebase_ratio;
    return [NSString stringWithFormat:@"animationAtLine%d_%f_%d", line, time, rand()];
}

- (BOOL)setPropertyValue:(NSString*)name value:(UIADPropertyValue*)value context:(UIADOperationContext*)context
{
    if (_entity == nil)
    {
        setLastError(context, [NSString stringWithFormat:@"Instance for object %@ not created.", _name]);
        return NO;
    }
    
    if ([name isEqualToString:@"image"])
    {
        if ([_entity isKindOfClass:[UIADImageEntity class]])
        {
            BOOL valid = NO, stretch = NO;
            NSInteger stretchCapX = 0, stretchCapY = 0;
            NSString* imageName = nil;
            if (value.type == UIAD_PROPERTY_VALUE_DICTIONARY)
            {
                stretch = YES;
                UIADPropertyValue* imageNameValue = [value.dictionaryValue objectForKey:@"image"];
                imageName = [imageNameValue evaluateFormatAsStringWithObject:self context:context];
                
                UIADPropertyValue* stretchCapValue = [value.dictionaryValue objectForKey:@"stretchCap"];
                valid = [_scene getImageCapParameters:stretchCapValue capX:&stretchCapX capY:&stretchCapY object:self context:context];
            }
            else
            {
                valid = YES;
                imageName = [value evaluateFormatAsStringWithObject:self context:context];
            }
            
            if (imageName && valid)
            {
                return [self loadImage:imageName context:context stretch:stretch capX:stretchCapX capY:stretchCapY];
            }
        }
    }
    else if ([name isEqualToString:@"movie"])
    {
        // movie:(images:["a", "b"], interval:0.01, repeat:1, autoreverse:0)
        // movie:(images:["a%d", [0, 10]], interval:0.01, repeat:1, autoreverse:1)
        UIADPropertyValue* pInterval = [value.dictionaryValue objectForKey:@"interval"];
        UIADPropertyValue* pRepeat = [value.dictionaryValue objectForKey:@"repeat"];
        UIADPropertyValue* pAutoreverse = [value.dictionaryValue objectForKey:@"autoreverse"];
        if (pInterval == nil)
            pInterval = [UIADPropertyValue valueAsNumber:[NSNumber numberWithDouble:0.1]];
        if (pRepeat == nil)
            pRepeat = [UIADPropertyValue valueAsNumber:[NSNumber numberWithDouble:1.0]];
        if (pAutoreverse == nil)
            pAutoreverse = [UIADPropertyValue valueAsNumber:[NSNumber numberWithDouble:0.0]];
        
        NSNumber* interval = [pInterval evaluateNumberWithObject:self context:context];
        NSNumber* repeat = [pRepeat evaluateNumberWithObject:self context:context];
        NSNumber* autoreverse = [pAutoreverse evaluateNumberWithObject:self context:context];
        
        if ((interval == nil) || [interval doubleValue] <= 0.0f || (repeat == nil) || autoreverse == nil)
            return NO;
        
        BOOL bAutoreverse = [autoreverse doubleValue] == 1.0;
        
        UIADPropertyValue* images = [value.dictionaryValue objectForKey:@"images"];
        if (images && images.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            // 先计算图片的数目
            BOOL imageValid = NO;
            int imageCount = 0;
            NSMutableDictionary* movieParameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:interval, @"interval", repeat, @"repeat", [NSNumber numberWithBool:bAutoreverse], @"autoreverse", nil];
            if ([images.arrayValue count] == 2 && ((UIADPropertyValue*)[images.arrayValue objectAtIndex:1]).type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                // images:["a%d", [0, 10]]
                UIADPropertyValue* format = (UIADPropertyValue*)[images.arrayValue firstObject];
                UIADPropertyValue* rangeArray = (UIADPropertyValue*)[images.arrayValue objectAtIndex:1];
                if (format.type == UIAD_PROPERTY_VALUE_STRING && [rangeArray.arrayValue count] == 2)
                {
                    UIADPropertyValue* fromValue = [rangeArray.arrayValue firstObject];
                    UIADPropertyValue* toValue = [rangeArray.arrayValue objectAtIndex:1];
                    NSNumber* from = [fromValue evaluateNumberWithObject:self context:context];
                    NSNumber* to = [toValue evaluateNumberWithObject:self context:context];
                    if (from && to && ([from integerValue] <= [to integerValue]))
                    {
                        imageValid = YES;
                        imageCount = [to integerValue] - [from integerValue] + 1;
                        [movieParameters setObject:format.stringValue forKey:@"format"];
                        [movieParameters setObject:from forKey:@"from"];
                        [movieParameters setObject:to forKey:@"to"];
                    }
                }
            }
            else
            {
                // images:["a", "b"]
                NSMutableArray* imageNames = [NSMutableArray arrayWithCapacity:[images.arrayValue count]];
                for (UIADPropertyValue* imageValue in images.arrayValue)
                {
                    if (imageValue.type == UIAD_PROPERTY_VALUE_STRING)
                    {
                        [imageNames addObject:imageValue.stringValue];
                    }
                    else
                    {
                        break;
                    }
                }
                imageValid = [imageNames count] == [images.arrayValue count];
                if (imageValid)
                {
                    imageCount = [imageNames count];
                    [movieParameters setObject:imageNames forKey:@"images"];
                }
            }
            
            if (imageValid && imageCount > 0)
            {
                [movieParameters setObject:[NSNumber numberWithInt:imageCount] forKey:@"imageCount"];
                
                // 创建一个durativeTimeLine，并向其中加入_movie操作
                NSTimeInterval duration = ([repeat doubleValue] == 0.0f) ? INFINITY : (bAutoreverse ? ((imageCount - 1) * [repeat doubleValue] * [interval doubleValue]) : ((imageCount * [repeat doubleValue] - 1) * [interval doubleValue]));
                NSTimeInterval now = context.operation.timeLine.time;
                UIADTimeLine* timeLine = context.functionEvent ? [context.functionEvent getDurativeTimeLine:now duration:duration] : [context.program getDurativeTimeLine:now duration:duration];
                UIADPropertyValue* propertyParameters = [UIADPropertyValue valueAsDictionary:movieParameters];
                [timeLine addOperation:UIAD_OPERATION_ASSIGN parameters:[NSDictionary dictionaryWithObjectsAndKeys:self, @"object", @"_movie", @"name", propertyParameters, @"value", nil] line:context.operation.line runtime:YES precondition:context.operation.precondition];
                return [self setPropertyValue:@"_movie" value:propertyParameters context:context]; // 执行第一帧
            }
        }
    }
    else if ([name isEqualToString:@"_movie"])
    {
        // 这个方法不对外公开，是movie方法生成的操作，执行具体的轮播图片效果
        // 重点是计算当前时刻，需要显示哪张图片
        NSTimeInterval movieLocalTime = context.operation.timeLine.localTime;
        NSDictionary* parameters = value.dictionaryValue;
        BOOL autoreverse = [[parameters objectForKey:@"autoreverse"] boolValue];
        int imageCount = [[parameters objectForKey:@"imageCount"] intValue];
        int step = (int)(movieLocalTime / [[parameters objectForKey:@"interval"] doubleValue]);
        
        int imageIndex = 0;
        if (imageCount > 1)
        {
            if (autoreverse)
            {
                int cycle = (imageCount - 1) * 2;
                int phase = step % cycle;
                imageIndex = (phase <= cycle / 2) ? phase : cycle - phase;
            }
            else
            {
                imageIndex = step % imageCount;
            }
        }
        
        NSString* imageName = nil;
        NSString* format = [parameters objectForKey:@"format"];
        if (format)
        {
            NSNumber* from = [parameters objectForKey:@"from"];
            NSNumber* to = [parameters objectForKey:@"to"];
            imageIndex += [from integerValue];
            if (imageIndex <= [to integerValue])
            {
                imageName = [UIADPropertyValue evaluateFormat:format withArguments:[UIADPropertyValue valueAsArray:[NSArray arrayWithObject:[UIADPropertyValue valueAsNumber:[NSNumber numberWithInt:imageIndex]]]] object:self context:context];
            }
        }
        else
        {
            NSArray* imageNames = [parameters objectForKey:@"images"];
            if (imageIndex < [imageNames count])
            {
                imageName = [imageNames objectAtIndex:imageIndex];
            }
        }
        
        if (imageName)
        {
            return [self setPropertyValue:@"image" value:[UIADPropertyValue valueAsString:imageName] context:context];
        }
    }
    else if ([name isEqualToString:@"backgroundColor"])
    {
        UIColor* color = [value evaluateArrayAsColorWithObject:self context:context];
        if (color)
        {
            _entity.backgroundColor = color;
            return YES;
        }
    }
    else if ([name isEqualToString:@"parent"])
    {
        UIADObject* object = [value evaluateAsObjectWithObject:self context:context];
        if (object && object.entity)
        {
            if (_entity.superview != object.entity)
            {
                [_entity retain];
                [_entity removeFromSuperview];
                [object.entity addSubview:_entity];
                [_entity release];
            }
            
            return YES;
        }
    }
    else if ([name isEqualToString:@"bringToFront"])
    {
        [_entity.superview bringSubviewToFront:_entity];
        return YES;
    }
    else if ([name isEqualToString:@"sendToBack"])
    {
        [_entity.superview sendSubviewToBack:_entity];
        return YES;
    }
    else if ([name isEqualToString:@"hide"])
    {
        _entity.hidden = YES;
        return YES;
    }
    else if ([name isEqualToString:@"show"])
    {
        _entity.hidden = NO;
        return YES;
    }
    else if ([name isEqualToString:@"alpha"])
    {
        NSNumber* alpha = [value evaluateNumberWithObject:self context:context];
        if (alpha)
        {
            _entity.alpha = (CGFloat)[alpha doubleValue];
            return YES;
        }
    }
    else if ([name isEqualToString:@"center"])
    {
        if ([value.arrayValue count] == 2)
        {
            NSNumber* x = [[value.arrayValue objectAtIndex:0] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.width context:context];
            NSNumber* y = [[value.arrayValue objectAtIndex:1] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.height context:context];
            if (x && y)
            {
                _entity.center = CGPointMake((CGFloat)[x doubleValue], (CGFloat)[y doubleValue]);
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"size"])
    {
        if ([value.arrayValue count] == 2)
        {
            NSNumber* w = [[value.arrayValue objectAtIndex:0] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.width context:context];
            NSNumber* h = [[value.arrayValue objectAtIndex:1] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.height context:context];
            if (w && h)
            {
                _entity.frame = CGRectMake(_entity.frame.origin.x, _entity.frame.origin.y, (CGFloat)[w doubleValue], (CGFloat)[h doubleValue]);
                _sizeModified = YES;
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"origin"])
    {
        if ([value.arrayValue count] == 2)
        {
            NSNumber* x = [[value.arrayValue objectAtIndex:0] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.width context:context];
            NSNumber* y = [[value.arrayValue objectAtIndex:1] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.height context:context];
            if (x && y)
            {
                _entity.frame = CGRectMake((CGFloat)[x doubleValue], (CGFloat)[y doubleValue], _entity.frame.size.width, _entity.frame.size.height);
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"rect"])
    {
        if ([value.arrayValue count] == 4)
        {
            NSNumber* x = [[value.arrayValue objectAtIndex:0] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.width context:context];
            NSNumber* y = [[value.arrayValue objectAtIndex:1] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.height context:context];
            NSNumber* w = [[value.arrayValue objectAtIndex:2] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.width context:context];
            NSNumber* h = [[value.arrayValue objectAtIndex:3] evaluateNumberAsDimensionWithObject:self dimension:_entity.superview.bounds.size.height context:context];
            
            if (x && y && w && h)
            {
                _entity.frame = CGRectMake((CGFloat)[x doubleValue], (CGFloat)[y doubleValue], (CGFloat)[w doubleValue], (CGFloat)[h doubleValue]);
                _sizeModified = YES;
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"anchor"])
    {
        if ([value.arrayValue count] == 2)
        {
            NSNumber* x = [[value.arrayValue objectAtIndex:0] evaluateNumberWithObject:self context:context];
            NSNumber* y = [[value.arrayValue objectAtIndex:1] evaluateNumberWithObject:self context:context];
            if (x && y)
            {
                _entity.layer.anchorPoint = CGPointMake((CGFloat)[x doubleValue], (CGFloat)[y doubleValue]);
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"anchorZ"])
    {
        NSNumber* zValue = [value evaluateNumberWithObject:self context:context];
        if (zValue)
        {
            _entity.layer.anchorPointZ = (CGFloat)[zValue doubleValue];
            return YES;
        }
    }
    else if ([name isEqualToString:@"animate"])
    {
        CAAnimation* animation = nil;
        // 判断是KeyFrameAnimation还是BasicAnimation
        if ([value.dictionaryValue objectForKey:@"values"])
        {
            animation = [self getKeyframeAnimation:value.dictionaryValue useDefault:YES context:context];
        }
        else if ([value.dictionaryValue objectForKey:@"type"])
        {
            animation = [self getTransitionAnimation:value.dictionaryValue useDefault:YES context:context];
        }
        else
        {
            animation = [self getBasicAnimation:value.dictionaryValue useDefault:YES context:context];
        }

        if (animation)
        {
            NSString* animationKey = [self getAnimationUniqueSignature:context.operation.line];
            if (context.operationWithTarget)
            {
                animation.delegate = context.animationDelegate;
                [_entity.layer addAnimation:animation forKey:animationKey];
                return YES;
            }
            else if (context.startEvent || context.stopEvent)
            {
                UIADAnimationDelegate* delegate = [context.program addAnimationEvents:animationKey context:context];
                if (delegate)
                {
                    animation.delegate = delegate;
                    [_entity.layer addAnimation:animation forKey:animationKey];
                    return YES;
                }
            }
            else
            {
                [_entity.layer addAnimation:animation forKey:animationKey];
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"animateGroup"])
    {
        CAAnimationGroup* group = [self getAnimationGroup:value.dictionaryValue context:context];
        if (group)
        {
            NSString* animationKey = [self getAnimationUniqueSignature:context.operation.line];
            if (context.operationWithTarget)
            {
                group.delegate = context.animationDelegate;
                [_entity.layer addAnimation:group forKey:animationKey];
                return YES;
            }
            else if (context.startEvent || context.stopEvent)
            {
                UIADAnimationDelegate* delegate = [context.program addAnimationEvents:animationKey context:context];
                if (delegate)
                {
                    group.delegate = delegate;
                    [_entity.layer addAnimation:group forKey:animationKey];
                    return YES;
                }
            }
            else
            {
                [_entity.layer addAnimation:group forKey:animationKey];
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"flash"])
    {
        // 需要运行时向timeLine里添加操作
        UIADPropertyValue* pInterval = [value.dictionaryValue objectForKey:@"interval"];
        UIADPropertyValue* pCount = [value.dictionaryValue objectForKey:@"count"];
        
        if (pInterval.type != UIAD_PROPERTY_VALUE_NUMBER || pCount.type != UIAD_PROPERTY_VALUE_NUMBER)
        {
            return NO;
        }
        
        NSNumber* interval = [pInterval evaluateNumberWithObject:self context:context];
        NSNumber* count = [pCount evaluateNumberWithObject:self context:context];
        
        if ((interval == nil) || ([interval doubleValue] <= 0.0f) || (count == nil) || ([count doubleValue] < 1.0f))
        {
            return NO;
        }
        
        int iCount = (int)(lrint(floor([count doubleValue])));
        if (iCount > 1000)
        {
            return NO; // 限制一下
        }
        BOOL visible = !_entity.hidden; // 获取当前状态
        
        for (int i = 0; i < iCount; i ++)
        {
            // 显示、隐藏操作的参数都是空
            UIADPropertyValue* value = [UIADPropertyValue valueAsNone];
            NSTimeInterval eventTime = context.operation.timeLine.time + [interval doubleValue] * i;
            UIADTimeLine* timeLine = context.functionEvent ? [context.functionEvent getTimeLine:eventTime] : [context.program getTimeLine:eventTime];
            [timeLine addOperation:UIAD_OPERATION_ASSIGN parameters:[NSDictionary dictionaryWithObjectsAndKeys:self, @"object", visible ? @"hide" : @"show", @"name", value, @"value", nil] line:context.operation.line runtime:YES precondition:context.operation.precondition];
            visible = !visible;
        }
        
        return YES;
    }
    else if ([name isEqualToString:@"tapEvent"])
    {
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            if ([context.program addTapGestureEvent:value.stringValue arguments:nil entity:_entity context:context])
            {
                return YES;
            }
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
        {
            UIADPropertyValue* eventName = [value.arrayValue objectAtIndex:0];
            UIADPropertyValue* eventParameters = [value.arrayValue objectAtIndex:1];
            if (eventName.type == UIAD_PROPERTY_VALUE_STRING && eventParameters.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                NSArray* arguments = [eventParameters evaluateArrayAsParameterArray:nil context:context];
                if (arguments)
                {
                    if ([context.program addTapGestureEvent:eventName.stringValue arguments:arguments entity:_entity context:context])
                    {
                        return YES;
                    }
                }
            }
        }
    }
    else if ([name isEqualToString:@"free"])
    {
        if (_functionEvent)
        {
            if (![_functionEvent removeLocalObject:self])
            {
                return NO;
            }
            _functionEvent = nil;
        }
        [_entity removeFromSuperview];
        [_entity release];
        _entity = nil;
        return YES;
    }
    else if ([name isEqualToString:@"transit"])
    {
        BOOL flag = NO;
        NSString* imageName = nil;
        NSTimeInterval duration = 1.0f;
        UIViewAnimationTransition transition = UIViewAnimationTransitionFlipFromLeft;
        
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            imageName = value.stringValue;
            flag = imageName != nil;
        }
        else if (value.type == UIAD_PROPERTY_VALUE_DICTIONARY)
        {
            UIADPropertyValue* imageNameValue = [value.dictionaryValue objectForKey:@"image"];
            UIADPropertyValue* durationValue = [value.dictionaryValue objectForKey:@"duration"];
            UIADPropertyValue* transitionTypeValue = [value.dictionaryValue objectForKey:@"transition"];
            
            if (imageNameValue.type == UIAD_PROPERTY_VALUE_STRING)
            {
                flag = YES;
                imageName = imageNameValue.stringValue;
            }
            else if (imageNameValue.type == UIAD_PROPERTY_VALUE_ARRAY && [imageNameValue.arrayValue count] == 2)
            {
                UIADPropertyValue* format = [imageNameValue.arrayValue objectAtIndex:0];
                UIADPropertyValue* arguments = [imageNameValue.arrayValue objectAtIndex:1];
                if (format.type == UIAD_PROPERTY_VALUE_STRING && arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
                {
                    NSString* formattedName = [UIADPropertyValue evaluateFormat:format.stringValue withArguments:arguments object:self context:context];
                    if (formattedName)
                    {
                        flag = YES;
                        imageName = formattedName;
                    }
                }
            }

            if (flag && durationValue && durationValue.type == UIAD_PROPERTY_VALUE_NUMBER)
            {
                NSNumber* value = [durationValue evaluateNumberWithObject:self context:context];
                flag = value && ([value doubleValue] > 0.0f);
                if (flag)
                {
                    duration = [value doubleValue];
                }
            }
            
            if (flag && transitionTypeValue && transitionTypeValue.type == UIAD_PROPERTY_VALUE_STRING)
            {
                if ([transitionTypeValue.stringValue isEqualToString:@"none"])
                {
                    transition = UIViewAnimationTransitionNone;
                }
                else if ([transitionTypeValue.stringValue isEqualToString:@"flipLeft"])
                {
                    transition = UIViewAnimationTransitionFlipFromLeft;
                }
                else if ([transitionTypeValue.stringValue isEqualToString:@"flipRight"])
                {
                    transition = UIViewAnimationTransitionFlipFromRight;
                }
                else if ([transitionTypeValue.stringValue isEqualToString:@"curlUp"])
                {
                    transition = UIViewAnimationTransitionCurlUp;
                }
                else if ([transitionTypeValue.stringValue isEqualToString:@"curlDown"])
                {
                    transition = UIViewAnimationTransitionCurlDown;
                }
                else
                {
                    flag = NO;
                }
            }
        }
        
        if (flag)
        {
            UIImage* image = [_scene getImageFile:imageName context:context];
            if (image)
            {
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationTransition:transition forView:_entity cache:YES];
                [UIView setAnimationDuration:duration];
                _entity.layer.contents = (id)image.CGImage;
                [UIView commitAnimations];
                return YES;
            }
        }
    }
    else if ([name isEqualToString:@"marqueeText"])
    {
        NSString* text = nil;
        NSNumber* duration = [NSNumber numberWithDouble:_defaultMarqueeTextDuration];
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            text = value.stringValue;
        }
        else if (value.type == UIAD_PROPERTY_VALUE_DICTIONARY)
        {
            UIADPropertyValue* textValue = [value.dictionaryValue objectForKey:@"text"];
            UIADPropertyValue* durationValue = [value.dictionaryValue objectForKey:@"duration"];
            if (textValue && textValue.type == UIAD_PROPERTY_VALUE_STRING && durationValue && durationValue.type == UIAD_PROPERTY_VALUE_NUMBER)
            {
                text = textValue.stringValue;
                duration = [durationValue evaluateNumberWithObject:self context:context];
            }
        }
        
        if (text && duration)
        {
            UIADMarqueeLabel* label = [[UIADMarqueeLabel alloc] initWithFrame:CGRectMake(0, _entity.bounds.size.height, _entity.bounds.size.width, 0)];
            label.text = text;
#ifdef __IPHONE_7_0
            label.textAlignment = NSTextAlignmentCenter;
            label.lineBreakMode = NSLineBreakByTruncatingMiddle;
#else
            label.textAlignment = UITextAlignmentCenter;
            label.lineBreakMode = UILineBreakModeMiddleTruncation;
#endif
            label.adjustsFontSizeToFitWidth = YES;
            label.backgroundColor = [UIColor clearColor];
            label.font = [UIFont systemFontOfSize:UIAD_MARQUEE_TEXT_FONT];
            label.marqueeIndex = _marqueeTextIndex ++;
            [_entity addSubview:label];
            [label release];
            
            if (_marqueeTexts == nil)
            {
                _marqueeTexts = [[NSMutableArray alloc] initWithCapacity:10];
            }
            [_marqueeTexts addObject:label];
            
            // 用户配置label
            for (UIADMarqueeLabel* labelItem in _marqueeTexts)
            {
                [context.mainView marqueeTextConfigureLabel:labelItem object:self newLine:labelItem == label];
            }
            
            // 开始执行动画
            CGFloat delta = -label.frame.size.height;
            CGFloat slope = 1 / (_entity.bounds.size.height + 0.5 * delta);
            label.alpha = 0.0f;
            [UIView animateWithDuration:[duration floatValue]
                             animations:^ () {
                                 CGFloat scaleFactor = 1.0f;
                                 for (int i = [_marqueeTexts count] - 1; i >= 0; i --)
                                 {
                                     UIADMarqueeLabel* labelItem = _marqueeTexts[i];
                                     CGFloat destCenterX = labelItem.center.x;
                                     CGFloat destCenterY = labelItem.center.y + delta;
                                     labelItem.center = CGPointMake(destCenterX, destCenterY);
                                     labelItem.alpha = slope * destCenterY;
                                     labelItem.transform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
                                     scaleFactor *= _marqueeTextScaleFactor;
                                 }
                             }
                             completion:^ (BOOL finished) {
                                 for (int i = [_marqueeTexts count] - 1; i >= 0; i --)
                                 {
                                     UIADMarqueeLabel* labelItem = _marqueeTexts[i];
                                     if (labelItem.center.y < -labelItem.bounds.size.height / 2)
                                     {
                                         [labelItem removeFromSuperview];
                                         [_marqueeTexts removeObjectAtIndex:i];
                                     }
                                 }
                             }];
        }
        return YES;
    }
    else if ([name isEqualToString:@"setDefaultMarqueeTextDuration"])
    {
        NSNumber* duration = [value evaluateNumberWithObject:self context:context];
        if (duration && [duration doubleValue] > 0.0f)
        {
            _defaultMarqueeTextDuration = (NSTimeInterval)[duration doubleValue];
            return YES;
        }
    }
    else if ([name isEqualToString:@"marqueeTexts"])
    {
        UIADPropertyValue* delayValue = [value.dictionaryValue objectForKey:@"delay"];
        UIADPropertyValue* durationValue = [value.dictionaryValue objectForKey:@"duration"];
        UIADPropertyValue* intervalValue = [value.dictionaryValue objectForKey:@"interval"];
        UIADPropertyValue* textsValue = [value.dictionaryValue objectForKey:@"texts"];
        
        BOOL flag = intervalValue && textsValue && (textsValue.type == UIAD_PROPERTY_VALUE_ARRAY) && ([textsValue.arrayValue count] > 0);
        NSTimeInterval delay = 0.0f;
        
        if (flag && delayValue)
        {
            flag = NO;
            NSNumber* value = [delayValue evaluateNumberWithObject:self context:context];
            if (value && [value doubleValue] >= 0.0f)
            {
                flag = YES;
                delay = [value doubleValue];
            }
        }
        
        NSNumber* duration = [NSNumber numberWithDouble:_defaultMarqueeTextDuration];
        if (flag && durationValue)
        {
            flag = NO;
            NSNumber* value = [durationValue evaluateNumberWithObject:self context:context];
            if (value && [value doubleValue] > 0.0f)
            {
                flag = YES;
                duration = value;
            }
        }
        
        NSTimeInterval interval = 1.0f;
        if (flag)
        {
            flag = NO;
            NSNumber* value = [intervalValue evaluateNumberWithObject:self context:context];
            if (value && [value doubleValue] > 0.0f)
            {
                flag = YES;
                interval = [value doubleValue];
            }
        }
        
        if (flag)
        {
            // 校验textsValue里是不是都是字符串
            for (UIADPropertyValue* value in textsValue.arrayValue)
            {
                if (value.type != UIAD_PROPERTY_VALUE_STRING)
                {
                    flag = NO;
                    break;
                }
            }
        }
        
        if (flag)
        {
            NSTimeInterval eventTime = context.operation.timeLine.time + delay;
            for (UIADPropertyValue* value in textsValue.arrayValue)
            {
                NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:[UIADPropertyValue valueAsString:value.stringValue], @"text", [UIADPropertyValue valueAsNumber:duration], @"duration", nil];
                UIADPropertyValue* value = [UIADPropertyValue valueAsDictionary:params];
                
                UIADTimeLine* timeLine = context.functionEvent ? [context.functionEvent getTimeLine:eventTime] : [context.program getTimeLine:eventTime];
                [timeLine addOperation:UIAD_OPERATION_ASSIGN parameters:[NSDictionary dictionaryWithObjectsAndKeys:self, @"object", @"marqueeText", @"name", value, @"value", nil] line:context.operation.line runtime:YES precondition:UIAD_NO_PRECONDITION];
                
                eventTime += interval;
            }
            
            UIADPropertyValue* stopEventValue = [value.dictionaryValue objectForKey:@"stopEvent"];
            if (stopEventValue)
            {
                eventTime -= interval;
                UIADTimeLine* timeLine = context.functionEvent ? [context.functionEvent getTimeLine:eventTime] : [context.program getTimeLine:eventTime];
                [timeLine addOperation:UIAD_OPERATION_ASSIGN parameters:[NSDictionary dictionaryWithObjectsAndKeys:self, @"object", @"event", @"name", stopEventValue, @"value", nil] line:context.operation.line runtime:YES precondition:UIAD_NO_PRECONDITION];
            }
            
            return YES;
        }
    }
    else if ([name isEqualToString:@"setMarqueeTextScaleFactor"])
    {
        NSNumber* scale = [value evaluateNumberWithObject:self context:context];
        if (scale && [scale doubleValue] <= 1.0 && [scale doubleValue] >= 0.0f)
        {
            _marqueeTextScaleFactor = [scale floatValue];
            return YES;
        }
    }
    else if ([name isEqualToString:@"invoke"])
    {
        // 调用外部方法
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            SEL selector = NSSelectorFromString(value.stringValue);
            if (context.invokeResponder && [context.invokeResponder respondsToSelector:selector])
            {
                [context.invokeResponder performSelector:selector];
                return YES;
            }
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
        {
            UIADPropertyValue* selectorName = [value.arrayValue objectAtIndex:0];
            UIADPropertyValue* parameter = [value.arrayValue objectAtIndex:1];
            if (selectorName.type == UIAD_PROPERTY_VALUE_STRING && parameter.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:", selectorName.stringValue]);
                if (context.invokeResponder && [context.invokeResponder respondsToSelector:selector])
                {
                    NSArray* arguments = [parameter evaluateArrayAsParameterArray:self context:context];
                    [context.invokeResponder performSelector:selector withObject:arguments];
                    return YES;
                }
            }
        }
    }
    else if ([name isEqualToString:@"event"])
    {
        // 调用内部方法
        if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            return [context.program executeEvent:value.stringValue arguments:nil context:context];
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
        {
            UIADPropertyValue* eventName = [value.arrayValue objectAtIndex:0];
            UIADPropertyValue* eventArguments = [value.arrayValue objectAtIndex:1];
            if (eventName.type == UIAD_PROPERTY_VALUE_STRING && eventArguments.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                NSArray* arguments = [eventArguments evaluateArrayAsParameterArray:self context:context];
                if (arguments)
                {
                    return [context.program executeEvent:eventName.stringValue arguments:arguments context:context];
                }
            }
        }
    }
    
    return NO;
}

@end

#pragma mark -

/// UIADPropertyValue

typedef NSNumber UIADOperator;

@interface NSNumber(UIAD_NUM_OP)

- (BOOL)is:(int)op;

@end

@implementation NSNumber(UIAD_NUM_OP)

- (BOOL)is:(int)op
{
    return [self intValue] == op;
}

- (int)op
{
    return [self intValue];
}

@end

@implementation NSBool

@synthesize value = _value;

+ (NSBool*)boolWithValue:(BOOL)value
{
    NSBool* r = [[NSBool alloc] init];
    r.value = value;
    return [r autorelease];
}

- (void)setNot
{
    _value = !_value;
}

@end

// 运算表达式的运算符
enum UIAD_NUMBER_OPERATORS
{
    UIAD_NUM_OP_LB,         // 左括号      (
    UIAD_NUM_OP_RB,         // 右括号      )
    UIAD_NUM_OP_POS,        // 正号       +
    UIAD_NUM_OP_NEG,        // 负号       -
    UIAD_NUM_OP_ADD,        // 加号       +
    UIAD_NUM_OP_SUB,        // 减号       -
    UIAD_NUM_OP_MUL,        // 乘号       *
    UIAD_NUM_OP_DIV,        // 除号       /
    UIAD_NUM_OP_INT_DIV,    // 整除       '\'
    UIAD_NUM_OP_MODULO,     // 取模       %
    UIAD_NUM_OP_NOT,        // 非        !
    UIAD_NUM_OP_AND,        // 与        &
    UIAD_NUM_OP_OR,         // 或        |
    UIAD_NUM_OP_XOR,        // 异或       ^
    UIAD_NUM_OP_LA,         // 大于       >
    UIAD_NUM_OP_LA_E,       // 大于 等于    >=
    UIAD_NUM_OP_LE,         // 小于       <
    UIAD_NUM_OP_LE_E,       // 小于等于     <=
    UIAD_NUM_OP_EQU,        // 等于       ==
    UIAD_NUM_OP_NOT_EQU,    // 不等于      !=
    UIAD_NUM_OP_END,        // 结束符
    UIAD_NUM_OP_COUNT,
};

#define UIAD_NUM_OP_END_PRI     0
#define UIAD_NUM_OP_LB_PRI      (UIAD_NUM_OP_END_PRI + 1)
#define UIAD_NUM_OP_RB_PRI      (UIAD_NUM_OP_LB_PRI + 1)
#define UIAD_NUM_OP_OR_XOR_PRI  (UIAD_NUM_OP_RB_PRI + 1)            // 或与异或
#define UIAD_NUM_OP_AND_PRI     (UIAD_NUM_OP_OR_XOR_PRI + 1)        // 与
#define UIAD_NUM_OP_CMP_PRI     (UIAD_NUM_OP_AND_PRI + 1)           // 大于、大于等于、小于、小于等于
#define UIAD_NUM_OP_EQU_PRI     (UIAD_NUM_OP_CMP_PRI + 1)           // 等于、不等于
#define UIAD_NUM_OP_AM_PRI      (UIAD_NUM_OP_EQU_PRI + 1)           // 加减
#define UIAD_NUM_OP_MD_PRI      (UIAD_NUM_OP_AM_PRI + 1)            // 乘除
#define UIAD_NUM_OP_SIGN_PRI    (UIAD_NUM_OP_MD_PRI + 1)            // 正负号
#define UIAD_NUM_OP_NOT_PRI     (UIAD_NUM_OP_SIGN_PRI)              // 非

#define UIAD_NUM_OP_OF(op)      [UIADOperator numberWithInt:op]

// 运算符优先级
const int UIAD_NUM_OP_PRIORITY[] =
{
    UIAD_NUM_OP_LB_PRI,         // UIAD_NUM_OP_LB
    UIAD_NUM_OP_RB_PRI,         // UIAD_NUM_OP_RB
    UIAD_NUM_OP_SIGN_PRI,       // UIAD_NUM_OP_POS
    UIAD_NUM_OP_SIGN_PRI,       // UIAD_NUM_OP_NEG
    UIAD_NUM_OP_AM_PRI,         // UIAD_NUM_OP_ADD
    UIAD_NUM_OP_AM_PRI,         // UIAD_NUM_OP_SUB
    UIAD_NUM_OP_MD_PRI,         // UIAD_NUM_OP_MUL
    UIAD_NUM_OP_MD_PRI,         // UIAD_NUM_OP_DIV
    UIAD_NUM_OP_MD_PRI,         // UIAD_NUM_OP_INT_DIV
    UIAD_NUM_OP_MD_PRI,         // UIAD_NUM_OP_MODULO
    UIAD_NUM_OP_NOT_PRI,        // UIAD_NUM_OP_NOT
    UIAD_NUM_OP_AND_PRI,        // UIAD_NUM_OP_AND
    UIAD_NUM_OP_OR_XOR_PRI,     // UIAD_NUM_OP_OR
    UIAD_NUM_OP_OR_XOR_PRI,     // UIAD_NUM_OP_XOR
    UIAD_NUM_OP_CMP_PRI,        // UIAD_NUM_OP_LA
    UIAD_NUM_OP_CMP_PRI,        // UIAD_NUM_OP_LA_E
    UIAD_NUM_OP_CMP_PRI,        // UIAD_NUM_OP_LE
    UIAD_NUM_OP_CMP_PRI,        // UIAD_NUM_OP_LE_E
    UIAD_NUM_OP_EQU_PRI,        // UIAD_NUM_OP_EQU
    UIAD_NUM_OP_EQU_PRI,        // UIAD_NUM_OP_NOT_EQU
    UIAD_NUM_OP_END_PRI,        // UIAD_NUM_OP_END
};

@implementation UIADPropertyValue

@synthesize type = _type;

@synthesize dictionaryValue = _dictionaryValue;
@synthesize arrayValue = _arrayValue;
@synthesize numberValue = _numberValue;
@synthesize stringValue = _stringValue;

+ (UIADPropertyValue*)valueAsNone
{
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = UIAD_PROPERTY_VALUE_NONE;
    return [value autorelease];
}

+ (UIADPropertyValue*)valueAsNumber:(NSNumber*)number
{
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = UIAD_PROPERTY_VALUE_NUMBER;
    value.numberValue = number;
    return [value autorelease];
}

+ (UIADPropertyValue*)valueAsNumberWithString:(NSString*)string
{
    return [UIADPropertyValue valueAsType:UIAD_PROPERTY_VALUE_NUMBER withString:string];
}

+ (UIADPropertyValue*)valueAsType:(int)type withString:(NSString*)string
{
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = type;
    value.stringValue = string;
    return [value autorelease];
}

+ (UIADPropertyValue*)valueAsString:(NSString*)string
{
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = UIAD_PROPERTY_VALUE_STRING;
    value.stringValue = string;
    return [value autorelease];
}

+ (UIADPropertyValue*)valueAsArray:(NSArray*)array
{
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = UIAD_PROPERTY_VALUE_ARRAY;
    value.arrayValue = array;
    return [value autorelease];
}

+ (UIADPropertyValue*)valueAsDictionary:(NSDictionary*)dictionary
{
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = UIAD_PROPERTY_VALUE_DICTIONARY;
    value.dictionaryValue = dictionary;
    return [value autorelease];
}

- (void)dealloc
{
    [_dictionaryValue release];
    [_arrayValue release];
    [_numberValue release];
    [_stringValue release];
    [super dealloc];
}

// 判断operator1是否比operator2优先级高，或与operator2相同
- (BOOL)compareOperator:(UIADOperator*)operator1 operator2:(UIADOperator*)operator2
{
    return UIAD_NUM_OP_PRIORITY[[operator1 op]] >= UIAD_NUM_OP_PRIORITY[[operator2 op]];
}

- (BOOL)popWithOperator:(UIADOperator*)operator operandStack:(NSMutableArray*)operandStack operatorStack:(NSMutableArray*)operatorStack
{
    typedef BOOL (^UIADOperatorIMP)(void);
    UIADOperatorIMP IMPS[UIAD_NUM_OP_COUNT] = {
        nil, // UIAD_NUM_OP_LB
        nil, // UIAD_NUM_OP_RB
        
        ^(void)
        {
            id num = [operandStack pop];
            if (num == nil || ![num isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:num];
            return YES;
        }, // UIAD_NUM_OP_POS
        
        ^(void)
        {
            id num = [operandStack pop];
            if (num == nil || ![num isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:-[num doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_NEG
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:[num1 doubleValue] + [num2 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_ADD
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:[num2 doubleValue] - [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_SUB
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:[num1 doubleValue] * [num2 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_MUL

        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:[num2 doubleValue] / [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_DIV
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:lrint([num2 doubleValue]) / lrint([num1 doubleValue])]];
            return YES;
        }, // UIAD_NUM_OP_INT_DIV
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSNumber numberWithDouble:lrint([num2 doubleValue]) % lrint([num1 doubleValue])]];
            return YES;
        }, // UIAD_NUM_OP_MODULO
        
        ^(void)
        {
            id num = [operandStack pop];
            if (num == nil || ![num isKindOfClass:[NSBool class]])
            {
                return NO;
            }
            [num setNot];
            [operandStack push:num];
            return YES;
        }, // UIAD_NUM_OP_NOT
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSBool class]] || ![num2 isKindOfClass:[NSBool class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[(NSBool*)num1 value] && [(NSBool*)num2 value]]];
            return YES;
        }, // UIAD_NUM_OP_AND
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSBool class]] || ![num2 isKindOfClass:[NSBool class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[(NSBool*)num1 value] || [(NSBool*)num2 value]]];
            return YES;
        }, // UIAD_NUM_OP_OR
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSBool class]] || ![num2 isKindOfClass:[NSBool class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[(NSBool*)num1 value] != [(NSBool*)num2 value]]];
            return YES;
        }, // UIAD_NUM_OP_XOR
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[num2 doubleValue] > [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_LA
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[num2 doubleValue] >= [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_LA_E
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[num2 doubleValue] < [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_LE
        
        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[num2 doubleValue] <= [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_LE_E

        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[num2 doubleValue] == [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_EQU

        ^(void)
        {
            id num1 = [operandStack pop];
            id num2 = [operandStack pop];
            if (num1 == nil || num2 == nil || ![num1 isKindOfClass:[NSNumber class]] || ![num2 isKindOfClass:[NSNumber class]])
            {
                return NO;
            }
            [operandStack push:[NSBool boolWithValue:[num2 doubleValue] != [num1 doubleValue]]];
            return YES;
        }, // UIAD_NUM_OP_NOT_EQU

        nil, // UIAD_NUM_OP_END
    };
    
    // 比较operator与operatorStack里的栈顶符号，如果operator优先级低于栈顶优先级，则弹出并做运算
    while ([operatorStack peek] && [self compareOperator:[operatorStack peek] operator2:operator])
    {
        UIADOperator* op = [operatorStack pop];
        if (IMPS[[op op]] == nil || !IMPS[[op op]]())
        {
            return NO;
        }
    }
    
    if ([operator is:UIAD_NUM_OP_RB])
    {
        UIADOperator* op = [operatorStack pop];
        if (op == nil || ![op is:UIAD_NUM_OP_LB])
        {
            return NO;
        }
    }
    
    return YES;
}

+ (BOOL)parseExpressionObjectField:(NSString*)source at:(int*)i offset:(int)offset dotSymbol:(BOOL)dotSymbol result:(UIADPropertyValue**)result
{
    int bracket = 1, squareBracket = 0;
    BOOL inString = NO;
    BOOL valid = NO;
    
    int initial = *i;
    *i += offset;
    
    if (!dotSymbol)
    {
        source = [source trimmed];
    }
    
    // 找下个小括号
    while (*i < [source length])
    {
        unichar c = [source characterAtIndex:*i];
        if (c == '(')
        {
            bracket ++;
        }
        else if (c == ')')
        {
            bracket --;
            if (bracket == 0 && squareBracket == 0 && !inString)
            {
                if (dotSymbol)
                {
                    // 找到了匹配的右括号，检查下面的字符是不是"."
                    (*i) ++;
                    valid = ((*i) < [source length]) && ([source characterAtIndex:*i] == '.');
                }
                else
                {
                    // i需要是最后一个字符
                    valid = ((*i) == [source length] - 1);
                }
                break;
            }
        }
        else if (c == '[')
        {
            squareBracket ++;
        }
        else if (c == ']')
        {
            squareBracket --;
        }
        else if (c == '"')
        {
            inString = !inString;
        }
        
        (*i) ++;
    }
    
    if (valid)
    {
        NSString* content = [[source substringWithRange:NSMakeRange(initial + offset, *i - initial - offset - (dotSymbol ? 1 : 0))] trimmed];
        *result = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"[%@]", content]];
        valid = (*result != nil);
    }
    
    return valid;
}

+ (NSString*)evaluateFormat:(NSString*)format withArguments:(UIADPropertyValue*)arguments object:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
    {
        NSArray* parsedArgs = [arguments evaluateArrayAsParameterArray:object context:context];
        if (parsedArgs)
        {
            BOOL flag = NO;
            NSMutableArray* args = [NSMutableArray arrayWithArray:parsedArgs];
            NSMutableString* built = [NSMutableString stringWithCapacity:[format length] * 2];
            for (unsigned int i = 0; i < [format length]; i ++)
            {
                unichar c = [format characterAtIndex:i];
                if (flag)
                {
                    flag = NO;
                    if (c == 'd' || c == 'D')
                    {
                        if ([args count] > 0)
                        {
                            id arg = [args objectAtIndex:0];
                            if ([arg isKindOfClass:[UIADPropertyValue class]] && ((UIADPropertyValue*)arg).type == UIAD_PROPERTY_VALUE_NUMBER)
                            {
                                [built appendFormat:@"%ld", lrint([((UIADPropertyValue*)arg).numberValue doubleValue])];
                                [args removeObjectAtIndex:0];
                                continue;
                            }
                        }
                        return nil; // 参数类型错误或少参数
                    }
                    else if (c == 'f' || c == 'F')
                    {
                        if ([args count] > 0)
                        {
                            id arg = [args objectAtIndex:0];
                            if ([arg isKindOfClass:[UIADPropertyValue class]] && ((UIADPropertyValue*)arg).type == UIAD_PROPERTY_VALUE_NUMBER)
                            {
                                [built appendFormat:@"%f", [((UIADPropertyValue*)arg).numberValue doubleValue]];
                                [args removeObjectAtIndex:0];
                                continue;
                            }
                        }
                        return nil; // 参数类型错误或少参数
                    }
                    else if (c == 's' || c == 'S')
                    {
                        if ([args count] > 0)
                        {
                            id arg = [args objectAtIndex:0];
                            if ([arg isKindOfClass:[UIADPropertyValue class]] && ((UIADPropertyValue*)arg).type == UIAD_PROPERTY_VALUE_STRING)
                            {
                                [built appendString:((UIADPropertyValue*)arg).stringValue];
                                [args removeObjectAtIndex:0];
                                continue;
                            }
                        }
                        return nil; // 参数类型错误或少参数
                    }
                    else if (c == '%')
                    {
                        [built appendString:@"%"];
                    }
                    else
                    {
                        return nil; // Invalid format
                    }
                }
                else if (c == '%')
                {
                    flag = YES;
                }
                else
                {
                    [built appendString:[format substringWithRange:NSMakeRange(i, 1)]];
                }
            }
            
            return flag ? nil : built; // 如果有残留%，说明格式错误
        }
    }
    
    return nil;
}

- (NSString*)evaluateFormatAsStringWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (_type == UIAD_PROPERTY_VALUE_ARRAY)
    {
        // image:("btn_video%d.png", [1])
        if ([_arrayValue count] == 2)
        {
            UIADPropertyValue* format = [_arrayValue objectAtIndex:0];
            UIADPropertyValue* arguments = [_arrayValue objectAtIndex:1];
            if (format.type == UIAD_PROPERTY_VALUE_STRING)
            {
                return [UIADPropertyValue evaluateFormat:format.stringValue withArguments:arguments object:object context:context];
            }
        }
    }
    else if (_type == UIAD_PROPERTY_VALUE_STRING)
    {
        // image:"btn_video.png"
        return _stringValue;
    }
    
    return nil;
}

- (NSNumber*)evaluateNumberWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    setLastError(context, @"Expression evaluation error.");
    
    if (_type != UIAD_PROPERTY_VALUE_NUMBER)
    {
        return nil;
    }
    
    if (_numberValue)
    {
        clearLastError(context);
        return _numberValue;
    }
    
    if (_stringValue == nil || [_stringValue length] == 0)
    {
        return nil;
    }
    
    BOOL shouldBeSign = YES;
    BOOL macroExpected = NO;
    NSMutableArray* operands = [NSMutableArray arrayWithCapacity:20]; // 运算对象
    NSMutableArray* operators = [NSMutableArray arrayWithCapacity:20]; // 运算符
    
    id currentObject = object;
    
    int i = 0;
    while (i < [_stringValue length])
    {
        BOOL state = YES;
        unichar c = [_stringValue characterAtIndex:i];
        unichar nextC = (i < [_stringValue length] - 1) ? [_stringValue characterAtIndex:i + 1] : (unichar)0;
        
        if (macroExpected && (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == ' ')))
        {
            return nil;
        }
        
        switch (c)
        {
            case ' ':
                break;
            case '(':
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_LB)];
                break;
            case ')':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_RB) operandStack:operands operatorStack:operators];
                break;
            case '+':
                if (shouldBeSign)
                {
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_POS)]; // positive
                }
                else
                {
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_ADD) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_ADD)];
                }
                break;
            case '-':
                if (shouldBeSign)
                {
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_NEG)]; // negative
                }
                else
                {
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_SUB) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_SUB)];
                }
                break;
            case '*':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_MUL) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_MUL)];
                break;
            case '/':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_DIV) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_DIV)];
                break;
            case '\\':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_INT_DIV) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_INT_DIV)];
                break;
            case '%':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_MODULO) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_MODULO)];
                break;
            case '!':
                if (nextC == '=')
                {
                    i ++;
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_NOT_EQU) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_NOT_EQU)];
                }
                else
                {
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_NOT)];
                }
                break;
            case '&':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_AND) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_AND)];
                break;
            case '|':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_OR) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_OR)];
                break;
            case '^':
                state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_XOR) operandStack:operands operatorStack:operators];
                [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_XOR)];
                break;
            case '>':
                if (nextC == '=')
                {
                    i ++;
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_LA_E) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_LA_E)];
                }
                else
                {
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_LA) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_LA)];
                }
                break;
            case '<':
                if (nextC == '=')
                {
                    i ++;
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_LE_E) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_LE_E)];
                }
                else
                {
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_LE) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_LE)];
                }
                break;
            case '=':
                if (nextC == '=')
                {
                    i ++;
                    state = [self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_EQU) operandStack:operands operatorStack:operators];
                    [operators push:UIAD_NUM_OP_OF(UIAD_NUM_OP_EQU)];
                }
                else
                {
                    setLastError(context, @"\"==\" for equal comparison.");
                    state = NO;
                }
                break;
            case '0'...'9':
            {
                // 检索数字
                int initial = i;
                BOOL hasDot = NO;
                i ++;
                while (i < [_stringValue length] + 1)
                {
                    unichar cc;
                    
                    if (i == [_stringValue length])
                    {
                        cc = '!'; // 随便一个非0~9，非.的字符就行
                    }
                    else
                    {
                        cc = [_stringValue characterAtIndex:i];
                    }

                    if (cc == '.')
                    {
                        if (hasDot)
                        {
                            return nil;
                        }
                        else
                        {
                            i ++;
                            hasDot = YES;
                        }
                    }
                    else if (cc >= '0' && cc <= '9')
                    {
                        i ++;
                    }
                    else
                    {
                        // 非数字字符
                        double d;
                        NSString* numberStr = [_stringValue substringWithRange:NSMakeRange(initial, i - initial)];
                        if ([numberStr toDouble:&d])
                        {
                            [operands push:[NSNumber numberWithDouble:d]]; // 搜索到一个操作数
                        }
                        else
                        {
                            return nil;
                        }
                        i --; // 后面还要再加一次
                        break;
                    }
                }
            }
                break;
            case 'A'...'Z':
            case 'a'...'z':
            case '_':
            {
                if (context && context.evaluateAllowObject)
                {
                    if (c == 'o' || c == 'l')
                    {
                        BOOL result = NO, isLocal = NO;
                        NSString* tmpStr = [_stringValue substringFromIndex:i];
                        UIADPropertyValue* objectDesc = nil;
                        if ([tmpStr hasPrefix:@"object("])
                        {
                            result = !macroExpected && [UIADPropertyValue parseExpressionObjectField:_stringValue at:&i offset:7 dotSymbol:YES result:&objectDesc];
                        }
                        else if ([tmpStr hasPrefix:@"localObject("])
                        {
                            isLocal = YES;
                            result = !macroExpected && [UIADPropertyValue parseExpressionObjectField:_stringValue at:&i offset:12 dotSymbol:YES result:&objectDesc];
                        }
                        
                        if (result)
                        {
                            result = NO;
                            if (objectDesc.type == UIAD_PROPERTY_VALUE_ARRAY)
                            {
                                if ([objectDesc.arrayValue count] == 1)
                                {
                                    UIADPropertyValue* value = [objectDesc.arrayValue objectAtIndex:0];
                                    if (value.type == UIAD_PROPERTY_VALUE_STRING)
                                    {
                                        // object("xxx")或localObject("xxx")
                                        if ([value.stringValue isValidName])
                                        {
                                            UIADObject* foundObject = nil;
                                            if (!isLocal)
                                            {
                                                foundObject = [context.scene objectWithNameNoCreate:value.stringValue];
                                            }
                                            else if (context && context.functionEvent)
                                            {
                                                foundObject = [context.functionEvent localObjectWithName:value.stringValue context:context allowCreate:NO];
                                            }
                                            
                                            if (foundObject)
                                            {
                                                currentObject = foundObject;
                                                macroExpected = YES;
                                                break; // break switch
                                            }
                                        }
                                    }
                                    else if (value.type == UIAD_PROPERTY_VALUE_NUMBER)
                                    {
                                        // object(xxx)，这种中间是不加引号的参数名
                                        if (isLocal && [value.stringValue isValidPropertyName])
                                        {
                                            currentObject = [context.functionEvent argumentValue:value.stringValue];
                                            if (currentObject && [currentObject isKindOfClass:[UIADObject class]])
                                            {
                                                macroExpected = YES;
                                                break; // break switch
                                            }
                                        }
                                    }
                                }
                                else
                                {
                                    // object("wall%d", [index])，localObject("wall%d", [index])
                                    UIADPropertyValue* format = [objectDesc.arrayValue objectAtIndex:0];
                                    UIADPropertyValue* arguments = [objectDesc.arrayValue objectAtIndex:1];
                                    if (format.type == UIAD_PROPERTY_VALUE_STRING && arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
                                    {
                                        NSString* formattedName = [UIADPropertyValue evaluateFormat:format.stringValue withArguments:arguments object:currentObject context:context];
                                        if (formattedName && [formattedName length] > 0)
                                        {
                                            if (!isLocal)
                                            {
                                                UIADObject* object = [context.scene objectWithName:formattedName];
                                                currentObject = [object getObject:context];
                                                if (currentObject)
                                                {
                                                    macroExpected = YES;
                                                    break; // break switch
                                                }
                                            }
                                            else if (context && context.functionEvent)
                                            {
                                                currentObject = [context.functionEvent localObjectWithName:formattedName context:context allowCreate:NO];
                                                if (currentObject)
                                                {
                                                    macroExpected = YES;
                                                    break; // break switch
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if (!result)
                            {
                                return nil;
                            }
                        }
                    }
                    else if (c == 'p')
                    {
                        // 判断是不是parent
                        NSString* tmpStr = [_stringValue substringFromIndex:i];
                        if ([tmpStr hasPrefix:@"parent."])
                        {
                            i += 6;
                            currentObject = object.entity.superview;
                            macroExpected = YES;
                            break;
                        }
                    }
                }

                int initial = i;
                i ++;
                while (i < [_stringValue length] + 1)
                {
                    unichar cc;
                    
                    if (i == [_stringValue length])
                    {
                        cc = '!'; // 随便一个非'A'..'Z，'a'..'z'，'_'的字符就行
                    }
                    else
                    {
                        cc = [_stringValue characterAtIndex:i];
                    }
                    
                    if ((cc >= 'A' && cc <= 'Z') || (cc >= 'a' && cc <= 'z') || (cc == '_'))
                    {
                        i ++;
                    }
                    else
                    {
                        NSString* macroStr = [_stringValue substringWithRange:NSMakeRange(initial, i - initial)];
                        id value = [UIADPropertyValue valueFromIdentifier:macroStr object:currentObject context:context];
                        if (value && ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSBool class]]))
                        {
                            [operands push:value];
                            i --; // 后面还要再加一次
                            break;
                        }
                        else
                        {
                            return nil;
                        }
                    }
                }
                
                macroExpected = NO;
                currentObject = object;
            }
                break;
            default:
                state = NO;
                break;
        }
        
        if (!state)
        {
            return nil;
        }
        
        shouldBeSign = c == '('; // 如果当前是左括号，下面的+或-就应该是正负号
        i ++;
    }
    
    // 最后把所有都处理，#是结束符
    if (macroExpected || ![self popWithOperator:UIAD_NUM_OP_OF(UIAD_NUM_OP_END) operandStack:operands operatorStack:operators])
    {
        return nil;
    }
    
    if ([operands count] == 1)
    {
        clearLastError(context);
        return [operands bottom];
    }
    
    return nil;
}

- (NSArray*)evaluateArrayAsNumbersWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (_type != UIAD_PROPERTY_VALUE_ARRAY)
    {
        return nil;
    }
    
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:[_arrayValue count]];
    
    for (int i = 0; i < [_arrayValue count]; i ++)
    {
        UIADPropertyValue* value = [_arrayValue objectAtIndex:i];
        if (value.type != UIAD_PROPERTY_VALUE_NUMBER)
        {
            return nil;
        }
        
        NSNumber* number = [value evaluateNumberWithObject:object context:context];
        if (number == nil)
        {
            return nil;
        }
        
        [array addObject:number];
    }
    
    return array;
}

- (NSArray*)evaluateArrayAsParameterArray:(UIADObject*)object context:(UIADOperationContext*)context
{
    NSMutableArray* arguments = [NSMutableArray arrayWithCapacity:[_arrayValue count]];
    for (UIADPropertyValue* value in _arrayValue)
    {
        if (value.type == UIAD_PROPERTY_VALUE_NUMBER)
        {
            NSNumber* number = [value evaluateNumberWithObject:object context:context];
            if (number)
            {
                [arguments addObject:[UIADPropertyValue valueAsNumber:number]];
            }
            else
            {
                setLastError(context, @"Invalid agruments.");
                return nil;
            }
        }
        else if (value.type == UIAD_PROPERTY_VALUE_STRING)
        {
            [arguments addObject:value];
        }
        else if ([value isObject])
        {
            UIADObject* evaluatedObject = [value evaluateAsObjectWithObject:object context:context];
            if (evaluatedObject)
            {
                [arguments addObject:evaluatedObject];
            }
            else
            {
                setLastError(context, @"Object not found.");
                return nil;
            }
        }
        else if (value.type == UIAD_PROPERTY_VALUE_ARRAY)
        {
            setLastError(context, @"Invalid agruments.");
            return nil;
        }
        else
        {
            setLastError(context, @"Invalid agruments.");
            return nil;
        }
    }
    
    return arguments;
}

- (NSValue*)evaluateAsNSValueWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (_type == UIAD_PROPERTY_VALUE_NUMBER)
    {
        return [self evaluateNumberWithObject:object context:context];
    }
    else if (_type == UIAD_PROPERTY_VALUE_ARRAY)
    {
        if ([_arrayValue count] == 2)
        {
            NSArray* array = [self evaluateArrayAsNumbersWithObject:object context:context];
            if (array)
            {
                return [NSValue valueWithCGPoint:CGPointMake((CGFloat)[[array objectAtIndex:0] doubleValue], (CGFloat)[[array objectAtIndex:1] doubleValue])];
            }
        }
        else if ([_arrayValue count] == 3)
        {
            NSArray* array = [self evaluateArrayAsNumbersWithObject:object context:context];
            if (array)
            {
                return [NSValue valueWithCATransform3D:CATransform3DMakeScale((CGFloat)[[array objectAtIndex:0] doubleValue], (CGFloat)[[array objectAtIndex:1] doubleValue], (CGFloat)[[array objectAtIndex:2] doubleValue])];
            }
        }
        else if ([_arrayValue count] == 4)
        {
            NSArray* array = [self evaluateArrayAsNumbersWithObject:object context:context];
            if (array)
            {
                return [NSValue valueWithCGRect:CGRectMake((CGFloat)[[array objectAtIndex:0] doubleValue], (CGFloat)[[array objectAtIndex:1] doubleValue], (CGFloat)[[array objectAtIndex:2] doubleValue], (CGFloat)[[array objectAtIndex:3] doubleValue])];
            }
        }
    }
    
    return nil;
}

- (NSArray*)evaluateArrayAsNSValueArrayWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (_type != UIAD_PROPERTY_VALUE_ARRAY)
    {
        return nil;
    }

    NSMutableArray* result = [NSMutableArray arrayWithCapacity:[_arrayValue count]];
    for (int i = 0; i < [_arrayValue count]; i ++)
    {
        UIADPropertyValue* value = [_arrayValue objectAtIndex:i];
        NSValue* nsValue = [value evaluateAsNSValueWithObject:object context:context];
        if (nsValue == nil)
        {
            return nil;
        }
        [result addObject:nsValue];
    }
    
    return result;
}

- (UIColor*)evaluateArrayAsColorWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (_type != UIAD_PROPERTY_VALUE_ARRAY || _arrayValue == nil || ([_arrayValue count] != 4 && [_arrayValue count] != 3))
    {
        return nil;
    }
    
    CGFloat elements[4] = {0.0f, 0.0f, 0.0f, 1.0f}; // alpha default 1.0
    for (int i = 0; i < [_arrayValue count]; i ++)
    {
        UIADPropertyValue* pValue = [_arrayValue objectAtIndex:i];
        if (pValue.type != UIAD_PROPERTY_VALUE_NUMBER)
        {
            return nil;
        }
        
        NSNumber* value = [pValue evaluateNumberWithObject:object context:context];
        if (value == nil)
        {
            return nil;
        }
        
        elements[i] = (CGFloat)[value doubleValue];
    }
    
    return [UIColor colorWithRed:elements[0] green:elements[1] blue:elements[2] alpha:elements[3]];
}

- (NSNumber*)evaluateNumberAsDimensionWithObject:(UIADObject*)object dimension:(CGFloat)dimension context:(UIADOperationContext*)context;
{
    if (_type != UIAD_PROPERTY_VALUE_NUMBER)
    {
        return nil;
    }
    
    if (_numberValue)
    {
        // 如果直接有数值数据了，说明既不需要解析四则运算，也不需要计算相对坐标
        return _numberValue;
    }
    
    if (_stringValue == nil || [_stringValue length] == 0)
    {
        return nil;
    }
    
    if ([_stringValue hasSuffix:@"r"])
    {
        double value;
        NSString* numberContent = [[_stringValue substringToIndex:[_stringValue length] - 1] trimmed];
        if ([numberContent length] == 0)
        {
            // r, -r这种
            return [NSNumber numberWithDouble:dimension];
        }
        else if ([numberContent isEqualToString:@"-"])
        {
            return [NSNumber numberWithDouble:-dimension];
        }
        
        NSScanner* scanner = [NSScanner scannerWithString:numberContent];
        if ([scanner scanDouble:&value])
        {
            return [NSNumber numberWithDouble:dimension * value];
        }
        
        return nil;
    }
    
    // 解析表达式
    return [self evaluateNumberWithObject:object context:context];
}

- (BOOL)isObject
{
    return _type == UIAD_PROPERTY_VALUE_OBJECT || _type == UIAD_PROPERTY_VALUE_OBJECT_REF ||
        _type == UIAD_PROPERTY_VALUE_OBJECT_FMT || _type == UIAD_PROPERTY_VALUE_OBJECT_LOCAL ||
        _type == UIAD_PROPERTY_VALUE_OBJECT_LOCAL_FMT;
}

- (UIADObject*)evaluateAsObjectWithObject:(UIADObject*)object context:(UIADOperationContext*)context
{
    if (_type == UIAD_PROPERTY_VALUE_OBJECT && context.scene)
    {
        return [context.scene objectWithNameNoCreate:_stringValue];
    }
    else if (_type == UIAD_PROPERTY_VALUE_OBJECT_REF && context.functionEvent)
    {
        id argValue = [context.functionEvent argumentValue:_stringValue];
        if ([argValue isKindOfClass:[UIADObject class]])
        {
            return (UIADObject*)argValue;
        }
    }
    else if (_type == UIAD_PROPERTY_VALUE_OBJECT_FMT && context.scene)
    {
        NSString* formattedName = [UIADPropertyValue evaluateFormat:_stringValue withArguments:[UIADPropertyValue valueAsArray:_arrayValue] object:object context:context];
        if (formattedName && [formattedName length] > 0)
        {
            UIADObject* object = [context.scene objectWithNameNoCreate:formattedName];
            if (object)
            {
                return (UIADObject*)[object getObject:context];
            }
        }
    }
    else if (_type == UIAD_PROPERTY_VALUE_OBJECT_LOCAL && context.functionEvent)
    {
        return [context.functionEvent localObjectWithName:_stringValue context:context allowCreate:NO];
    }
    else if (_type == UIAD_PROPERTY_VALUE_OBJECT_LOCAL_FMT && context.functionEvent)
    {
        NSString* formattedName = [UIADPropertyValue evaluateFormat:_stringValue withArguments:[UIADPropertyValue valueAsArray:_arrayValue] object:object context:context];
        if (formattedName && [formattedName length] > 0)
        {
            return [context.functionEvent localObjectWithName:formattedName context:context allowCreate:NO];
        }
    }
    
    return nil;
}

+ (id)valueFromIdentifier:(NSString*)macro object:(id)object context:(UIADOperationContext*)context
{
    UIADEntity* entity = nil;
    if ([object isKindOfClass:[UIADObject class]])
    {
        entity = ((UIADObject*)object).entity;
    }
    else if ([object isKindOfClass:[UIADEntity class]])
    {
        entity = (UIADEntity*)object;
    }
    
    if ([macro isEqualToString:@"WIDTH"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.frame.size.width];
    }
    else if ([macro isEqualToString:@"HEIGHT"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.frame.size.height];
    }
    else if ([macro isEqualToString:@"X"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.frame.origin.x];
    }
    else if ([macro isEqualToString:@"Y"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.frame.origin.y];
    }
    else if ([macro isEqualToString:@"CENTER_X"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.center.x];
    }
    else if ([macro isEqualToString:@"CENTER_Y"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.center.y];
    }
    else if ([macro isEqualToString:@"IMAGE_WIDTH"])
    {
        if (entity && [entity isKindOfClass:[UIADImageEntity class]])
        {
            return [NSNumber numberWithFloat:((UIADImageEntity*)entity).image.size.width];
        }
    }
    else if ([macro isEqualToString:@"IMAGE_HEIGHT"])
    {
        if (entity && [entity isKindOfClass:[UIADImageEntity class]])
        {
            return [NSNumber numberWithFloat:((UIADImageEntity*)entity).image.size.height];
        }
    }
    else if ([macro isEqualToString:@"BOTTOM"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.frame.origin.y + entity.frame.size.height];
    }
    else if ([macro isEqualToString:@"RIGHT"])
    {
        return entity == nil ? nil : [NSNumber numberWithFloat:entity.frame.origin.x + entity.frame.size.width];
    }
    else if ([macro isEqualToString:@"PI"])
    {
        return [NSNumber numberWithDouble:M_PI];
    }
    else if ([macro isEqualToString:@"RANDOM"])
    {
        // 返回0～1间的随机数
        return [NSNumber numberWithDouble:(double)rand() / RAND_MAX];
    }
    else if ([macro isEqualToString:@"INT_MAX"])
    {
        return [NSNumber numberWithDouble:INT32_MAX];
    }
    else if ([macro isEqualToString:@"CURRENT_TIME"])
    {
        return [NSNumber numberWithDouble:context.now];
    }
    else if ([macro isEqualToString:@"SCREEN_WIDTH"])
    {
        return [NSNumber numberWithDouble:[UIScreen mainScreen].bounds.size.width];
    }
    else if ([macro isEqualToString:@"SCREEN_HEIGHT"])
    {
        return [NSNumber numberWithDouble:[UIScreen mainScreen].bounds.size.height];
    }
    else if ([macro isEqualToString:@"SCENE_WIDTH"])
    {
        // 这个宏返回UIAnimationDirector对象的宽度，也就是动画场景的宽度
        return [NSNumber numberWithDouble:context.mainView.frame.size.width];
    }
    else if ([macro isEqualToString:@"SCENE_HEIGHT"])
    {
        return [NSNumber numberWithDouble:context.mainView.frame.size.height];
    }
    else if (context)
    {
        // 先检查循环变量
        if (context.forLoopVariables)
        {
            NSNumber* value = [context.forLoopVariables objectForKey:macro];
            if (value)
            {
                return value;
            }
        }
        
        // 如果位于functionEvent里，检查macro是不是参数
        if (context.functionEvent)
        {
            id argValue = [context.functionEvent argumentValue:macro];
            if (argValue)
            {
                if ([argValue isKindOfClass:[NSNumber class]])
                {
                    return argValue;
                }
                else if ([argValue isKindOfClass:[UIADPropertyValue class]])
                {
                    UIADPropertyValue* propValue = (UIADPropertyValue*)argValue;
                    if (propValue.type == UIAD_PROPERTY_VALUE_NUMBER)
                    {
                        return propValue.numberValue;
                    }
                }
            }
            
            // 检查是不是局部变量
            id value = [context.functionEvent getLocalVariable:macro];
            if (value)
            {
                return value;
            }
        }
        
        // 依次检查是否是program级的变量，用户注册的宏，编译期的常量
        id value = [context.program getLocalVariable:macro];
        if (value == nil)
        {
            value = [context.program.macros objectForKey:macro];
            if (value == nil)
            {
                value = [context.program.consts objectForKey:macro];
            }
        }
        
        return value;
    }
    
    return nil;
}

+ (UIADPropertyValue*)propertyValueWithString:(NSString*)str
{
    if ([str length] == 0)
    {
        return [UIADPropertyValue valueAsNone];
    }
    else if ([str characterAtIndex:0] == '"' && [str characterAtIndex:[str length] - 1] == '"')
    {
        return [UIADPropertyValue valueAsString:[str substringWithRange:NSMakeRange(1, [str length] - 2)]];
    }
    else if ([str characterAtIndex:0] == '(' && [str characterAtIndex:[str length] - 1] == ')')
    {
        NSString* content = nil;
        if ([str length] > 2)
        {
            NSString* innerStr = [[str substringWithRange:NSMakeRange(1, [str length] - 2)] trimmed];
            if (innerStr && [innerStr length] > 0)
            {
                content = innerStr;
            }
        }
        
        if (content)
        {
            // 检查整个表达式是否有冒号，如果没有则按照数组进行解析
            if (![content hasColonSymbol])
            {
                // 按照数组解析
                return [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"[%@]", content]];
            }
            
            // dictionary
            NSMutableDictionary* dic = [NSMutableDictionary dictionaryWithCapacity:5];
            content = [NSString stringWithFormat:@"%@,", content]; // 向最后加个逗号
            int i = 0, initial = 0, bracket = 0, squareBracket = 0;
            BOOL inString = NO;
            while (i < [content length])
            {
                unichar c = [content characterAtIndex:i];
                
                if (c == ',')
                {
                    if (bracket == 0 && squareBracket == 0 && !inString)
                    {
                        // 不在括号或字符串里，说明找到了一段参数，解出key和value
                        NSString* section = [content substringWithRange:NSMakeRange(initial, i - initial)];
                        NSRange colonRange = [section rangeOfString:@":"];
                        if (colonRange.length <= 0)
                        {
                            return nil;
                        }
                        
                        NSString* key = [[section substringToIndex:colonRange.location] trimmed];
                        if (![key isValidPropertyName])
                        {
                            return nil;
                        }
                        
                        NSString* value = [[section substringFromIndex:colonRange.location + 1] trimmed];
                        if ([value length] == 0)
                        {
                            return nil;
                        }
                        
                        UIADPropertyValue* propertyValue = [UIADPropertyValue propertyValueWithString:value];
                        if (propertyValue == nil)
                        {
                            return nil;
                        }
                        [dic setObject:propertyValue forKey:key];
                        initial = i + 1;
                    }
                }
                else if (c == '(')
                {
                    bracket ++;
                }
                else if (c == ')')
                {
                    bracket --;
                }
                else if (c == '[')
                {
                    squareBracket ++;
                }
                else if (c == ']')
                {
                    squareBracket --;
                }
                else if (c == '"')
                {
                    inString = !inString;
                }
                
                i ++;
            }
            
            if (squareBracket != 0 || bracket != 0 || inString)
            {
                return nil;
            }
            
            if ([dic count] > 0)
            {
                return [UIADPropertyValue valueAsDictionary:dic];
            }
        }
    }
    else if ([str characterAtIndex:0] == '[' && [str characterAtIndex:[str length] - 1] == ']')
    {
        NSMutableArray* array = [NSMutableArray arrayWithCapacity:5];
        NSString* content = nil;
        if ([str length] > 2)
        {
            NSString* innerStr = [[str substringWithRange:NSMakeRange(1, [str length] - 2)] trimmed];
            if (innerStr && [innerStr length] > 0)
            {
                content = [NSString stringWithFormat:@"%@,", innerStr]; // 向最后加个逗号
            }
        }
        
        if (content)
        {
            int i = 0, initial = 0, bracket = 0, squareBracket = 0;
            BOOL inString = NO;
            while (i < [content length])
            {
                unichar c = [content characterAtIndex:i];
                
                if (c == ',')
                {
                    if (bracket == 0 && squareBracket == 0 && !inString)
                    {
                        // 不在括号或字符串里，说明找到了一段参数
                        NSString* section = [content substringWithRange:NSMakeRange(initial, i - initial)];
                        UIADPropertyValue* propertyValue = [UIADPropertyValue propertyValueWithString:[section trimmed]];
                        if (propertyValue == nil)
                        {
                            return nil;
                        }
                        [array addObject:propertyValue];
                        initial = i + 1;
                    }
                }
                else if (c == '(')
                {
                    bracket ++;
                }
                else if (c == ')')
                {
                    bracket --;
                }
                else if (c == '[')
                {
                    squareBracket ++;
                }
                else if (c == ']')
                {
                    squareBracket --;
                }
                else if (c == '"')
                {
                    inString = !inString;
                }
                
                i ++;
            }
            
            if (squareBracket != 0 || bracket != 0 || inString)
            {
                return nil;
            }
        }
        
        return [UIADPropertyValue valueAsArray:array];
    }
    else if ([str hasPrefix:@"object("] || [str hasPrefix:@"localObject("])
    {
        int i = 0;
        BOOL result = NO, isLocal = NO;
        UIADPropertyValue* objectDesc = nil;
        if ([str hasPrefix:@"object("])
        {
            result = [UIADPropertyValue parseExpressionObjectField:str at:&i offset:7 dotSymbol:NO result:&objectDesc];
        }
        else if ([str hasPrefix:@"localObject("])
        {
            isLocal = YES;
            result = [UIADPropertyValue parseExpressionObjectField:str at:&i offset:12 dotSymbol:NO result:&objectDesc];
        }
        
        if (result)
        {
            if (objectDesc.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                if ([objectDesc.arrayValue count] == 1)
                {
                    UIADPropertyValue* param = [objectDesc.arrayValue objectAtIndex:0];
                    if (param.type == UIAD_PROPERTY_VALUE_STRING)
                    {
                        // object("xxx")或localObject("xxx")
                        if ([param.stringValue isValidName])
                        {
                            if (isLocal)
                            {
                                return [UIADPropertyValue valueAsType:UIAD_PROPERTY_VALUE_OBJECT_LOCAL withString:param.stringValue];
                            }
                            else
                            {
                                return [UIADPropertyValue valueAsType:UIAD_PROPERTY_VALUE_OBJECT withString:param.stringValue];
                            }
                        }
                    }
                    else if (param.type == UIAD_PROPERTY_VALUE_NUMBER)
                    {
                        // object(xxx)，这种中间是不加引号的参数名
                        if (!isLocal && [param.stringValue isValidPropertyName])
                        {
                            return [UIADPropertyValue valueAsType:UIAD_PROPERTY_VALUE_OBJECT_REF withString:param.stringValue];
                        }
                    }
                }
                else
                {
                    // object("wall%d", [index])，localObject("wall%d", [index])
                    UIADPropertyValue* format = [objectDesc.arrayValue objectAtIndex:0];
                    UIADPropertyValue* arguments = [objectDesc.arrayValue objectAtIndex:1];
                    if (format.type == UIAD_PROPERTY_VALUE_STRING && arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
                    {
                        if (isLocal)
                        {
                            UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
                            value.type = UIAD_PROPERTY_VALUE_OBJECT_LOCAL_FMT;
                            value.stringValue = format.stringValue;     // 这个记录格式
                            value.arrayValue = arguments.arrayValue;    // 这个记录参数表
                            return [value autorelease];
                        }
                        else
                        {
                            UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
                            value.type = UIAD_PROPERTY_VALUE_OBJECT_FMT;
                            value.stringValue = format.stringValue;     // 这个记录格式
                            value.arrayValue = arguments.arrayValue;    // 这个记录参数表
                            return [value autorelease];
                        }
                    }
                }
            }
        }
    }

    // 应该只能是一个四则运算表达式了
    double d;
    UIADPropertyValue* value = [[UIADPropertyValue alloc] init];
    value.type = UIAD_PROPERTY_VALUE_NUMBER;
    if ([str toDouble:&d])
    {
        // 如果能转成一个数字，就直接用numberValue记录
        value.numberValue = [NSNumber numberWithDouble:d];
    }
    value.stringValue = str; // stringValue记录表达式，可能运行时再解析
    return [value autorelease];
}

@end

