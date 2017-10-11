//
//  JBSecurityPolicy.h
//  JBNetworking
//
//  Created by philia on 2017/9/25.
//  Copyright © 2017年 philia. All rights reserved.
//

#import <Foundation/Foundation.h>
// 本类的依赖框架
#import <Security/Security.h>


/**
 验证证书是否正确的枚举

 - JBSSLPinningModeNone: 无条件信任证书
 - JBSSLPinningModePublicKey: 对服务器返回的公钥进行验证,通过则通过,否则不通过
 - JBSSLPinningModeCertificate: 对本地的公钥进行验证,通过则通过,否则不通过
 */
typedef NS_ENUM(NSUInteger, JBSSLPinningMode) {
    JBSSLPinningModeNone,
    JBSSLPinningModePublicKey,
    JBSSLPinningModeCertificate,
};

/// 参数不能是空
NS_ASSUME_NONNULL_BEGIN

// 遵守NSSecureCoding, NSCopying协议
@interface JBSecurityPolicy : NSObject<NSSecureCoding, NSCopying>

/// 验证证书的模式
@property (readonly, nonatomic, assign) JBSSLPinningMode SSLPinningMode;

/// 证书集合<里面是二进制数据>
@property (nonatomic, strong) NSSet<NSData *> *pinnedCertificates;

/// 是否信任无效过着过期服务器的证书<默认不允许 为NO>
@property (nonatomic, assign) BOOL allowInvalidCertificates;

/// 是否验证证书CN域中的域名 默认为YES验证
@property (nonatomic, assign) BOOL validatesDomainName;

/// 使用此方法来寻找程序包中所包含的证书,调用policyWithPinningMode:withPinnedCertificates 方法创建安全策略的时候,返回这些证书
+ (NSSet<NSData *> *)certificatesInBundle:(NSBundle *)bundle;

/// 默认的缓存策略
+ (instancetype)defaultPolicy;

/// 根据验证证书的模式指定缓存策略
+ (instancetype)policyWithPinningMode:(JBSSLPinningMode)pinningMode;

/// 根据验证证书的模式和各种证书指定缓存策略
+ (instancetype)policyWithPinningMode:(JBSSLPinningMode)pinningMode withPinnedCertificates:(NSSet <NSData *> *)pinnedCertificates;


/**
 是否应该接受指定服务器的信任:当从服务器响应身份挑战的时候,调用此方法

 @param serverTrust 服务器的X509证书信任
 @param domain 服务器的域, 如果是nil表示不被信任
 @return 是否信任服务器
 */
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain;

NS_ASSUME_NONNULL_END

@end
