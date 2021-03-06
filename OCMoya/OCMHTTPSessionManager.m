//
//  OCMHTTPManager.m
//  OCMoya
//
//  Created by KeithXi on 05/04/2017.
//  Copyright © 2017 keithxi. All rights reserved.
//

#import "OCMHTTPSessionManager.h"



@interface OCMHTTPSessionManager()


@end

@implementation OCMHTTPSessionManager
@dynamic responseSerializer;


- (void)setResponseSerializer:(OCMHTTPResponseSerializer <OCMURLResponseSerialization> *)responseSerializer {
    NSParameterAssert(responseSerializer);
    
    [super setResponseSerializer:responseSerializer];
}

- (OCMDataRequestTask *)dataTaskWithRequest:(NSURLRequest *)request
                                     target:(nullable id<OCMTargetType>)target
                             uploadProgress:(nullable progressClosure) uploadProgressClosure
                           downloadProgress:(nullable progressClosure) downloadProgressClosure
                                 completion:(nullable completionClosure)completionClosure{
    
    __block OCMDataRequestTask *task = [[OCMDataRequestTask alloc] initWithSession:self.session requestTask:nil orginalTarget:target];
    NSURLSessionDataTask * sessiontask =
    [self sessionDataTaskWithRequest:request uploadProgress:uploadProgressClosure downloadProgress:downloadProgressClosure completion:^(BOOL success, id  _Nullable responseObject, OCMoyaError * _Nullable error) {
        task.endTime = CFAbsoluteTimeGetCurrent();
        if (completionClosure) {
            
            //check if need retry first
            if (self.retrier && [self.retrier respondsToSelector:@selector(shouldretryRequest:target:manager:response:error:completion:)]) {
                [self retryWithTask:task error:error target:target response:responseObject uploadProgress:uploadProgressClosure downloadProgress:downloadProgressClosure completion:completionClosure];
                return;
            }
            
            if (!success) {//network or service error

                completionClosure(NO,nil,error);

            }else{ //request success, your custom service error

                completionClosure(success,responseObject,error);
            }
                
        }
        
        
    }];
    
    [task updateTask:sessiontask];
    
    if (self.startRequestsImmediately) {
        [task resume];
    }
    return task;
}


- (NSURLSessionDataTask *)sessionDataTaskWithRequest:(NSURLRequest *)request
                                      uploadProgress:(nullable progressClosure) uploadProgressClosure
                                    downloadProgress:(nullable progressClosure) downloadProgressClosure
                                          completion:(nullable completionClosure)completionClosure
{
    
    __block NSURLSessionDataTask *dataTask = nil;
    
    dataTask = [self dataTaskWithRequest:request
                          uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                              
                              if (!uploadProgressClosure) {
                                  return;
                              }
                              OCMProgressResponse  *progress = [[OCMProgressResponse alloc] initWith:uploadProgress];
                              uploadProgressClosure(progress);
                          }
                
                        downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                            
                            if (!downloadProgressClosure) {
                                return ;
                            }
                            OCMProgressResponse *progress = [[OCMProgressResponse alloc] initWith:downloadProgress];
                            downloadProgressClosure(progress);
                        }
                
                       completionHandler:^(NSURLResponse * _Nonnull urlresponse, id  _Nullable responseObject, NSError * _Nullable error) {
                           
                           NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlresponse;
                           OCMResponse *response = [[OCMResponse alloc] initWithStatusCode:httpResponse.statusCode
                                                                                      data:responseObject
                                                                                   request:request
                                                                                  response:httpResponse];
                           
                           if (completionClosure) {
                               if (error) {
                                   OCMoyaError *aError = [[OCMoyaError alloc] initWithError:error
                                                                                  errorType:OCMoyaErrorTypeHttpFailed
                                                                                   response:response];
                                   completionClosure(NO,response,aError);
                               }else{
                                   completionClosure(YES,response,nil);
                               }
                           }
                           
                           
                       }];
    
    return dataTask;
}

#pragma mark - upload

- (OCMDataRequestTask *)uploadDataTaskWithRequest:(NSURLRequest *)request
                                           target:(nullable id<OCMTargetType>)target
                                   uploadProgress:(nullable progressClosure) uploadProgressClosure
                                       completion:(nullable completionClosure)completionClosure{
    
    __block OCMDataRequestTask *task = [[OCMDataRequestTask alloc] initWithSession:self.session requestTask:nil orginalTarget:target];
    NSURLSessionDataTask * sessiontask =
    [self uploadDatatask:request progress:uploadProgressClosure completion:^(BOOL success, id  _Nullable responseObject, OCMoyaError * _Nullable error) {
        task.endTime = CFAbsoluteTimeGetCurrent();
        if (completionClosure) {
            completionClosure(success,responseObject,error);
        }
    }];
    
    [task updateTask:sessiontask];
    
    if (self.startRequestsImmediately) {
        [task resume];
    }
    return task;
}

- (NSURLSessionDataTask *)uploadDatatask:(NSURLRequest *)request
                                progress:(nullable progressClosure)uploadProgressClosure
                              completion:(nullable completionClosure)completionClosure
{
    
    __block NSURLSessionDataTask *task = [self uploadTaskWithStreamedRequest:request progress:^(NSProgress * _Nonnull uploadProgress) {
        if (!uploadProgressClosure) {
            return;
        }
        OCMProgressResponse  *progress = [[OCMProgressResponse alloc] initWith:uploadProgress];
        uploadProgressClosure(progress);
    } completionHandler:^(NSURLResponse * _Nonnull urlresponse, id  _Nullable responseObject, NSError * _Nullable error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlresponse;
        OCMResponse *response = [[OCMResponse alloc] initWithStatusCode:httpResponse.statusCode
                                                                   data:responseObject
                                                                request:request
                                                               response:httpResponse];
        if (completionClosure) {
            if (error) {
                OCMoyaError *aError = [[OCMoyaError alloc] initWithError:error
                                                               errorType:OCMoyaErrorTypeHttpFailed
                                                                response:response];
                completionClosure(NO,response,aError);
            }else{
                completionClosure(YES,response,nil);
            }
        }
        
    }];
    
    return task;
}

#pragma mark - retry a Failed Task

- (void)retryWithTask:(OCMRequestTask *)task
                error:(OCMoyaError *)error
               target:(id<OCMTargetType>)target
             response:(id)responseObj
       uploadProgress:(nullable progressClosure) uploadProgressClosure
     downloadProgress:(nullable progressClosure) downloadProgressClosure
           completion:(nullable completionClosure)completionClosure{
    
    if (![self.retrier respondsToSelector:@selector(shouldretryRequest:target:manager:response:error:completion:)]) {
        if (error) {
            completionClosure(NO,nil,error);
        }else{
            completionClosure(YES,responseObj,nil);
        }
        
        return;
    }
    
    __weak typeof(self) weakself = self;
    [self.retrier shouldretryRequest:task
                              target:target
                             manager:self
                            response:responseObj
                               error:error
                          completion:^(BOOL shouldRetry, NSTimeInterval timeDelay) {
                              __strong typeof(self) strongself = weakself;
                              if (!shouldRetry) {
                                  if (error) {
                                      completionClosure(NO,nil,error);
                                  }else{
                                      completionClosure(YES,responseObj,nil);
                                  }
                                  return;
                              }
                              
                              void(^excute)() = ^{
                                  
                                  NSURLSessionTask  * newDataTask = [strongself
                                                                     convertTask:task
                                                                     orginalTarget:target
                                                                     uploadProgress:uploadProgressClosure
                                                                     downloadProgress:downloadProgressClosure
                                                                     completion:^(BOOL success, id  _Nullable newresponseObject, OCMoyaError * _Nullable newerror) {
                                                                         
                                                                         //retry if need
                                                                         [strongself retryWithTask:task
                                                                                             error:newerror
                                                                                            target:target
                                                                                          response:newresponseObject uploadProgress:uploadProgressClosure downloadProgress:downloadProgressClosure completion:completionClosure];
                                                                        
                                                                         task.endTime = CFAbsoluteTimeGetCurrent();
                                                                         
                                                                     }];
                                  

                                  [task updateTask:newDataTask];//update the session task
                                  [task increaseRertyCount];//increase the count
                                  [task resume];
                              };
                              
                              if(timeDelay>0){
                                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                      excute();
                                  });
                              }else{
                                  excute();
                              }
                              
                          }];
    
}

- (NSURLSessionTask *)convertTask:(OCMRequestTask *)orignalTask
                    orginalTarget:(id<OCMTargetType>)orignalTarget
                   uploadProgress:(nullable progressClosure) uploadProgressClosure
                 downloadProgress:(nullable progressClosure) downloadProgressClosure
                       completion:(nullable completionClosure)completionClosure{
    if(!orignalTask){
        return nil;
    };
    
    NSURLRequest *newrequest = nil;
    if ([self.taskConverter respondsToSelector:@selector(taskWithTask:target:)]) {
        NSURLSessionTask *newtask = [self.taskConverter taskWithTask:orignalTask.task target:orignalTarget];
        return newtask;
        
    }else{
        newrequest = [orignalTask.request copy];
    }
    
    NSURLSessionDataTask *task = [self sessionDataTaskWithRequest:newrequest
                                                   uploadProgress:uploadProgressClosure
                                                 downloadProgress:downloadProgressClosure
                                                       completion:completionClosure];
    return task;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    
    NSURLSessionConfiguration *configuration = [decoder decodeObjectOfClass:[NSURLSessionConfiguration class] forKey:@"sessionConfiguration"];
    if (!configuration) {
        NSString *configurationIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        if (configurationIdentifier) {
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1100)
            configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:configurationIdentifier];
#else
            configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:configurationIdentifier];
#endif
        }
    }
    
    self = [self initWithSessionConfiguration:configuration];
    if (!self) {
        return nil;
    }
    
    self.responseSerializer = [decoder decodeObjectOfClass:[AFHTTPResponseSerializer class] forKey:NSStringFromSelector(@selector(responseSerializer))];
    AFSecurityPolicy *decodedPolicy = [decoder decodeObjectOfClass:[AFSecurityPolicy class] forKey:NSStringFromSelector(@selector(securityPolicy))];
    if (decodedPolicy) {
        self.securityPolicy = decodedPolicy;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    if ([self.session.configuration conformsToProtocol:@protocol(NSCoding)]) {
        [coder encodeObject:self.session.configuration forKey:@"sessionConfiguration"];
    } else {
        [coder encodeObject:self.session.configuration.identifier forKey:@"identifier"];
    }
    [coder encodeObject:self.responseSerializer forKey:NSStringFromSelector(@selector(responseSerializer))];
    [coder encodeObject:self.securityPolicy forKey:NSStringFromSelector(@selector(securityPolicy))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    OCMHTTPSessionManager *HTTPClient = [[[self class] allocWithZone:zone] initWithSessionConfiguration:self.session.configuration];
    
    HTTPClient.responseSerializer = [self.responseSerializer copyWithZone:zone];
    HTTPClient.securityPolicy = [self.securityPolicy copyWithZone:zone];
    return HTTPClient;
}


@end
