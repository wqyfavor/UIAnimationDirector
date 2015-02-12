//
//  UIAnimationDirector.m
//  mPaas
//
//  Created by bruiswang on 12-10-9.
//
//

#import "UIAnimationDirector.h"
#import "UIAnimationDirector+Parser.h"

#import <mach/mach_time.h>

@class UIAnimationThread;

@interface UIAnimationDirector ()
{
    NSString* _script;
    NSString* _filePath;
    UIAnimationThread* _animationThread;
}

+ (void)removeOperationByThread:(UIAnimationThread*)thread;

@end

@interface UIAnimationThread : NSObject

@property (nonatomic, retain) UIADOperationContext* context;
@property (nonatomic, readonly) NSThread* thread;
@property (nonatomic, assign) id owner;

@property (nonatomic, readonly) BOOL isCancelled;

- (void)start;
- (void)cancel;

@end

@implementation UIAnimationThread

- (id)init
{
    if (self = [super init])
    {
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadEvent) object:nil];
        [_thread setThreadPriority:1.0];
    }
    return self;
}

- (void)dealloc
{
    if (_thread && ![_thread isCancelled])
    {
        [_thread cancel];
        [_thread release];
    }
    [_context release];
    [super dealloc];
}

- (void)threadEvent
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    struct mach_timebase_info timebase;
    mach_timebase_info(&timebase);
    double timebase_ratio = ((double)timebase.numer / (double)timebase.denom) * 1.0e-9;
    NSTimeInterval start = mach_absolute_time() * timebase_ratio;
    
    srandom(time(0));
    srand(time(0));
    
    [_owner performSelectorOnMainThread:@selector(didTimerEventStart:) withObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:start], [NSNumber numberWithDouble:timebase_ratio], nil] waitUntilDone:NO];
    
    while (![[NSThread currentThread] isCancelled] && ![_context.program finished:_context.now])
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        NSTimeInterval modification = 0;
        NSTimeInterval now = (mach_absolute_time() * timebase_ratio - start) * _context.speed; // 计算启动多久了
        
        NSArray* executableLines = [_context.program getExecutableLines:now modification:&modification];
        start += modification;
        
        _context.now = now;
        for (int i = 0; i < [executableLines count]; i ++)
        {
            UIADTimeLine* line = [executableLines objectAtIndex:i];
            for (int t = 0; t < [line.operations count]; t ++)
            {
                UIADOperation* operation = [line.operations objectAtIndex:t];
                if (_owner)
                    [_owner performSelectorOnMainThread:@selector(executeOperation:) withObject:operation waitUntilDone:NO];
                else
                    [self performSelectorOnMainThread:@selector(executeOperation:) withObject:operation waitUntilDone:NO];
            }
        }
        
        [pool drain];
        
        [NSThread sleepForTimeInterval:0.001]; // 每一毫秒休息一次
    }
    
    if (_owner)
        [_owner performSelectorOnMainThread:@selector(didAllOperationsExecute) withObject:nil waitUntilDone:NO];
    else
        [UIAnimationDirector removeOperationByThread:self];
    
    [pool drain];
}

- (void)executeOperation:(UIADOperation*)operation
{
    @try
    {
        if (![operation execute:_context])
        {
        }
    }
    @catch (NSException *exception)
    {
    }
}

- (void)start
{
    [_thread start];
}

- (void)cancel
{
    if (![_thread isCancelled])
    {
        [_thread cancel];
    }
    [_thread release];
    _thread = nil;
}

- (BOOL)isCancelled
{
    return [_thread isCancelled];
}

@end

#pragma mark -

@implementation UIAnimationDirector

@synthesize program = _program;
@synthesize compiled = _compiled;
@synthesize running = _running;
@synthesize resourcesReady = _resourcesReady;
@synthesize speed = _speed;
@synthesize context = _context;
@synthesize delegate = _delegate;
@synthesize scriptInvokeResponder = _scriptInvokeResponder;

- (id)init
{
    return [self initWithScript:nil];
}

- (id)initWithScriptFile:(NSString*)file
{
    _filePath = [[NSString stringWithFormat:@"%@/", [file stringByDeletingLastPathComponent]] retain];
    NSString* content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    return [self initWithScript:content];
}

- (id)initWithScript:(NSString*)script
{
    self = [super init];
    if (self)
    {
        _script = [script retain];
        _context = [[UIADOperationContext alloc] init];
    }
    
    return self;
}

- (void)loadScript:(NSString*)script
{
    if (!_running)
    {
        [_script release];
        _script = [script retain];
        _compiled = NO;
    }
}

- (void)loadScriptFromFile:(NSString*)file
{
    if (!_running)
    {
        NSString* content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        if (content)
        {
            [_script release];
            _script = [content retain];
            _compiled = NO;
        }
    }
}

- (void)dealloc
{
    _animationThread.owner = nil;
    if (_animationThread && ![_animationThread isCancelled])
    {
        [_animationThread cancel];
        [_animationThread release];
    }
    
    [_context release];
    [_script release];
    [_filePath release];

    [_program cancelDownloads];
    [_program release];
    
    [super dealloc];
}

- (void)compile
{
    if (_script == nil)
    {
        return;
    }
    
    UIADParser* parser = [[UIADParser alloc] initWithScript:_script];
    @try
    {
        [parser parse];
        [_program release];
        _program = [parser.program retain];
        _program.delegate = self;
        _compiled = YES;
        _resourcesReady = [_program isResourcesReady];
    }
    @catch (NSException *exception)
    {
        if ([exception isKindOfClass:[UIADParserException class]])
        {
            UIAD_LOG(@"UIAnimationDirector failed compiling line %d of script, [%@]", ((UIADParserException*)exception).errorLine, ((UIADParserException*)exception).errorInfo);
        }
        else
        {
            UIAD_LOG(@"UIAnimationDirector failed compiling script. Infomation:%@", exception.reason);
        }
    }
    @finally
    {
        [parser release];
    }
}

- (void)reset
{
    [self stop];
    [_program reset];
}

- (void)run:(double)speed
{
    if (!_running && _compiled && _resourcesReady && speed > 0 && speed <= 5)
    {
        [self reset];
        
        _speed = speed;
        _running = YES;
        
        _context.evaluateAllowObject = YES;
        _context.speed = _speed;
        _context.mainView = self;
        _context.program = _program;
        _context.invokeResponder = _scriptInvokeResponder;
        _context.operationWithTarget = NO;
        _context.animationDelegate = nil;
        _context.scriptFilePath = _filePath;
        _context.lastError = [NSMutableString stringWithCapacity:256];
        
        if (_delegate && [_delegate respondsToSelector:@selector(shouldRegisterMacros:)])
        {
            [_delegate shouldRegisterMacros:self];
        }
        
        if (_animationThread)
        {
            if (![_animationThread isCancelled])
            {
                [_animationThread cancel];
            }
            [_animationThread release];
        }
        
        _animationThread = [[UIAnimationThread alloc] init];
        _animationThread.owner = self;
        _animationThread.context = _context;
        [_animationThread start];
    }
}

- (void)stop
{
    if (_running)
    {
        [self finish];
    }
}

- (void)finish
{
    if (![_animationThread isCancelled])
    {
        [_animationThread cancel];
    }
    [_animationThread release];
    _animationThread = nil;
    _running = NO;
}

- (void)executeOperation:(UIADOperation*)operation
{
    @try
    {
        if (![operation execute:_context])
        {
            [self finish];
            @throw [NSException exceptionWithName:@"" reason:_context.lastError userInfo:nil];
        }
    }
    @catch (NSException *exception)
    {
        UIAD_LOG(@"UIAnimationDirector failed running line %d of script, [%@]", operation.line, exception.reason);
        if (_delegate && [_delegate respondsToSelector:@selector(didAnimationExecutionFail:)])
        {
            [_delegate didAnimationExecutionFail:self];
        }
    }
}

- (void)didTimerEventStart:(NSArray*)timeParameters
{
    if (_delegate && [_delegate respondsToSelector:@selector(didAnimationBegin:startTime:timeRatio:)])
    {
        [_delegate didAnimationBegin:self startTime:(NSTimeInterval)[[timeParameters objectAtIndex:0] doubleValue] timeRatio:[[timeParameters objectAtIndex:1] doubleValue]];
    }
}

- (void)didAllOperationsExecute
{
    if (_delegate && [_delegate respondsToSelector:@selector(didAnimationFinish:)])
    {
        [_delegate didAnimationFinish:self];
    }
}

static NSMutableArray* _execute_on_single_object_queue = nil;

+ (void)removeOperationByThread:(UIAnimationThread*)thread
{
    @synchronized(_execute_on_single_object_queue)
    {
        for (int i = 0; i < [_execute_on_single_object_queue count]; i ++)
        {
            NSDictionary* dict = [_execute_on_single_object_queue objectAtIndex:i];
            if ([dict objectForKey:@"thread"] == thread)
            {
                [_execute_on_single_object_queue removeObjectAtIndex:i];
                break;
            }
        }
    }
}

+ (BOOL)executeOperationWithTarget:(UIADEntity*)target script:(NSString*)script delegate:(id)delegate
{
    UIADOperation* operation = [UIADParser parseAssignmentOperationWithTarget:target script:script];
    if (operation)
    {
        if (_execute_on_single_object_queue == nil)
            _execute_on_single_object_queue = [[NSMutableArray alloc] initWithCapacity:10];
        
        UIADProgram* program = [[UIADProgram alloc] init];
        [[program getTimeLine:0.0f] addOperation:UIAD_OPERATION_ASSIGN parameters:operation.parameters line:0 runtime:NO precondition:UIAD_NO_PRECONDITION];
        
        // 执行
        UIADOperationContext* context = [[UIADOperationContext alloc] init];
        context.speed = 1.0f;
        context.mainView = nil;
        context.program = program;
        context.invokeResponder = nil;
        context.operationWithTarget = YES;
        context.animationDelegate = delegate;
        
        UIAnimationThread* thread = [[UIAnimationThread alloc] init];
        thread.context = context;
        
        @synchronized(_execute_on_single_object_queue)
        {
            [_execute_on_single_object_queue addObject:[NSDictionary dictionaryWithObjectsAndKeys:program, @"program", thread, @"thread", nil]];
        }
        
        [thread start];
        
        [context release];
        [program release];
        [thread release];
    }
    
    return NO;
}

#pragma mark UIADOperationDelegate

- (void)didSceneEntityCreated:(UIADScene*)scene
{
    if (_delegate && [_delegate respondsToSelector:@selector(shouldRegisterExternalObjects:scene:)])
    {
        [_delegate shouldRegisterExternalObjects:self scene:scene.name];
    }
}

- (void)didObjectEntityCreated:(UIADObject*)object
{
    if (_delegate && [_delegate respondsToSelector:@selector(didObjectEntityCreated:object:)])
    {
        [_delegate didObjectEntityCreated:self object:object];
    }
}

- (void)marqueeTextConfigureLabel:(UIADMarqueeLabel*)label object:(UIADObject*)object newLine:(BOOL)newLine
{
    if (_delegate && [_delegate respondsToSelector:@selector(marqueeTextConfigureLabel:label:object:newLine:)])
    {
        [_delegate marqueeTextConfigureLabel:self label:label object:object newLine:newLine];
    }
}

#pragma mark UIADProgramDelegate

- (void)didBeginDownloadingResources:(UIADProgram*)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(didBeginDownloadingResources:)])
    {
        [_delegate didBeginDownloadingResources:self];
    }
}

- (void)didEndDownloadingResources:(UIADProgram*)sender success:(BOOL)success
{
    if (success)
    {
        _resourcesReady = YES;
    }
    if (_delegate && [_delegate respondsToSelector:@selector(didEndDownloadingResources:success:)])
    {
        [_delegate didEndDownloadingResources:self success:success];
    }
}

@end

@implementation UIView (UIANIMATION_DIRECTOR)

+ (UIADScene*)getDefaultScene
{
    return [UIADParser getDefaultScene];
}

- (void)executeAnimationScript:(NSString*)script
{
    [UIAnimationDirector executeOperationWithTarget:self script:script delegate:nil];
}

- (void)executeAnimationScript:(NSString*)script delegate:(id)delegate
{
    [UIAnimationDirector executeOperationWithTarget:self script:script delegate:delegate];
}

@end
