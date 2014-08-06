//
//  UIAnimationDirector+Parser.m
//  QQMSFContact
//
//  Created by bruiswang on 12-10-9.
//
//

#import "UIAnimationDirector+Parser.h"
#import "UIAnimationDirector+Operation.h"
#import "UIADExtensions.h"

NSString* const UIAD_INVALID_SCENE_PARAM = @"Invalid scene parameters.";
NSString* const UIAD_INVALID_EVENT_PARAM = @"Invalid event parameters.";
NSString* const UIAD_INVALID_ASSIGNMENT = @"Invalid assignment.";
NSString* const UIAD_INVALID_OBJECT_NAME = @"Invalid object name.";
NSString* const UIAD_INVALID_PROPERTY_NAME = @"Invalid property name.";
NSString* const UIAD_SCENE_NOT_FOUND = @"Scene not found.";
NSString* const UIAD_OBJECTS_CANNOT_BE_NESTED = @"Objects cannot be nested.";
NSString* const UIAD_INVALID_FOR_STATEMENT = @"Invalid for statement";

#pragma mark UIADParserException

@implementation UIADParserException

@synthesize errorLine = _errorLine;
@synthesize errorInfo = _errorInfo;

- (id)initWithLine:(int)errorLine
{
    if (self = [super initWithName:@"UIADParserException" reason:@"parsing" userInfo:nil])
    {
        _errorLine = errorLine;
    }
    
    return self;
}

- (void)dealloc
{
    [_errorInfo release];
    [super dealloc];
}

- (id)withInformation:(NSString*)info
{
    self.errorInfo = info;
    return self;
}

@end

#pragma mark UIADSetValueLineSegment

// 一个最完整的赋值(函数调用)语句定义，赋值语句其实也可以理解为函数调用语句，[]为可选项(循环中的[from, to]不是)，{EXP, n}，表示可重复
// [if(bool):][event(const):]{[for(var, [from, to][, step]):], n}[object():]methodName:[parameters]
// [event(const):][if(bool):]{[for(var, [from, to][, step]):], n}[object():]methodName:[parameters]

enum UIAD_PARSER_LINE_SEGMENT
{
    UIAD_PARSER_LINE_SEGMENT_IF,
    UIAD_PARSER_LINE_SEGMENT_FOR,
    UIAD_PARSER_LINE_SEGMENT_OBJECT,                // object("")                               普通对象
    UIAD_PARSER_LINE_SEGMENT_OBJECT_REF,            // object(ARG)                              函数事件里对参数对象引用
    UIAD_PARSER_LINE_SEGMENT_OBJECT_FMT,            // object("wall%d", [index])                参数方式访问普通对象
    UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL,          // localObject("")                          函数事件里创建的物体
    UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL_FMT,      // localObject("wall%d", [index])           函数事件里创建的物体，使用参数方式访问
    UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE,          // object("name", "image"):method:          快速创建对象，同时指定图片
    UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE_LOCAL,    // localObject("name", "image"):method:     快速创建局部对象，同时指定图片
    UIAD_PARSER_LINE_SEGMENT_METHOD,                // 方法名
    UIAD_PARSER_LINE_SEGMENT_PARAMETERS,            // 参数表
    UIAD_PARSER_LINE_SEGMENT_EVENT,                 // 简单事件，时间确定的
};

@interface UIADSetValueLineSegment : NSObject
{
    int _type;
    NSString* _value;
    id _userInfo;
    UIADPropertyValue* _arguments;
}

@property (readonly) int type;
@property (nonatomic, readonly) NSString* value;
@property (nonatomic, assign) id userInfo;
@property (nonatomic, retain) UIADPropertyValue* arguments;

- (id)initWithType:(int)type value:(NSString*)value;

@end

@implementation UIADSetValueLineSegment

@synthesize type = _type;
@synthesize value = _value;
@synthesize userInfo = _userInfo;
@synthesize arguments = _arguments;

- (id)initWithType:(int)type value:(NSString*)value
{
    if (self = [super init])
    {
        _type = type;
        _value = [value retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_value release];
    [_arguments release];
    [super dealloc];
}

@end

@interface NSMutableArray(UIADSetValueLineSegment)

- (BOOL)hasObject;
- (UIADSetValueLineSegment*)getObject;
- (BOOL)has:(int)type;
- (UIADSetValueLineSegment*)get:(int)type;

@end

@implementation NSMutableArray(UIADSetValueLineSegment)

- (BOOL)hasObject
{
    for (UIADSetValueLineSegment* segment in self)
    {
        if (segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT || segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_REF ||
            segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_FMT || segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL ||
            segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL_FMT || segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE ||
            segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE_LOCAL)
        {
            return YES;
        }
    }
    
    return NO;
}

- (UIADSetValueLineSegment*)getObject
{
    for (UIADSetValueLineSegment* segment in self)
    {
        if (segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT || segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_REF ||
            segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_FMT || segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL ||
            segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL_FMT || segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE ||
            segment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE_LOCAL)
        {
            return segment;
        }
    }
    
    return nil;
}

- (BOOL)has:(int)type
{
    for (UIADSetValueLineSegment* segment in self)
    {
        if (segment.type == type)
        {
            return YES;
        }
    }
    
    return NO;
}

- (UIADSetValueLineSegment*)get:(int)type
{
    for (UIADSetValueLineSegment* segment in self)
    {
        if (segment.type == type)
        {
            return segment;
        }
    }
    
    return nil;
}

- (NSArray*)getArray:(int)type
{
    NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:[self count]];
    for (unsigned int i = 0; i < [self count]; i ++)
    {
        UIADSetValueLineSegment* segment = [self objectAtIndex:i];
        if (segment.type == type)
        {
            [result addObject:segment];
        }
    }

    return [result autorelease];
}

@end

#pragma mark UIADParser

@implementation UIADParser

@synthesize program = _program;

- (id)initWithScript:(NSString*)script
{
    if (self = [super init])
    {
        _script = [script retain];
        _program = [[UIADProgram alloc] init];
    }

    return self;
}

- (void)dealloc
{
    [_script release];
    [_program release];
    [super dealloc];
}

- (BOOL)parseSetValueLine:(NSString*)line segments:(NSMutableArray*)segments error:(NSString**)error
{
    BOOL inString = NO;
    int startIndex = 0;
    int bracket = 0, squareBracket = 0; // 小括号，中括号的数目
    
    for (int i = 0; i < [line length]; i ++)
    {
        BOOL shoudBreakFor = NO;
        unichar c = [line characterAtIndex:i];
        switch (c)
        {
            case '(':
                bracket ++;
                break;
            case ')':
                bracket --;
                break;
            case '[':
                squareBracket ++;
                break;
            case ']':
                squareBracket --;
                break;
            case '"':
                inString = !inString;
                break;
            case ':':
                if (bracket == 0 && squareBracket == 0 && !inString)
                {
                    NSString* segment = [[line substringWithRange:NSMakeRange(startIndex, i - startIndex)] trimmed];
                    startIndex = i + 1;
                    
                    if ([segment hasPrefix:@"event("] && [segment hasSuffix:@")"])
                    {
                        // event块前面最多只能有一个if块
                        if ([segments count] == 0 || ([segments count] == 1 && [segments has:UIAD_PARSER_LINE_SEGMENT_IF]))
                        {
                            NSString* timeStr = [[segment substringWithRange:NSMakeRange(6, [segment length] - 6 - 1)] trimmed];
                            [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_EVENT value:timeStr] autorelease]];
                        }
                        else
                        {
                            *error = UIAD_INVALID_ASSIGNMENT;
                            return NO;
                        }
                    }
                    else if ([segment hasPrefix:@"object("] || [segment hasPrefix:@"localObject("])
                    {
                        int i = 0;
                        BOOL result = NO, isLocal = NO;
                        UIADPropertyValue* objectDesc = nil;
                        if ([segment hasPrefix:@"object("])
                        {
                            result = [UIADPropertyValue parseExpressionObjectField:segment at:&i offset:7 dotSymbol:NO result:&objectDesc];
                        }
                        else if ([segment hasPrefix:@"localObject("])
                        {
                            isLocal = YES;
                            result = [UIADPropertyValue parseExpressionObjectField:segment at:&i offset:12 dotSymbol:NO result:&objectDesc];
                        }
                        
                        if (result)
                        {
                            if ([segments hasObject])
                            {
                                *error = UIAD_INVALID_ASSIGNMENT;
                                return NO;
                            }
                            
                            result = NO;
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
                                            [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:isLocal ? UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL : UIAD_PARSER_LINE_SEGMENT_OBJECT value:param.stringValue] autorelease]];
                                            result = YES;
                                        }
                                    }
                                    else if (param.type == UIAD_PROPERTY_VALUE_NUMBER)
                                    {
                                        // object(xxx)，这种中间是不加引号的参数名
                                        if (!isLocal && [param.stringValue isValidPropertyName])
                                        {
                                            [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_OBJECT_REF value:param.stringValue] autorelease]];
                                            result = YES;
                                        }
                                    }
                                }
                                else
                                {
                                    // object("wall%d", [index])，localObject("wall%d", [index])，或object("name", "image")，localObject("name", "image")
                                    UIADPropertyValue* format = [objectDesc.arrayValue objectAtIndex:0];
                                    UIADPropertyValue* arguments = [objectDesc.arrayValue objectAtIndex:1];
                                    if (format.type == UIAD_PROPERTY_VALUE_STRING)
                                    {
                                        if (arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
                                        {
                                            UIADSetValueLineSegment* segment = [[[UIADSetValueLineSegment alloc] initWithType:isLocal ? UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL_FMT : UIAD_PARSER_LINE_SEGMENT_OBJECT_FMT value:format.stringValue] autorelease];
                                            segment.arguments = arguments;
                                            [segments addObject:segment];
                                            result = YES;
                                        }
                                        else if (arguments.type == UIAD_PROPERTY_VALUE_STRING && [format.stringValue isValidName])
                                        {
                                            [_program verifyImageFromURL:arguments.stringValue]; // 检查是不是url资源图片
                                            UIADSetValueLineSegment* segment = [[[UIADSetValueLineSegment alloc] initWithType:isLocal ? UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE_LOCAL : UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE value:format.stringValue] autorelease];
                                            segment.arguments = arguments;
                                            [segments addObject:segment];
                                            result = YES;
                                        }
                                    }
                                }
                            }
                        }
                        
                        if (!result)
                        {
                            *error = UIAD_INVALID_ASSIGNMENT;
                            return NO;
                        }
                    }
                    else if ([segment hasPrefix:@"if("] && [segment hasSuffix:@")"])
                    {
                        // if块前面最多只能有一个event块
                        if ([segments count] == 0 || ([segments count] == 1 && [segments has:UIAD_PARSER_LINE_SEGMENT_EVENT]))
                        {
                            NSString* expression = [[segment substringWithRange:NSMakeRange(3, [segment length] - 3 - 1)] trimmed];
                            [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_IF value:expression] autorelease]];
                        }
                        else
                        {
                            *error = UIAD_INVALID_ASSIGNMENT;
                            return NO;
                        }
                    }
                    else if ([segment hasPrefix:@"for("] && [segment hasSuffix:@")"])
                    {
                        if ([segments hasObject])
                        {
                            *error = UIAD_INVALID_ASSIGNMENT;
                            return NO;
                        }
                        
                        // for(var, [from, to][, step])
                        NSString* expression = [[segment substringWithRange:NSMakeRange(4, [segment length] - 4 - 1)] trimmed];
                        UIADPropertyValue* parsed = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"[%@]", expression]];
                        if (parsed && parsed.type == UIAD_PROPERTY_VALUE_ARRAY && ([parsed.arrayValue count] == 2 || [parsed.arrayValue count] == 3))
                        {
                            UIADPropertyValue* argExpr = [parsed.arrayValue objectAtIndex:0];
                            UIADPropertyValue* rangeExpr = [parsed.arrayValue objectAtIndex:1];
                            UIADPropertyValue* stepExpr = nil;
                            if ([parsed.arrayValue count] == 3)
                            {
                                stepExpr = [parsed.arrayValue objectAtIndex:2];
                            }
                         
                            BOOL valid = (argExpr.type == UIAD_PROPERTY_VALUE_NUMBER && [argExpr.stringValue isValidPropertyName]); // 循环变量名
                            valid = valid && (rangeExpr.type == UIAD_PROPERTY_VALUE_ARRAY && [rangeExpr.arrayValue count] == 2);
                            valid = valid && (((UIADPropertyValue*)[rangeExpr.arrayValue objectAtIndex:0]).type == UIAD_PROPERTY_VALUE_NUMBER);
                            valid = valid && (((UIADPropertyValue*)[rangeExpr.arrayValue objectAtIndex:1]).type == UIAD_PROPERTY_VALUE_NUMBER);
                            valid = valid && (stepExpr == nil || (stepExpr.type == UIAD_PROPERTY_VALUE_NUMBER));
                            
                            if (valid)
                            {
                                UIADSetValueLineSegment* segment = [[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_FOR value:nil] autorelease];
                                segment.arguments = parsed;
                                [segments addObject:segment];
                            }
                            else
                            {
                                *error = UIAD_INVALID_FOR_STATEMENT;
                                return NO;
                            }
                        }
                        else
                        {
                            *error = UIAD_INVALID_FOR_STATEMENT;
                            return NO;
                        }
                    }
                    else if ([segment isValidPropertyName])
                    {
                        [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_METHOD value:segment] autorelease]];
                        shoudBreakFor = YES;
                    }
                    else
                    {
                        *error = UIAD_INVALID_PROPERTY_NAME;
                        return NO;
                    }
                }
            default:
                break;
        }
        
        if (shoudBreakFor)
        {
            break;
        }
    }
    
    if (![segments has:UIAD_PARSER_LINE_SEGMENT_METHOD])
    {
        *error = UIAD_INVALID_ASSIGNMENT;
        return NO;
    }
    
    // 最后解析出参数表
    if (startIndex >= [line length])
    {
        // 参数表为空
        [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_PARAMETERS value:@""] autorelease]];
    }
    else
    {
        NSString* parameters = [[line substringWithRange:NSMakeRange(startIndex, [line length] - startIndex)] trimmed];
        [segments addObject:[[[UIADSetValueLineSegment alloc] initWithType:UIAD_PARSER_LINE_SEGMENT_PARAMETERS value:parameters] autorelease]];
    }
    
    return YES;
}

- (void)parse
{
    BOOL shouldBeLeftBrace = NO;
    
    [_program release];
    _program = [[UIADProgram alloc] init];
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableArray* fieldStack = [NSMutableArray arrayWithCapacity:10];
    
    NSArray* lines = [_script componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray* lines2 = [NSMutableArray arrayWithArray:lines];
    // 把每行#后面的注释删除
    for (int i = 0; i < [lines count]; i ++)
    {
        NSString* line = [lines objectAtIndex:i];
        NSRange comment = [line rangeOfString:@"#"];
        if (comment.length > 0)
        {
            [lines2 replaceObjectAtIndex:i withObject:[line substringToIndex:comment.location]];
        }
    }
    lines = lines2;
    
    int iLine = 1; // 脚本是行数是从1开始的，这样方便一些
    UIADParserException* exception = [[[UIADParserException alloc] initWithLine:0] autorelease];
    
    UIADOperationContext* context = [[[UIADOperationContext alloc] init] autorelease];
    context.program = _program;
    
    while (iLine < [lines count] + 1)
    {
        UIAD_LOG(@"UIAnimationDirector parsing line %d of script", iLine);
        
        NSString* line = [[lines objectAtIndex:iLine - 1] trimmed];
        
        if (line == nil || [line length] == 0)
        {
            iLine ++;
            continue;
        }
        
        exception.errorLine = iLine;
        
        if (shouldBeLeftBrace && ![line isEqualToString:@"{"])
        {
            @throw [exception withInformation:@"\"{\" expected."];
        }
        
        BOOL hasColon = [line hasColonSymbol];
        
        if ([line hasPrefix:@"scene("] && [line hasSuffix:@")"])
        {
            // 开启scene时，fieldStack必须为空
            if ([fieldStack peek] != nil)
            {
                @throw [exception withInformation:@"Scene should not be embraced by superior struct."];
            }
            
            NSString* sceneName = @"";
            double initialTime = 0.0;
            
            // 场景场景可以使用scene(1)，只指定场景时间；或scene(1, "scene1")，指定时间与名称；或scene("scene1")指定名称。只指定名称的场景是可调用场景，目前不支持
            NSString* content = [[line substringWithRange:NSMakeRange(6, [line length] - 6 - 1)] trimmed];
            UIADPropertyValue* parameters = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"[%@]", content]]; // 按照数组进行解析
            if (parameters == nil || parameters.type != UIAD_PROPERTY_VALUE_ARRAY)
            {
                @throw [exception withInformation:@"Scene parameters expected."];
            }
            
            UIADPropertyValue* timeParameter = nil;
            UIADPropertyValue* nameParameter = nil;
            
            if ([parameters.arrayValue count] == 1 && (((UIADPropertyValue*)[parameters.arrayValue objectAtIndex:0]).type == UIAD_PROPERTY_VALUE_NUMBER))
            {
                timeParameter = [parameters.arrayValue objectAtIndex:0];
            }
            else if ([parameters.arrayValue count] == 1 && (((UIADPropertyValue*)[parameters.arrayValue objectAtIndex:0]).type == UIAD_PROPERTY_VALUE_STRING))
            {
                nameParameter = [parameters.arrayValue objectAtIndex:0];
            }
            else if ([parameters.arrayValue count] == 2)
            {
                timeParameter = [parameters.arrayValue objectAtIndex:0];
                nameParameter = [parameters.arrayValue objectAtIndex:1];
            }
            else
            {
                @throw [exception withInformation:UIAD_INVALID_SCENE_PARAM];
            }

            // 暂不支持不带时间信息的场景
            if (timeParameter == nil)
            {
                 @throw [exception withInformation:UIAD_INVALID_SCENE_PARAM];
            }
            NSNumber* time = [timeParameter evaluateNumberWithObject:nil context:context];
            if (time == nil)
            {
                @throw [exception withInformation:UIAD_INVALID_SCENE_PARAM];
            }
            initialTime = [time doubleValue];
            if (initialTime < 0.0f)
            {
                @throw [exception withInformation:UIAD_INVALID_SCENE_PARAM];
            }
            
            if (nameParameter && nameParameter.type == UIAD_PROPERTY_VALUE_STRING)
            {
                sceneName = nameParameter.stringValue;
            }
            
            UIADScene* scene = [[UIADScene alloc] initWithAbsoluteTime:(NSTimeInterval)initialTime name:sceneName];
            [fieldStack push:scene];
            [scene release];
            
            [_program addScene:scene];
            
            UIADTimeLine* timeLine = [_program getTimeLine:(NSTimeInterval)initialTime];
            [timeLine addOperation:UIAD_OPERATION_SCENE parameters:[NSDictionary dictionaryWithObject:scene forKey:@"object"] line:iLine runtime:NO precondition:UIAD_NO_PRECONDITION];
            
            shouldBeLeftBrace = YES;
        }
        else if ([line isEqualToString:@"{"])
        {
            if (shouldBeLeftBrace)
            {
                shouldBeLeftBrace = NO;
            }
            else
            {
                @throw [exception withInformation:@"Unexpected \"{\"."];
            }
        }
        else if ([line isEqualToString:@"}"])
        {
            if ([fieldStack peek] == nil)
            {
                // 没有任何域可以退出
                @throw [exception withInformation:@"Unexpected \"}\"."];
            }
            [fieldStack pop];
        }
        else if ([line hasPrefix:@"object(\""] && [line hasSuffix:@"\")"] && !hasColon)
        {
            // object("1")
            // 取名称
            NSString* nameStr = [line substringWithRange:NSMakeRange(8, [line length] - 8 - 2)];
            if (![nameStr isValidName])
            {
                @throw [exception withInformation:UIAD_INVALID_OBJECT_NAME];
            }

            UIADTimeObject* superTimeObject = [fieldStack peekUntilClass:[UIADTimeObject class]];
            UIADReferenceObject* superObject = [fieldStack peekUntilClass:[UIADReferenceObject class]];
            if (superTimeObject == nil || superObject != nil)
            {
                @throw [exception withInformation:@"Object should be embraced by superior scene, event or boolean condition and cannot be embarced by another object."];
            }
            
            id scene = [fieldStack bottom];
            if (scene == nil || ![scene isKindOfClass:[UIADScene class]])
            {
                @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
            }
            
            // 进入对象域
            [fieldStack push:[scene objectWithName:nameStr]];
            shouldBeLeftBrace = YES;
        }
        else if ([line hasPrefix:@"object("] && [line hasSuffix:@")"] && !hasColon)
        {
            // object("image%d", [index])，带参数的对象引用
            // object(arg)，参数函数里对参数物体的访问，取参数名称，向上找function event，判断是不是这个function event的参数
            NSString* nameStr = [[line substringWithRange:NSMakeRange(7, [line length] - 7 - 1)] trimmed];
            UIADPropertyValue* arguments = nil; // 带参数对象引用的参数表
            
            if (![nameStr isValidPropertyName])
            {
                UIADPropertyValue* value = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"(%@)", nameStr]];
                if (value && value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
                {
                    UIADPropertyValue* format = [value.arrayValue objectAtIndex:0];
                    arguments = [value.arrayValue objectAtIndex:1];
                    if (format.type == UIAD_PROPERTY_VALUE_STRING && arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
                    {
                        nameStr = format.stringValue;
                    }
                    else
                    {
                        @throw [exception withInformation:UIAD_INVALID_OBJECT_NAME];
                    }
                }
                else
                {
                    @throw [exception withInformation:UIAD_INVALID_OBJECT_NAME];
                }
            }
            else
            {
                // object(arg)，这种是引用参数传过来的对象，必须在函数块里
                UIADFunctionEvent* functionEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
                if (functionEvent == nil || ![functionEvent hasArgument:nameStr])
                {
                    @throw [exception withInformation:[NSString stringWithFormat:@"Unfound object \"%@\".", nameStr]];
                }
            }

            UIADReferenceObject* superObject = [fieldStack peekUntilClass:[UIADReferenceObject class]];
            if (superObject != nil)
            {
                // 暂不支持物体嵌套
                @throw [exception withInformation:UIAD_OBJECTS_CANNOT_BE_NESTED];
            }
            
            id scene = [fieldStack bottom];
            if (scene == nil || ![scene isKindOfClass:[UIADScene class]])
            {
                @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
            }
            
            // 进入对象域
            UIADReferenceObject* object = nil;
            if (arguments)
            {
                object = [[[UIADFormatReferenceObject alloc] initWithName:nameStr scene:scene arguments:arguments] autorelease];
            }
            else
            {
                object = [[[UIADReferenceObject alloc] initWithName:nameStr scene:scene] autorelease];
            }
            [fieldStack push:object];
            shouldBeLeftBrace = YES;
        }
        else if ([line hasPrefix:@"localObject(\""] && [line hasSuffix:@"\")"] && !hasColon)
        {
            // localObject("1")
            // 取名称
            NSString* nameStr = [line substringWithRange:NSMakeRange(13, [line length] - 13 - 2)];
            if (![nameStr isValidName])
            {
                @throw [exception withInformation:UIAD_INVALID_OBJECT_NAME];
            }
            
            // object域只能位于functionEvent第一级，或event域的第一级
            UIADFunctionEvent* functionEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
            if (functionEvent == nil)
            {
                @throw [exception withInformation:@"Local object can only exist in a function event."];
            }
            
            UIADReferenceObject* superObject = [fieldStack peekUntilClass:[UIADReferenceObject class]];
            if (superObject != nil)
            {
                // 暂不支持物体嵌套
                @throw [exception withInformation:UIAD_OBJECTS_CANNOT_BE_NESTED];
            }
            
            id scene = [fieldStack bottom];
            if (scene == nil || ![scene isKindOfClass:[UIADScene class]])
            {
                @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
            }
            
            // 进入对象域
            UIADLocalObject* object = [[[UIADLocalObject alloc] initWithName:nameStr scene:scene] autorelease];
            [fieldStack push:object];
            shouldBeLeftBrace = YES;
        }
        else if ([line hasPrefix:@"localObject("] && [line hasSuffix:@")"] && !hasColon)
        {
            // localObject("wall%d", [index])
            NSString* content = [[line substringWithRange:NSMakeRange(12, [line length] - 12 - 1)] trimmed];
            
            UIADPropertyValue* value = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"(%@)", content]];
            if (value && value.type == UIAD_PROPERTY_VALUE_ARRAY && [value.arrayValue count] == 2)
            {
                UIADPropertyValue* format = [value.arrayValue objectAtIndex:0];
                UIADPropertyValue* arguments = [value.arrayValue objectAtIndex:1];
                if (format.type == UIAD_PROPERTY_VALUE_STRING && arguments.type == UIAD_PROPERTY_VALUE_ARRAY)
                {
                    // object域只能位于functionEvent第一级，或event域的第一级
                    UIADFunctionEvent* functionEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
                    if (functionEvent == nil)
                    {
                        @throw [exception withInformation:@"Local object can only exist in a function event."];
                    }
                    
                    UIADReferenceObject* superObject = [fieldStack peekUntilClass:[UIADReferenceObject class]];
                    if (superObject != nil)
                    {
                        // 暂不支持物体嵌套
                        @throw [exception withInformation:UIAD_OBJECTS_CANNOT_BE_NESTED];
                    }
                    
                    id scene = [fieldStack bottom];
                    if (scene == nil || ![scene isKindOfClass:[UIADScene class]])
                    {
                        @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
                    }
                    
                    // 进入对象域
                    UIADFormatReferenceLocalObject* object = [[[UIADFormatReferenceLocalObject alloc] initWithName:format.stringValue scene:scene arguments:arguments] autorelease];
                    [fieldStack push:object];
                    shouldBeLeftBrace = YES;
                }
                else
                {
                    @throw [exception withInformation:UIAD_INVALID_OBJECT_NAME];
                }
            }
            else
            {
                @throw [exception withInformation:UIAD_INVALID_OBJECT_NAME];
            }
        }
        else if ([line hasPrefix:@"event("] && [line hasSuffix:@")"] && !hasColon)
        {
            // 取时间或event名称
            BOOL variableTimeEvent = NO;
            double initialTime = 0.0;
            NSString* eventName = nil;
            NSString* content = [[line substringWithRange:NSMakeRange(6, [line length] - 6 - 1)] trimmed];
            UIADPropertyValue* value = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"(%@)", content]];
            NSArray* arguments = nil; // 带参数事件函数的参数表

            if (value && value.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                if ([value.arrayValue count] == 1)
                {
                    UIADPropertyValue* element = [value.arrayValue objectAtIndex:0];
                    if (element.type == UIAD_PROPERTY_VALUE_NUMBER)
                    {
                        NSNumber* time = [element evaluateNumberWithObject:nil context:context];
                        if (time)
                        {
                            initialTime = [time doubleValue];
                            if (initialTime < 0.0f)
                            {
                                @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
                            }
                        }
                        else
                        {
                            // 解析不出具体event时间的情况，那么这是个动态时间的事件，需要特殊处理
                            variableTimeEvent = YES;
                        }
                    }
                    else if (element.type == UIAD_PROPERTY_VALUE_STRING)
                    {
                        eventName = element.stringValue;
                    }
                }
                else if ([value.arrayValue count] == 2)
                {
                    UIADPropertyValue* nameValue = [value.arrayValue objectAtIndex:0];
                    if (nameValue.type != UIAD_PROPERTY_VALUE_STRING)
                    {
                        @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
                    }
                    else
                    {
                        eventName = nameValue.stringValue;
                    }
                    
                    UIADPropertyValue* argumentsValue = [value.arrayValue objectAtIndex:1];
                    if (argumentsValue.type != UIAD_PROPERTY_VALUE_ARRAY)
                    {
                        @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
                    }
                    else
                    {
                        arguments = argumentsValue.arrayValue;
                        int argResult = [UIADFunctionEvent isValidArguments:arguments];
                        if (argResult == UIAD_FUNCTION_EVENT_ARGUMENT_TOO_MANY)
                        {
                            @throw [exception withInformation:@"Too many event arguments."];
                        }
                        else if (argResult == UIAD_FUNCTION_EVENT_ARGUMENT_INVALID)
                        {
                            @throw [exception withInformation:@"Invalid event argument."];
                        }
                        else if (argResult == UIAD_FUNCTION_EVENT_ARGUMENT_DUPLICATED)
                        {
                            @throw [exception withInformation:@"Duplicate argument found."];
                        }
                    }
                }
                else
                {
                    @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
                }
            }
            else
            {
                @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
            }
            
            // event域不能位于object域里，其它都可以
            UIADReferenceObject* superObject = [fieldStack peekUntilClass:[UIADReferenceObject class]];
            if (superObject != nil)
            {
                // 暂不支持物体嵌套
                @throw [exception withInformation:@"Event cannot be embraced by superior object field."];
            }
            
            if (variableTimeEvent)
            {
                // 如果是动态时间event，只能位于函数事件的第一级
                if (![[fieldStack peek] isKindOfClass:[UIADFunctionEvent class]])
                {
                    @throw [exception withInformation:@"Variable time event must be embraced by superior function event and must be of the first level."];
                }

                UIADFunctionEvent* superEvent = [fieldStack peek];
                if (superEvent.variableTimeEvent)
                {
                    @throw [exception withInformation:@"Variable time event cannot be embraced by another variable time event."];
                }
        
                UIADFunctionEvent* thisEvent = [[UIADFunctionEvent alloc] initAsVariableTimeEvent:content superEvent:superEvent sourceLine:iLine];
                [fieldStack push:thisEvent];
                [thisEvent release];
            }
            else if (eventName)
            {
                if (![eventName isValidPropertyName])
                {
                    @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
                }
                
//                // 函数式事件不允许嵌套在别的函数式事件里
//                if ([fieldStack peekUntilClass:[UIADFunctionEvent class]])
//                {
//                    @throw [exception withInformation:@"Function events can not be nested."];
//                }
                
                UIADFunctionEvent* event = [[UIADFunctionEvent alloc] initWithName:eventName arguments:arguments];
                [fieldStack push:event];
                [event release];
                
                if (![_program addFunctionEvent:event])
                {
                    @throw [exception withInformation:@"An event with the same name already exists."];
                }
            }
            else
            {
                UIADTimeObject* superTimeObject = [fieldStack peekUntilClass:[UIADTimeObject class]];
                if (superTimeObject == nil)
                {
                    @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
                }
                
                // 正常的时间event，如果位于另一个event里，则时间为相对这个event的时间
                UIADEvent* event = [[UIADEvent alloc] initWithTime:(NSTimeInterval)initialTime absoluteTime:(NSTimeInterval)(initialTime + superTimeObject.absoluteTime)];
                [fieldStack push:event];
                [event release];
            }

            shouldBeLeftBrace = YES;
        }
        else if ([line hasPrefix:@"if("] && [line hasSuffix:@")"] && !hasColon)
        {
            UIADScene* scene = [fieldStack bottom];
            if (scene == nil)
            {
                @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
            }
            
            NSString* expression = [[line substringWithRange:NSMakeRange(3, [line length] - 3 - 1)] trimmed];
            
            UIADFunctionEvent* functionEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
            UIADBooleanEvaluator* superEvaluator = [fieldStack peekUntilClass:[UIADBooleanEvaluator class]];
            UIADReferenceObject* superObject = [fieldStack peekUntilClass:[UIADReferenceObject class]];
            if (superEvaluator && functionEvent)
            {
                // 如果上一层条件与自己之间夹了functionEvent，则自己与上一层条件无关
                superEvaluator = ([fieldStack is:superEvaluator lowerThan:functionEvent]) ? nil : superEvaluator;
            }
            
            UIADBooleanEvaluator* evaluator = nil;
            if (functionEvent)
            {
                evaluator = [functionEvent addBooleanEvaluator:superEvaluator expression:expression referenceObject:superObject];
            }
            else
            {
                evaluator = [_program addBooleanEvaluator:superEvaluator expression:expression referenceObject:superObject];
            }
            
            // 进入条件判断域
            [fieldStack push:evaluator];
            shouldBeLeftBrace = YES;
        }
        else if ([line hasPrefix:@"var("] && [line hasSuffix:@")"])
        {
            // 声明变量  var(SnowCount, 5)
            NSString* content = [line substringWithRange:NSMakeRange(4, [line length] - 4 - 1)];
            UIADPropertyValue* assignment = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"(%@)", content]];
            
            if (assignment && assignment.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                UIADPropertyValue* name = [assignment.arrayValue objectAtIndex:0];
                UIADPropertyValue* value = [assignment.arrayValue objectAtIndex:1];
                
                if (name.type != UIAD_PROPERTY_VALUE_NUMBER || value.type != UIAD_PROPERTY_VALUE_NUMBER || ![name.stringValue isValidPropertyName])
                {
                    @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
                }
                
                UIADReferenceObject* object = [fieldStack peekUntilClass:[UIADReferenceObject class]];
                UIADFunctionEvent* superEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
                UIADTimeObject* superTimeField = [fieldStack peekUntilClass:[UIADTimeObject class]];
                
                if (superTimeField == nil)
                {
                    @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
                }
                
                // 生成operation
                UIADTimeLine* timeLine = nil;
                if (superEvent)
                {
                    // 如果在function_event域名里，则operation要添加到evetn的timeLine里
                    timeLine = [superEvent getTimeLine:superTimeField.absoluteTime];
                }
                else
                {
                    timeLine = [_program getTimeLine:superTimeField.absoluteTime];
                }
                
                // 如果是 if -> functionEvent -> var() 这种域结构，那么这个语句是和precondition无关的
                UIADBooleanEvaluator* precondition = [fieldStack peekUntilClass:[UIADBooleanEvaluator class]];
                if (precondition && superEvent)
                {
                    precondition = [fieldStack is:precondition lowerThan:superEvent] ? nil : precondition;
                }
                
                UIADVariableAssignment* assignment = [[UIADVariableAssignment alloc] initWithName:name.stringValue expression:value.stringValue eventVariable:NO referenceObject:object];
                [timeLine addOperation:UIAD_OPERATION_ASSIGN_VAR parameters:[NSDictionary dictionaryWithObjectsAndKeys:assignment, @"assignment", [fieldStack bottom], @"scene", nil] line:iLine runtime:NO precondition:precondition ? precondition.index : UIAD_NO_PRECONDITION];
                [assignment release];
            }
            else
            {
                @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
            }
        }
        else if ([line hasPrefix:@"localVar("] && [line hasSuffix:@")"])
        {
            // 声明变量  localVar(SnowCount, 5)
            NSString* content = [line substringWithRange:NSMakeRange(9, [line length] - 9 - 1)];
            UIADPropertyValue* assignment = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"(%@)", content]];
            
            if (assignment && assignment.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                UIADPropertyValue* name = [assignment.arrayValue objectAtIndex:0];
                UIADPropertyValue* value = [assignment.arrayValue objectAtIndex:1];
                
                if (name.type != UIAD_PROPERTY_VALUE_NUMBER || value.type != UIAD_PROPERTY_VALUE_NUMBER || ![name.stringValue isValidPropertyName])
                {
                    @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
                }
                
                UIADFunctionEvent* superEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
                if (superEvent == nil)
                {
                    @throw [exception withInformation:@"Local variable should only be declared in a function event."];
                }
                
                UIADReferenceObject* object = [fieldStack peekUntilClass:[UIADReferenceObject class]];
                
                UIADTimeObject* superTimeField = [fieldStack peekUntilClass:[UIADTimeObject class]];
                
                // 生成operation
                UIADTimeLine* timeLine = [superEvent getTimeLine:superTimeField.absoluteTime];                

                // 如果是 if -> functionEvent -> localVar() 这种域结构，那么这个语句是和precondition无关的
                UIADBooleanEvaluator* precondition = [fieldStack peekUntilClass:[UIADBooleanEvaluator class]];
                if (precondition)
                {
                    precondition = [fieldStack is:precondition lowerThan:superEvent] ? nil : precondition;
                }
                
                UIADVariableAssignment* assignment = [[UIADVariableAssignment alloc] initWithName:name.stringValue expression:value.stringValue eventVariable:YES referenceObject:object];
                [timeLine addOperation:UIAD_OPERATION_ASSIGN_VAR parameters:[NSDictionary dictionaryWithObjectsAndKeys:assignment, @"assignment", [fieldStack bottom], @"scene", nil] line:iLine runtime:NO precondition:precondition ? precondition.index : UIAD_NO_PRECONDITION];
                [assignment release];
            }
            else
            {
                @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
            }
        }
        else if ([line hasPrefix:@"const("] && [line hasSuffix:@")"])
        {
            // 声明常量  const(TIME, 5)
            NSString* content = [line substringWithRange:NSMakeRange(6, [line length] - 6 - 1)];
            UIADPropertyValue* assignment = [UIADPropertyValue propertyValueWithString:[NSString stringWithFormat:@"(%@)", content]];
            
            if (assignment && assignment.type == UIAD_PROPERTY_VALUE_ARRAY)
            {
                UIADPropertyValue* name = [assignment.arrayValue objectAtIndex:0];
                UIADPropertyValue* value = [assignment.arrayValue objectAtIndex:1];
                
                if (name.type != UIAD_PROPERTY_VALUE_NUMBER || value.type != UIAD_PROPERTY_VALUE_NUMBER || ![name.stringValue isValidPropertyName])
                {
                    @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
                }
                
                NSNumber* evaluatedValue = [value evaluateNumberWithObject:nil context:context];
                if (![_program registerConst:name.stringValue value:evaluatedValue])
                {
                    @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
                }
            }
            else
            {
                @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
            }
        }
        else
        {
            // 解析赋值语句（也就是函数调用语句）
            BOOL pushedLocalEvent = NO;
            id scene = [fieldStack bottom];
            if (scene == nil || ![scene isKindOfClass:[UIADScene class]])
            {
                @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
            }
            
            NSString* error = nil;
            NSMutableArray* segments = [NSMutableArray arrayWithCapacity:10];
            if (![self parseSetValueLine:line segments:segments error:&error])
            {
                @throw [exception withInformation:error];
            }
            
            // 赋值语句对域的要求是如果指定了对象，也就是语句里有object()、localObject()，那么不能在物体域里；否则向上查找物体域，表示对该物体调用方法，这种情况下物体域与本行之间只能有条件域或（循环域）
            UIADObjectBase* object = [fieldStack peekUntilClass:[UIADReferenceObject class]];
            UIADReferenceObject* superObject = (UIADReferenceObject*)object;
            UIADFunctionEvent* superEvent = [fieldStack peekUntilClass:[UIADFunctionEvent class]];
            UIADSetValueLineSegment* objectSegment = [segments getObject];
            if (object)
            {
                // 已经在对象域里，不允许再使用segment方式访问其它对象。比如这样是不允许的，object("object"){object("object2"):show:}
                if (objectSegment)
                {
                    @throw [exception withInformation:UIAD_INVALID_ASSIGNMENT];
                }
            }
            else
            {
                if (objectSegment == nil)
                {
                    // 无物体，调用的是scene的方法
                    object = scene;
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT)
                {
                    object = [scene objectWithName:objectSegment.value];
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_REF)
                {
                    // 引用对象需要在函数事件里
                    if (superEvent == nil || ![superEvent hasArgument:objectSegment.value])
                    {
                        @throw [exception withInformation:[NSString stringWithFormat:@"Unfound object \"%@\".", objectSegment.value]];
                    }
                    
                    // 创建用来访问这个参数的对象
                    object = [[[UIADReferenceObject alloc] initWithName:objectSegment.value scene:scene] autorelease];
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_FMT)
                {
                    // 参数式访问对象 object("wall%d", [1])，可出现在代码中任何位置
                    object = [[[UIADFormatReferenceObject alloc] initWithName:objectSegment.value scene:scene arguments:objectSegment.arguments] autorelease];
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL)
                {
                    // 是参数函数内部对象
                    if (superEvent == nil)
                    {
                        @throw [exception withInformation:[NSString stringWithFormat:@"Unfound object \"%@\".", objectSegment.value]];
                    }
                    
                    // 创建用来访问这个参数的对象
                    object = [[[UIADLocalObject alloc] initWithName:objectSegment.value scene:scene] autorelease];
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_LOCAL_FMT)
                {
                    // 是参数函数内部对象的参数方式访问，localObject("wall%d", [index])
                    if (superEvent == nil)
                    {
                        @throw [exception withInformation:[NSString stringWithFormat:@"Unfound object \"%@\".", objectSegment.value]];
                    }
                    
                    // 创建用来访问这个参数的对象
                    object = [[[UIADFormatReferenceLocalObject alloc] initWithName:objectSegment.value scene:scene arguments:objectSegment.arguments] autorelease];
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE)
                {
                    object = [[[UIADObjectWithImage alloc] initWithName:objectSegment.value scene:scene imageName:objectSegment.arguments.stringValue] autorelease];
                }
                else if (objectSegment.type == UIAD_PARSER_LINE_SEGMENT_OBJECT_IMAGE_LOCAL)
                {
                    // 是参数函数内部对象
                    if (superEvent == nil)
                    {
                        @throw [exception withInformation:[NSString stringWithFormat:@"Unfound object \"%@\".", objectSegment.value]];
                    }
                    
                    object = [[[UIADLocalObjectWithImage alloc] initWithName:objectSegment.value scene:scene imageName:objectSegment.arguments.stringValue] autorelease];
                }
            }
            
            // 检查参数与方法是否匹配
            // 解析调用的方法的参数表
            UIADPropertyValue* propertyValue = [UIADPropertyValue propertyValueWithString:[segments get:UIAD_PARSER_LINE_SEGMENT_PARAMETERS].value];
            if (propertyValue == nil)
            {
                @throw [exception withInformation:@"Invalid property value."]; // 属性值解析失败
            }
            
            UIADSetValueLineSegment* methodSegment = [segments get:UIAD_PARSER_LINE_SEGMENT_METHOD]; // 取函数名
            if (object == nil || methodSegment == nil || ![object isValidPropertyValueForProperty:methodSegment.value value:propertyValue])
            {
                @throw [exception withInformation:[NSString stringWithFormat:@"Unsupported method \"%@\".", methodSegment.value]];
            }
            
            // 检查参数里是不是使用url资源图片
            if ([methodSegment.value isEqualToString:@"image"] && propertyValue.type == UIAD_PROPERTY_VALUE_STRING)
            {
                [_program verifyImageFromURL:propertyValue.stringValue];
            }
            else if ([methodSegment.value isEqualToString:@"transit"])
            {
                if (propertyValue.type == UIAD_PROPERTY_VALUE_STRING)
                {
                    [_program verifyImageFromURL:propertyValue.stringValue];
                }
                else if (propertyValue.type == UIAD_PROPERTY_VALUE_DICTIONARY)
                {
                    UIADPropertyValue* imageNameValue = [propertyValue.dictionaryValue objectForKey:@"image"];
                    if (imageNameValue.type == UIAD_PROPERTY_VALUE_STRING)
                    {
                        [_program verifyImageFromURL:imageNameValue.stringValue];
                    }
                }
            }
            
            // for循环块
            NSArray* forBlocks = [segments getArray:UIAD_PARSER_LINE_SEGMENT_FOR];
            NSMutableArray* forEvaluators = [NSMutableArray arrayWithCapacity:[forBlocks count]];
            NSMutableDictionary* forVariableNames = [NSMutableDictionary dictionaryWithCapacity:[forBlocks count]]; // 循环变量的名称
            for (unsigned int i = 0; i < [forBlocks count]; i ++)
            {
                // 校验工作已经在解析segments时做了
                UIADSetValueLineSegment* segment = [forBlocks objectAtIndex:i];
                UIADForLoopEvaluator* evaluator = nil;
                
                // 检查循环变量名字是否重复
                NSString* variableName = ((UIADPropertyValue*)[segment.arguments.arrayValue objectAtIndex:0]).stringValue;
                if ([forVariableNames objectForKey:variableName])
                {
                    @throw [exception withInformation:@"Duplicate for loop variable names."];
                }
                else
                {
                    [forVariableNames setObject:@"" forKey:variableName];
                }
                
                // 如果没有superEvent这个for语句就加到program里，否则加到event自己的空间里
                if (superEvent)
                {
                    evaluator = [superEvent addForLoopEvaluator:segment.arguments referenceObject:superObject];
                }
                else
                {
                    evaluator = [_program addForLoopEvaluator:segment.arguments referenceObject:superObject];
                }
                
                if ([forEvaluators count] > 0)
                {
                    UIADForLoopEvaluator* previous = [forEvaluators objectAtIndex:[forEvaluators count] - 1];
                    previous.next = evaluator;
                }
                [forEvaluators addObject:evaluator];
            }
            
            // 是否有事件，比如“if(A > 0):event(3):object("wall%d", [index]):animate:(key:"opacity", to:1)”
            UIADSetValueLineSegment* eventSegment = [segments get:UIAD_PARSER_LINE_SEGMENT_EVENT];
            if (eventSegment)
            {
                NSNumber* time = [[UIADPropertyValue valueAsNumberWithString:eventSegment.value] evaluateNumberWithObject:nil context:context];
                if (time)
                {
                    double initialTime = [time doubleValue];
                    if (initialTime < 0.0f)
                    {
                        @throw [exception withInformation:UIAD_INVALID_EVENT_PARAM];
                    }
                    
                    UIADTimeObject* superTimeObject = [fieldStack peekUntilClass:[UIADTimeObject class]];
                    if (superTimeObject == nil)
                    {
                        @throw [exception withInformation:UIAD_SCENE_NOT_FOUND];
                    }
                    
                    // 正常的时间event，如果位于另一个event里，则时间为相对这个event的时间
                    UIADEvent* event = [[UIADEvent alloc] initWithTime:(NSTimeInterval)initialTime absoluteTime:(NSTimeInterval)(initialTime + superTimeObject.absoluteTime)];
                    [fieldStack push:event];
                    [event release];
                    pushedLocalEvent = YES; // 这一行解析完后要pop掉
                }
            }
            
            // 是否有先决条件，本次赋值语句里的条件segment也要加到条件里
            UIADBooleanEvaluator* precondition = [fieldStack peekUntilClass:[UIADBooleanEvaluator class]]; // 查找上层if语句
            if (precondition && superEvent)
            {
                // 如果上一层条件与自己之间夹了functionEvent，则自己与上一层条件无关
                precondition = ([fieldStack is:precondition lowerThan:superEvent]) ? nil : precondition;
            }
            UIADSetValueLineSegment* ifSegment = [segments get:UIAD_PARSER_LINE_SEGMENT_IF];
            if (ifSegment)
            {
                UIADBooleanEvaluator* thisCondition = nil;
                if (superEvent)
                {
                    thisCondition = [superEvent addBooleanEvaluator:precondition expression:ifSegment.value referenceObject:superObject];
                }
                else
                {
                    thisCondition = [_program addBooleanEvaluator:precondition expression:ifSegment.value referenceObject:superObject];
                }
                precondition = thisCondition;
            }
            
            // 取上层时间对象
            UIADTimeObject* superTimeField = [fieldStack peekUntilClass:[UIADTimeObject class]];
            
            // 生成operation
            UIADTimeLine* timeLine = nil;
            if (superEvent)
            {
                // 如果在function_event域名里，则operation要添加到evetn的timeLine里
                timeLine = [superEvent getTimeLine:superTimeField.absoluteTime];
            }
            else
            {
                timeLine = [_program getTimeLine:superTimeField.absoluteTime];
            }
            
            UIADOperation* operation = [timeLine addOperation:UIAD_OPERATION_ASSIGN parameters:[NSDictionary dictionaryWithObjectsAndKeys:object, @"object", methodSegment.value, @"name", propertyValue, @"value", [fieldStack bottom], @"scene", nil] line:iLine runtime:NO precondition:precondition ? precondition.index : UIAD_NO_PRECONDITION];
            if ([forEvaluators count] > 0)
            {
                operation.forLoopConditions = forEvaluators;
            }
            
            if (pushedLocalEvent)
            {
                [fieldStack pop];
            }
        }
        
        iLine ++;
    }
    
    // 域没结束
    if ([fieldStack peek] != nil)
    {
        exception.errorLine = [lines count];
        @throw [exception withInformation:@"Incomplete script."];
    }
    
    [pool drain];
    
    [_program sort];
}

+ (UIADOperation*)parseAssignmentOperationWithTarget:(UIView*)target script:(NSString*)script
{
    static UIADScene* _default_scene = nil;
    
    NSRange colonRange = [script rangeOfString:@":"];
    if (colonRange.length <= 0)
    {
        return nil;
    }
    
    NSString* propertyName = nil;
    NSMutableString* lineStr = [NSMutableString stringWithString:script];
    NSString* leftStr = [[lineStr substringToIndex:colonRange.location] trimmed];
    [lineStr deleteCharactersInRange:NSMakeRange(0, colonRange.location + 1)]; // 去掉第一个冒号和它左边的字符
    
    if (![leftStr isValidPropertyName])
    {
        return nil;
    }
    
    propertyName = leftStr;
    
    UIADPropertyValue* propertyValue = [UIADPropertyValue propertyValueWithString:[lineStr trimmed]];
    if (propertyValue == nil)
    {
        return nil;
    }
    
    if (_default_scene == nil)
        _default_scene = [[UIADScene alloc] initWithAbsoluteTime:0.0f name:@"default"];
    
    UIADObject* object = [[[UIADObject alloc] initWithExternal:@"" scene:_default_scene entity:target] autorelease];
    if (![object isValidPropertyValueForProperty:propertyName value:propertyValue])
    {
        return nil;
    }
    
    UIADOperation* operation = [[UIADOperation alloc] initWithType:UIAD_OPERATION_ASSIGN parameters:[NSDictionary dictionaryWithObjectsAndKeys:object, @"object", propertyName, @"name", propertyValue, @"value", nil] timeLine:nil line:0 runtime:NO precondition:UIAD_NO_PRECONDITION];
    return [operation autorelease];
}

@end
