//
//  UIAnimationDirector+Operation.h
//  QQMSFContact
//
//  Created by bruiswang on 12-10-10.
//
//

#import <Foundation/Foundation.h>
 
#define UIAD_LOG(format, ...)                   NSLog(format, ##__VA_ARGS__)
//#define UIAD_LOG(format, ...)

#define UIAD_TIME_LINE_PRECISION        0.01
#define UIAD_NO_PRECONDITION            -1
#define UIAD_FINISH_BUFFER_TIME         3       // 动画的operation都执行过了，但是需要再有一个缓冲时间才真正认为整个动画结束
#define UIAD_MARQUEE_TEXT_DURATION      0.3     // 滚动文本默认动画时间
#define UIAD_MARQUEE_TEXT_FONT          14      // 滚动文本默认字号

@class UIADProgram;
@class UIADTimeLine;
@class UIADOperation;
@class UIADScene;
@class UIADReferenceObject;
@class UIADObject;
@class UIADMarqueeLabel;
@class UIADFunctionEvent;
@class UIADBooleanEvaluator;
@class UIADForLoopEvaluator;
@class UIADPropertyValue;
@protocol UIADOperationDelegate;

@interface UIADOperationContext : NSObject
{
    NSTimeInterval _now;        // 脚本已经运行的时间
    
    BOOL _evaluateAllowObject;  // 四则运算解析时是否允许访问对象
    BOOL _operationWithTarget;  // 是否是对某个对象执行单行动画脚本
    
    id _animationDelegate;
    
    double _speed;
    UIView<UIADOperationDelegate>* _mainView;
    UIADProgram* _program;
    UIADScene* _scene;
    NSObject* _invokeResponder;
    
    // 对每个operation运行时临时变量
    UIADOperation* _operation;
    UIADFunctionEvent* _functionEvent;
    
    // 用于对动画起始、事件的解析
    id _animation;
    UIADPropertyValue* _startEvent, *_stopEvent;
    NSArray* _startEventArgs, *_stopEventArgs;
    
    NSMutableDictionary* _forLoopValues; // 记录循环变量的值
    
    NSString* _scriptFilePath; // 脚本文件的路径，用于取相对路径的图片资源
    NSMutableString* _lastError;
}

@property (nonatomic, assign) NSTimeInterval now;
@property (nonatomic, assign) BOOL evaluateAllowObject;
@property (nonatomic, assign) BOOL operationWithTarget;
@property (nonatomic, assign) id animationDelegate;
@property (nonatomic, assign) double speed;
@property (nonatomic, assign) UIView<UIADOperationDelegate>* mainView;
@property (nonatomic, assign) UIADProgram* program;
@property (nonatomic, assign) UIADScene* scene;
@property (nonatomic, assign) NSObject* invokeResponder;
@property (nonatomic, assign) UIADOperation* operation;
@property (nonatomic, assign) UIADFunctionEvent* functionEvent;
@property (nonatomic, assign) id animation;
@property (nonatomic, assign) UIADPropertyValue* startEvent;
@property (nonatomic, assign) UIADPropertyValue* stopEvent;
@property (nonatomic, retain) NSArray* startEventArgs;
@property (nonatomic, retain) NSArray* stopEventArgs;
@property (nonatomic, retain) NSMutableDictionary* forLoopVariables;
@property (nonatomic, retain) NSString* scriptFilePath;
@property (nonatomic, retain) NSMutableString* lastError;

@end

#pragma mark -

enum UIAD_PROGRAM_STATUS
{
    UIAD_PROGRAM_STATUS_IDLE,
    UIAD_PROGRAM_STATUS_RUNNING,
    UIAD_PROGRAM_STATUS_FINISH_BUFFER,
    UIAD_PROGRAM_STATUS_FINISHED,
};

@protocol UIADProgramDelegate <NSObject>

- (void)didBeginDownloadingResources:(UIADProgram*)sender;
- (void)didEndDownloadingResources:(UIADProgram*)sender success:(BOOL)success;

@end

@interface UIADProgram : NSObject
{
    BOOL _infiniteRunloop;                  // 在UIAnimationDirector的线程循环里，是否执行完所有timeLine后自动退出
    int _current;
    int _status;
    NSTimeInterval _finishBufferTime;       // 结束缓冲的起始时间
    NSMutableArray* _timeLines;             // 脚本代码解析出的时间确定的时间线
    NSMutableDictionary* _functionEvents;   // 脚本里的函数event事件
    NSMutableDictionary* _localVariables;   // 数值变量
    NSMutableArray* _booleanEvaluators;     // boolean域
    NSMutableArray* _forLoopEvaluators;     // for循环域
    NSMutableArray* _scenes;                // 脚本里的场景
    NSMutableArray* _animationDelegates;    // 每个CAAnimation创建一个代理，响应动画起始和终止事件
    NSMutableArray* _gestureDelegates;      // 对象的点击事件代理，触发后调用脚本里的一个event
    NSMutableArray* _eventPipelines;        // 当前正在运行的functionEvents
    NSMutableDictionary* _macros;           // 用户注册的宏。宏每次reset会被清掉，而const不会，const是编译期确定的
    NSMutableDictionary* _consts;           // 脚本中的常量，常量可以用在表达式解析，以及event(CONST)里指定时间
    NSMutableDictionary* _manually;         // 手动操纵的对象，使用key来分组
    
    id<UIADProgramDelegate> _delegate;
    
@private
    NSMutableArray* _downloadResources;     // 需要下载的图片链接
    NSMutableArray* _downloaders;
}

@property (nonatomic, assign) int status;
@property (nonatomic, assign) BOOL infiniteRunloop;
@property (nonatomic, readonly) NSMutableArray* timeLines;
@property (nonatomic, readonly) NSMutableDictionary* functionEvents;
@property (nonatomic, readonly) NSMutableDictionary* localVariables;
@property (nonatomic, readonly) NSMutableArray* booleanEvaluators;
@property (nonatomic, readonly) NSMutableArray* forLoopEvaluators;
@property (nonatomic, readonly) NSMutableArray* scenes;
@property (nonatomic, readonly) NSMutableArray* animationDelegates;
@property (nonatomic, readonly) NSMutableDictionary* macros;
@property (nonatomic, readonly) NSMutableDictionary* consts;
@property (nonatomic, assign) id<UIADProgramDelegate> delegate;

- (void)addScene:(UIADScene*)scene;
- (UIADTimeLine*)getTimeLine:(NSTimeInterval)time;
- (void)sort;
- (void)reset;
- (BOOL)finished:(NSTimeInterval)now;

- (UIADScene*)sceneWithName:(NSString*)name;
- (BOOL)addFunctionEvent:(UIADFunctionEvent*)event;
- (UIADBooleanEvaluator*)addBooleanEvaluator:(UIADBooleanEvaluator*)superEvaluator expression:(NSString*)expression referenceObject:(UIADReferenceObject*)referenceObject;
- (UIADBooleanEvaluator*)getBooleanEvaluator:(int)index;
- (UIADForLoopEvaluator*)addForLoopEvaluator:(UIADPropertyValue*)arguments referenceObject:(UIADReferenceObject*)referenceObject;

- (void)setLocalVariable:(NSString*)name value:(id)value;
- (id)getLocalVariable:(NSString*)name;

- (NSArray*)getExecutableLines:(NSTimeInterval)time modification:(NSTimeInterval*)modification;
- (BOOL)executeEvent:(NSString*)name arguments:(NSArray*)arguments context:(UIADOperationContext*)context;

- (void)registerMacro:(NSString*)name value:(id)value;
- (BOOL)registerConst:(NSString*)name value:(id)value;

- (void)addManuallyManipulatedObject:(UIADObject*)object forKey:(NSString*)key;
- (void)setTimeOffset:(CFTimeInterval)value forObjectsByKey:(NSString*)key;

// 注册一个外部的UIView到program的某个scene里，以便让program能够对该对象释加动画
//- (BOOL)registerExternalObject:(UIView*)object name:(NSString*)name scene:(NSString*)scene;

- (void)verifyImageFromURL:(NSString*)location;
- (void)cancelDownloads;
- (BOOL)isResourcesReady;

@end

enum UIAD_OPERATION_TYPE
{
    UIAD_OPERATION_SCENE,           // 创建scene
    UIAD_OPERATION_ASSIGN,          // 属性赋值或调用方法
    UIAD_OPERATION_ASSIGN_VAR,      // 数值变量赋值
    UIAD_OPERATION_VARIABLE_EVENT,  // 时间在编译期无法判断的动态事件
};

@interface UIADTimeLine : NSObject
{
    NSTimeInterval _time;
    
    NSMutableArray* _operations;
    UIADFunctionEvent* _functionEvent;
}

@property (nonatomic, readonly) NSTimeInterval time;
@property (nonatomic, readonly) NSMutableArray* operations;
@property (nonatomic, assign) UIADFunctionEvent* functionEvent;

- (id)initWithTime:(NSTimeInterval)time;
- (id)initWithTime:(NSTimeInterval)time capacity:(int)capacity;

- (UIADOperation*)addOperation:(int)type parameters:(NSDictionary*)parameters line:(int)line runtime:(BOOL)runtime precondition:(int)precondition;
- (void)reset;

- (UIADTimeLine*)duplicateTimeLine;

@end

@protocol UIADOperationDelegate <NSObject>

@required
- (void)didSceneEntityCreated:(UIADScene*)scene;
- (void)didObjectEntityCreated:(UIADObject*)object;
- (void)marqueeTextConfigureLabel:(UIADMarqueeLabel*)label object:(UIADObject*)object newLine:(BOOL)newLine;

@end

@interface UIADOperation : NSObject
{
    int _line;  // 记录对应的代码行数，便于定位脚本问题
    BOOL _runtime;  // 运行时创建的operation
    BOOL _invalid;  // timeline已经无效
    
    int _type;
    NSDictionary* _parameters;
    
    UIADTimeLine* _timeLine; // 在哪个timeLine里
    int _precondition;  // 这个operation要执行，需要需要的先决条件，是UIADBooleanEvaluator的序号
    NSMutableArray* _forLoopConditions; // 这个operation在哪些for循环里
}

@property (nonatomic, readonly) int line;
@property (nonatomic, readonly) BOOL runtime;
@property (nonatomic, assign) BOOL invalid;
@property (nonatomic, readonly) int type;
@property (nonatomic, readonly) NSDictionary* parameters;
@property (nonatomic, assign) UIADTimeLine* timeLine;
@property (nonatomic, readonly) int precondition;
@property (nonatomic, retain) NSMutableArray* forLoopConditions;

- (id)initWithType:(int)type parameters:(NSDictionary*)parameters timeLine:(UIADTimeLine*)timeLine line:(int)line runtime:(BOOL)runtime precondition:(int)precondition;

- (UIADScene*)getScene;
- (BOOL)execute:(UIADOperationContext*)context;
- (UIADOperation*)duplicateOperation;

@end

#pragma mark -

@class UIADObject;
@class UIADPropertyValue;

// 用于动画呈现的实体，暂为UIView
typedef UIView UIADEntity;

@interface UIView(UIADEntity)
+ (UIADEntity*)createDefaultEntity;
@end

@interface UIADImageEntity : UIADEntity
{
    UIImage* _image;
}

@property (nonatomic, retain) UIImage* image;

+ (UIADImageEntity*)createDefaultEntity;

@end

@interface UIADMarqueeLabel : UILabel

@property (nonatomic, assign) int marqueeIndex;
@property (nonatomic, assign) CGFloat minAlpha; // default 0.0

@end

@interface UIADObjectBase : NSObject

- (BOOL)isValidPropertyName:(NSString*)str; // str是不是这个物体可用的属性
- (BOOL)isValidPropertyValueForProperty:(NSString*)name value:(UIADPropertyValue*)value;
- (BOOL)setPropertyValue:(NSString*)name value:(UIADPropertyValue*)value context:(UIADOperationContext*)context;
- (UIADObjectBase*)getObject:(UIADOperationContext*)context;

@end

@interface UIADTimeObject : UIADObjectBase
{
    NSTimeInterval _absoluteTime;
}

@property (nonatomic, readonly) NSTimeInterval absoluteTime;

@end

enum UIAD_RESOURCE_TYPE
{
    UIAD_RESOURCE_MAIN_BUNDLE,      // 这个scene里的资源在mainBundle里
    UIAD_RESOURCE_PATH,             // 这个scene里的资源在一个路径下，使用时需要拼文件完整名
    UIAD_RESOURCE_ABSOLUTE,         // 资源使用绝对路径
};

@interface UIADScene : UIADTimeObject
{
    NSString* _name;
    NSMutableDictionary* _objects;
    
    UIADEntity* _entity;
    
    // 资源查找
    int _resourceType;
    NSString* _mainPath;
    
    // 默认值，简化脚本用的
    NSString* _defaultFillMode;
    NSString* _defaultTimingFunction;
    BOOL _defaultRemovedOnCompletion;
    CFTimeInterval _defaultDuration;
    double _defaultImageScale;
}

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSMutableDictionary* objects;
@property (nonatomic, retain) UIADEntity* entity;
@property (nonatomic, readonly) int resourceType;
@property (nonatomic, readonly) NSString* mainPath;

@property (nonatomic, readonly) NSString* defaultFillMode;
@property (nonatomic, readonly) NSString* defaultTimingFunction;
@property (nonatomic, readonly) BOOL defaultRemovedOnCompletion;
@property (nonatomic, readonly) CFTimeInterval defaultDuration;
@property (nonatomic, readonly) double defaultImageScale; // 场景内的图片加载后，会设置一次对象的尺寸，使和图片相同，这个是默认的尺寸缩放比例

- (id)initWithAbsoluteTime:(NSTimeInterval)absoluteTime name:(NSString*)name;
- (UIADObject*)objectWithName:(NSString*)name;
- (UIADObject*)objectWithNameNoCreate:(NSString *)name;
- (UIImage*)getImageFile:(NSString*)fileName context:(UIADOperationContext*)context;

- (void)reset;

@end

@interface UIADEvent : UIADTimeObject
{
    NSTimeInterval _time;           // 相对上层的时间
}

@property (nonatomic, readonly) NSTimeInterval time;

- (id)initWithTime:(NSTimeInterval)time absoluteTime:(NSTimeInterval)absoluteTime;

@end

enum UIAD_FUNCTION_EVENT_STATE
{
    UIAD_FUNCTION_EVENT_IDLE,
    UIAD_FUNCTION_EVENT_STARTED,
    UIAD_FUNCTION_EVENT_FINISH_BUFFER,
    UIAD_FUNCTION_EVENT_FINISHED,
};

enum UIAD_FUNCTION_EVENT_ARGUMENT
{
    UIAD_FUNCTION_EVENT_ARGUMENT_OK,
    UIAD_FUNCTION_EVENT_ARGUMENT_TOO_MANY,
    UIAD_FUNCTION_EVENT_ARGUMENT_INVALID,
    UIAD_FUNCTION_EVENT_ARGUMENT_DUPLICATED,
};

@interface UIADFunctionEvent : UIADEvent
{
    int _variableTimeEventLine;     // 可变时间事件在代码中的行数
    BOOL _variableTimeEvent;        // 可变时间的事件
    
    NSTimeInterval _startTime;
    NSTimeInterval _finishBufferTime;       // 结束缓冲的起始时间
    
    int _status;
    int _current;
    NSString* _name;                // 拥有名字的event，类似一个函数，编译时无法确定执行时间
    NSMutableArray* _timeLines;
    
    NSDictionary* _argumentIndex;   // 记录某个参数名是第几个参数
    NSArray* _runtimeArguments;     // 运行时真正参数，从UIAD_PROPERTY_VALUE_ARRAY类型的UIADPropertyValue里获得
    
    NSMutableArray* _variableTimeEvents;    // 子可变时间事件
    NSMutableDictionary* _localObjects;
    NSMutableDictionary* _localVariables;   // 局部的数值变量
    NSMutableArray* _booleanEvaluators;     // 函数里的条件域
    NSMutableArray* _forLoopEvaluators;     // for循环域
}

@property (nonatomic, readonly) int variableTimeEventLine;
@property (nonatomic, readonly) BOOL variableTimeEvent;
@property (nonatomic, readonly) int status;
@property (nonatomic, readonly) int current;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSMutableArray* timeLines;
@property (nonatomic, retain) NSDictionary* argumentIndex;
@property (nonatomic, retain) NSArray* runtimeArguments;
@property (nonatomic, retain) NSMutableArray* variableTimeEvents;
@property (nonatomic, readonly) NSMutableDictionary* localObjects;
@property (nonatomic, readonly) NSMutableDictionary* localVariables;
@property (nonatomic, readonly) NSMutableArray* booleanEvaluators;
@property (nonatomic, retain) NSMutableArray* forLoopEvaluators;

+ (int)isValidArguments:(NSArray*)arguments;

- (id)initWithName:(NSString*)name;
- (id)initWithName:(NSString*)name arguments:(NSArray*)arguments;
- (id)initAsVariableTimeEvent:(NSString*)expression superEvent:(UIADFunctionEvent*)superEvent sourceLine:(int)sourceLine;

- (UIADTimeLine*)getTimeLine:(NSTimeInterval)time;
- (UIADFunctionEvent*)duplicateEvent;

- (BOOL)hasArgument:(NSString*)arg;
- (id)argumentValue:(NSString*)argName;

- (BOOL)finished:(NSTimeInterval)now;
- (void)trigger:(NSTimeInterval)time;
- (NSArray*)getExecutableLines:(NSTimeInterval)time;

- (UIADObject*)localObjectWithName:(NSString*)name context:(UIADOperationContext*)context allowCreate:(BOOL)allowCreate;
- (BOOL)removeLocalObject:(UIADObject*)object;

- (void)addSubVariableTimeEvent:(UIADFunctionEvent*)subEvent;
- (BOOL)decideSubVariableTimeEventTime:(UIADOperationContext*)context; // 当自己开始要执行时，将子的动态时间方法添加到自己的时间线里

- (UIADBooleanEvaluator*)addBooleanEvaluator:(UIADBooleanEvaluator*)superEvaluator expression:(NSString*)expression referenceObject:(UIADReferenceObject*)referenceObject;
- (UIADBooleanEvaluator*)getBooleanEvaluator:(int)index;
- (UIADForLoopEvaluator*)addForLoopEvaluator:(UIADPropertyValue*)arguments referenceObject:(UIADReferenceObject*)referenceObject;

- (void)setLocalVariable:(NSString*)name value:(id)value;
- (id)getLocalVariable:(NSString*)name;

@end

enum UIAD_BOOL_VALUE
{
    UIAD_BOOL_FALSE = 0,
    UIAD_BOOL_TRUE = 1,
    UIAD_BOOL_UNDEFINED,
};

// 处理脚本中的条件语句
@interface UIADBooleanEvaluator : NSObject
{
    int _index;         // 自己的序号
    int _superIndex;    // 上一层boolean表达式的序号
    int _inner_value;
    NSString* _expression;
    UIADFunctionEvent* _functionEvent;
    UIADReferenceObject* _referenceObject;  // 当bool域或bool块在对象域里面时，bool表达式访问该对象属性是可以省略对象名的
}

@property (nonatomic, readonly) int index;
@property (nonatomic, readonly) NSString* expression;
@property (nonatomic, assign) UIADFunctionEvent* functionEvent;
@property (nonatomic, retain) UIADReferenceObject* referenceObject;

- (id)initWithIndex:(int)index superIndex:(int)superIndex expression:(NSString*)expression referenceObject:(UIADReferenceObject*)referenceObject;

- (UIADBooleanEvaluator*)duplicateBooleanEvaluator;
- (void)reset;

- (BOOL)getValue:(UIADOperationContext*)context pValue:(BOOL*)pValue; // 函数返回是否成功，具体bool值是在参数pValue里返回

@end

// 处理脚本中的变量赋值
@interface UIADVariableAssignment : NSObject
{
    BOOL _eventVariable;  // 是否是functionEvent里的变量
    NSString* _name;
    NSString* _expression;
    UIADReferenceObject* _referenceObject;  // 当变量赋值操作在对象域里面时，访问该对象属性是可以省略对象名的
}

@property (nonatomic, readonly) BOOL eventVariable;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* expression;
@property (nonatomic, readonly) UIADReferenceObject* referenceObject;

- (id)initWithName:(NSString*)name expression:(NSString*)expression eventVariable:(BOOL)eventVariable referenceObject:(UIADReferenceObject*)referenceObject;

- (BOOL)performAssignment:(UIADOperationContext*)context;

@end

// 处理脚本中的循环语句
@interface UIADForLoopEvaluator : NSObject
{
    NSNumber* _loopValue;
    UIADForLoopEvaluator* _next;
    UIADPropertyValue* _arguments;
    UIADReferenceObject* _referenceObject;  // 当for块在对象域里面时，bool表达式访问该对象属性是可以省略对象名的
}

@property (nonatomic, assign) UIADForLoopEvaluator* next;   // 多重循环使用
@property (nonatomic, readonly) UIADPropertyValue* arguments;
@property (nonatomic, retain) UIADReferenceObject* referenceObject;

- (id)initWithArguments:(UIADPropertyValue*)arguments referenceObject:(UIADReferenceObject*)referenceObject;
- (BOOL)execute:(UIADOperation*)operation context:(UIADOperationContext*)context;

@end

#pragma mark -

// 参数函数里对物体的引用，解析时生成UIADReferenceObject，记录一下引用的参数名称
@interface UIADReferenceObject : UIADObjectBase
{
    NSString* _name;
    UIADScene* _scene;
}

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) UIADScene* scene;

- (id)initWithName:(NSString*)name scene:(UIADScene*)scene;

@end

// 带参数的对象引用
// eg. object("wall%d", [index])
@interface UIADFormatReferenceObject : UIADReferenceObject
{
    UIADPropertyValue* _arguments;
}

@property (nonatomic, readonly) UIADPropertyValue* arguments;

- (id)initWithName:(NSString *)name scene:(UIADScene *)scene arguments:(UIADPropertyValue*)arguments;

@end

// 参数函数里创建的对象
// eg. localObject("obj")
@interface UIADLocalObject : UIADReferenceObject

@end

// 参数函数里的带参数的局部对象引用
// eg. localObject("wall%d", [index])
@interface UIADFormatReferenceLocalObject : UIADFormatReferenceObject

@end

// 访问对象时同时指定图片
// eg. object("name", "image")
@interface UIADObjectWithImage : UIADReferenceObject
{
    NSString* _imageName;
}

@property (nonatomic, readonly) NSString* imageName;

- (id)initWithName:(NSString *)name scene:(UIADScene *)scene imageName:(NSString*)imageName;

@end

@interface UIADLocalObjectWithImage : UIADObjectWithImage

@end

// 普通对象
@interface UIADObject : UIADReferenceObject
{   
    BOOL _external;     // 是否是外部对象
    BOOL _sizeModified; // 通过脚本设置过尺寸了

    UIADEntity* _entity;    
    CGSize _resourceImageSize;  // 记录资源图片的尺寸
    
    UIADFunctionEvent* _functionEvent; // 当这个物体是创建在事件函数里时有效
    
    int _marqueeTextIndex;
    NSMutableArray* _marqueeTexts;
    NSTimeInterval _defaultMarqueeTextDuration;
    CGFloat _marqueeTextScaleFactor; // 默认是1，也就是不缩小
}

@property (nonatomic, readonly) BOOL external;
@property (nonatomic, retain) UIADEntity* entity;
@property (nonatomic, assign) UIADFunctionEvent* functionEvent;
@property (nonatomic, readonly) NSMutableArray* marqueeTexts;
@property (nonatomic, readonly) NSTimeInterval defaultMarqueeTextDuration;
@property (nonatomic, readonly) CGFloat marqueeTextScaleFactor;

- (id)initWithName:(NSString*)name scene:(UIADScene*)scene;
- (id)initWithExternal:(NSString*)name scene:(UIADScene*)scene entity:(UIADEntity*)entity;

- (void)reset;
- (void)replaceEntity:(UIADEntity*)entity;

@end

#pragma mark -

enum UIAD_PROPERTY_VALUE_TYPE
{
    UIAD_PROPERTY_VALUE_NONE,
    UIAD_PROPERTY_VALUE_OBJECT,             // 使用stringValue存储对象名，运行动画时再显示是否有效
    UIAD_PROPERTY_VALUE_OBJECT_REF,         // 参数名对象
    UIAD_PROPERTY_VALUE_OBJECT_FMT,         // object("wall%d", [index])
    UIAD_PROPERTY_VALUE_OBJECT_LOCAL,       // functionEvent里声明的对象
    UIAD_PROPERTY_VALUE_OBJECT_LOCAL_FMT,   // localObject("wall%d", [index])
    UIAD_PROPERTY_VALUE_NUMBER,             // 一个四则运算表达式，里面支持使用一些宏
    UIAD_PROPERTY_VALUE_STRING,
    UIAD_PROPERTY_VALUE_ARRAY,
    UIAD_PROPERTY_VALUE_DICTIONARY,
};

enum UIAD_PROPERTY_NUMBER_FLAG
{
    UIAD_PROPERTY_NUMBER_FLAG_NORMAL,
    UIAD_PROPERTY_NUMBER_FLAG_RELATIVE,
    UIAD_PROPERTY_NUMBER_FLAG_NO_CHANGE,
};

@interface UIADPropertyValue : NSObject
{
    int _type;
    
    NSDictionary* _dictionaryValue;
    NSArray* _arrayValue;
    NSNumber* _numberValue;
    NSString* _stringValue; // 记录UIAD_PROPERTY_VALUE_STRING以及UIAD_PROPERTY_VALUE_OBJECT类型的对象名
}

@property (nonatomic, assign) int type;

@property (nonatomic, retain) NSDictionary* dictionaryValue;
@property (nonatomic, retain) NSArray* arrayValue;
@property (nonatomic, retain) NSNumber* numberValue;
@property (nonatomic, retain) NSString* stringValue;

// return autoreleased objects
+ (UIADPropertyValue*)valueAsNone;
+ (UIADPropertyValue*)valueAsNumber:(NSNumber*)number;
+ (UIADPropertyValue*)valueAsNumberWithString:(NSString*)string;
+ (UIADPropertyValue*)valueAsType:(int)type withString:(NSString*)string;
+ (UIADPropertyValue*)valueAsString:(NSString*)string;
+ (UIADPropertyValue*)valueAsArray:(NSArray*)array;
+ (UIADPropertyValue*)valueAsDictionary:(NSDictionary*)dictionary;

// parsing
+ (UIADPropertyValue*)propertyValueWithString:(NSString*)str;
+ (BOOL)parseExpressionObjectField:(NSString*)source at:(int*)i offset:(int)offset dotSymbol:(BOOL)dotSymbol result:(UIADPropertyValue**)result;

// 解析字符串，或(format, args)这种数组构成的格式化字符串
+ (NSString*)evaluateFormat:(NSString*)format withArguments:(UIADPropertyValue*)arguments object:(UIADObject*)object context:(UIADOperationContext*)context;
- (NSString*)evaluateFormatAsStringWithObject:(UIADObject*)object context:(UIADOperationContext*)context;

// 解析四则运算表达式，同时支持在表达式里访问对象属性
- (NSNumber*)evaluateNumberWithObject:(UIADObject*)object context:(UIADOperationContext*)context;

- (NSArray*)evaluateArrayAsNumbersWithObject:(UIADObject*)object context:(UIADOperationContext*)context;
- (NSArray*)evaluateArrayAsParameterArray:(UIADObject*)object context:(UIADOperationContext*)context;

// 解析数组格式，需要数组能解析成NSValue，比如[0, 1, 2]、[(0, 1), (1, 2)]、[(0, 1, 2), (1, 2, 3)]、[(0, 1, 2, 3), (1, 2, 3, 4)]，
// 分别看作NSNumber、CGPoint、CATransform3DMakeScale、CGRect存到NSValue里
- (NSValue*)evaluateAsNSValueWithObject:(UIADObject*)object context:(UIADOperationContext*)context;
- (NSArray*)evaluateArrayAsNSValueArrayWithObject:(UIADObject*)object context:(UIADOperationContext*)context;

// 解析数组为颜色
- (UIColor*)evaluateArrayAsColorWithObject:(UIADObject*)object context:(UIADOperationContext*)context;

// center, rect, size, origin四个属性解析，需要能处理相对坐标
- (NSNumber*)evaluateNumberAsDimensionWithObject:(UIADObject*)object dimension:(CGFloat)dimension context:(UIADOperationContext*)context;

// 从UIAD_PROPERTY_VALUE_OBJECT_XXX的几种类型的UIADPropertyValue里获取对象
- (BOOL)isObject;
- (UIADObject*)evaluateAsObjectWithObject:(UIADObject*)object context:(UIADOperationContext*)context;

@end
