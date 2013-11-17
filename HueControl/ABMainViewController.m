//
//  ABMainViewController.m
//  LightBright
//
//  Created by Allan Baril on 23-06-13.
//  Copyright (c) 2013 Allan Baril. All rights reserved.
//

#import "ABMainViewController.h"

#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import <HueSDK/HueSDK.h>
#import "PHBridgePushLinkViewController.h"
#import "PHBridgeSelectionViewController.h"

@interface ABMainViewController () <PHBridgePushLinkViewControllerDelegate, PHBridgeSelectionViewControllerDelegate, CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *brightnessLabel;
@property (weak, nonatomic) IBOutlet UILabel *proximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *rangeLabel;
@property (strong, nonatomic) PHHueSDK *phHueSDK;
@property (strong, nonatomic) PHBridgePushLinkViewController *pushLinkViewController;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSOperationQueue *motionQueue;
@property (copy, nonatomic) NSNumber *lightOn;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;

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

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (void)initAccelerometer
{
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = 1.0;
    
    self.motionQueue = [[NSOperationQueue alloc] init];

    [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
        if (accelerometerData.acceleration.z > 0.5) {
            [self turnLightOff];
        }
        else {
            [self turnLightOn];
        }
    }];
}

- (void)updateBrightnessLabel
{
    self.brightnessLabel.text = [NSString stringWithFormat:@"%f", [UIScreen mainScreen].brightness];

    [self performSelector:@selector(updateBrightnessLabel) withObject:nil afterDelay:2.0];
}

- (void)updateProximity
{
    self.proximityLabel.text = [NSString stringWithFormat:@"%d", [UIDevice currentDevice].proximityState];
    /*
    if ([UIDevice currentDevice].proximityState) {
        [self turnLightOff];
    }
    else {
        [self turnLightOn];
    }
     */
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

#pragma mark - iBeacon

- (void)initializeBeaconSupport
{
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:@"C8FABE4D-44AC-4EBB-A232-31E3478F2309"]
                                                                major:1 minor:2 identifier:@"Allan"];

    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    NSLog(@"Beacon in range!");
    
    if (beacons && beacons.count > 0) {
        CLBeacon *beacon = beacons[0];
        self.rangeLabel.text = [NSString stringWithFormat:@"%.02f", beacon.accuracy];
        if (beacon.accuracy <= 3.0) {
            [self turnLightOn];
        }
        else
        {
            [self turnLightOff];
        }
    }
    else {
        [self turnLightOff];
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    NSLog(@"Error ranging beacon: %@", [error localizedDescription]);
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
    
    //[self initAccelerometer];
    [self initializeBeaconSupport];
}

- (void)switchLightToState:(NSNumber *)on
{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSDictionary *lights = cache.lights;
    
    PHLight *light = [lights objectForKey:@"2"];
    light.lightState.on = on;
    if ([on boolValue]) {
        light.lightState.brightness = @((int)((1.0f - [UIScreen mainScreen].brightness) * 254.0));
        NSLog(@"Setting brightness to: %@", light.lightState.brightness);
    }
    
    id<PHBridgeSendAPI> bridgeSendAPI = [[[PHOverallFactory alloc] init] bridgeSendAPI];
    [bridgeSendAPI updateLightStateForId:light.identifier withLighState:light.lightState completionHandler:^(NSArray *errors) {
        NSLog(@"Turned light on/off with errors: %@", errors);
    }];
}

- (void)turnLightOn
{
    if (self.lightOn && ([self.lightOn boolValue] == YES)) {
        return;
    }
    
    self.lightOn = @YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self switchLightToState:@YES];
    });
}

- (void)turnLightOff
{
    if (self.lightOn && ([self.lightOn boolValue] == NO)) {
        return;
    }
    
    self.lightOn = @NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self switchLightToState:@NO];
    });
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
