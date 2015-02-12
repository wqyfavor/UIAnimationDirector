//
//  UIADExtensions.h
//  mPaas
//
//  Created by bruiswang on 12-10-10.
//
//

#import <Foundation/Foundation.h>

// work as a stack

@interface NSMutableArray(UIADExtensions)

- (void)push:(id)obj;
- (id)pop;
- (id)peek;
- (id)peekUntilClass:(Class)aClass;
- (id)bottom;
- (BOOL)is:(id)obj1 lowerThan:(id)obj2;

@end


@interface NSString(UIADExtensions)

- (BOOL)isValidPropertyName;
- (BOOL)isValidName;
- (BOOL)toDouble:(double*)value;
- (NSString*)trimmed;
- (BOOL)hasColonSymbol;

@end