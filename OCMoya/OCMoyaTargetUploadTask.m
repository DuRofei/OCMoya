//
//  OCMUploadTask.m
//  OCMoya
//
//  Created by keith on 26/03/2017.
//  Copyright © 2017 keithxi. All rights reserved.
//

#import "OCMoyaTargetUploadTask.h"



@interface OCMoyaTargetUploadMultipartTask()

@property (nonatomic,strong) NSArray<OCMUploadFormProvider *>  *providers;


@end

@implementation OCMoyaTargetUploadMultipartTask

- (instancetype)initWithFormProviders:(NSArray<OCMUploadFormProvider *> *)providers; {
    
    if(self = [super init]){
        self.providers = providers;
    }
    
    return self;
    
}


@end

@interface OCMUploadFormProvider()

@property (nonatomic,copy) NSString *name;

@property (nonatomic,copy) NSString *fileName;

@property (nonatomic,copy) NSString *mimeType;

@end

@implementation OCMUploadFormProvider

- (instancetype)initWithName:(NSString *)name
                    fileName:(NSString *)fileName
                    mimeType:(NSString *)mimeType{

    if (self = [super init]) {
        self.name = name;
        self.fileName = fileName;
        self.mimeType = mimeType;
    }
    
    return self;
}


@end

@interface OCMUploadFormDataProvider()

@property (nonatomic,strong) NSData *data;

@end

@implementation OCMUploadFormDataProvider

- (instancetype)initWithData:(NSData *)data
                        name:(NSString *)name
                    fileName:(NSString *)fileName
                    mimeType:(NSString *)mimeType{

    if (self = [super initWithName:name fileName:fileName mimeType:mimeType]) {
        self.data = data;
    }
    
    return self;
}

@end

@interface OCMUploadFormFileProvider()

@property (nonatomic,strong) NSURL *file;

@end

@implementation OCMUploadFormFileProvider

- (instancetype)initWithFile:(NSURL *)url
                        name:(NSString *)name
                    fileName:(NSString *)fileName
                    mimeType:(NSString *)mimeType{

    if (self = [super initWithName:name fileName:fileName mimeType:mimeType]) {
        self.file = url;
    }
    
    return self;
}

@end

@interface OCMUploadFormStreamProvider()

@property (nonatomic,strong) NSInputStream *inputStream;

@property (nonatomic,assign) uint64_t offset;

@end

@implementation OCMUploadFormStreamProvider

- (instancetype)initWithSream:(NSInputStream *)inputStream
                       offset:(uint64_t)offset
                         name:(NSString *)name
                     fileName:(NSString *)fileName
                     mimeType:(NSString *)mimeType{

    if (self = [super initWithName:name fileName:fileName mimeType:mimeType]) {
        self.inputStream = inputStream;
        self.offset = offset;
    }
    
    return self;
}

@end
