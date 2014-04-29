//
//  UIADExtensions.m
//  QQMSFContact
//
//  Created by bruiswang on 12-10-10.
//
//

#import "UIADExtensions.h"

@implementation NSMutableArray(UIADExtensions)

- (void)push:(id)obj
{
    [self addObject:obj];
}

- (id)pop
{
    id obj = [[self lastObject] retain];
    [self removeLastObject];
    return [obj autorelease];
}

- (id)peek
{
    return [self lastObject];
}

- (id)peekUntilClass:(Class)aClass
{
    for (int i = [self count] - 1; i >= 0; i --)
    {
        id obj = [self objectAtIndex:i];
        if ([obj isKindOfClass:aClass])
        {
            return obj;
        }
    }
    
    return nil;
}

- (id)bottom
{
    if ([self count] > 0)
    {
        return [self objectAtIndex:0];
    }
    else
    {
        return nil;
    }
}

- (BOOL)is:(id)obj1 lowerThan:(id)obj2
{
    NSUInteger idx1 = [self indexOfObject:obj1];
    NSUInteger idx2 = [self indexOfObject:obj2];
    if (idx1 != NSNotFound && idx2 != NSNotFound)
    {
        return idx1 < idx2;
    }
    else
    {
        return NO;
    }
}

@end

@implementation NSString(UIADExtensions)

- (BOOL)isValidPropertyName
{
    if ([self length] > 0)
    {
        for (int i = 0; i < [self length]; i ++)
        {
            unichar c = [self characterAtIndex:i];
            if (!(c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')))
            {
                return NO;
            }
        }
        
        unichar firstC = [self characterAtIndex:0];
        if (firstC >= '0' && firstC <= '9')
        {
            return NO;
        }
        else
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isValidName
{
    if ([self length] > 0)
    {
        for (int i = 0; i < [self length]; i ++)
        {
            unichar c = [self characterAtIndex:i];
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == '.'))
            {
                return NO;
            }
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL)toDouble:(double*)value
{
    NSScanner* scanner = [NSScanner scannerWithString:self];
    return [scanner scanDouble:value] && [scanner isAtEnd];
}

- (NSString*)trimmed
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (BOOL)hasColonSymbol
{
    // 是否有不在双引号中的冒号
    int string = 0;
    for (unsigned int i = 0; i < [self length]; i ++)
    {
        unichar c = [self characterAtIndex:i];
        if (c == '"')
        {
            string = string > 0 ? 0 : 1;
        }
        else if (c == ':' && string == 0)
        {
            return YES;
        }
    }
    
    return NO;
}

@end
