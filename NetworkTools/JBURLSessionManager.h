//
//  JBURLSessionManager.h
//  JBNetworking
//
//  Created by philia on 2017/10/1.
//  Copyright © 2017年 philia. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JBURLRequestSerialization.h"
#import "JBURLResponseSerialization.h"
#import "JBSecurityPolicy.h"
#import "JBNetworkReachabilityManager.h"

@interface JBURLSessionManager : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSSecureCoding, NSCopying>

@property (readonly, nonatomic, strong) NSURLSession *session;

@property (readonly, nonatomic, strong) NSOperationQueue *operationQueue;

@property (nonatomic, strong) id <JBURLResponseSerialization> responseSerializer;

@property (nonatomic, strong) JBSecurityPolicy *securityPolicy;

@property (nonatomic, strong) JBNetworkReachabilityManager *reachabilityManger;

@property (nonatomic, strong) NSArray <NSURLSessionTask *> *tasks;

@property (nonatomic, strong) NSArray <NSURLSessionUploadTask *> *dataTasks;

@property (readonly, nonatomic, strong) NSArray <NSURLSessionUploadTask *> *uploadTasks;

@property (readonly, nonatomic, strong) NSArray <NSURLSessionDownloadTask *> *downloadTasks;

@property (nonatomic, strong) dispatch_queue_t completionQueue;

@property (nonatomic, strong) dispatch_group_t completionGroup;

@property (nonatomic, assign) BOOL attemptsToRecreateUploadTasksForBackgroundSessions;

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (void)invalidateSessionCancleTask:(BOOL)cancelPendingTasks;

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler;


- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                               uploadProgress:(void(^)(NSProgress *uploadProgress))uploadProgressBlock
                             downloadProgress:(void(^)(NSProgress *downloadProgress))downloadProgressBlock
                            completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler;

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                                         progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                completionHandler:(void(^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler;

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)bodyData
                                         progress:(void (^)(NSProgress *))uploadProgressBlock
                                completionHandler:(void (^)(NSURLResponse *, id, NSError *))completionHandler;


- (NSURLSessionUploadTask *)uploadTaskWithStreamRequest:(NSURLRequest *)request
                                               progress:(void (^)(NSProgress *))uploadProgressBlock
                                completionHandler:(void (^)(NSURLResponse *, id, NSError *))completionHandler;


- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
                                             progress:(void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                          destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                    completionHandler:(void (^)(NSURLResponse *response, NSURL * filePath, NSError * error))completionHandler;

- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData
                                                progress:(void(^)(NSProgress *downloadProgress))downloadProgressBlock
                                             destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                       completionHandler:(void (^)(NSURLResponse *response, NSURL * filePath, NSError *  error))completionHandler;


- (NSProgress *)uploadProgressForTask:(NSURLSessionTask *)task;
- (NSProgress *)downloadProgressForTask:(NSURLSessionTask *)task;


- (void)setSessionDidBecomeInvalidBlock:(void (^)(NSURLSession *session, NSError *error))block;


- (void)setSessionDidReceiveAuthenticationChallengeBlock:(NSURLSessionAuthChallengeDisposition (^)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *creadential))block;

- (void)setTaskNeedNewBodyStreamBlcok:(NSInputStream *(^)(NSURLSession *session, NSURLSessionTask *task))block;

- (void)setTaskWillPerformHTTPRedirectionBlock:(NSURLRequest * (^)(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request))block;


- (void)setTaskDidReceiveAuthenticationChallengeBlock:(NSURLSessionAuthChallengeDisposition (^)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *creadential))block;

- (void)setTaskDidSendBodyDataBlock:(void (^)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend))block;

- (void)setTaskDidCompletionBlock:(void (^)(NSURLSession *session, NSURLSessionTask *task, NSError *error))block;

- (void)setDataTaskDidReceiveResponseBlock:(NSURLSessionResponseDisposition (^)(NSURLSession *session, NSURLSessionTask *dataTask, NSURLResponse *response))block;

- (void)setDataTaskDidBecomeDownloadTaskBlock:(void (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLSessionDownloadTask *downloadTask))block;

- (void)setDataTaskDidReceiveDataBlock:(void (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data))block;

- (void)setDataTaskWillCacheResponseBlock:(NSCachedURLResponse * (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSCachedURLResponse *proposedResponse))block;

- (void)setDidFinishEventsForBackgroundURLSessionBlock:(void (^)(NSURLSession *session))block;

- (void)setDownloadTaskDidFinishDownloadingBlock:(NSURL * (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location))block;

- (void)setDownloadTaskDidWriteDataBlock:(void (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite))block;

- (void)setDownloadTaskDidResumeBlock:(void (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t fileOffset, int64_t expectedTotalBytes))block;

@end


FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidResumeNotification;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidCompleteNotification;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidSuspendNotification;

FOUNDATION_EXPORT NSString * const JBURLSessionDidInvalidateNotification;

FOUNDATION_EXPORT NSString * const JBURLSessionDownloadTaskDidFailToMoveFileNotification;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidCompleteResponseDataKey;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidCompleteSerializedResponseKey;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidCompleteResponseSerializerKey;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidCompleteAssetPathKey;

FOUNDATION_EXPORT NSString * const JBNetworkingTaskDidCompleteErrorKey;

