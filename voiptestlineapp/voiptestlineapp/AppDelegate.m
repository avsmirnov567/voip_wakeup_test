//
//  AppDelegate.m
//  voiptestlineapp
//
//  Created by Aleksandr Smirnov on 06.03.17.
//  Copyright © 2017 Line App. All rights reserved.
//

#import "AppDelegate.h"
#import <PushKit/PushKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import "VTNetworkManager.h"

@interface AppDelegate ()<PKPushRegistryDelegate, CLLocationManagerDelegate, AVAudioRecorderDelegate>
{
    PKPushRegistry *_pushRegistry;
    CLLocationManager *_locationManager;
    AVAudioSession *_audioSession;
    AVAudioRecorder *_recorder;
    BOOL _isSend;
}
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSLog(@"app launched with state %ld", (long)[application applicationState]);
    
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:settings];
    
    
    _pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    _pushRegistry.delegate = self;
    _pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    [_locationManager requestAlwaysAuthorization];
    
    return YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [_locationManager stopUpdatingLocation];
    CLLocation *location = [locations lastObject];
    if (!_isSend) {
        NSString *locString = [NSString stringWithFormat:@"%f %f", location.coordinate.latitude, location.coordinate.longitude];
        
        [VTNetworkManager sendLocation:locString success:^(NSString *response){
            [self sendLocalNotificationsWithMessage:response];
        }failure:^BOOL(NSError *error) {
            return YES;
        }];
        
        _isSend = YES;
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type{
    if([credentials.token length] == 0) {
        NSLog(@"voip token NULL");
        return;
    }
    
    NSLog(@"PushCredentials: %@", credentials.token);
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    NSDictionary *payloadDict = payload.dictionaryPayload[@"aps"];
    
    NSLog(@"didReceiveIncomingPushWithPayload: %@", payloadDict);
    NSString *message = payloadDict[@"alert"];
    
    NSLog(@"%@", message);
    
    [_locationManager startUpdatingLocation];
    _isSend = NO;
}

- (void)sendLocalNotificationsWithMessage:(NSString *)message {
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertBody = message;
        localNotification.applicationIconBadgeNumber = 1;
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
}

- (void)configureAudioSession {
    if (_recorder == nil) {
        NSArray *pathComponents = [NSArray arrayWithObjects:
                                   [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                                   @"chat_record.m4a",
                                   nil];
        NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
        
        // Setup audio session
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        
        // Define the recorder setting
        NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
        
        [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
        [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
        [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
        
        // Initiate and prepare the recorder
        _recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:NULL];
        _recorder.delegate = self;
        [_recorder prepareToRecord];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
