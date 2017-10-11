//
//  JBNetworkReachabilityManager.h
//  JBNetworking
//
//  Created by philia on 2017/9/25.
//  Copyright © 2017年 philia. All rights reserved.
//

#import <Foundation/Foundation.h>
// 以此类作为基础
#import <SystemConfiguration/SystemConfiguration.h>

/**
 网络连接的四种状态

 - JBNetworkReachabilityStatusUnknown: 不明确的连接状态
 - JBNetworkReachabilityStatusNotConnect: 没有链接
 - JBNetworkReachabilityStatusConnectViaWWAN: 连接的蜂窝移动网络
 - JBNetworkReachabilityStatusConnectViaWiFi: 连接的WiFi
 */
typedef NS_ENUM(NSInteger, JBNetworkReachabilityStatus) {
    JBNetworkReachabilityStatusUnknown        = -1,
    JBNetworkReachabilityStatusNotConnect     = 0,
    JBNetworkReachabilityStatusConnectViaWWAN = 1,
    JBNetworkReachabilityStatusConnectViaWiFi = 2
};


@interface JBNetworkReachabilityManager : NSObject


#pragma mark - 表示网络连接的四种状态

/// 网络连接的状态
@property (readonly, nonatomic, assign) JBNetworkReachabilityStatus networkReachabilityStatus;

/// 是否能够连接
@property (readonly, nonatomic, assign, getter = isReachable) BOOL reachable;

/// 是否能够连接蜂窝移动数据
@property (readonly, nonatomic, assign, getter = isReachableConnectViaWWAN) BOOL reachableViaWWAN;

/// 是否能够连接WiFi
@property (readonly, nonatomic, assign, getter = isReachableConnectViaWiFi) BOOL reachableWiFi;


/// 获取全局网络状态单例的方法
+ (instancetype)sharedManager;

/// 默认socket地址的管理器
+ (instancetype)manager;

/// 返回特定区域的manager
+ (instancetype)managerForDomain:(NSString *)domain;

/// 特定socket地址的管理器
+ (instancetype)managerForAddress:(const void *)address;


/// 默认初始化方法
- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability NS_DESIGNATED_INITIALIZER;


/// 开始监测网络环境
- (void)startMonitoring;

/// 停止监测网络环境
- (void)stopMonitoring;

/// 获得本地状态的字符串
- (NSString *)localizedNetworkReachabilityStatusString;

/// 获得状态改变的方法
- (void)setReachabilityStatusChangeBlock:(void (^) (JBNetworkReachabilityStatus status))block;


@end

// 这样定义更加便捷 也可以用  ==  进行比较  在.m文件中实现,更加隐蔽 

/// 定义几个通知用来接收状态改变时候发送调用<通过改变userinfo中Number的值来确定状态>
FOUNDATION_EXPORT NSString * const JBNetworkingReachabilityDidChangeNotification;
FOUNDATION_EXPORT NSString * const JBNetworkingReachabilityNotificationStatusItem;


/// 返回字符串的函数<用函数的执行效率更高>

FOUNDATION_EXPORT NSString * JBStringFormNetworkReachabilityStatus(JBNetworkReachabilityStatus status);
