//
//  JBURLRequestSerialization.h
//  JBNetworking
//
//  Created by philia on 2017/9/27.
//  Copyright © 2017年 philia. All rights reserved.
//

#import <Foundation/Foundation.h>

// 为iPhone 和 OS X 自动配置TARGET文件
#import <TargetConditionals.h>

#import <UIKit/UIKit.h>

/// 百分比转译字符串
FOUNDATION_EXPORT NSString * JBPercentEscapedStringFromString(NSString * string);

/// 拼接参数到URL后面
FOUNDATION_EXPORT NSString * JBQueryStringFromParameters(NSDictionary *parameters);


/// 请求序列化可以将参数编码成查询字符串,根据需求设置HTTP请求头
@protocol JBURLRequestSerialization <NSObject, NSSecureCoding, NSCopying>

/// 拼接参数返回一个URL请求
- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request withParameters:(id)parameters error:(NSError * __autoreleasing *)error;

@end

typedef NS_ENUM(NSUInteger, JBHTTPRequestQueryStringSerializationStyle) {
    JBHTTPRequestQueryStringDefaultStyle = 0,
};

@protocol JBMultipartFormData;

/// 对于任何处理HTTP请求的序列化类,都作为此类别的子类<本类提供默认请求头的实现,以及响应状态码和类型的验证>
@interface JBHTTPRequestSerializer : NSObject <JBURLRequestSerialization>

/// 默认UTF8
@property (nonatomic, assign) NSStringEncoding stringEncoding;

/// 创建的请求是否可以使用蜂窝数据网络 默认为YES
@property (nonatomic, assign) BOOL allowsCellularAccess;

/// 请求的缓存策略
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

/// 创建的请求是否使用默认的Cookie处理 默认为YES
@property (nonatomic, assign) BOOL HTTPShouldHandleCookies;

/// 在接收到响应之前是否可以继续传输数据  默认为NO
@property (nonatomic, assign) BOOL HTTPShouldUsePipelining;

/// 网络服务类别  默认为Default
@property (nonatomic, assign) NSURLRequestNetworkServiceType networkServiceType;

/// 超时时长,默认60秒
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/// 默认的HTTP请求头信息,包括: "Accept-Language: NSLocale + preferredLanguages  " ,  "User- Agent: 包括各种捆绑的标识符和操作系统等信息"
@property (readonly, nonatomic, strong) NSDictionary<NSString *, NSString *> *HTTPRequestHeaders;

/// 采用默认的配置创建
+ (instancetype)serializer;

/// 设置由HTTP客户端创建的设置请求头的值,如果为nil,则删除
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/// 返回请求序列化设置的请求头
- (NSString *)valueForHTTPHeaderField:(NSString *)field;

/// 由HTTP客户端创建的请求头, 具有Base64编码的用户名和密码作为身份验证,覆盖原来的值
- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username password:(NSString *)password;

/// 清空所有的授权的请求头
- (void)clearAuthorizationHeader;
/// 将参数作为字符串查询的序列化请求方法: 默认 "GET", "HEAD" "DELETE"
@property (nonatomic, strong) NSSet <NSString *> *HTTPMethodsEncodingParametersInURI;

/// 根据预定义的样式设置查询字符串序列化方法<你TM就定义了一种.逗呢啊>
- (void)setQueryStringSerializationWithStyle:(JBHTTPRequestQueryStringSerializationStyle)style;

/// 根据制定的block设置查询字符串的序列化方法
- (void)setQueryStringSerializationWithBlock:(NSString *(^)(NSURLRequest *request, id parameters, NSError * __autoreleasing *error))block;


/**
 使用制定的HTTP方法和URL字符串创建可变请求对象<可以添加附加请求编码格式,否则根据parameterEncoding属性值进行编码>

 @param method "GET" "POST" "DELETE"等HTTP请求方法 参数不能为空
 @param URLString 创建URL请求的字符串
 @param parameters 请求参数
 @param error 构造请求可能会出现的错误
 @return 返回一个可变请求对象
 */
- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                 URLString:(NSString *)URLString 
                                parameters:(id)parameters 
                                     error:(NSError * __autoreleasing *)error;


/**
 创建请求,使用指定的参数和表单数据构建 "multipart/form-data"请求体, 大部分表单请求自动流式传输,直接从磁盘读取文件和单个HTTP请求体内的数据,所以具有"HTTPBodyStream的属性", 因此将清除大部分表单主题的流

 @param method 请求方法  不能是 "GET" "HEAD" "nil"
 @param URLString URL请求字符串
 @param parameters HTTP请求主题中编码和设置参数
 @param block 接受参数附加到HTTP主题, 参数式遵守<AFMultipartFormData>协议的对象
 @param error 错误信息
 @return 返回一个可变请求的对象
 */
- (NSMutableURLRequest *)multipartFormRequestWithMethod:(NSString *)method
                                              URLString:(NSString *)URLString 
                                             parameters:(NSDictionary <NSString *, id> *)parameters 
                              constructingBodyWithBlick:(void (^)(id<JBMultipartFormData>formData))block 
                                                  error:(NSError * __autoreleasing *)error;


/**
 通过从请求中删除"HTTPBodyStream"来创建请求, 并且将内容异步写入指定的文件,在完成的时候调用完成处理程序

 @param request "HTTPBodyStream属性不能是nil"
 @param fileURL 将多部分内容写入文件URL
 @param handler 要执行的回调Block
 @return 返回请求
 */
- (NSMutableURLRequest *)requestWithMultipartFormRequest:(NSURLRequest *)request
                             writingStreamContentsToFile:(NSURL *)fileURL 
                                       completionHandler:(void (^)(NSError * error))handler;


@end

/// 定义了请求方法里面的block中参数所支持的方法
@protocol JBMultipartFormData

///  Appends the HTTP header `Content-Disposition: file; filename=#{generated filename}; name=#{name}"` and `Content-Type: #{generated mimeType}`,两种形式自动生成表单中系统关联的MIME类型,成功拼接返回YES, 否则返回NO
- (BOOL)appendPartWithFileURL:(NSURL *)fileURL
                         name:(NSString *)name 
                        error:(NSError * __autoreleasing *)error;

/// 多了文件数据声明的MIME类型, 参数不能是nil
- (BOOL)appendPartWithFileURL:(NSURL *)fileURL 
                         name:(NSString *)name 
                     fileName:(NSString *)fileName 
                     mimeType:(NSString *)mimeType 
                        error:(NSError * __autoreleasing *)error;

/// 根据来自输入的流和大部分形式边界的数据进行拼接
- (void)appendPartWithInputStream:(NSInputStream *)inputStream 
                             name:(NSString *)name 
                         fileName:(NSString *)fileName 
                           length:(int64_t)length 
                         mineType:(NSString *)mimeType;

/// 根据编码文件的数据进行拼接
- (void)appendPartWithFileData:(NSData *)data
                          name:(NSString *)name
                      fileName:(NSString *)fileName
                      mimeType:(NSString *)mimeType;

/// 根据编码数据<附加到表单的数据>,以及数据相关联的名称
- (void)appendPartWithFormData:(NSData *)data
                          name:(NSString *)name;

/// 拼接HTTP请求头,后面跟上表单数据和表单boundary
- (void)appendPartWithHeaders:(NSDictionary <NSString *, NSString *> *)headers
                         body:(NSData *)body;


/**
 /// 节流器通过限制分组大小并未从上传流中读取每个部分添加延迟来请求贷款
 /// 通过3G或者EDGE链接上传的时候,请求可能会失败

 @param numberOfBytes 最大数据包大小,单位是字节  默认是16KB
 @param delay 每次读取书包的延迟时间, 默认没有延迟
 */
- (void)throttleBandwidthWithPacketSize:(NSUInteger)numberOfBytes
                                  delay:(NSTimeInterval)delay;

@end

/// HTTP请求序列化的子类, 参数编码是JSON, 请求类型是"application/json"
@interface JBJSONRequestSerializer : JBHTTPRequestSerializer 

/// 请求JSON数据时候的选项,默认为0<数组,字典>
@property (nonatomic, assign) NSJSONWritingOptions writingOptions;

/// 根据JSON请求设置时候的选项返回请求JSON序列化
+ (instancetype)serializerWithWritingOptions:(NSJSONWritingOptions)writingOptions;

@end

/// 请求类型 "application/x-plist"
@interface JBPropertyListRequestSerializer : JBHTTPRequestSerializer

/// 属性列表格式
@property (nonatomic, assign) NSPropertyListFormat format;

/// 未使用writeOption
@property (nonatomic, assign) NSPropertyListWriteOptions writeOptions;

/// 根据属性列表和writeOption创建
+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format writeOptions:(NSPropertyListWriteOptions)writeOptions;

@end

/// 错误域 主要是 AFURLRequestSerializer错误
FOUNDATION_EXPORT NSString * const JBURLRequestSerializationErrorDomain;

/// 用户信息字典keys, 错误信息保存在用户信息字典中
FOUNDATION_EXPORT NSString * const JBNetworkingOperationFailingURLRequestErrorKey;

//  HTTP请求输入流的限制带宽
/// 最大数据包大小，以字节为单位。 等于16kb。
FOUNDATION_EXPORT NSUInteger const kAFUploadStream3GSuggestedPacketSize;
/// 每次读取数据包时延迟的时间。 等于0.2秒。
FOUNDATION_EXPORT NSTimeInterval const kAFUploadStream3GSuggestedDelay;

