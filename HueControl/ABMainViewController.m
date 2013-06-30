//
//  ABMainViewController.m
//  LightBright
//
//  Created by Allan Baril on 23-06-13.
//  Copyright (c) 2013 Allan Baril. All rights reserved.
//

#import "ABMainViewController.h"

#import <HueSDK/SDK.h>
#import "PHBridgePushLinkViewController.h"
#import "PHBridgeSelectionViewController.h"

@interface ABMainViewController () <PHBridgePushLinkViewControllerDelegate, PHBridgeSelectionViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *brightnessLabel;
@property (weak, nonatomic) IBOutlet UILabel *proximityLabel;
@property (strong, nonatomic) PHHueSDK *phHueSDK;
@property (strong, nonatomic) PHBridgePushLinkViewController *pushLinkViewController;

@end

@implementation ABMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [UIDevice currentDevice].proximityMonitoringEnabled = YES;
    [self initializeHueSDK];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateBrightnessLabel];
    [self updateProximity];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProximity) name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateBrightnessLabel
{
    self.brightnessLabel.text = [NSString stringWithFormat:@"%f", [UIScreen mainScreen].brightness];

    [self performSelector:@selector(updateBrightnessLabel) withObject:nil afterDelay:2.0];
}

- (void)updateProximity
{
    self.proximityLabel.text = [NSString stringWithFormat:@"%d", [UIDevice currentDevice].proximityState];
    if ([UIDevice currentDevice].proximityState) {
        [self turnLightOff];
    }
    else {
        [self turnLightOn];
    }
}

#pragma mark - Flipside View Controller

- (void)flipsideViewControllerDidFinish:(ABFlipsideViewController *)controller
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
    }
}

- (IBAction)showInfo:(id)sender
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        ABFlipsideViewController *controller = [[ABFlipsideViewController alloc] initWithNibName:@"ABFlipsideViewController" bundle:nil];
        controller.delegate = self;
        controller.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:controller animated:YES completion:nil];
    } else {
        if (!self.flipsidePopoverController) {
            ABFlipsideViewController *controller = [[ABFlipsideViewController alloc] initWithNibName:@"ABFlipsideViewController" bundle:nil];
            controller.delegate = self;
            
            self.flipsidePopoverController = [[UIPopoverController alloc] initWithContentViewController:controller];
        }
        if ([self.flipsidePopoverController isPopoverVisible]) {
            [self.flipsidePopoverController dismissPopoverAnimated:YES];
        } else {
            [self.flipsidePopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
    }
}

#pragma mark - Hue

- (void)initializeHueSDK
{
    self.phHueSDK = [[PHHueSDK alloc] init];
    [self.phHueSDK startUpSDK];
    
    PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
    
    [notificationManager registerObject:self withSelector:@selector(hueLocalConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(hueNoLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
    
    [notificationManager registerObject:self withSelector:@selector(hueNotAuthenticated) forNotification:NO_LOCAL_AUTHENTICATION_NOTIFICATION];
    
    [self enableHueLocalHeartbeat];
}

- (void)hueLocalConnection
{
    NSLog(@"Connected!!!");
}

- (void)turnLightOn
{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSDictionary *lights = cache.lights;
    
    PHLight *light = [lights objectForKey:@"2"];
    light.lightState.on = @YES;
    light.lightState.brightness = @((int)((1.0f - [UIScreen mainScreen].brightness) * 254.0));
    NSLog(@"Setting brightness to: %@", light.lightState.brightness);
    
    id<PHBridgeSendAPI> bridgeSendAPI = [[[PHOverallFactory alloc] init] bridgeSendAPI];
    [bridgeSendAPI updateLightStateForId:light.identifier withLighState:light.lightState completionHandler:^(NSArray *errors) {
        NSLog(@"Turned light on with errors: %@", errors);
    }];
}

- (void)turnLightOff
{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSDictionary *lights = cache.lights;
    
    PHLight *light = [lights objectForKey:@"2"];
    light.lightState.on = @NO;
    
    id<PHBridgeSendAPI> bridgeSendAPI = [[[PHOverallFactory alloc] init] bridgeSendAPI];
    [bridgeSendAPI updateLightStateForId:light.identifier withLighState:light.lightState completionHandler:^(NSArray *errors) {
        NSLog(@"Turned light off with errors: %@", errors);
    }];    
}

- (void)hueNoLocalConnection
{
    NSLog(@"Not connected");
}

- (void)hueNotAuthenticated
{
    [self disableHueLocalHeartbeat];
    
    // Create an interface for the pushlinking
    self.pushLinkViewController = [[PHBridgePushLinkViewController alloc] initWithNibName:@"PHBridgePushLinkViewController" bundle:[NSBundle mainBundle] hueSDK:self.phHueSDK delegate:self];
    
    [self presentViewController:self.pushLinkViewController animated:YES completion:^{
        [self.pushLinkViewController startPushLinking];
    }];

}

- (void)pushlinkSuccess
{
    NSLog(@"Link success");
}

- (void)pushlinkFailed:(PHError *)error
{
    NSLog(@"Link failed");
}

- (void)enableHueLocalHeartbeat
{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    if (cache != nil && cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil) {
        // Some bridge is known
        [self.phHueSDK enableLocalConnectionUsingInterval:10];
    }
    else {
        [self searchForBridgeLocal];
    }
}

- (void)disableHueLocalHeartbeat
{
    [self.phHueSDK disableLocalConnection];
}

- (void)searchForBridgeLocal {
    // Stop heartbeats
    [self disableHueLocalHeartbeat];
    
//    // Show search screen
//    [self showLoadingViewWithText:NSLocalizedString(@"Searching...", @"Searching for bridges text")];
    /***************************************************
     A bridge search is started using UPnP to find local bridges
     *****************************************************/
    
    // Start search
    PHBridgeSearching *bridgeSearch = [[PHBridgeSearching alloc] initWithUpnpSearch:YES andPortalSearch:YES];
    [bridgeSearch startSearchWithCompletionHandler:^(NSDictionary *bridgesFound) {
        // Done with search, remove loading view
//        [self removeLoadingView];
        
        // Check for results
        if (bridgesFound.count > 0) {
            NSLog(@"Bridge found");
            PHBridgeSelectionViewController *bridgeSelectionViewController = [[PHBridgeSelectionViewController alloc] initWithNibName:@"PHBridgeSelectionViewController" bundle:[NSBundle mainBundle] bridges:bridgesFound delegate:self];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgeSelectionViewController];
            navController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:navController animated:YES completion:nil];
        }
        else {
//            self.noBridgeFoundAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No bridges", @"No bridge found alert title")
//                                                                 message:NSLocalizedString(@"Could not find bridge", @"No bridge found alert message")
//                                                                delegate:self
//                                                       cancelButtonTitle:nil
//                                                       otherButtonTitles:NSLocalizedString(@"Retry", @"No bridge found alert retry button"), nil];
//            self.noBridgeFoundAlert.tag = 1;
//            [self.noBridgeFoundAlert show];
            NSLog(@"No bridge found");
        }
    }];
}

- (void)bridgeSelectedWithIpAddress:(NSString *)ipAddress andMacAddress:(NSString *)macAddress {

    [self dismissViewControllerAnimated:YES completion:nil];
    
//    // Show a connecting view while we try to connect to the bridge
//    [self showLoadingViewWithText:NSLocalizedString(@"Connecting...", @"Connecting text")];
    
    NSString *username = [PHUtilities whitelistIdentifier];
    [self.phHueSDK setBridgeToUseWithIpAddress:ipAddress macAddress:macAddress andUsername:username];
    
    [self performSelector:@selector(enableHueLocalHeartbeat) withObject:nil afterDelay:1];
}


@end
