//
//  UIAnimationDirector.m
//  QQMSFContact
//
//  Created by bruiswang on 12-10-9.
//
//

#import "UIAnimationDirector.h"
#import "UIAnimationDirector+Parser.h"

#import <mach/mach_time.h>

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
    [_context release];
    [_script release];
    [_filePath release];
    
    if (_timerThread && ![_timerThread isCancelled])
    {
        [_timerThread cancel];
        [_timerThread release];
    }
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

- (void)timerThreadEvent
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    struct mach_timebase_info timebase;
    mach_timebase_info(&timebase);
    double timebase_ratio = ((double)timebase.numer / (double)timebase.denom) * 1.0e-9;
    NSTimeInterval start = mach_absolute_time() * timebase_ratio;
    
    srandom(time(0));
    srand(time(0));
    
    [self performSelectorOnMainThread:@selector(didTimerEventStart:) withObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:start], [NSNumber numberWithDouble:timebase_ratio], nil] waitUntilDone:NO];
    
    while (![[NSThread currentThread] isCancelled] && ![_program finished:_context.now])
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        NSTimeInterval modification = 0;
        NSTimeInterval now = (mach_absolute_time() * timebase_ratio - start) * _speed; // 计算启动多久了

        NSArray* executableLines = [_program getExecutableLines:now modification:&modification];
        start += modification;
        
        _context.now = now;
        for (int i = 0; i < [executableLines count]; i ++)
        {
            UIADTimeLine* line = [executableLines objectAtIndex:i];
            for (int t = 0; t < [line.operations count]; t ++)
            {
                UIADOperation* operation = [line.operations objectAtIndex:t];
                [self performSelectorOnMainThread:@selector(executeOperation:) withObject:operation waitUntilDone:NO];
            }
        }
        
        [pool drain];
        
        [NSThread sleepForTimeInterval:0.001]; // 每一毫秒休息一次
    }
    
    [self performSelectorOnMainThread:@selector(didAllOperationsExecute) withObject:nil waitUntilDone:NO];
    
    [pool drain];
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
        
        if (_timerThread)
        {
            if (![_timerThread isCancelled])
            {
                [_timerThread cancel];
            }
            
            [_timerThread release];
        }
        
        _timerThread = [[NSThread alloc] initWithTarget:self selector:@selector(timerThreadEvent) object:nil];
        [_timerThread setThreadPriority:1.0];
        [_timerThread start];
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
    if (![_timerThread isCancelled])
    {
        [_timerThread cancel];
    }
    [_timerThread release];
    _timerThread = nil;
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
    @finally
    {
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

+ (BOOL)executeOperationWithTarget:(UIADEntity*)target script:(NSString*)script delegate:(id)delegate
{
    UIADOperation* operation = [UIADParser parseAssignmentOperationWithTarget:target script:script];
    if (operation)
    {
        // 执行
        UIADOperationContext* context = [[UIADOperationContext alloc] init];
        context.speed = 1;
        context.mainView = nil;
        context.program = nil;
        context.invokeResponder = nil;
        context.operationWithTarget = YES;
        context.animationDelegate = delegate;
        
        @try
        {
            if ([operation execute:context])
            {
                return YES;
            }
        }
        @catch (NSException *exception)
        {
        }
        @finally
        {
            [context release];
        }
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
