//
//  JBURLResponseSerialization.m
//  JBNetworking
//
//  Created by philia on 2017/9/27.
//  Copyright © 2017年 philia. All rights reserved.
//

#import "JBURLResponseSerialization.h"

#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

NSString * const JBURLResponseSerializationErrorDomain = @"JBURLResponseSerializationErrorDomain";

NSString * const JBNetworkingOperationFailingURLResponseErrorKey = @"JBNetworkingOperationFailingURLResponseErrorKey";

NSString * const JBNetworkingOperationFailingURLResponseDataErrorKey = @"JBNetworkingOperationFailingURLResponseDataErrorKey";


/// 根据底层的错误返回错误
static NSError * JBErrorWithUnderlyingError(NSError *error, NSError *underlyingError) {
    if (!error) {
        return underlyingError;
    }
    
    if (!underlyingError || error.userInfo[NSUnderlyingErrorKey]) {
        return error;
    }
    
    NSMutableDictionary *mutableUserInfo = error.userInfo.mutableCopy;
    mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
    
    return [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:mutableUserInfo];
}


/// 发生的错误在域名内,并且否包含有错误码
static BOOL JBErrorOrUnderlyingErrorHasCodeInDomain(NSError *error, NSInteger code, NSString *domain) {
    
    if ([error.domain isEqualToString:domain] && error.code == code) {
        return YES;
    } else if (error.userInfo[NSUnderlyingErrorKey]) {
        /// 递归判断底层的错误, 如果错误不匹配就返回NO
        return JBErrorOrUnderlyingErrorHasCodeInDomain(error.userInfo[NSUnderlyingErrorKey], code, domain);
    }
    return NO;
}

/// 在JSON对象中移除为Null的值<递归遍历>
static id JBJSONObjectByRemovingKeysWithNullValues(id JSONObject, NSJSONReadingOptions readingOptions) {
    // 把数组里面的字典遍历出来
    if ([JSONObject isKindOfClass:[NSArray class]]) {
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:[JSONObject count]];
        for (id value in JSONObject) {
            [mutableArray addObject:JBJSONObjectByRemovingKeysWithNullValues(value, readingOptions)];
        }
        /// 根据readingOptions条件判断是否返回可变的或者不可变
        return (readingOptions & NSJSONReadingMutableContainers) ? mutableArray : [NSArray arrayWithArray:mutableArray];
    }
    
    else if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:JSONObject];
        
        for (id <NSCopying> key in [JSONObject allKeys]) {
            id value = JSONObject[key];
            if (!value || [value isEqual:[NSNull null]]) {
                [mutableDictionary removeObjectForKey:key];
            } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                // 再次递归遍历
                mutableDictionary[key] = JBJSONObjectByRemovingKeysWithNullValues(value, readingOptions);
            }
        }
        return (readingOptions & NSJSONReadingMutableContainers) ? mutableDictionary : [NSDictionary dictionaryWithDictionary:mutableDictionary];
    }
    return JSONObject;
}


@implementation JBHTTPResponseSerializer 

+ (instancetype)serializer {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.stringEncoding = NSUTF8StringEncoding;
    
    self.acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    self.acceptableContentTypes = nil;
    
    return self;
}

- (BOOL)validateResponse:(NSHTTPURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    
    BOOL responseIsValid = YES;
    NSError *validationError = nil;
 
    // 1. 是正常的HTTP响应
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        // 2.设置了响应的类型, 并且得到响应体的类型与设置的类型不匹配
        if (self.acceptableContentTypes && ![self.acceptableContentTypes containsObject:[response MIMEType]]) {
            // 3. 有数据,并且能获得响应的URL 
            if (data.length && response.URL) {
                
                // 错误描述
                NSMutableDictionary *mutableUserInfo = [@{NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"呵呵,骚年,这种请求格式我们默认不支持呀,哈哈哈哈: content-type: %@", @"JBNetworking", nil), [response MIMEType]], NSURLErrorFailingURLErrorKey: [response URL], JBNetworkingOperationFailingURLResponseErrorKey: response} mutableCopy];
                if (data) {
                    mutableUserInfo[JBNetworkingOperationFailingURLResponseDataErrorKey] = data;
                }
                
                validationError = JBErrorWithUnderlyingError([NSError errorWithDomain:JBURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:mutableUserInfo], validationError);
                
            }
            responseIsValid = NO;
        }
        
        // 2.2 有数据并且响应码不正常
        if (self.acceptableStatusCodes && [self.acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode] && response.URL) {
            NSMutableDictionary *mutableUserInfo = [@{NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ (%ld)", @"JBNetworking", nil), [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], response.statusCode], NSURLErrorFailingURLErrorKey: response.URL, JBNetworkingOperationFailingURLResponseErrorKey: response} mutableCopy];
            
            if (data) {
                mutableUserInfo[JBNetworkingOperationFailingURLResponseDataErrorKey] = data;
            }
            validationError = JBErrorWithUnderlyingError([NSError errorWithDomain:JBURLResponseSerializationErrorDomain code:NSURLErrorBadServerResponse userInfo:mutableUserInfo], validationError);
            
            responseIsValid = NO;
        }
    }
    
    if (error && !responseIsValid) {
        *error = validationError;
    }
    
    return responseIsValid;
}

#pragma mark - JBURLResponseSerialization
- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    
    [self validateResponse:(NSHTTPURLResponse *)response data:data error:error];
    
    return data;
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.acceptableStatusCodes = [decoder decodeObjectOfClass:[NSIndexSet class] forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
    self.acceptableContentTypes = [decoder decodeObjectOfClass:[NSIndexSet class] forKey:NSStringFromSelector(@selector(acceptableContentTypes))];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.acceptableStatusCodes forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
    [coder encodeObject:self.acceptableContentTypes forKey:NSStringFromSelector(@selector(acceptableContentTypes))];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    JBHTTPResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    
    serializer.acceptableContentTypes = [self.acceptableContentTypes copyWithZone:zone];
    serializer.acceptableStatusCodes = [self.acceptableStatusCodes copyWithZone:zone];
    
    return serializer;
}

@end


#pragma mark - 最重要的JSON解析
@implementation JBJSONResponseSerializer

+ (instancetype)serializer {
    // NSJSONReadingMutableContainers  指定数组和字典作为返回值
    return [self serializerWithReadingOptions:0];
}

+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions {
    JBJSONResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;
    
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", nil];
    
    return self;
}

#pragma mark - JBURLResponseSerialization
- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    // 1.如果评估失败
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        // 2.域名内有错误(码)
        if (!error || JBErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, JBURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    
    id responseObject = nil;
    NSError *serializationError = nil;
    
    // 返回单个空间的解决方法，这不被NSJSONSerialization解释为有效的输入。
    BOOL isSpace = [data isEqualToData:[NSData dataWithBytes:" " length:1]];
    if (data.length > 0 && !isSpace) {
        responseObject = [NSJSONSerialization JSONObjectWithData:data options:self.readingOptions error:&serializationError];
    } else {
        return nil;
    }
    
    if (self.removesKeysWithNullValues && responseObject) {
        responseObject = JBJSONObjectByRemovingKeysWithNullValues(responseObject, self.readingOptions);
    } else {
        return nil;
    }
    
    return responseObject;
}


#pragma mark - 各种烦人的协议
- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.readingOptions = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(readingOptions))] unsignedIntegerValue];
    self.removesKeysWithNullValues = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(removesKeysWithNullValues))] boolValue];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    
    [coder encodeObject:@(self.readingOptions) forKey:NSStringFromSelector(@selector(readingOptions))];
    [coder encodeObject:@(self.removesKeysWithNullValues) forKey:NSStringFromSelector(@selector(setRemovesKeysWithNullValues:))];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    JBJSONResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.readingOptions = self.readingOptions;
    serializer.removesKeysWithNullValues = self.removesKeysWithNullValues;
    
    return serializer;
}

@end

#pragma mark JBXMLParserResponseSerializer
@implementation JBXMLParserResponseSerializer 

+ (instancetype)serializer {
    JBXMLParserResponseSerializer *serializer = [[self alloc] init];
    
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.acceptableContentTypes = [[NSSet alloc] initWithObjects:@"application/xml", @"text/xml", nil];
    
    return self;
}

#pragma mark - 重写JBURLResponseSerialization
- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    // 1.评估失败
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        // 2. 域名出错
        if (!error || JBErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, JBURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    
    return [[NSXMLParser alloc] initWithData:data];
}

@end


@implementation JBPropertyListResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithFormat:NSPropertyListXMLFormat_v1_0 readOptions:0];
}

+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format readOptions:(NSPropertyListReadOptions)readOptions {
    
    JBPropertyListResponseSerializer *serializer = [[self alloc] init];
    serializer.format = format;
    serializer.readOptions = readOptions;
    
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.acceptableContentTypes = [NSSet setWithObjects:@"application/x-plist", nil];
    
    return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        if (!error || JBErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, JBURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    
    id responseObject = nil;
    NSError *serializationError = nil;
    
    if (data) {
        responseObject = [NSPropertyListSerialization propertyListWithData:data options:self.readOptions format:NULL error:&serializationError];
    }
    
    if (error) {
        *error = JBErrorWithUnderlyingError(serializationError, *error);
    }
    
    return responseObject;
}


#pragma mark - NSSecureCoding
- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.format = (NSPropertyListFormat)[[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(format))] unsignedIntegerValue];
    self.readOptions = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(readOptions))] unsignedIntegerValue];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.format) forKey:NSStringFromSelector(@selector(format))];
    [coder encodeObject:@(self.readOptions) forKey:NSStringFromSelector(@selector(readOptions))];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    JBPropertyListResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.format = self.format;
    serializer.readOptions = self.readOptions;
    
    return serializer;
}

@end

#pragma mark - JBImageResponseSerializer
#if TARGET_OS_IOS
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

/// UIImage分类
@interface UIImage (JBNetworkingSafeImageLoading)

+ (UIImage *)jb_safeImageWithData:(NSData *)data;

@end

static NSLock *imageLock = nil;

@implementation UIImage (JBNetworkingSafeImageLoading)

+ (UIImage *)jb_safeImageWithData:(NSData *)data {
    UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageLock = [[NSLock alloc] init];
    });
    
    [imageLock lock];
    image = [UIImage imageWithData:data];
    [imageLock unlock];
    
    return image;
}

@end

/// 通过data和尺寸返回图片的函数
static UIImage * JBImageWithDataAtScale(NSData *data, CGFloat scale) {
    UIImage *image = [UIImage jb_safeImageWithData:data];
    if (image.images) {
        return image;
    }
    return [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
}

/// 从响应体中获取图片的方法
static UIImage * JBInflatedImageFromResposeWithDataAtScale(NSHTTPURLResponse *response, NSData *data, CGFloat scale) {
    if (!data || data.length == 0) {
        return nil;
    }
    
    CGImageRef imageRef = NULL;
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    if ([response.MIMEType isEqualToString:@"image/png"]) {
        imageRef = CGImageCreateWithPNGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault); // 默认渲染
    } else if ([response.MIMEType isEqualToString:@"image/jpeg"]) {
        imageRef = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
    
        if (imageRef) {
            CGColorSpaceRef imageColorSpace = CGImageGetColorSpace(imageRef);
            CGColorSpaceModel imageColorSpaceModel = CGColorSpaceGetModel(imageColorSpace);
            
            // 如果provider没有妥善处理CMYK那么用JBImageWithDataAtScale这个函数
            if (imageColorSpaceModel == kCGColorSpaceModelCMYK) {
                CGImageRelease(imageRef);
                imageRef = NULL;
            }
        }
    }
    
    CGDataProviderRelease(dataProvider);
    
    UIImage *image = JBImageWithDataAtScale(data, scale);
    if (!imageRef) {
        if (image.images || !image) {
            return image;
        }
        
        imageRef = CGImageCreateCopy(image.CGImage);
        if (!imageRef) {
            return nil;
        }
    }
    
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    
    if (width * height > 1024 * 1024 || bitsPerComponent > 8) {
        CGImageRelease(imageRef);
        return image;
    }
    
    /// CGImageGetBytesPerRow()在 iOS5中计算不正确, 所以使用位图上下文创建
    size_t bytesPerRow = 0;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    if (colorSpaceModel == kCGColorSpaceModelRGB) {
        uint32_t alpha = (bitmapInfo & kCGBitmapAlphaInfoMask);
        
        if (alpha == kCGImageAlphaNone) {
            bitmapInfo &= ~kCGBitmapAlphaInfoMask;
            bitmapInfo |= kCGImageAlphaNoneSkipFirst;
        } else if (!(alpha == kCGImageAlphaNoneSkipFirst || alpha == kCGImageAlphaNoneSkipLast)) {
            bitmapInfo &= ~kCGBitmapAlphaInfoMask;
            bitmapInfo |= kCGImageAlphaPremultipliedFirst;
        }
    }
    
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    
    if (!context) {
        CGImageRelease(imageRef);
        
        return image;
    }
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGImageRef inflatedImageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    
    
    UIImage *inflatedImage = [[UIImage alloc] initWithCGImage:inflatedImageRef scale:scale orientation:image.imageOrientation];
    
    
    CGImageRelease(inflatedImageRef);
    CGImageRelease(imageRef);
    
    return inflatedImage;
}

#endif

#pragma mark - JBImageResponseSerializer
@implementation JBImageResponseSerializer 

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.acceptableContentTypes = [NSSet setWithObjects:@"image/tiff", @"image/jpeg", @"image/gif", @"image/png", @"image/ico", @"image/x-icon", @"image/bmp", @"image/x-bmp", @"image/x-xbitmap", nil];
    
    self.imageScale = [UIScreen mainScreen].scale;
    self.automaticallyInflatesResponseImage = YES;
    
    return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        if (!error || JBErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, JBURLResponseSerializationErrorDomain)) {
            return nil;
        } 
    }
    
    if (self.automaticallyInflatesResponseImage) {
        return JBInflatedImageFromResposeWithDataAtScale((NSHTTPURLResponse *)response, data, self.imageScale);
    } else {
        return JBImageWithDataAtScale(data, self.imageScale);
    }
    
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    NSNumber *imageScale = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(imageScale))];
    self.imageScale = [imageScale doubleValue];
    self.automaticallyInflatesResponseImage = [decoder decodeBoolForKey:NSStringFromSelector(@selector(automaticallyInflatesResponseImage))];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.imageScale) forKey:NSStringFromSelector(@selector(imageScale))];
    [coder encodeBool:self.automaticallyInflatesResponseImage forKey:NSStringFromSelector(@selector(automaticallyInflatesResponseImage))];
}


- (instancetype)copyWithZone:(NSZone *)zone {
    JBImageResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    
    serializer.imageScale = self.imageScale;
    serializer.automaticallyInflatesResponseImage = self.automaticallyInflatesResponseImage;
    return serializer;
}

@end

#pragma mark - JBCompoundResponseSerializer
@interface JBCompoundResponseSerializer()
@property (readwrite, nonatomic, copy) NSArray <id<JBURLResponseSerialization>> *responseSerializers;
@end

@implementation JBCompoundResponseSerializer

+ (instancetype)compoundSerializerWithResponseSerializer:(NSArray<id<JBURLResponseSerialization>> *)responseSerializers {
    JBCompoundResponseSerializer *serializer = [[self alloc] init];
    serializer.responseSerializers = responseSerializers;
    
    return serializer;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error {
    for (id <JBURLResponseSerialization> serializer in self.responseSerializers) {
        if (![serializer isKindOfClass:[JBHTTPResponseSerializer class]]) {
            continue;
        }
        
        NSError *serializerError = nil;
        id responseObject = [serializer responseObjectForResponse:response data:data error:&serializerError];
        if (responseObject) {
            *error = JBErrorWithUnderlyingError(serializerError, *error);
        }
        return responseObject;
    }
    
    return [super responseObjectForResponse:response data:data error:error];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.responseSerializers = [decoder decodeObjectOfClass:[NSArray class] forKey:NSStringFromSelector(@selector(responseSerializers))];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.responseSerializers forKey:NSStringFromSelector(@selector(responseSerializers))];
}


- (instancetype)copyWithZone:(NSZone *)zone {
    JBCompoundResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.responseSerializers = self.responseSerializers;
    
    return serializer;
}

@end






