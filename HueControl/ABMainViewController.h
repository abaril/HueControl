//
//  ABMainViewController.h
//  LightBright
//
//  Created by Allan Baril on 23-06-13.
//  Copyright (c) 2013 Allan Baril. All rights reserved.
//

#import "ABFlipsideViewController.h"

@interface ABMainViewController : UIViewController <ABFlipsideViewControllerDelegate>

@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;

- (IBAction)showInfo:(id)sender;

@end
