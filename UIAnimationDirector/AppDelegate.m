//
//  AppDelegate.m
//  UIAnimationDirector
//
//  Created by 王 乾元 on 12/15/12.
//  Copyright (c) 2012 王 乾元. All rights reserved.
//

#import "AppDelegate.h"
#import "TestEntriesViewController.h"

@implementation AppDelegate

- (void)dealloc
{
    [_window release];
    [_tabBarController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    TestEntriesViewController* viewController = [[[TestEntriesViewController alloc] init] autorelease];
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
