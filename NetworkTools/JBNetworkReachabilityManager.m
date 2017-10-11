//
//  JBNetworkReachabilityManager.m
//  JBNetworking
//
//  Created by philia on 2017/9/25.
//  Copyright © 2017年 philia. All rights reserved.
//

#import "JBNetworkReachabilityManager.h"

// 导入socket的头文件<为后面的sockaddr_in6/sockaddr_in做准备>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

// 给通知赋值
NSString * const JBNetworkingReachabilityDidChangeNotification = @"JBNetworkingReachabilityDidChangeNotification";
NSString * const JBNetworkingReachabilityNotificationStatusItem = @"JBNetworkingReachabilityNotificationStatusItem";

/// typedef一下状态的Block
typedef void (^JBNetworkReachabilityStatusBlock)(JBNetworkReachabilityStatus status);

/// 返回状态字符串的函数,  <用于国际化>
NSString * JBStringFormNetworkReachabilityStatus(JBNetworkReachabilityStatus status) {
    switch (status) {
        case JBNetworkReachabilityStatusNotConnect:
            return NSLocalizedStringFromTable(@"Not Connect", @"JBNetworking", nil);
            break;
            
        case JBNetworkReachabilityStatusConnectViaWWAN:
            return NSLocalizedStringFromTable(@"Connect via WWAN", @"JBNetworking", nil);
            break;
            
        case JBNetworkReachabilityStatusConnectViaWiFi:
            return NSLocalizedStringFromTable(@"Connect via WiFi", @"JBNetworking", nil);
            break;
            
        case JBNetworkReachabilityStatusUnknown:
        default:
            return NSLocalizedStringFromTable(@"Unknown", @"JBNetworking", nil);
            break;
    }
}

/// 通过SCNetworkReachabilityFlags来判断网络状态的函数,用static修饰强行拉到静态区,如果编译器心情好会放在栈区,执行速度回变快
static JBNetworkReachabilityStatus JBNetworkReachabilityStatusForFlags(SCNetworkReachabilityFlags flags) {
    
    // 判断是否有网络连接<必须满足flag  和  kSCNetworkReachabilityFlagsReachable该标志表示指定的节点名或地址可以使用当前网络配置达成>
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    
    // 表示需要连接  kSCNetworkReachabilityFlagsConnectionRequired:该标志表示指定的节点名或地址可以使用当前的网络配置达成，但必须首先建立连接
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    
    // 表示能够自动连接
    // 1.该标志表示指定的节点名或地址可以使用当前的网络配置达成，但必须首先建立连接。连接将由“按需”建立CFSocketStream API。其他API将不会建立连接。
    // 2.该标志表示指定的节点名或地址可以使用当前的网络配置达成，但必须首先建立连接。任何交通指示到指定的名称或地址将启动连接
    BOOL canConnectionAutomatically = ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0);
    
    // 该标志表示指定的节点名或地址可以使用当前的网络配置达成，但必须首先建立连接。另外一些需要用户干预的形式来确定这一点连接，如提供密码，认证令牌等
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    
    // 表示有网,但是必须要先连接
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));
    
    // 类型先是不确定
    JBNetworkReachabilityStatus status = JBNetworkReachabilityStatusUnknown;
    
    // 无网络条件
    if (isNetworkReachable == NO) {
        status = JBNetworkReachabilityStatusNotConnect;
    }
    
    // 蜂窝数据移动
    else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = JBNetworkReachabilityStatusConnectViaWWAN;
    } 
    
    // WiFi
    else {
        status = JBNetworkReachabilityStatusConnectViaWiFi;
    }
    
    return status;
}

/// 状态改变发送通知的函数,要在主线程发送通知,同样写成静态函数提高效率
/// static函数可以不声明类的对象而直接调用
/// 但是这样就不能传递this指针,不能访问类中的非静态成员
static void JBPostReachabilityStatusChange(SCNetworkReachabilityFlags flags, JBNetworkReachabilityStatusBlock block) {
    
    // Flags状态
    JBNetworkReachabilityStatus status = JBNetworkReachabilityStatusForFlags(flags);
    
    // 安全的主队列发送通知
    dispatch_async(dispatch_get_main_queue(), ^{
        // 安全判断<需要传入block>
        if (block) {
            block(status);
        }
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        
        // 包成对象用于通知传递 
        NSDictionary *userInfo = @{JBNetworkingReachabilityNotificationStatusItem: @(status)};
        
        [notificationCenter postNotificationName:JBNetworkingReachabilityDidChangeNotification object:nil userInfo:userInfo];
    });
}

/// 状态发生改变后进行回调
static void JBNetworkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void * info) {
    
    JBPostReachabilityStatusChange(flags, (__bridge JBNetworkReachabilityStatusBlock)info);
}


/// 对block进行copy<从栈 -> 堆>要使用Block_copy()/Block_release()
/// 即使在ARC的环境下也这么做一下,为了更加严谨
/// 为下面网络监测上下文的参数做准备
static const void * JBNetworkReachabilityRetainCallback(const void * info) {
    return Block_copy(info);
}

static void JBNetworkReachabilityReleaseCallback(const void * info) {
    if (info) {        
        Block_release(info);
    }
}


/// 内部的延展就readwrite了, 只想说外部readonly内部readwrite好鸡贼哦~~~
@interface JBNetworkReachabilityManager()

@property (nonatomic, assign) SCNetworkReachabilityRef networkReachability;

@property (nonatomic, assign) JBNetworkReachabilityStatus networkReachabilityStatus;

@property (nonatomic, assign) JBNetworkReachabilityStatusBlock networkReachabilityStatusBlock;

@end

@implementation JBNetworkReachabilityManager

+ (instancetype)sharedManager {
    static JBNetworkReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [self manager];
    });
    
    return _sharedManager;
}

+ (instancetype)managerForDomain:(NSString *)domain {
    
    // 创建网络环境Ref类<default 表示Null>
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, domain.UTF8String);
    
    JBNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    
    // 有create就有release
    CFRelease(reachability);
    
    return manager;
}

+ (instancetype)managerForAddress:(const void *)address {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);
    
    JBNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    
    CFRelease(reachability);
    
    return manager;
}

+ (instancetype)manager {
    
    // 对版本适配进行判断<超过默认版本支持ipv6>
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000)
    struct sockaddr_in6 address;
    bzero(&address, sizeof(address));
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET6;
#else
    struct sockaddr_in address;
    bzero(&address, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
#endif
    return [self managerForAddress:&address];
}

- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _networkReachability = CFRetain(reachability);
    self.networkReachabilityStatus = JBNetworkReachabilityStatusUnknown;
    
    return self;
}

/// 让默认的init方法无效化
- (instancetype)init NS_UNAVAILABLE {
    return nil;
}

- (void)dealloc {
    // 停止监测
    [self stopMonitoring];
    // 释放监测对象
    if (_networkReachability != NULL) {
        CFRelease(_networkReachability);
    }
}

#pragma mark - 几个网络条件的判断
- (BOOL)isReachable {
    return [self isReachableConnectViaWiFi] || [self isReachableConnectViaWWAN];
}

- (BOOL)isReachableConnectViaWWAN {
    return self.networkReachabilityStatus == JBNetworkReachabilityStatusConnectViaWWAN;
}

- (BOOL)isReachableConnectViaWiFi {
    return self.networkReachabilityStatus == JBNetworkReachabilityStatusConnectViaWiFi;
}


#pragma mark - 开始监测和结束监测的方法
- (void)startMonitoring {
    // 首先结束监测
    [self stopMonitoring];
    
    if (!self.networkReachability) {
        return;
    }
    
    // 设置回调 <避免循环引用weak strong dance>
    __weak typeof(self) weakSelf = self;
    JBNetworkReachabilityStatusBlock callBack = ^(JBNetworkReachabilityStatus status) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        strongSelf.networkReachabilityStatus = status;
        if (strongSelf.networkReachabilityStatusBlock) {
            strongSelf.networkReachabilityStatusBlock(status);
        }
    };
    
    // 网络环境监测上下文 根据ability中的用户指定数据和回调
    // version: 结构类型的版本号 一般传入0
    // info: 用户指定模块的 C 函数指针
    // retain: info 为info字段添加retain的回调.如果不指向正确的函数指针可能为NULL
    // release: 用于删除原来添加的保留的callback的信息字段  如果不指向正确的函数指针可能为NULL
    // copyDescription: 用于提供描述的回调
    SCNetworkReachabilityContext context = {0, (__bridge void *)callBack, JBNetworkReachabilityRetainCallback,
        JBNetworkReachabilityReleaseCallback, NULL};
    
    // 设置回调<客户端分配给目标,发生改变的时候>
    // target: 与地址相关联的网络引用要检查的名称 是否可用
    // callout: 可用时候函数目标是否发生更改, 如果为NULL 表示客户端被删除
    // context: 之前关联的上下文, 可能为NULL
    // 结果用来通知客户端是否成功  成功返回TRUE
    SCNetworkReachabilitySetCallback(self.networkReachability, JBNetworkReachabilityCallback, &context);
    
    // runloop: 将ability添加到的runloop 必须不能为空
    SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);

    // 全局队列, 优先级为后台<最低>
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            // 改变状态, 并且回调
            JBPostReachabilityStatusChange(flags, callBack);
        }
    });
}


// 停止监测
- (void)stopMonitoring {
    if (!self.networkReachability) {
        return;
    }
    
    SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}


// 返回本地化(国际化)字符串的方法
- (NSString *)localizedNetworkReachabilityStatusString {
    return JBStringFormNetworkReachabilityStatus(self.networkReachabilityStatus);
}

// 回调网络状态的方法
- (void)setReachabilityStatusChangeBlock:(void (^)(JBNetworkReachabilityStatus))block {
    
    self.networkReachabilityStatusBlock = block;
}

// KVO监听网络状态改变
+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableViaWWAN"] || [key isEqualToString:@"reachableViaWiFi"]) {
        return [NSSet setWithObjects:@"networkReachabilityStatus", nil];
    }
    return [super keyPathsForValuesAffectingValueForKey:key];
}

@end
