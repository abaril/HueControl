//
//  ABHueManager.m
//  LightBright
//
//  Created by Allan Baril on 23-06-13.
//  Copyright (c) 2013 Allan Baril. All rights reserved.
//

#import "ABHueManager.h"
#import <HueSDK/HueSDK.h>

@interface ABHueManager ()

@property (nonatomic, strong) PHHueSDK *phHueSDK;

@end

@implementation ABHueManager

+ (ABHueManager *)sharedHueManager
{
    static dispatch_once_t singletonPredicate;
    static ABHueManager *singletonInstance;
    
    dispatch_once(&singletonPredicate, ^{
        singletonInstance = [[ABHueManager alloc] init];
    });
    
    return singletonInstance;
}

- (void)start
{
    self.phHueSDK = [[PHHueSDK alloc] init];
    [self.phHueSDK startUpSDK];

}

@end
