#!/bin/bash

# Telegram YouTube Video Downloader Bot Installer
# Fixed URL Encoding Version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logo
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "=============================================="
    echo "   YOUTUBE DOWNLOADER BOT - FIXED VERSION"
    echo "        URL ENCODING ISSUE RESOLVED"
    echo "=============================================="
    echo -e "${NC}"
}

# Print functions
print_info() { echo -e "${CYAN}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }

# Install dependencies
install_deps() {
    print_info "Installing system dependencies..."
    
    if command -v apt &> /dev/null; then
        apt update -y
        apt install -y python3 python3-pip python3-venv git ffmpeg curl wget nano jq
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano jq
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano jq
    else
        print_error "Unsupported OS"
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# Install Python packages
install_python_packages() {
    print_info "Installing Python packages..."
    
    pip3 install --upgrade pip
    pip3 install python-telegram-bot==20.7 yt-dlp requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/youtube_bot
    mkdir -p /opt/youtube_bot
    cd /opt/youtube_bot
    
    # Create necessary directories
    mkdir -p downloads temp logs
    
    print_success "Directory created: /opt/youtube_bot"
}

# Create fixed bot.py script
create_bot_script() {
    print_info "Creating fixed bot script..."
    
    cat > /opt/youtube_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Fixed YouTube Downloader Bot with URL Encoding Fix
"""

import os
import json
import logging
import subprocess
import re
import asyncio
import urllib.parse
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from typing import Dict, List, Tuple

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('/opt/youtube_bot/logs/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Bot token
BOT_TOKEN = os.getenv('BOT_TOKEN', '')

# User data storage
user_sessions: Dict[int, Dict] = {}

def is_youtube_url(url: str) -> bool:
    """Check if URL is from YouTube"""
    patterns = [
        r'(https?://)?(www\.)?youtube\.com/watch\?v=',
        r'(https?://)?(www\.)?youtu\.be/',
        r'(https?://)?(www\.)?youtube\.com/shorts/',
        r'(https?://)?(www\.)?youtube\.com/embed/',
        r'(https?://)?(www\.)?youtube\.com/live/'
    ]
    
    for pattern in patterns:
        if re.search(pattern, url.lower()):
            return True
    return False

def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size"""
    if bytes_size == 0:
        return "N/A"
    
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.1f} TB"

def get_video_formats(url: str) -> Tuple[List[Dict], Dict]:
    """
    Get available formats for a YouTube video
    Returns: (formats_list, video_info)
    """
    try:
        # Clean and validate URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        # Get video info using yt-dlp
        cmd = [
            'yt-dlp',
            '--dump-json',
            '--no-warnings',
            '--skip-download',
            url
        ]
        
        logger.info(f"Getting formats for URL: {url[:100]}...")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            logger.error(f"Failed to get video info: {result.stderr[:200]}")
            return [], {}
        
        video_info = json.loads(result.stdout)
        
        # Get available formats
        formats = []
        for fmt in video_info.get('formats', []):
            format_id = fmt.get('format_id', '')
            ext = fmt.get('ext', '')
            vcodec = fmt.get('vcodec', 'none')
            acodec = fmt.get('acodec', 'none')
            
            # Skip storyboard formats
            if 'storyboard' in str(format_id).lower():
                continue
            
            # Skip m3u8 formats
            if fmt.get('protocol', '') == 'm3u8_native':
                continue
            
            # Calculate file size
            filesize = fmt.get('filesize')
            filesize_approx = fmt.get('filesize_approx')
            
            if filesize:
                size = filesize
            elif filesize_approx:
                size = filesize_approx
            else:
                # Estimate size based on duration and bitrate
                duration = video_info.get('duration', 0)
                tbr = fmt.get('tbr', 0)
                if duration and tbr:
                    size = (tbr * 1000 * duration) / 8  # Convert to bytes
                else:
                    size = 0
            
            # Determine format type
            if vcodec != 'none' and acodec != 'none':
                format_type = 'video+audio'
                icon = '🎬'
            elif vcodec != 'none':
                format_type = 'video'
                icon = '📹'
            elif acodec != 'none':
                format_type = 'audio'
                icon = '🎵'
            else:
                format_type = 'unknown'
                icon = '📄'
            
            # Get resolution
            height = fmt.get('height')
            width = fmt.get('width')
            
            if height and width:
                resolution = f"{width}x{height}"
            elif height:
                resolution = f"{height}p"
            else:
                resolution = fmt.get('format_note', 'Audio')
            
            # Get fps
            fps = fmt.get('fps')
            fps_str = f"{int(fps)}fps" if fps else ""
            
            # Get bitrate
            abr = fmt.get('abr', 0)
            vbr = fmt.get('vbr', 0)
            tbr = fmt.get('tbr', 0)
            
            bitrate = ''
            if abr:
                bitrate = f"{abr}k"
            elif vbr:
                bitrate = f"{vbr}k"
            elif tbr:
                bitrate = f"{tbr}k"
            
            format_data = {
                'id': format_id,
                'ext': ext,
                'resolution': resolution,
                'fps': fps_str,
                'vcodec': vcodec,
                'acodec': acodec,
                'size': size,
                'type': format_type,
                'icon': icon,
                'format_note': fmt.get('format_note', ''),
                'bitrate': bitrate,
                'height': height,
                'width': width
            }
            
            formats.append(format_data)
        
        # Remove duplicates (keep highest quality)
        unique_formats = {}
        for fmt in formats:
            key = (fmt['resolution'], fmt['ext'], fmt['type'])
            if key not in unique_formats or fmt['size'] > unique_formats[key]['size']:
                unique_formats[key] = fmt
        
        formats = list(unique_formats.values())
        
        # Sort formats by quality
        def sort_key(fmt):
            # Priority: video+audio > video > audio
            type_score = {'video+audio': 0, 'video': 1, 'audio': 2}.get(fmt['type'], 3)
            height = fmt.get('height', 0) or 0
            width = fmt.get('width', 0) or 0
            size = fmt.get('size', 0) or 0
            return (type_score, -height, -width, -size)
        
        formats.sort(key=sort_key)
        
        return formats, video_info
        
    except Exception as e:
        logger.error(f"Error getting formats: {str(e)}")
        return [], {}

def create_quality_keyboard(formats: List[Dict], url: str, page: int = 0) -> InlineKeyboardMarkup:
    """Create keyboard with quality options"""
    items_per_page = 8
    start_idx = page * items_per_page
    end_idx = start_idx + items_per_page
    
    keyboard = []
    
    # Encode URL for callback data
    encoded_url = urllib.parse.quote(url, safe='')
    
    # Add formats for current page
    for fmt in formats[start_idx:end_idx]:
        format_id = fmt['id']
        resolution = fmt['resolution']
        ext = fmt['ext'].upper()
        size = format_size(fmt['size'])
        icon = fmt['icon']
        format_type = fmt['type']
        bitrate = fmt['bitrate']
        
        # Create button text
        button_text = f"{icon} {resolution}"
        
        if bitrate and format_type == 'audio':
            button_text += f" ({bitrate})"
        
        button_text += f" - {size}"
        
        if fmt['fps'] and format_type != 'audio':
            button_text += f" [{fmt['fps']}]"
        
        # Truncate if too long
        if len(button_text) > 40:
            button_text = button_text[:37] + "..."
        
        callback_data = f"dl:{format_id}:{encoded_url}"
        keyboard.append([InlineKeyboardButton(button_text, callback_data=callback_data)])
    
    # Add navigation buttons if needed
    nav_buttons = []
    
    if page > 0:
        nav_buttons.append(InlineKeyboardButton("⬅️ قبلی", callback_data=f"nav:{page-1}:{encoded_url}"))
    
    if end_idx < len(formats):
        nav_buttons.append(InlineKeyboardButton("بعدی ➡️", callback_data=f"nav:{page+1}:{encoded_url}"))
    
    if nav_buttons:
        keyboard.append(nav_buttons)
    
    # Add quick action buttons
    keyboard.append([
        InlineKeyboardButton("🎯 بهترین کیفیت", callback_data=f"best:{encoded_url}"),
        InlineKeyboardButton("🎵 فقط صدا", callback_data=f"audio:{encoded_url}")
    ])
    
    keyboard.append([InlineKeyboardButton("❌ انصراف", callback_data="cancel")])
    
    return InlineKeyboardMarkup(keyboard)

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
🎬 *ربات دانلود یوتیوب*

👋 سلام {user.first_name}!

من می‌توانم ویدیوهای یوتیوب را با *انتخاب کیفیت* دانلود کنم.

✨ *ویژگی‌ها:*
• دانلود با *کیفیت‌های مختلف*
• نمایش *حجم فایل* قبل از دانلود
• استخراج صدا
• سریع و قابل اعتماد

📌 *نحوه استفاده:*
1. لینک یوتیوب را برای من بفرستید
2. من کیفیت‌های موجود را نشان می‌دهم
3. کیفیت مورد نظر را انتخاب کنید
4. فایل را دریافت کنید

🔗 *لینک‌های پشتیبانی شده:*
• youtube.com/watch?v=...
• youtu.be/...
• youtube.com/shorts/...
• youtube.com/live/...

⚡ *دستورات:*
/start - نمایش این پیام
/help - راهنمایی
/formats <لینک> - نمایش فرمت‌ها

📊 *انتخاب کیفیت:*
من *تمام فرمت‌های موجود* را با *حجم فایل* نشان می‌دهم.
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *راهنمای ربات یوتیوب*

📌 *نحوه دانلود:*
1. یک لینک یوتیوب بفرستید
2. من فرمت‌های موجود را بررسی می‌کنم
3. کیفیت را از لیست انتخاب کنید
4. منتظر دانلود بمانید
5. فایل را دریافت کنید

🎯 *انواع فرمت:*
• 🎬 ویدیو+صدا (کامل)
• 📹 فقط ویدیو
• 🎵 فقط صدا

📊 *حجم فایل:*
همه فرمت‌ها حجم تخمینی را نشان می‌دهند

⚡ *دستورات سریع:*
/formats <لینک> - نمایش فرمت‌ها مستقیم
/audio <لینک> - دانلود بهترین صدا
/video <لینک> - دانلود بهترین ویدیو

⚠️ *محدودیت‌ها:*
• حداکثر حجم فایل: ۲ گیگابایت (محدودیت تلگرام)
• ویدیوهای طولانی ممکن است زمان‌بر باشند
• برخی فرمت‌ها ممکن است ناموفق باشند

💡 *نکات:*
• 720p/480p برای تعادل کیفیت/حجم مناسب‌اند
• MP4 برای بهترین سازگاری
• MP3 برای صدا
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def formats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /formats command"""
    if not context.args:
        await update.message.reply_text("❌ استفاده: /formats <لینک-یوتیوب>")
        return
    
    url = ' '.join(context.args)
    await show_formats(update, context, url)

async def show_formats(update: Update, context: ContextTypes.DEFAULT_TYPE, url: str):
    """Show available formats for a URL"""
    if not is_youtube_url(url):
        await update.message.reply_text("❌ لطفاً یک لینک معتبر یوتیوب ارسال کنید")
        return
    
    message = None
    if update.message:
        message = await update.message.reply_text("🔍 در حال بررسی فرمت‌های ویدیو...")
    elif update.callback_query:
        message = await update.callback_query.message.reply_text("🔍 در حال بررسی فرمت‌های ویدیو...")
    
    try:
        # Clean URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        formats, video_info = get_video_formats(url)
        
        if not formats:
            await message.edit_text("❌ فرمتی پیدا نشد یا لینک نامعتبر است")
            return
        
        # Store formats in user session
        user_id = update.effective_user.id
        user_sessions[user_id] = {
            'url': url,
            'formats': formats,
            'video_info': video_info
        }
        
        # Create info message
        title = video_info.get('title', 'بدون عنوان')[:100]
        duration = video_info.get('duration', 0)
        duration_str = f"{duration // 60}:{duration % 60:02d}" if duration else "نامشخص"
        uploader = video_info.get('uploader', 'نامشخص')[:50]
        view_count = video_info.get('view_count', 0)
        
        info_text = f"""
📺 *بررسی ویدیو کامل شد!*

🎬 *عنوان:* {title}
👤 *آپلودکننده:* {uploader}
👁️ *تعداد بازدید:* {view_count:,}
⏱️ *مدت زمان:* {duration_str}
🔢 *تعداد فرمت‌ها:* {len(formats)}

*کیفیت مورد نظر را انتخاب کنید:*
        """
        
        # Create keyboard
        keyboard = create_quality_keyboard(formats, url, 0)
        
        await message.edit_text(info_text, parse_mode='Markdown', reply_markup=keyboard)
        
    except Exception as e:
        logger.error(f"خطا در show_formats: {e}")
        await message.edit_text(f"❌ خطا در بررسی ویدیو: {str(e)[:200]}")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_youtube_url(url):
        await message.reply_text("❌ لطفاً یک لینک معتبر یوتیوب ارسال کنید")
        return
    
    await show_formats(update, context, url)

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    callback_data = query.data
    user_id = query.from_user.id
    
    logger.info(f"Callback received: {callback_data[:100]}")
    
    # Handle navigation
    if callback_data.startswith('nav:'):
        try:
            _, page_str, encoded_url = callback_data.split(':', 2)
            page = int(page_str)
            url = urllib.parse.unquote(encoded_url)
            
            # Get formats
            formats, _ = get_video_formats(url)
            
            if not formats:
                await query.edit_message_text("❌ فرمت‌ها پیدا نشدند")
                return
            
            keyboard = create_quality_keyboard(formats, url, page)
            await query.edit_message_reply_markup(reply_markup=keyboard)
        except Exception as e:
            logger.error(f"Navigation error: {e}")
            await query.edit_message_text("❌ خطا در ناوبری")
        return
    
    # Handle format selection
    elif callback_data.startswith('dl:'):
        try:
            _, format_id, encoded_url = callback_data.split(':', 2)
            url = urllib.parse.unquote(encoded_url)
            await download_format(query, context, url, format_id)
        except Exception as e:
            logger.error(f"Format selection error: {e}")
            await query.edit_message_text("❌ خطا در انتخاب فرمت")
        return
    
    # Handle best quality
    elif callback_data.startswith('best:'):
        try:
            _, encoded_url = callback_data.split(':', 1)
            url = urllib.parse.unquote(encoded_url)
            await download_best(query, context, url)
        except Exception as e:
            logger.error(f"Best quality error: {e}")
            await query.edit_message_text("❌ خطا در دانلود بهترین کیفیت")
        return
    
    # Handle audio only
    elif callback_data.startswith('audio:'):
        try:
            _, encoded_url = callback_data.split(':', 1)
            url = urllib.parse.unquote(encoded_url)
            await download_audio(query, context, url)
        except Exception as e:
            logger.error(f"Audio download error: {e}")
            await query.edit_message_text("❌ خطا در دانلود صدا")
        return
    
    # Handle cancel
    elif callback_data == 'cancel':
        await query.edit_message_text("❌ دانلغو شد")
        return

async def download_format(query, context, url: str, format_id: str):
    """Download specific format"""
    user_id = query.from_user.id
    message = query.message
    
    # Update message
    await message.edit_text(f"⬇️ در حال دانلود فرمت {format_id}...")
    
    try:
        # Create download directory
        os.makedirs('/opt/youtube_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Download using yt-dlp
        cmd = [
            'yt-dlp',
            '-f', format_id,
            '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--no-check-certificate',
            '--socket-timeout', '30',
            '--retries', '3',
            url
        ]
        
        logger.info(f"Downloading {url[:100]}... with format {format_id}")
        
        # Start download
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:500]
            logger.error(f"Download failed: {error_msg}")
            
            # Try alternative method
            if "is not a valid URL" in error_msg:
                await message.edit_text("🔄 در حال امتحان روش جایگزین...")
                # Try with different format selection
                cmd = [
                    'yt-dlp',
                    '-f', f'best[format_id={format_id}]',
                    '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
                    '--no-warnings',
                    url
                ]
                
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await process.communicate()
                
                if process.returncode != 0:
                    await message.edit_text(f"❌ دانلود ناموفق: {stderr.decode()[:200]}")
                    return
        
        # Find downloaded file
        downloaded_files = []
        for file in os.listdir('/opt/youtube_bot/downloads'):
            if file.startswith(filename):
                file_path = f'/opt/youtube_bot/downloads/{file}'
                if os.path.exists(file_path):
                    downloaded_files.append(file_path)
        
        if not downloaded_files:
            # Check for any file with similar pattern
            for file in os.listdir('/opt/youtube_bot/downloads'):
                if str(user_id) in file:
                    file_path = f'/opt/youtube_bot/downloads/{file}'
                    downloaded_files.append(file_path)
        
        if not downloaded_files:
            await message.edit_text("❌ فایل پس از دانلود پیدا نشد")
            return
        
        file_path = downloaded_files[0]
        file_size = os.path.getsize(file_path)
        
        # Check file size (Telegram limit: 2GB)
        if file_size > 2000 * 1024 * 1024:
            await message.edit_text("❌ حجم فایل بیشتر از 2GB است (محدودیت تلگرام)")
            os.remove(file_path)
            return
        
        # Send file based on type
        with open(file_path, 'rb') as f:
            if file_path.endswith(('.mp3', '.m4a', '.flac', '.wav', '.ogg')):
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=f"✅ دانلود شده ({format_size(file_size)})",
                    parse_mode='Markdown'
                )
            elif file_path.endswith(('.mp4', '.mkv', '.webm', '.mov', '.avi')):
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ دانلود شده ({format_size(file_size)})",
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            else:
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=f"✅ دانلود شده ({format_size(file_size)})",
                    parse_mode='Markdown'
                )
        
        # Cleanup
        try:
            os.remove(file_path)
        except:
            pass
        
        await message.edit_text(f"✅ دانلود کامل شد! ({format_size(file_size)})")
        
    except Exception as e:
        logger.error(f"Download error: {str(e)}")
        await message.edit_text(f"❌ خطا در دانلود: {str(e)[:200]}")

async def download_best(query, context, url: str):
    """Download best video+audio"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎯 در حال دانلود بهترین کیفیت...")
    
    try:
        # Create download directory
        os.makedirs('/opt/youtube_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Download best video+audio
        cmd = [
            'yt-dlp',
            '-f', 'bestvideo+bestaudio/best',
            '--merge-output-format', 'mp4',
            '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            '--no-check-certificate',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:500]
            logger.error(f"Best quality download failed: {error_msg}")
            
            # Try simple best format
            cmd = [
                'yt-dlp',
                '-f', 'best[ext=mp4]',
                '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
                '--no-warnings',
                url
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                await message.edit_text(f"❌ دانلود ناموفق: {stderr.decode()[:200]}")
                return
        
        # Send file
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp4'
        if not os.path.exists(file_path):
            # Find any file with that prefix
            for file in os.listdir('/opt/youtube_bot/downloads'):
                if file.startswith(filename):
                    file_path = f'/opt/youtube_bot/downloads/{file}'
                    break
        
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            # Check file size
            if file_size > 2000 * 1024 * 1024:
                await message.edit_text("❌ حجم فایل بیشتر از 2GB است")
                os.remove(file_path)
                return
            
            with open(file_path, 'rb') as f:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ بهترین کیفیت دانلود شده ({format_size(file_size)})",
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ بهترین کیفیت دانلود شد! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ فایل پس از دانلود پیدا نشد")
        
    except Exception as e:
        logger.error(f"Best quality download error: {str(e)}")
        await message.edit_text(f"❌ خطا در دانلود: {str(e)[:200]}")

async def download_audio(query, context, url: str):
    """Download audio only"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎵 در حال دانلود صدا...")
    
    try:
        # Create download directory
        os.makedirs('/opt/youtube_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        # Download best audio
        cmd = [
            'yt-dlp',
            '-f', 'bestaudio',
            '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
            '--extract-audio',
            '--audio-format', 'mp3',
            '--no-warnings',
            '--add-metadata',
            '--embed-thumbnail',
            '--no-check-certificate',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:500]
            logger.error(f"Audio download failed: {error_msg}")
            
            # Try m4a format
            cmd = [
                'yt-dlp',
                '-f', 'bestaudio[ext=m4a]',
                '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
                '--no-warnings',
                url
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                await message.edit_text(f"❌ دانلود ناموفق: {stderr.decode()[:200]}")
                return
        
        # Send file
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp3'
        if not os.path.exists(file_path):
            # Find any audio file
            for ext in ['.mp3', '.m4a', '.opus', '.webm']:
                test_path = f'/opt/youtube_bot/downloads/{filename}{ext}'
                if os.path.exists(test_path):
                    file_path = test_path
                    break
        
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            with open(file_path, 'rb') as f:
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=f"✅ صدا دانلود شده ({format_size(file_size)})",
                    parse_mode='Markdown'
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ صدا دانلود شد! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ فایل پس از دانلود پیدا نشد")
        
    except Exception as e:
        logger.error(f"Audio download error: {str(e)}")
        await message.edit_text(f"❌ خطا در دانلود: {str(e)[:200]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        if update.callback_query:
            await update.callback_query.message.reply_text("⚠️ خطایی رخ داد. لطفاً دوباره تلاش کنید.")
        elif update.message:
            await update.message.reply_text("⚠️ خطایی رخ داد. لطفاً دوباره تلاش کنید.")
    except:
        pass

def main():
    """Main function"""
    if not BOT_TOKEN:
        print("❌ خطا: BOT_TOKEN تنظیم نشده است")
        print("لطفاً توکن ربات خود را در /opt/youtube_bot/.env اضافه کنید")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("formats", formats_command))
    app.add_handler(CommandHandler("audio", download_audio_command))
    app.add_handler(CommandHandler("video", download_video_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 ربات یوتیوب در حال راه‌اندازی...")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("✅ ربات آماده دریافت لینک‌های یوتیوب است")
    
    app.run_polling()

async def download_audio_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command handler for /audio"""
    if not context.args:
        await update.message.reply_text("❌ استفاده: /audio <لینک-یوتیوب>")
        return
    
    url = ' '.join(context.args)
    if not is_youtube_url(url):
        await update.message.reply_text("❌ لینک یوتیوب معتبر نیست")
        return
    
    msg = await update.message.reply_text("🎵 در حال دانلود صدا...")
    await download_audio_simple(update, context, url, msg)

async def download_video_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command handler for /video"""
    if not context.args:
        await update.message.reply_text("❌ استفاده: /video <لینک-یوتیوب>")
        return
    
    url = ' '.join(context.args)
    if not is_youtube_url(url):
        await update.message.reply_text("❌ لینک یوتیوب معتبر نیست")
        return
    
    msg = await update.message.reply_text("🎬 در حال دانلود ویدیو...")
    await download_video_simple(update, context, url, msg)

async def download_audio_simple(update, context, url: str, message):
    """Simple audio download for command"""
    user_id = update.effective_user.id
    
    try:
        os.makedirs('/opt/youtube_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        cmd = [
            'yt-dlp',
            '-f', 'bestaudio',
            '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
            '--extract-audio',
            '--audio-format', 'mp3',
            '--no-warnings',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            await message.edit_text(f"❌ خطا: {stderr.decode()[:200]}")
            return
        
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp3'
        if os.path.exists(file_path):
            with open(file_path, 'rb') as f:
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption="✅ دانلود شده"
                )
            os.remove(file_path)
            await message.edit_text("✅ دانلود کامل شد!")
        else:
            await message.edit_text("❌ فایل پیدا نشد")
            
    except Exception as e:
        logger.error(f"Simple audio error: {e}")
        await message.edit_text(f"❌ خطا: {str(e)[:200]}")

async def download_video_simple(update, context, url: str, message):
    """Simple video download for command"""
    user_id = update.effective_user.id
    
    try:
        os.makedirs('/opt/youtube_bot/downloads', exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{user_id}"
        
        cmd = [
            'yt-dlp',
            '-f', 'best[ext=mp4]',
            '-o', f'/opt/youtube_bot/downloads/{filename}.%(ext)s',
            '--no-warnings',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            await message.edit_text(f"❌ خطا: {stderr.decode()[:200]}")
            return
        
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp4'
        if os.path.exists(file_path):
            with open(file_path, 'rb') as f:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption="✅ دانلود شده",
                    supports_streaming=True
                )
            os.remove(file_path)
            await message.edit_text("✅ دانلود کامل شد!")
        else:
            await message.edit_text("❌ فایل پیدا نشد")
            
    except Exception as e:
        logger.error(f"Simple video error: {e}")
        await message.edit_text(f"❌ خطا: {str(e)[:200]}")

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/youtube_bot/bot.py
    print_success "Fixed bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/youtube_bot/.env.example << ENVEOF
# توکن ربات تلگرام از @BotFather
# مثال: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# حداکثر حجم فایل (بایت) - محدودیت تلگرام 2GB است
MAX_FILE_SIZE=2000000000

# شناسه کاربران مجاز (با کاما جدا شود)
# خالی بگذارید تا همه کاربران مجاز باشند
ALLOWED_USERS=

# پوشه دانلود
DOWNLOAD_DIR=/opt/youtube_bot/downloads

# پوشه موقت
TEMP_DIR=/tmp/youtube_bot
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/youtube-bot.service << SERVICEEOF
[Unit]
Description=YouTube Downloader Bot with Quality Selection
After=network.target
Requires=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/youtube_bot
EnvironmentFile=/opt/youtube_bot/.env
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 /opt/youtube_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security
NoNewPrivileges=true
ReadWritePaths=/opt/youtube_bot/downloads /opt/youtube_bot/logs /tmp
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICEEOF
    
    systemctl daemon-reload
    print_success "Service file created"
}

# Create control script
create_control_script() {
    print_info "Creating control script..."
    
    cat > /usr/local/bin/youtube-bot << CONTROLEOF
#!/bin/bash

case "\$1" in
    start)
        if [ ! -f /opt/youtube_bot/.env ]; then
            echo "❌ لطفاً ابتدا ربات را تنظیم کنید: youtube-bot setup"
            exit 1
        fi
        
        systemctl start youtube-bot
        echo "✅ ربات یوتیوب شروع شد"
        echo "📋 وضعیت: youtube-bot status"
        echo "📊 لاگ‌ها: youtube-bot logs"
        ;;
    stop)
        systemctl stop youtube-bot
        echo "🛑 ربات متوقف شد"
        ;;
    restart)
        systemctl restart youtube-bot
        echo "🔄 ربات راه‌اندازی مجدد شد"
        ;;
    status)
        systemctl status youtube-bot --no-pager -l
        ;;
    logs)
        if [ "\$2" = "-f" ]; then
            journalctl -u youtube-bot -f
        else
            journalctl -u youtube-bot --no-pager -n 50
        fi
        ;;
    setup)
        echo "📝 تنظیم ربات یوتیوب..."
        
        if [ ! -f /opt/youtube_bot/.env ]; then
            cp /opt/youtube_bot/.env.example /opt/youtube_bot/.env
            echo ""
            echo "📋 فایل .env در /opt/youtube_bot/.env ایجاد شد"
            echo ""
            echo "🔑 مراحل دریافت توکن ربات:"
            echo "1. تلگرام را باز کنید"
            echo "2. @BotFather را جستجو کنید"
            echo "3. /newbot را ارسال کنید"
            echo "4. نام ربات را انتخاب کنید (مثال: YouTube Downloader)"
            echo "5. یوزرنیم را انتخاب کنید (باید با 'bot' پایان یابد، مثال: MyYouTubeDLBot)"
            echo "6. توکن را کپی کنید (مشابه: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)"
            echo ""
            echo "✏️ ویرایش فایل تنظیمات:"
            echo "   nano /opt/youtube_bot/.env"
            echo ""
            echo "📁 یا از دستور زیر استفاده کنید:"
            echo "   youtube-bot config"
        else
            echo "✅ فایل .env از قبل وجود دارد"
            echo "✏️ ویرایش: youtube-bot config"
        fi
        ;;
    config)
        nano /opt/youtube_bot/.env
        ;;
    update)
        echo "🔄 آپدیت ربات یوتیوب..."
        echo "آپدیت پکیج‌های پایتون..."
        pip3 install --upgrade pip python-telegram-bot yt-dlp
        
        echo "آپدیت yt-dlp..."
        yt-dlp -U
        
        echo "راه‌اندازی مجدد ربات..."
        systemctl restart youtube-bot
        
        echo "✅ ربات با موفقیت آپدیت شد"
        ;;
    test)
        echo "🧪 تست نصب ربات یوتیوب..."
        echo ""
        
        echo "1. تست پکیج‌های پایتون..."
        python3 -c "import telegram, yt_dlp, json; print('✅ پکیج‌های پایتون OK')"
        
        echo ""
        echo "2. تست yt-dlp..."
        yt-dlp --version
        
        echo ""
        echo "3. تست FFmpeg..."
        ffmpeg -version | head -1
        
        echo ""
        echo "4. تست سرویس..."
        systemctl is-active youtube-bot &>/dev/null && echo "✅ سرویس در حال اجراست" || echo "⚠️ سرویس در حال اجرا نیست"
        
        echo ""
        echo "5. تست دایرکتوری‌ها..."
        ls -la /opt/youtube_bot/
        
        echo ""
        echo "✅ تمام تست‌ها تکمیل شد"
        ;;
    clean)
        echo "🧹 پاک کردن دانلودها..."
        rm -rf /opt/youtube_bot/downloads/*
        rm -rf /opt/youtube_bot/temp/*
        echo "✅ دانلودها و فایل‌های موقت پاک شدند"
        ;;
    backup)
        echo "💾 تهیه نسخه پشتیبان از ربات..."
        BACKUP_DIR="/opt/youtube_bot_backup_\$(date +%Y%m%d_%H%M%S)"
        mkdir -p "\$BACKUP_DIR"
        cp -r /opt/youtube_bot/* "\$BACKUP_DIR"/
        echo "✅ نسخه پشتیبان ایجاد شد: \$BACKUP_DIR"
        ;;
    stats)
        echo "📊 آمار ربات:"
        echo ""
        echo "پوشه دانلود:"
        du -sh /opt/youtube_bot/downloads
        echo ""
        echo "سایز فایل لاگ:"
        du -sh /opt/youtube_bot/logs/* 2>/dev/null || echo "هنوز لاگی وجود ندارد"
        echo ""
        echo "وضعیت سرویس:"
        systemctl status youtube-bot --no-pager -l | grep -A 3 "Active:"
        ;;
    *)
        echo "🤖 ربات دانلودکننده یوتیوب پیشرفته"
        echo "نسخه: 2.1 | رفع مشکل URL"
        echo ""
        echo "استفاده: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean|backup|stats}"
        echo ""
        echo "دستورات:"
        echo "  start     - شروع ربات"
        echo "  stop      - توقف ربات"
        echo "  restart   - راه‌اندازی مجدد"
        echo "  status    - بررسی وضعیت"
        echo "  logs      - مشاهده لاگ‌ها (برای دنبال کردن -f اضافه کنید)"
        echo "  setup     - تنظیم اولیه"
        echo "  config    - ویرایش تنظیمات"
        echo "  update    - آپدیت ربات و پکیج‌ها"
        echo "  test      - اجرای تست‌ها"
        echo "  clean     - پاک کردن دانلودها"
        echo "  backup    - تهیه نسخه پشتیبان"
        echo "  stats     - نمایش آمار"
        echo ""
        echo "راه‌اندازی سریع:"
        echo "  1. youtube-bot setup"
        echo "  2. youtube-bot config  (توکن خود را اضافه کنید)"
        echo "  3. youtube-bot start"
        echo "  4. youtube-bot logs -f"
        echo ""
        echo "ویژگی‌ها:"
        echo "  • انتخاب کیفیت با نمایش حجم فایل"
        echo "  • پشتیبانی از فرمت‌های مختلف"
        echo "  • استخراج صدا"
        echo "  • بهترین کیفیت به صورت خودکار"
        echo "  • رفع مشکل encoding URL"
        ;;
esac
CONTROLEOF
    
    chmod +x /usr/local/bin/youtube-bot
    print_success "Control script created"
}

# Create a test script
create_test_script() {
    print_info "Creating test script..."
    
    cat > /opt/youtube_bot/test_url.py << 'TESTEOF'
#!/usr/bin/env python3
"""
Test URL encoding/decoding
"""

import urllib.parse

# Test URL
test_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

print("Testing URL encoding...")
print(f"Original URL: {test_url}")

encoded = urllib.parse.quote(test_url, safe='')
print(f"Encoded URL: {encoded}")

decoded = urllib.parse.unquote(encoded)
print(f"Decoded URL: {decoded}")

print(f"\nMatch: {test_url == decoded}")
TESTEOF
    
    chmod +x /opt/youtube_bot/test_url.py
    print_success "Test script created"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}=============================================="
    echo "   نصب ربات یوتیوب با موفقیت کامل شد!"
    echo "=============================================="
    echo -e "${NC}"
    
    echo -e "\n${YELLOW}🚀 مراحل بعدی:${NC}"
    echo "1. ${GREEN}تنظیم ربات:${NC}"
    echo "   youtube-bot setup"
    echo ""
    echo "2. ${GREEN}دریافت توکن ربات از @BotFather:${NC}"
    echo "   • تلگرام را باز کنید"
    echo "   • @BotFather را جستجو کنید"
    echo "   • /newbot را ارسال کنید"
    echo "   • نام و یوزرنیم را انتخاب کنید"
    echo "   • توکن را کپی کنید (مثال: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)"
    echo ""
    echo "3. ${GREEN}تنظیم ربات:${NC}"
    echo "   youtube-bot config"
    echo "   • توکن خود را در فایل اضافه کنید"
    echo ""
    echo "4. ${GREEN}تست نصب:${NC}"
    echo "   youtube-bot test"
    echo ""
    echo "5. ${GREEN}شروع ربات:${NC}"
    echo "   youtube-bot start"
    echo ""
    echo "6. ${GREEN}مشاهده لاگ‌ها:${NC}"
    echo "   youtube-bot logs -f"
    echo ""
    
    echo -e "${YELLOW}🎬 ویژگی‌های جدید:${NC}"
    echo "• ${GREEN}رفع مشکل URL${NC} - مشکل 'https is not a valid URL' حل شد"
    echo "• ${GREEN}انتخاب کیفیت${NC} - نمایش تمام فرمت‌ها با حجم"
    echo "• ${GREEN}صفحه‌بندی${NC} - برای ویدیوهای با فرمت‌های زیاد"
    echo "• ${GREEN}رابط فارسی${NC} - پیام‌ها به فارسی"
    echo "• ${GREEN}خطایابی پیشرفته${NC} - لاگ‌گیری کامل"
    echo ""
    
    echo -e "${YELLOW}⚡ راه‌اندازی سریع:${NC}"
    echo "1. لینک یوتیوب را برای ربات بفرستید"
    echo "2. ربات تمام کیفیت‌های موجود را با حجم نشان می‌دهد"
    echo "3. کیفیت مورد نظر را انتخاب کنید"
    echo "4. ربات فایل را دانلود و ارسال می‌کند"
    echo ""
    
    echo -e "${GREEN}✅ ربات آماده است! با 'youtube-bot start' شروع کنید${NC}"
    echo ""
    
    echo -e "${CYAN}📞 پشتیبانی:${NC}"
    echo "مشاهده لاگ: youtube-bot logs"
    echo "بررسی وضعیت: youtube-bot status"
    echo "آپدیت ربات: youtube-bot update"
    echo "پاک کردن دانلودها: youtube-bot clean"
}

# Main installation
main() {
    show_logo
    print_info "شروع نصب ربات یوتیوب..."
    
    install_deps
    install_python_packages
    create_bot_dir
    create_bot_script
    create_env_file
    create_service_file
    create_control_script
    create_test_script
    
    # Create log files
    touch /opt/youtube_bot/logs/bot.log
    chmod 666 /opt/youtube_bot/logs/bot.log
    
    show_completion
}

# Run installation
main "$@"
