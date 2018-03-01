#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WRLDMenuChild : NSObject

@property (nonatomic, copy) NSString* text;

@property (nonatomic, copy) NSString* icon;

@property (nonatomic, copy) NSObject* context;

- (instancetype)initWithText:(NSString *)text
                        icon:(nullable NSString *)icon
                     context:(nullable NSObject *)context;

@end

NS_ASSUME_NONNULL_END
