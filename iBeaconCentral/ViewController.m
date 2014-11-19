//
//  ViewController.m
//  iBeaconCentral
//
//  Created by takanori uehara on 2014/11/17.
//  Copyright (c) 2014年 takanori uehara. All rights reserved.
//

#import "ViewController.h"

#import "AppDelegate.h"
#define app (AppDelegate *)[[UIApplication sharedApplication] delegate]

#define START_MONITORING_RETRY_COUNT 10

#define PROXIMITY_UUID @"913C64F0-9886-4FC3-B11C-78581F21CDB4"
#define IDENTIFIER @"iBeacon text"
#define MAJOR -1 // 1~4桁(0~9999) それ以上/以下は指定なしとみなす
#define MINER -1 // 1~4桁(0~9999) それ以上/以下は指定なしとみなす

@interface ViewController (){
    CGFloat displayWidth;
    CGFloat displayHeight;
    
    UIScrollView *contentsView;
    CGFloat tempScrollTop;
    UITextField *activeTextField;
    
    UILabel *icon;
    
    UIButton *proximityUUIDButton;
    UITextField *majorTextField;
    UITextField *minorTextField;
    
    int startMonitoringRetryCount;
    NSTimer *startMonitoringRetryTimer;
}

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) CLBeaconRegion *beaconRegion;
@property (nonatomic) NSUUID *proximityUUID;
@property (nonatomic) NSString *identifier;
@property (nonatomic) int major;
@property (nonatomic) int minor;

@property (nonatomic) UILabel *beaconStatusLabel;
@property (nonatomic) UILabel *beaconInfoLabel;
@property (nonatomic) BOOL noticeEnabled;
@property (nonatomic) BOOL inBeacon;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"ViewController :: viewDidLoad");
    
    displayWidth = self.view.frame.size.width;
    displayHeight = self.view.frame.size.height;
    
    // キーボード表示/非表示通知登録
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // ユーザデフォルト取得
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults registerDefaults:@{@"localNotificationEnabled":@YES}];
    
    // 初期設定
    self.view.backgroundColor = [UIColor colorWithRed:0.255 green:0.412 blue:0.882 alpha:1.0];
    self.noticeEnabled = [userDefaults boolForKey:@"localNotificationEnabled"];
    NSLog(@"self.noticeEnabled = %@", [userDefaults boolForKey:@"localNotificationEnabled"] ? @"True" : @"False");
    self.inBeacon = NO;
    
    // iBeacon機能が利用可能かどうか (シミュレータは不可)
    BOOL iBeaconAvailable = [CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]];
    NSLog(@"iBeaconAvailable = %@", iBeaconAvailable ? @"True" : @"False");
    
    // iBeacon 初期設定
    self.proximityUUID = [[NSUUID alloc] initWithUUIDString:PROXIMITY_UUID];
    self.identifier = IDENTIFIER;
    self.major = MAJOR;
    self.minor = MINER;
    
    contentsView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, displayWidth, displayHeight)];
    [self.view addSubview:contentsView];
    
    UILabel *label;
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, displayWidth, 30)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"iBeacon Central";
    label.font = [UIFont systemFontOfSize:32];
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 90, displayWidth, 40)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = iBeaconAvailable ? @"iBeacon is Available" : @"iBeacon is Unavailable";
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    
    icon = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, displayWidth, 300)];
    icon.center = CGPointMake(displayWidth/2, 140);
    icon.textAlignment = NSTextAlignmentCenter;
    icon.text = @"●";
    icon.textColor = [UIColor whiteColor];
    icon.font = [UIFont systemFontOfSize:icon.frame.size.height];
    icon.alpha = 0;
    icon.transform = CGAffineTransformMakeScale(1.0, 1.0);
    [contentsView addSubview:icon];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 160, displayWidth, 20)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"Search Beacons";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    UISwitch *enableSwitch = [[UISwitch alloc] init];
    enableSwitch.center = CGPointMake(displayWidth/2, label.frame.origin.y+label.frame.size.height+20);
    enableSwitch.on = YES;
    [enableSwitch addTarget:self action:@selector(toggleBeaconEnabled:) forControlEvents:UIControlEventValueChanged];
    [contentsView addSubview:enableSwitch];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(displayWidth*0.05, 250, displayWidth*0.9, 20)];
    label.textAlignment = NSTextAlignmentLeft;
    label.text = @"Proximity UUID";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    proximityUUIDButton = [[UIButton alloc] initWithFrame:CGRectMake(displayWidth*0.05, label.frame.origin.y+label.frame.size.height, displayWidth*0.9, 30)];
    proximityUUIDButton.layer.borderWidth = 1;
    proximityUUIDButton.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    proximityUUIDButton.layer.cornerRadius = 4.0;
    //[proximityUUIDButton addTarget:self action:@selector(selectProximityUUID:) forControlEvents:UIControlEventTouchUpInside];
    [proximityUUIDButton setTitle:[self.proximityUUID UUIDString] forState:UIControlStateNormal];
    proximityUUIDButton.titleLabel.font = [UIFont systemFontOfSize:12];
    proximityUUIDButton.alpha = 0.5;
    proximityUUIDButton.userInteractionEnabled = NO;
    [contentsView addSubview:proximityUUIDButton];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(displayWidth*0.05, proximityUUIDButton.frame.origin.y+proximityUUIDButton.frame.size.height+5, displayWidth*0.9, 20)];
    label.textAlignment = NSTextAlignmentLeft;
    label.text = @"Major";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    majorTextField = [[UITextField alloc] initWithFrame:CGRectMake(displayWidth*0.05, label.frame.origin.y+label.frame.size.height, displayWidth*0.9, 30)];
    majorTextField.layer.borderWidth = 1;
    majorTextField.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    majorTextField.layer.cornerRadius = 4.0;
    majorTextField.delegate = self;
    majorTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    majorTextField.returnKeyType = UIReturnKeyDone;
    majorTextField.textAlignment = NSTextAlignmentCenter;
    majorTextField.textColor = [UIColor whiteColor];
    majorTextField.font = [UIFont systemFontOfSize:12];
    majorTextField.text = [NSString stringWithFormat:@"%@", (self.major>=0 && self.major<=9999)?[NSString stringWithFormat:@"%d", self.major]:@"-"];
    majorTextField.alpha = 0.5;
    majorTextField.userInteractionEnabled = NO;
    [contentsView addSubview:majorTextField];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(displayWidth*0.05, majorTextField.frame.origin.y+majorTextField.frame.size.height+5, displayWidth*0.9, 20)];
    label.textAlignment = NSTextAlignmentLeft;
    label.text = @"Minor";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    minorTextField = [[UITextField alloc] initWithFrame:CGRectMake(displayWidth*0.05, label.frame.origin.y+label.frame.size.height, displayWidth*0.9, 30)];
    minorTextField.layer.borderWidth = 1;
    minorTextField.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    minorTextField.layer.cornerRadius = 4.0;
    minorTextField.delegate = self;
    minorTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    minorTextField.returnKeyType = UIReturnKeyDone;
    minorTextField.textAlignment = NSTextAlignmentCenter;
    minorTextField.textColor = [UIColor whiteColor];
    minorTextField.font = [UIFont systemFontOfSize:12];
    minorTextField.text = [NSString stringWithFormat:@"%@", (self.minor>=0 && self.minor<=9999)?[NSString stringWithFormat:@"%d", self.minor]:@"-"];
    minorTextField.alpha = 0.5;
    minorTextField.userInteractionEnabled = NO;
    [contentsView addSubview:minorTextField];
    
    self.beaconStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, minorTextField.frame.origin.y+minorTextField.frame.size.height+20, displayWidth, 40)];
    self.beaconStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.beaconStatusLabel.text = @"Wait...";
    self.beaconStatusLabel.font = [UIFont systemFontOfSize:21];
    self.beaconStatusLabel.textColor = [UIColor whiteColor];
    self.beaconStatusLabel.numberOfLines = 0;
    [contentsView addSubview:self.beaconStatusLabel];
    
    self.beaconInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(displayWidth*0.15, self.beaconStatusLabel.frame.origin.y+self.beaconStatusLabel.frame.size.height, displayWidth*0.7, 100)];
    self.beaconInfoLabel.textAlignment = NSTextAlignmentLeft;
    self.beaconInfoLabel.text = @"";
    self.beaconInfoLabel.font = [UIFont fontWithName:@"Courier" size:18];
    self.beaconInfoLabel.textColor = [UIColor whiteColor];
    self.beaconInfoLabel.numberOfLines = 0;
    [contentsView addSubview:self.beaconInfoLabel];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, self.beaconInfoLabel.frame.origin.y+self.beaconInfoLabel.frame.size.height+30, displayWidth, 20)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"Local Notification Enabled";
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor whiteColor];
    [contentsView addSubview:label];
    UISwitch *noticeSwitch = [[UISwitch alloc] init];
    noticeSwitch.center = CGPointMake(displayWidth/2, label.frame.origin.y+label.frame.size.height+20);
    noticeSwitch.on = self.noticeEnabled;
    [noticeSwitch addTarget:self action:@selector(toggleNoticeEnabled:) forControlEvents:UIControlEventValueChanged];
    [contentsView addSubview:noticeSwitch];
    
    // コンテントサイズ調整
    contentsView.contentSize = CGSizeMake(contentsView.frame.size.width, noticeSwitch.frame.origin.y+noticeSwitch.frame.size.height+20);
    
    // iBeacon機能が利用可能な場合
    if (iBeaconAvailable) {
        NSLog(@"iBeacon Available");
        
        // CLLocationManager 生成
        self.locationManager = [CLLocationManager new];
        self.locationManager.delegate = self;
    } else {
        NSLog(@"iBeacon Unavailable");
    }
}

// iBeacon領域観測のON/OFF切り替え
- (void)toggleBeaconEnabled:(UISwitch*)_switch {
    NSLog(@"toggleBeaconEnabled: enabled = %@", _switch.on?@"true":@"false");
    
    if (_switch.on) {
        [self startMonitoring];
    } else {
        [self stopMonitoring];
    }
}

// Beacon領域観測開始処理
- (void)startBeacon {
    // 位置情報サービスの設定状態を取得
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    [self startBeacon:status];
}
- (void)startBeacon:(CLAuthorizationStatus)status {
    NSLog(@"startBeacon:: status = %d", status);
    
    switch (status) {
        case kCLAuthorizationStatusAuthorized: {
            // (3) - 位置情報サービスへのアクセスが許可されている
            NSLog(@"startBeacon:: status = kCLAuthorizationStatusAuthorized (%d)", status);
            
            // 位置情報測位を開始
            [self.locationManager startUpdatingLocation];
            
            // モニタリング開始
            [self startMonitoring];
        }
            break;
            
            
        case kCLAuthorizationStatusNotDetermined: {
            // (0) - 位置情報サービスへのアクセスを許可するか選択されていない
            NSLog(@"startBeacon:: status = kCLAuthorizationStatusNotDetermined (%d)", status);
            
            // iOS8 からは requestAlwaysAuthorization / requestWhenInUseAuthorization を明示的に呼び出す必要がある
            if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
                // 位置情報測位の許可を求めるメッセージを表示する
                [self.locationManager requestAlwaysAuthorization]; // NSLocationAlwaysUsageDescription - XXXX を使用していないときでも位置情報の利用を許可しますか？
                //[self.locationManager requestWhenInUseAuthorization]; // NSLocationWhenInUseUsageDescription - XXXX の使用中に位置情報の利用を許可しますか？
            } else {
                // 位置情報測位を開始する
                [self.locationManager startUpdatingLocation];
            }
        }
            break;
            
        case kCLAuthorizationStatusRestricted: {
            // 位置情報サービスがオフになっている (設定 -> プライバシー -> 位置情報サービス)
            NSLog(@"startBeacon:: status = kCLAuthorizationStatusRestricted (%d)", status);
            
            self.beaconStatusLabel.text = @"Location services\ndisabled";
            
            // モニタリング停止
            [self stopMonitoring];
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"エラー" message:@"位置情報サービスがオフになっています" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
            break;
            
        case kCLAuthorizationStatusDenied: {
            // (2) - 位置情報サービスへのアクセスが許可されていない (設定 -> プライバシー -> 位置情報サービス)
            NSLog(@"startBeacon:: status = kCLAuthorizationStatusDenied (%d)", status);
            
            self.beaconStatusLabel.text = @"Location services\naccess denied";
            
            // モニタリング停止
            [self stopMonitoring];
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"エラー" message:@"位置情報サービスへのアクセスが許可されていません" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
            break;
            
        default:
            break;
    }
}

// 位置情報サービスの変更を検知
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"locationManager:didChangeAuthorizationStatus:: status = %d", status);
    
    // Beacon領域観測開始処理
    [self startBeacon:status];
}

// モニタリング開始処理
- (void)startMonitoring {
    NSLog(@"startMonitoring");
    
    proximityUUIDButton.alpha = 0.5;
    proximityUUIDButton.userInteractionEnabled = NO;
    majorTextField.alpha = 0.5;
    majorTextField.userInteractionEnabled = NO;
    minorTextField.alpha = 0.5;
    minorTextField.userInteractionEnabled = NO;
    
    self.beaconStatusLabel.text = @"Searching ...";
    
    // CLBeaconRegion 生成
    if (self.major >= 0 && self.major <= 9999 && self.minor >= 0 && self.minor <= 9999) {
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:self.proximityUUID major:self.major minor:self.minor identifier:self.identifier];
    } else if (self.major >= 0 && self.major <= 9999) {
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:self.proximityUUID major:self.major identifier:self.identifier];
    } else {
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:self.proximityUUID identifier:self.identifier];
    }
    NSLog(@"beaconRegion = %@", self.beaconRegion);
    
    // モニタリング開始
    [self.locationManager startMonitoringForRegion:self.beaconRegion];
    
    icon.alpha = 0;
    [UIView animateWithDuration:1.0f
                          delay:0.8f
                        options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         icon.alpha = 1;
                         icon.transform = CGAffineTransformMakeScale(0.01, 0.01);
                     } completion:^(BOOL finished) {
                         
                     }];
}

// モニタリング停止処理
- (void)stopMonitoring {
    NSLog(@"stopMonitoring");
    
    proximityUUIDButton.alpha = 1;
    proximityUUIDButton.userInteractionEnabled = YES;
    majorTextField.alpha = 1;
    majorTextField.userInteractionEnabled = YES;
    minorTextField.alpha = 1;
    minorTextField.userInteractionEnabled = YES;
    
    self.beaconStatusLabel.text = @"Stop";
    
    // モニタリング停止
    [self.locationManager stopMonitoringForRegion:self.beaconRegion];
    
    icon.alpha = 0;
    icon.transform = CGAffineTransformMakeScale(1.0, 1.0);
}

// モニタリング再開始
- (void)restartMonitoring {
    NSLog(@"restartMonitoring");
    [self stopMonitoring];
    [self startMonitoring];
}

// モニタリング開始リトライ
- (void)retryStartMonitoring:(CLBeaconRegion *)beaconRegion {
    NSLog(@"retryStartMonitoring:");
    
    if (startMonitoringRetryCount < START_MONITORING_RETRY_COUNT) {
        NSLog(@"retryStartMonitoring:: retry (%d / %d)", startMonitoringRetryCount+1, START_MONITORING_RETRY_COUNT);
        
        // モニタリング再開始
        [self restartMonitoring];
        
        startMonitoringRetryCount++;
    } else {
        NSLog(@"retryStartMonitoring:: retry count limit (%d)", START_MONITORING_RETRY_COUNT);
    }
}

// モニタリング開始失敗時
- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"locationManager:monitoringDidFailForRegion:withError:: error = %@", error);
    
    // リトライ
    startMonitoringRetryTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(retryStartMonitoring:) userInfo:self.beaconRegion repeats:NO];
}

// モニタリング開始時
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSLog(@"locationManager:didStartMonitoringForRegion:: region = %@", region);
    [self.locationManager requestStateForRegion:region];
}

// モニタリング状態決定時
- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    NSLog(@"locationManager:didDetermineState:");
    
    switch (state) {
        case CLRegionStateInside: {
            // 領域内にいる
            NSLog(@"Beacon: Inside region");
            self.beaconStatusLabel.text = @"Inside region";
            if (!self.inBeacon) {
                self.inBeacon = YES;
                if (self.noticeEnabled) {
                    [self sendLocalNotificationForMessage:@"Beacon領域内にいます"];
                }
            }
            [self startRangingBeacon:region];
        }
            break;
        case CLRegionStateOutside: {
            // 領域外にいる
            NSLog(@"Beacon: Outside region");
            self.beaconStatusLabel.text = @"Outside region";
            if (self.inBeacon) {
                self.inBeacon = NO;
                if (self.noticeEnabled) {
                    [self sendLocalNotificationForMessage:@"Beacon領域外にいます"];
                }
            }
            [self stopRangingBeacon:region];
        }
            break;
        case CLRegionStateUnknown: {
            // 不明
            NSLog(@"Beacon: Unknown region");
            self.beaconStatusLabel.text = @"Unknown region";
            if (self.inBeacon) {
                self.inBeacon = NO;
                if (self.noticeEnabled) {
                    [self sendLocalNotificationForMessage:@"未知の領域"];
                }
            }
        }
            break;
        default:
            break;
    }
}

// Beacon領域進入時
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"Beacon: Enter region");
    self.beaconStatusLabel.text = @"Enter region";
    if (!self.inBeacon) {
        self.inBeacon = YES;
        if (self.noticeEnabled) {
            [self sendLocalNotificationForMessage:@"Beacon領域に入りました"];
        }
    }
    [self startRangingBeacon:region];
}

// Beacon領域退出時
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"Beacon: Exit region");
    self.beaconStatusLabel.text = @"Exit region";
    if (self.inBeacon) {
        self.inBeacon = NO;
        if (self.noticeEnabled) {
            [self sendLocalNotificationForMessage:@"Beacon領域を出ました"];
        }
    }
    [self stopRangingBeacon:region];
}

// Beacon距離測定開始処理
- (void)startRangingBeacon:(CLRegion *)region {
    NSLog(@"Beacon: startRangingBeacon");
    if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
        [self.locationManager startRangingBeaconsInRegion:(CLBeaconRegion *)region];
    }
}

// Beacon距離測定終了処理
- (void)stopRangingBeacon:(CLRegion *)region {
    NSLog(@"Beacon: stopRangingBeacon");
    if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
        [self.locationManager stopRangingBeaconsInRegion:(CLBeaconRegion *)region];
    }
}

// Beacon距離測定開始失敗時
- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"locationManager:rangingBeaconsDidFailForRegion:withError:: error = %@", error);
    
    // リトライ
    //////
}

// Beacon距離測定 (フォアグラウンドのみ)
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    NSLog(@"locationManager:didRangeBeacons:");
    
    if (beacons.count > 0) {
        // 最も距離の近いBeaconについて処理する
        CLBeacon *nearestBeacon = beacons.firstObject;
        
        // 大まかな距離取得
        NSString *proximity;
        switch (nearestBeacon.proximity) {
            case CLProximityImmediate:
                // 間近 (約1m以内)
                proximity = @"Immediate";
                break;
            case CLProximityNear:
                // 近い (約1m)
                proximity = @"Near";
                break;
            case CLProximityFar:
                // 遠い (約1m以上)
                proximity = @"Far";
                break;
            default:
                // 不明
                proximity = @"Unknown";
                break;
        }
        
        // 表示情報更新
        // accuracy: 近接値の精度
        // rssi:     受信強度
        NSString *beaconInfo = [NSString stringWithFormat:@"major:%@, minor:%@, accuracy:%f, rssi:%ld, proximity:%@",
                                nearestBeacon.major, nearestBeacon.minor, nearestBeacon.accuracy, (long)nearestBeacon.rssi, proximity];
        NSLog(@"Beacon: %@", beaconInfo);
        
        self.beaconStatusLabel.text = @"Ranging...";
        self.beaconInfoLabel.text = [NSString stringWithFormat:@"      major: %@\n      minor: %@\n   accuracy: %f\n       rssi: %ld\n  proximity: %@",
                                     nearestBeacon.major, nearestBeacon.minor, nearestBeacon.accuracy, (long)nearestBeacon.rssi, proximity];
        
        if (self.noticeEnabled) {
            [self sendLocalNotificationForMessage:beaconInfo foregroundPush:NO];
        }
    }
}

// ローカル通知を送信
- (void)sendLocalNotificationForMessage:(NSString *)message {
    [self sendLocalNotificationForMessage:message foregroundPush:YES];
}
- (void)sendLocalNotificationForMessage:(NSString *)message foregroundPush:(BOOL)foregroundPush {
    UILocalNotification *localNotification = [UILocalNotification new];
    localNotification.alertBody = message;
    localNotification.fireDate = [NSDate date];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    
    if (foregroundPush && [app appStatus] == kAppStatusForeground) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notification" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
}

// TextField デリゲートメソッド
// フォーカス時
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    activeTextField = textField;
}
// メッセージ入力終了処理
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if (textField == majorTextField) {
        self.major = ([textField.text isEqualToString:@""] || [textField.text isEqualToString:@"-"])?-1:[textField.text intValue];
        textField.text = [NSString stringWithFormat:@"%@", (self.major>=0 && self.major<=9999)?[NSString stringWithFormat:@"%d", self.major]:@"-"];
        NSLog(@"changed major: self.major = %d", self.major);
    } else if (textField == minorTextField) {
        self.minor = ([textField.text isEqualToString:@""] || [textField.text isEqualToString:@"-"])?-1:[textField.text intValue];
        textField.text = [NSString stringWithFormat:@"%@", (self.minor>=0 && self.minor<=9999)?[NSString stringWithFormat:@"%d", self.minor]:@"-"];
        NSLog(@"changed minor: self.minor = %d", self.minor);
    }
    
    [textField resignFirstResponder];
    return YES;
}

// キーボード表示時
- (void)keyboardWillShow:(NSNotification*)notification {
    NSLog(@"keyboardWillShow");
    // スクロール位置一時保存
    tempScrollTop = contentsView.scrollsToTop;
    
    // キーボードサイズ取得
    CGRect keyboardRect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    // 最適位置までスクロール
    CGPoint scrollPoint = CGPointMake(0, (activeTextField.frame.origin.y+activeTextField.frame.size.height+5)-(displayHeight-keyboardRect.size.height));
    [contentsView setContentOffset:scrollPoint animated:YES];
}
// キーボード非表示時
- (void)keyboardWillHide:(NSNotification*)notification {
    NSLog(@"keyboardWillHide");
    
    // スクロール位置を戻す
    [contentsView setContentOffset:CGPointMake(0.0, tempScrollTop) animated:YES];
}

// ローカル通知のON/OFF切り替え
- (void)toggleNoticeEnabled:(UISwitch*)_switch {
    self.noticeEnabled = _switch.on;
    NSLog(@"toggleNoticeEnabled: noticeEnabled = %@", self.noticeEnabled?@"true":@"false");
    
    // ローカル通知ON/OFF設定保存
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:self.noticeEnabled forKey:@"localNotificationEnabled"];
    [userDefaults synchronize];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
