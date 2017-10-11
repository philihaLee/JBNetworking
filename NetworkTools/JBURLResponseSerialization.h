//
//  JBURLResponseSerialization.h
//  JBNetworking
//
//  Created by philia on 2017/9/27.
//  Copyright © 2017年 philia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>


/// 可以对有效的数据进行验证,或者对传入的响应数据进行验证
@protocol JBURLResponseSerialization <NSObject, NSSecureCoding, NSCopying>

/**
 从响应中解析相关联的数据

 @param response 要处理的响应
 @param data 需要进行解码的数据
 @param error 尝试解码发生的错误
 @return 从响应数据解析出来的对象
 */
- (id)responseObjectForResponse:(NSURLResponse *)response 
                           data:(NSData *)data 
                          error:(NSError * __autoreleasing *)error NS_SWIFT_NOTHROW;

@end;

/// 提供查询字符串.URL编码的序列化和默认请求头的实现,以及响应状态代码和内容的验证
@interface JBHTTPResponseSerializer : NSObject<JBURLResponseSerialization>

- (instancetype)init;

/// 用指定的字符串编码序列化,默认是UTF-8
@property (nonatomic, assign) NSStringEncoding stringEncoding;

/// 用默认的配置近行序列化
+ (instancetype)serializer;

/// 用于响应可接受的HTTP状态码, 非"nil"的时候, 集合中不包含状态码的响应 默认200~299
@property (nonatomic, copy) NSIndexSet *acceptableStatusCodes;

/// 用于可接受的MIME类型,非"nil"的时候,如果没有里面相匹配的类型会发生错误
@property (nonatomic, copy) NSSet <NSString *> *acceptableContentTypes;

/// 验证指定响应类型的数据,可以检查状态码和内容  response表示需要验证的响应,data表示要关联的数据, error表示响应验证可能会发生的错误, 如果响应式有效的返回YES
- (BOOL)validateResponse:(NSHTTPURLResponse *)response 
                    data:(NSData *)data 
                   error:(NSError * __autoreleasing *)error;

@end

/// JSON响应类型默认接收  - `application/json`  - `text/json`  - `text/javascript` `text/html`<开心不开心激动不激动😊>
@interface JBJSONResponseSerializer : JBHTTPResponseSerializer 

- (instancetype)init;


/*
 NSJSONReadingMutableContainers 指定的数组和字典创建返回的可变对象,
 NSJSONReadingMutableLeaves 指定叶状字符串作为NSMtableString进行创建,
 NSJSONReadingAllowFragments 指定解析器不是数组和字典的实例的顶级对象
 */
/// 读取JSON数据并创建对象时候的选项, 默认0
@property (nonatomic, assign) NSJSONReadingOptions readingOptions;

/// 是否移除NSNull 的各种值, 默认不移除
@property (nonatomic, assign) BOOL removesKeysWithNullValues;

/// 根据JSON读取选项创建序列化响应
+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions;

@end

/// 将XML响应序列化成为NSXMLParser对象 默认接受:  - `application/xml`  - `text/xml`
@interface JBXMLParserResponseSerializer : JBHTTPResponseSerializer

@end

///// 将XML响应序列化成为NSXMLDocument对象 默认接受:  - `application/xml`  - `text/xml`
//@interface JBXMLDocumentResponseSerializer : JBHTTPResponseSerializer
//
//- (instancetype)init;
//
///// 专门针对XMLDocument 的输入输出选项, 默认为0
//@property (nonatomic, assign) NSUInteger options;
//
///// 根据XML文档选项序列化XML
//+ (instancetype)serializerWithXMLDocumentOptions:(NSUInteger)mask;
//
//@end

/// 将XML解码成XMLDocument对象, 默认- `application / x-plist`
@interface JBPropertyListResponseSerializer : JBHTTPResponseSerializer

- (instancetype)init;

/// 属性列表的描述
@property (nonatomic, assign) NSPropertyListFormat format;

/// 属性列表的readOptions
@property (nonatomic, assign) NSPropertyListReadOptions readOptions;

/// 根据描述和readOptions序列化
+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format readOptions:(NSPropertyListReadOptions)readOptions;

@end

/// 用于验证和解码图像的响应,默认情况下用于UIImage   - `image / tiff`  - `image / jpeg`  - `image / gif`   - `image / png`   - `image / ico`  - `image / x-icon`   - `image / bmp`   - `image / x-bmp`  - `image / x-xbitmap`  - `image / x-win-bitmap`
@interface JBImageResponseSerializer : JBHTTPResponseSerializer

/// 解析图像构造响应时候的比例因子,指定1.0会保证图像大小和像素尺寸相匹配, 默认设置为和主屏幕相同的比例值, 会自动缩放retina 屏幕
@property (nonatomic, assign) CGFloat imageScale;

/// 是否自动对压缩格式的数据进行填充, 当使用`setCompletionBlockWithSuccess:failure:` 这个方法时候, 打开此选项会提高绘图的性能,它允许在后台构建位图, 默认为YES
@property (nonatomic, assign) BOOL automaticallyInflatesResponseImage;

@end


/// 序列化委托给第一个返回`responseObjectForResponse:data:error:` 这个方法的对象, 这样有利于一个serializer序列化多个服务器的响应
@interface JBCompoundResponseSerializer : JBHTTPResponseSerializer

/// 序列化数组
@property (readonly, nonatomic, copy) NSArray <id<JBURLResponseSerialization>> *responseSerializers;

/// 创建并返回由指定的响应序列化程序组成的复合序列化的程序<每个响应的serializer必须是ResponseSerializer的子类,并且对`-validateResponse:data:error:`这个方法做出响应>
+ (instancetype)compoundSerializerWithResponseSerializer:(NSArray <id<JBURLResponseSerialization>> *)responseSerializers;

@end

/// 响应错误
FOUNDATION_EXPORT NSString * const JBURLResponseSerializationErrorDomain;

/// 包含该与错误相关联的操作的响应数据
FOUNDATION_EXPORT NSString * const JBNetworkingOperationFailingURLResponseErrorKey;

/// 包含与错误相关联的操作的响应NSData数据
FOUNDATION_EXPORT NSString * const JBNetworkingOperationFailingURLResponseDataErrorKey;







