//
//  Demuxer.m
//  TsDemuxer
//
//  Created by iSmicro on 2020/9/21.
//  Copyright © 2020 iSmicro. All rights reserved.
//

#import "Demuxer.h"
#import "ts.h"

@interface NSError (Demuxer)
+ (NSError *) errorWithCode:(NSInteger)code msg:(NSString *)msg;
@end

@implementation NSError (Demuxer)
+ (NSError *) errorWithCode:(NSInteger)code msg:(NSString *)msg {
    NSError *error = [[NSError alloc]initWithDomain:@"Demuxer Error" code:code userInfo:@{NSLocalizedDescriptionKey : msg}];
    return error;
}
@end

static double const UndefinedFPS = -1.0;

@implementation Demuxer

+ (void) demuxLocalTsFiles:(NSArray<NSURL *> *) tsURLs dir:(NSString *)dir handler:(void (^)(NSURL *, NSURL *, NSError *)) handler {

    // 参数校验 0
    if (tsURLs.count <= 0) {
        handler(nil, nil, [NSError errorWithCode:1 msg:@"参数错误"]);
        return;
    }
    // 参数校验 1
    [tsURLs enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj.absoluteString.lowercaseString containsString:@".ts"]) {
            handler(nil, nil, [NSError errorWithCode:1 msg:@"ts 文件格式错误"]);
            return;
        }
    }];

    // demux
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(queue, ^(void) {

            int demuxStatus = 0;
            // TS 解封包存储路径
            NSURL *cacheTsDirURL = [NSURL fileURLWithPath:dir];
            double video_fps = UndefinedFPS;

            ts::demuxer demuxer;
            demuxer.parse_only = false;
            demuxer.es_parse = false;
            demuxer.dump = 0;
            demuxer.av_only = false;
            demuxer.channel = 0;
            demuxer.pes_output = false;
            demuxer.prefix = [[[NSProcessInfo processInfo] globallyUniqueString] UTF8String];
            demuxer.dst = [[cacheTsDirURL path] cStringUsingEncoding:[NSString defaultCStringEncoding]];

            for (int i = 0; i < tsURLs.count; i ++) {
                demuxStatus += demuxer.demux_file([[tsURLs[i] path] UTF8String], &video_fps);
            }

            NSString *fileName = [NSString stringWithFormat:@"%s",demuxer.prefix.c_str()];
            NSString *audioType = [NSString stringWithFormat:@"%s",demuxer.type()];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                // demux success
                if (demuxStatus == 0) {

                    NSString *audioFileName = [NSString stringWithFormat:@"%@%@",fileName, audioType];
                    NSString *audioPath = [cacheTsDirURL.path stringByAppendingPathComponent:audioFileName];
                    NSURL *returnAudioURL = [NSURL fileURLWithPath:audioPath];

                    NSURL *returnVideoURL = nil;
                    if (video_fps != UndefinedFPS) {
                        NSString *videoFileName = [NSString stringWithFormat:@"%@h264",fileName];
                        NSString *videoPath = [cacheTsDirURL.path stringByAppendingPathComponent:videoFileName];
                        returnVideoURL = [NSURL fileURLWithPath:videoPath];
                    }

                    handler(returnAudioURL, returnVideoURL, [NSError errorWithCode:0 msg:@"SUCCESS"]);
                }
                else {
                    handler(nil, nil, [NSError errorWithCode:2 msg:@"ts 解封包失败"]);
                }

                [tsURLs enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [[NSFileManager defaultManager] removeItemAtURL:obj error:nil];
                }];
            });
        });
}

@end
