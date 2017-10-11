//
//  JBHTTPSessionManager.h
//  JBNetworking
//
//  Created by philia on 2017/10/5.
//  Copyright © 2017年 philia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <TargetConditionals.h>

#import <MobileCoreServices/MobileCoreServices.h>

#import "JBURLSessionManager.h"




@interface JBHTTPSessionManager : JBURLSessionManager <NSSecureCoding, NSCopying>

@property (readonly, nonatomic, strong) NSURL *baseURL;

@property (nonatomic, strong) JBHTTPRequestSerializer<JBURLRequestSerialization> *requestSerializer;

@property (nonatomic, strong) JBHTTPResponseSerializer<JBURLResponseSerialization> *responseSerializer;

+ (instancetype)manager;

- (instancetype)initWithBaseURL:(NSURL *)url;

- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                     progress:(void (^)(NSProgress *downloadProgress))downloadProgress
                      success:(void(^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask * task, NSError *error))failure;

- (NSURLSessionDataTask *)HEAD:(NSString *)URLString
                    parameters:(id)parameters success:(void (^)(NSURLSessionDataTask *task))success
                       failure:(void(^)(NSURLSessionDataTask *task, NSError *error))failure;

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                      progress:(void(^)(NSProgress *uploadProgress))uploadProgress
                       success:(void(^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
     constructingBodyWithBlock:(void (^)(id <JBMultipartFormData> formData))block
                      progress:(void(^)(NSProgress *uploadProgress))uploadProgress
                       success:(void(^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;


- (NSURLSessionDataTask *)PATCH:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

- (NSURLSessionDataTask *)DELETE:(NSString *)URLString
                     parameters:(id)parameters
                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

@end

















