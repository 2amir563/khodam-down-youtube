


دستور نصب ربات یوتیوب در سرور
۱. دستور نصب اصلی:
bash
```
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-youtube/main/install.sh)
```

۲. اگر خطا داد، این دستور جایگزین را امتحان کنید:
bash
wget -qO- https://raw.githubusercontent.com/2amir563/khodam-down-youtube/main/install.sh | bash
۳. یا به صورت مرحله‌ای:
bash
# مرحله ۱: دانلود اسکریپت
curl -O https://raw.githubusercontent.com/2amir563/khodam-down-youtube/main/install.sh

# مرحله ۲: دادن مجوز اجرا
chmod +x install.sh

# مرحله ۳: اجرای نصب
./install.sh
مراحل کامل راه‌اندازی:
مرحله ۱: نصب ربات
در سرور لینوکس دستور زیر را اجرا کنید:

bash
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-youtube/main/install.sh)
مرحله ۲: تنظیم توکن ربات تلگرام
پس از اتمام نصب:

bash
# اجرای تنظیم اولیه
```
youtube-bot setup
```
این دستور یک فایل .env ایجاد می‌کند. حالا باید توکن ربات تلگرام خود را در آن قرار دهید:
```
nano /opt/youtube_bot/.env
```


bash
# ویرایش فایل تنظیمات
```
youtube-bot config
```

در فایل ویرایشگر باز شده، توکن ربات خود را اضافه کنید:

text
BOT_TOKEN=توکن_ربات_شما_اینجا
مرحله ۳: گرفتن توکن ربات تلگرام:
اگر توکن ندارید:

در تلگرام به @BotFather بروید

/newbot را ارسال کنید

نام ربات را انتخاب کنید (مثلاً: YouTube Downloader)

یوزرنیم ربات را انتخاب کنید (مثلاً: MyYouTubeDLBot)

توکن را کپی کنید (مثلاً: 6123456789:AAEfghIJKlmNOPqRsTUVwxyZ-abcdefg)

مرحله ۴: تست نصب
bash
# تست پکیج‌ها
youtube-bot test

# تست اتصال به یوتیوب
youtube-bot yt-test
مرحله ۵: شروع ربات
bash
# شروع ربات
```
youtube-bot start
```


# بررسی وضعیت
youtube-bot status

# مشاهده لاگ‌ها
youtube-bot logs
مرحله ۶: استفاده از ربات
۱. در تلگرام، ربات خود را پیدا کنید
۲. روی /start کلیک کنید
۳. یک لینک یوتیوب ارسال کنید، مثال:

text
https://www.youtube.com/watch?v=dQw4w9WgXcQ
۴. گزینه مورد نظر را انتخاب کنید
۵. کیفیت/فرمت را انتخاب کنید
۶. منتظر دانلود بمانید

دستورات مدیریتی:
شروع و توقف:
bash
youtube-bot start     # شروع ربات
youtube-bot stop      # توقف ربات
youtube-bot restart   # راه‌اندازی مجدد
youtube-bot status    # وضعیت ربات
مشاهده لاگ‌ها:
bash
youtube-bot logs           # لاگ اصلی
youtube-bot logs error     # لاگ خطاها
مدیریت تنظیمات:
bash
youtube-bot setup     # تنظیم اولیه
youtube-bot config    # ویرایش تنظیمات
youtube-bot update    # آپدیت ربات
عیب‌یابی:
bash
youtube-bot test      # تست نصب
youtube-bot yt-test   # تست یوتیوب
youtube-bot fix       # رفع مشکلات
اطلاعات فنی:
مسیرهای مهم:
text
/opt/youtube_bot/              # پوشه اصلی ربات
/opt/youtube_bot/.env          # فایل تنظیمات
/opt/youtube_bot/logs/         # لاگ‌ها
/opt/youtube_bot/downloads/    # دانلودها (موقت)
بررسی نصب:
bash
# بررسی سرویس
systemctl status youtube-bot

# بررسی فرآیند
ps aux | grep youtube-bot

# بررسی اتصال
netstat -tulpn | grep python
اگر مشکل داشتید:
۱. خطای "command not found":
bash
# بارگذاری مجدد PATH
source ~/.bashrc

# یا اجرای مستقیم
/usr/local/bin/youtube-bot start
۲. خطای توکن:
bash
# بررسی توکن
cat /opt/youtube_bot/.env

# تنظیم مجدد
youtube-bot config
۳. خطای دانلود یوتیوب:
bash
# آپدیت yt-dlp
youtube-bot update

# رفع مشکلات
youtube-bot fix
۴. ربات شروع نمی‌شود:
bash
# بررسی خطاها
journalctl -u youtube-bot -f

# راه‌اندازی مجدد
systemctl daemon-reload
youtube-bot restart
مثال کامل از یک جلسه:
bash
# اتصال به سرور
ssh root@your-server-ip

# نصب
bash <(curl -s https://raw.githubusercontent.com/2amir563/khodam-down-youtube/main/install.sh)

# تنظیم توکن
youtube-bot setup
youtube-bot config  # توکن را اضافه کنید

# شروع
youtube-bot start

# بررسی
youtube-bot status
youtube-bot logs
نکات مهم:
۱. ربات باید ۲۴/۷ اجرا باشد تا پیام‌ها را دریافت کند
۲. هر ربات توکن مخصوص خود دارد (متفاوت از ربات توییتر)
۳. حداکثر حجم فایل: ویدیو ۲GB، صدا ۵۰۰MB
۴. لاگ‌ها را چک کنید اگر مشکلی پیش آمد

تست سریع پس از نصب:
bash
# ۱. بررسی سرویس
youtube-bot status

# ۲. ارسال دستور start به ربات در تلگرام
# ۳. ارسال یک لینک یوتیوب
# ۴. انتخاب گزینه و دانلود
حالا دستور نصب را در سرور اجرا کنید و مراحل را دنبال نمایید.




Start the Bot:

bash
youtube-bot start
Check Status:

bash
youtube-bot status
youtube-bot logs
Usage
Commands in Telegram:
/start - Show welcome message

/help - Show help guide

/audio <url> - Download audio only

/video <url> - Download video (best quality)

/formats <url> - Show all available formats

Direct Usage:
Send any YouTube URL to the bot

Choose "Download Video" or "Download Audio"

Select quality/format

Wait for download

Receive your file

Management
Control Commands:
bash
# Start/Stop
youtube-bot start
youtube-bot stop
youtube-bot restart

# Status & Logs
youtube-bot status
youtube-bot logs
youtube-bot logs error

# Configuration
youtube-bot setup    # Initial setup
youtube-bot config   # Edit config
youtube-bot update   # Update software
youtube-bot test     # Run tests
youtube-bot yt-test  # Test YouTube download
youtube-bot fix      # Fix issues
File Locations
Bot directory: /opt/youtube_bot

Configuration: /opt/youtube_bot/.env

Downloads: /opt/youtube_bot/downloads/

Logs: /opt/youtube_bot/logs/

Supported Formats
Video:
144p, 240p, 360p, 480p

720p (HD), 1080p (Full HD)

1440p (2K), 2160p (4K)

Best available quality

Audio:
MP3: 128kbps, 192kbps, 320kbps

M4A (AAC)

Best audio quality

Troubleshooting
Bot not responding:

bash
youtube-bot restart
youtube-bot logs
Download fails:

bash
youtube-bot fix
youtube-bot update
YouTube blocks downloads:

bash
youtube-bot update  # U
