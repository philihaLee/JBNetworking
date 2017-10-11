//
//  JBSecurityPolicy.m
//  JBNetworking
//
//  Created by philia on 2017/9/25.
//  Copyright © 2017年 philia. All rights reserved.
//

#import "JBSecurityPolicy.h"

/// 结构化错误处理的断言宏~
#import <AssertMacros.h>


/*
 ios::in 允许从流中输入（读取操作）。当您想从文件中读取时，将使用ios :: in
 ios::out 允许输出（写入操作）到流。 当您想要写入文件时，会使用ios :: out
 */
/// 将加密密匙转换成NSData的函数 注意加入跨平台的宏定义<用流来拼接data>,对于iOS完全没有用,完全是为了跨平台才搞了个这个函数 
/// 如果断言没有错误转到<goto>_out
#if !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
static NSData * JBSecKeyGetData(SecKeyRef key) {
    
    CFDateRef data = NULL;
    
    __Require_noErr_Quiet(SecItemExport(key, kSecFormatUnknown, kSecItemPemArmour, NULL, &data), _out);
    return (__bridge_transfer NSData *)data;

_out:
    if (data) {
        CFRelease(data);
    }
    return nil;
}
#endif

// isEqual: 判断两个对象是否相等<NSObject>
static BOOL JBSecKeyIsEqualToKey(SecKeyRef key1, SecKeyRef key2) {
    
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
    return [(__bridge id)key1 isEqual:(__bridge id)key2];
#else
    return [JBSecKeyGetData(key1) isEqual:JBSecKeyGetData(key2)];
#endif
}

// 通过证书获取公钥的函数
static id JBPublicKeyForCertificate(NSData *certificate) {
    id allowedPublicKey = nil;
    
    SecCertificateRef allowedCertificate;
    SecCertificateRef allowedCertificates[1];
    
    CFArrayRef tempCertificates = nil;
    SecPolicyRef policy = nil;
    SecTrustRef allowedTrust = nil;
    SecTrustResultType result;
    
    allowedCertificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificate);
    // 如果证书为空转到_out
    __Require_Quiet(allowedCertificate != NULL, _out);
    
    allowedCertificates[0] = allowedCertificate;

    /*
     NULL 为当前默认值使用CFAllocator    values C数组中指针大小的值阵列
     values 赋值到数组的值的数量 
     */
    tempCertificates = CFArrayCreate(NULL, (const void **)allowedCertificates, 1, NULL);
    
    // 509证书
    policy = SecPolicyCreateBasicX509();
    /// 根据证书创建一个信任对象的策略
    // 1.证书数组  2.策略数组<1个或多个>  3.指向信任管理引用的指针   如果传入多个策略,那么每个策略都要进行验证
    __Require_noErr_Quiet(SecTrustCreateWithCertificates(tempCertificates, policy, &allowedTrust), _out);
    // 同步评估信任引用  
    // 1. 对要评估的信任对象的引用  2. 指向结果类型的指针 
    __Require_noErr_Quiet(SecTrustEvaluate(allowedTrust, &result), _out);
    
    allowedPublicKey = (__bridge_transfer id)SecTrustCopyPublicKey(allowedTrust);
    
_out:
    if (allowedTrust) {
        CFRelease(allowedTrust);
    }
    
    if (policy) {
        CFRelease(policy);
    }
    
    if (tempCertificates) {
        CFRelease(tempCertificates);
    }
    
    if (allowedCertificate) {
        CFRelease(allowedCertificate);
    }
    
    return allowedPublicKey;
}

/// 判断服务器是否能够信任
static BOOL JBServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
    __Require_noErr_Quiet(SecTrustEvaluate(serverTrust, &result), _out);
    
    // kSecTrustResultUnspecified  表示评估成功证书是隐含信任的，但用户意图没有明确指定
    // kSecTrustResultProceed  表示可以继续。这个值可以由SecTrustEvaluate函数返回或作为其一部分存储用户信任设置
    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
    
_out:
    return isValid;
}

/// 获取证书的数组
static NSArray * JBCertificateTrustChainForServerTrust(SecTrustRef serverTrust) {
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
    
    /// 遍历证书,获取可以信任的证书
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        // 转换成NSData存储起来
        [trustChain addObject:(__bridge_transfer NSData *)SecCertificateCopyData(certificate)];
    }
    
    return [NSArray arrayWithArray:trustChain];
}

/// 获取公钥数组的函数
static NSArray * JBPublicKeyTrustChainForServerTrust(SecTrustRef serverTrust) {
    // 509策略
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    // 证书数量
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
    
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        
        // 证书数组
        SecCertificateRef someCertificates[] = {certificate};
        
        // 根据创建的数组获得CFArray
        CFArrayRef certificates = CFArrayCreate(NULL, (const void **)someCertificates, 1, NULL);
        
        SecTrustRef trust;
        __Require_noErr_Quiet(SecTrustCreateWithCertificates(certificates, policy, &trust), _out);
        
        SecTrustResultType result;
        __Require_noErr_Quiet(SecTrustEvaluate(trust, &result), _out);
        [trustChain addObject:(__bridge_transfer id)SecTrustCopyPublicKey(trust)];
        
    _out:
        if (trust) {
            CFRelease(trust);
        }
        
        if (certificates) {
            CFRelease(certificates);
        }
        
        continue;
    }
    CFRelease(policy);
    
    return [NSArray arrayWithArray:trustChain];
}

@interface JBSecurityPolicy()

@property (readwrite, nonatomic, assign) JBSSLPinningMode SSLPinningMode;

@property (readwrite, nonatomic, strong) NSSet *pinnedPublicKeys;

@end

@implementation JBSecurityPolicy


+ (NSSet<NSData *> *)certificatesInBundle:(NSBundle *)bundle {

    // 获得证书中的路径的地址
    NSArray *paths = [bundle pathsForResourcesOfType:@"cer" inDirectory:@"."];
    
    NSMutableSet *certificates = [NSMutableSet setWithCapacity:paths.count];
    
    // 转二进制文件
    for (NSString *path in paths) {
        NSData *certificatesData = [NSData dataWithContentsOfURL:[NSURL URLWithString:path]];
        [certificates addObject:certificatesData];
    }

    return certificates;
}

/// 默认证书数组
+ (NSSet *)defaultPinnedCertificates {
    static NSSet *_defaultPinnedCertificates = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        _defaultPinnedCertificates = [self certificatesInBundle:bundle];
    });
    
    return _defaultPinnedCertificates;
}


/// 默认安全策略
+ (instancetype)defaultPolicy {
    JBSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = JBSSLPinningModeNone; //无条件信任证书
    return securityPolicy;
}

/// 根据模式返回安全策略
+ (instancetype)policyWithPinningMode:(JBSSLPinningMode)pinningMode {
    return [self policyWithPinningMode:pinningMode withPinnedCertificates:[self defaultPinnedCertificates]];
}

+ (instancetype)policyWithPinningMode:(JBSSLPinningMode)pinningMode withPinnedCertificates:(NSSet<NSData *> *)pinnedCertificates {
    JBSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = pinningMode;
    
    [securityPolicy setPinnedCertificates:pinnedCertificates];
    
    return securityPolicy;
}

// 默认验证域名
- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.validatesDomainName = YES;
    return self;
}


/// 重写设置证书的set方法
- (void)setPinnedCertificates:(NSSet<NSData *> *)pinnedCertificates {
    _pinnedCertificates = pinnedCertificates;
    
    // 如果有证书,根据证书进行解析
    if (self.pinnedCertificates) {
        
        // 公钥集合
        NSMutableSet *mutablePinnedPublickKeys = [NSMutableSet setWithCapacity:self.pinnedCertificates.count];
        
        for (NSData *certificate in self.pinnedCertificates) {
            // 获取证书公钥
            id publicKey = JBPublicKeyForCertificate(certificate);
            if (!publicKey) {
                continue;
            }
            [mutablePinnedPublickKeys addObject:publicKey];
        }
        self.pinnedPublicKeys = [NSSet setWithSet:mutablePinnedPublickKeys];
    } else {
        // 否则公钥为nil
        self.pinnedPublicKeys = nil;   
    }
}


// 评估服务器是否收到信任的方法
// 你应该只把你所信任的证书进行评估,把固定证书添加到信任,要是没有固定证书,就没有什么可评价的
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {
    if (domain && self.allowInvalidCertificates && self.validatesDomainName && (self.SSLPinningMode == JBSSLPinningModeNone || self.pinnedCertificates.count == 0)) {
        
        NSLog(@"为了验证证书的域名, 你必须要绑定证书");
        return NO;
    }
    
    // 需要验证域名的时候, 添加策略
    NSMutableArray *policies = [NSMutableArray array];
    if (self.validatesDomainName) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
    
    // 验证多个策略
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
    
    if (self.SSLPinningMode == JBSSLPinningModeNone) {
        return self.allowInvalidCertificates || JBServerTrustIsValid(serverTrust);
    } else if (!JBServerTrustIsValid(serverTrust) && !self.allowInvalidCertificates) {
        return NO;
    }
    
    // 根据服务器证书的内容进行返回
    switch (self.SSLPinningMode) {
        case JBSSLPinningModeNone:
        default:
            return NO;
            
        // 将本地证书设置为信任的证书然后进行判断,和服务器相同就返回yes
        case JBSSLPinningModeCertificate: {   
            NSMutableArray *pinnedCertificates = [NSMutableArray array];
            for (NSData *certificateData in self.pinnedCertificates) {
                [pinnedCertificates addObject:(__bridge id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
            }
            SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates);
            
            if (!JBServerTrustIsValid(serverTrust)) {
                return NO;
            }
            
            // 经过验证获得证书链,应该在最后的位置
            NSArray *serverCertificates = JBCertificateTrustChainForServerTrust(serverTrust);
            // 倒序遍历
            for (NSData *trustChainForServerTrust in [serverCertificates reverseObjectEnumerator]) {
                if ([self.pinnedCertificates containsObject:trustChainForServerTrust]) {
                    return YES;
                }
            }
            
            return NO;
        }
        case JBSSLPinningModePublicKey: {
            NSUInteger trustedPublicKeyCount = 0;
            NSArray *publicKeys = JBPublicKeyTrustChainForServerTrust(serverTrust);
            
            for (id trustChainPublicKey in publicKeys) {
                for (id pinnedPublicKey in self.pinnedPublicKeys) {
                    // 证书的公钥相同信任的公钥数量+1
                    if (JBSecKeyIsEqualToKey((__bridge SecKeyRef)trustChainPublicKey, (__bridge SecKeyRef)pinnedPublicKey)) {
                        trustedPublicKeyCount += 1;
                    }
                }
            }
            // 只要有公钥相同就验证通过
            return trustedPublicKeyCount > 0;
        }
    }
    return NO;
}


#pragma mark - KVO
+ (NSSet<NSString *> *)keyPathsForValuesAffectingPinnedPublicKeys {
    return [NSSet setWithObject:@"pinnedCertificates"];
}


#pragma mark - NSSecureCoding<继承NSCoding>
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    if (!self) {
        return nil;
    }
    // 解档
    self.SSLPinningMode = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(SSLPinningMode))] unsignedIntegerValue];
    self.allowInvalidCertificates = [decoder decodeBoolForKey:NSStringFromSelector(@selector(allowInvalidCertificates))];
    self.validatesDomainName = [decoder decodeBoolForKey:NSStringFromSelector(@selector(validatesDomainName))];
    self.pinnedCertificates = [decoder decodeObjectOfClass:[NSArray class] forKey:NSStringFromSelector(@selector(pinnedCertificates))];
    
    return self;
}

/// 归档
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.SSLPinningMode] forKey:NSStringFromSelector(@selector(SSLPinningMode))];
    [coder encodeBool:self.allowInvalidCertificates forKey:NSStringFromSelector(@selector(allowInvalidCertificates))];
    [coder encodeBool:self.validatesDomainName forKey:NSStringFromSelector(@selector(validatesDomainName))];
    [coder encodeObject:self.pinnedCertificates forKey:NSStringFromSelector(@selector(pinnedCertificates))];
}


#pragma mark - NSCoping
- (instancetype)copyWithZone:(NSZone *)zone {
    JBSecurityPolicy *securityPolicy = [[self class] allocWithZone:zone];
    
    securityPolicy.SSLPinningMode = self.SSLPinningMode;
    securityPolicy.allowInvalidCertificates = self.allowInvalidCertificates;
    securityPolicy.validatesDomainName = self.validatesDomainName;
    securityPolicy.pinnedCertificates = [self.pinnedCertificates copyWithZone:zone];
    
    return securityPolicy;
}


@end
