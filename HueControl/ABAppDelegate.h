//
//  ABAppDelegate.h
//  LightBright
//
//  Created by Allan Baril on 23-06-13.
//  Copyright (c) 2013 Allan Baril. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ABMainViewController;

@interface ABAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ABMainViewController *mainViewController;

@end
