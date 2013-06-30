//
//  ABFlipsideViewController.h
//  LightBright
//
//  Created by Allan Baril on 23-06-13.
//  Copyright (c) 2013 Allan Baril. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ABFlipsideViewController;

@protocol ABFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(ABFlipsideViewController *)controller;
@end

@interface ABFlipsideViewController : UIViewController

@property (weak, nonatomic) id <ABFlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end
