//
//  AppDelegate.h
//  iBeaconCentral
//
//  Created by takanori uehara on 2014/11/17.
//  Copyright (c) 2014年 takanori uehara. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

typedef NS_ENUM (NSUInteger, kAppStatus) {
    kAppStatusUnknown,
    kAppStatusForeground,
    kAppStatusBackground
};

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic) kAppStatus appStatus;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;


@end

