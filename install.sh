#!/bin/bash

# Telegram YouTube Video Downloader Bot Installer
# Advanced Version with Quality Selection

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
    echo "   ADVANCED YOUTUBE DOWNLOADER BOT"
    echo "       WITH QUALITY SELECTION"
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
        apt install -y python3 python3-pip python3-venv git ffmpeg curl wget nano jq mediainfo
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano jq mediainfo
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano jq mediainfo
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
    pip3 install python-telegram-bot yt-dlp requests pillow
    
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

# Create advanced bot.py script with quality selection
create_bot_script() {
    print_info "Creating Advanced YouTube bot script..."
    
    cat > /opt/youtube_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Advanced Telegram YouTube Downloader Bot with Quality Selection
"""

import os
import json
import logging
import subprocess
import re
import asyncio
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

# User data storage (in production use a database)
user_sessions: Dict[int, Dict] = {}

def is_youtube_url(url: str) -> bool:
    """Check if URL is from YouTube"""
    patterns = [
        r'youtube\.com/watch\?v=',
        r'youtu\.be/',
        r'youtube\.com/shorts/',
        r'youtube\.com/embed/',
        r'youtube\.com/live/'
    ]
    
    url_lower = url.lower()
    for pattern in patterns:
        if re.search(pattern, url_lower):
            return True
    return False

def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size"""
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
        # Get video info using yt-dlp
        cmd = [
            'yt-dlp',
            '--dump-json',
            '--no-warnings',
            '--skip-download',
            url
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            logger.error(f"Failed to get video info: {result.stderr}")
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
            if 'storyboard' in format_id.lower():
                continue
            
            # Calculate file size
            filesize = fmt.get('filesize')
            filesize_approx = fmt.get('filesize_approx')
            
            if filesize:
                size = filesize
            elif filesize_approx:
                size = filesize_approx
            else:
                size = 0
            
            # Determine format type
            if vcodec != 'none' and acodec != 'none':
                format_type = 'video+audio'
            elif vcodec != 'none':
                format_type = 'video'
            elif acodec != 'none':
                format_type = 'audio'
            else:
                format_type = 'unknown'
            
            # Get resolution
            height = fmt.get('height', 0)
            width = fmt.get('width', 0)
            
            if height:
                resolution = f"{height}p"
                if width:
                    resolution = f"{width}x{height}"
            else:
                resolution = fmt.get('format_note', 'Audio')
            
            # Get fps
            fps = fmt.get('fps', 0)
            fps_str = f"{int(fps)}fps" if fps else ""
            
            # Get quality
            quality = fmt.get('quality', 0)
            
            format_data = {
                'id': format_id,
                'ext': ext,
                'resolution': resolution,
                'fps': fps_str,
                'vcodec': vcodec,
                'acodec': acodec,
                'size': size,
                'type': format_type,
                'format_note': fmt.get('format_note', ''),
                'quality': quality,
                'filesize': size
            }
            
            formats.append(format_data)
        
        # Sort formats
        formats.sort(key=lambda x: (
            0 if x['type'] == 'video+audio' else 
            1 if x['type'] == 'video' else 
            2 if x['type'] == 'audio' else 3,
            -x.get('height', 0) if isinstance(x.get('height'), (int, float)) else 0,
            -x.get('quality', 0)
        ))
        
        return formats, video_info
        
    except Exception as e:
        logger.error(f"Error getting formats: {e}")
        return [], {}

def create_quality_keyboard(formats: List[Dict], url: str, page: int = 0) -> InlineKeyboardMarkup:
    """Create keyboard with quality options"""
    items_per_page = 8
    start_idx = page * items_per_page
    end_idx = start_idx + items_per_page
    
    keyboard = []
    
    # Add formats for current page
    for fmt in formats[start_idx:end_idx]:
        format_id = fmt['id']
        resolution = fmt['resolution']
        ext = fmt['ext'].upper()
        size = format_size(fmt['size']) if fmt['size'] else "N/A"
        format_type = fmt['type']
        
        # Create button text
        if format_type == 'video+audio':
            icon = '🎬'
        elif format_type == 'video':
            icon = '📹'
        elif format_type == 'audio':
            icon = '🎵'
        else:
            icon = '📄'
        
        button_text = f"{icon} {resolution} ({ext}) - {size}"
        
        # Truncate if too long
        if len(button_text) > 50:
            button_text = button_text[:47] + "..."
        
        keyboard.append([InlineKeyboardButton(
            button_text,
            callback_data=f"dl:{format_id}:{url}:{page}"
        )])
    
    # Add navigation buttons if needed
    nav_buttons = []
    
    if page > 0:
        nav_buttons.append(InlineKeyboardButton("⬅️ Previous", callback_data=f"page:{page-1}:{url}"))
    
    if end_idx < len(formats):
        nav_buttons.append(InlineKeyboardButton("Next ➡️", callback_data=f"page:{page+1}:{url}"))
    
    if nav_buttons:
        keyboard.append(nav_buttons)
    
    # Add best quality options
    keyboard.append([
        InlineKeyboardButton("🎯 Best Video+Audio", callback_data=f"best:{url}"),
        InlineKeyboardButton("🎵 Best Audio Only", callback_data=f"audio:{url}")
    ])
    
    keyboard.append([InlineKeyboardButton("🔙 Cancel", callback_data="cancel")])
    
    return InlineKeyboardMarkup(keyboard)

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
🎬 *Advanced YouTube Downloader Bot*

👋 Hello {user.first_name}!

I can download videos from YouTube with *quality selection*.

✨ *Features:*
• Download in *multiple qualities*
• See *file sizes* before download
• Audio extraction
• Fast and reliable

📌 *How to use:*
1. Send me a YouTube link
2. I'll show available qualities
3. Select your preferred quality
4. Receive your file

🔗 *Supported URLs:*
• youtube.com/watch?v=...
• youtu.be/...
• youtube.com/shorts/...
• youtube.com/live/...

⚡ *Commands:*
/start - Show this message
/help - Help information
/formats <url> - Show formats directly

📊 *Quality Selection:*
I'll show you *all available formats* with their *file sizes*.
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *Advanced YouTube Bot Help*

📌 *How to download:*
1. Send a YouTube link
2. I'll analyze available formats
3. Choose quality from list
4. Wait for download
5. Receive your file

🎯 *Format Types:*
• 🎬 Video+Audio (complete)
• 📹 Video only
• 🎵 Audio only

📊 *File Sizes:*
All formats show estimated file size

⚡ *Quick Commands:*
/formats <url> - Show formats directly
/audio <url> - Download best audio
/video <url> - Download best video

⚠️ *Limits:*
• Max file size: 2GB (Telegram limit)
• Long videos may take time
• Some formats may fail

💡 *Tips:*
• 720p/480p for good quality/size balance
• MP4 for best compatibility
• MP3 for audio
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def formats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /formats command"""
    if not context.args:
        await update.message.reply_text("Usage: /formats <youtube-url>")
        return
    
    url = context.args[0]
    await show_formats(update, context, url)

async def show_formats(update: Update, context: ContextTypes.DEFAULT_TYPE, url: str):
    """Show available formats for a URL"""
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please provide a valid YouTube URL")
        return
    
    message = None
    if update.message:
        message = await update.message.reply_text("🔍 Analyzing video formats...")
    elif update.callback_query:
        message = await update.callback_query.message.reply_text("🔍 Analyzing video formats...")
    
    try:
        formats, video_info = get_video_formats(url)
        
        if not formats:
            await message.edit_text("❌ No formats found or invalid URL")
            return
        
        # Store formats in user session
        user_id = update.effective_user.id
        user_sessions[user_id] = {
            'url': url,
            'formats': formats,
            'video_info': video_info
        }
        
        # Create info message
        title = video_info.get('title', 'Unknown')
        duration = video_info.get('duration', 0)
        duration_str = f"{duration // 60}:{duration % 60:02d}" if duration else "Unknown"
        
        info_text = f"""
📺 *Video Analysis Complete!*

🎬 *Title:* {title[:100]}
⏱️ *Duration:* {duration_str}
🔢 *Formats Available:* {len(formats)}

*Select a quality from below:*
        """
        
        # Create keyboard
        keyboard = create_quality_keyboard(formats, url, 0)
        
        await message.edit_text(info_text, parse_mode='Markdown', reply_markup=keyboard)
        
    except Exception as e:
        logger.error(f"Error in show_formats: {e}")
        await message.edit_text(f"❌ Error analyzing video: {str(e)[:200]}")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_youtube_url(url):
        await message.reply_text("❌ Please send a valid YouTube URL")
        return
    
    await show_formats(update, context, url)

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    callback_data = query.data
    user_id = query.from_user.id
    
    # Handle navigation
    if callback_data.startswith('page:'):
        _, page_str, url = callback_data.split(':', 2)
        page = int(page_str)
        
        # Get formats from session or fetch again
        if user_id in user_sessions and user_sessions[user_id]['url'] == url:
            formats = user_sessions[user_id]['formats']
        else:
            formats, _ = get_video_formats(url)
        
        keyboard = create_quality_keyboard(formats, url, page)
        await query.edit_message_reply_markup(reply_markup=keyboard)
        return
    
    # Handle format selection
    elif callback_data.startswith('dl:'):
        _, format_id, url, page_str = callback_data.split(':', 3)
        await download_format(query, context, url, format_id)
        return
    
    # Handle best quality
    elif callback_data.startswith('best:'):
        _, url = callback_data.split(':', 1)
        await download_best(query, context, url)
        return
    
    # Handle audio only
    elif callback_data.startswith('audio:'):
        _, url = callback_data.split(':', 1)
        await download_audio(query, context, url)
        return
    
    # Handle cancel
    elif callback_data == 'cancel':
        await query.edit_message_text("❌ Download cancelled")
        return

async def download_format(query, context, url: str, format_id: str):
    """Download specific format"""
    user_id = query.from_user.id
    message = query.message
    
    # Update message
    await message.edit_text(f"⬇️ Downloading format {format_id}...")
    
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
            '--add-metadata',
            url
        ]
        
        logger.info(f"Downloading {url} with format {format_id}")
        
        # Start download
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:200]
            await message.edit_text(f"❌ Download failed: {error_msg}")
            return
        
        # Find downloaded file
        downloaded_files = []
        for ext in ['mp4', 'mkv', 'webm', 'mp3', 'm4a', 'flac', 'wav']:
            file_path = f'/opt/youtube_bot/downloads/{filename}.{ext}'
            if os.path.exists(file_path):
                downloaded_files.append((file_path, ext))
        
        if not downloaded_files:
            await message.edit_text("❌ File not found after download")
            return
        
        file_path, ext = downloaded_files[0]
        file_size = os.path.getsize(file_path)
        
        # Send file based on type
        with open(file_path, 'rb') as f:
            if ext in ['mp3', 'm4a', 'flac', 'wav']:
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=f"✅ Downloaded ({format_size(file_size)})",
                    parse_mode='Markdown'
                )
            elif ext in ['mp4', 'mkv', 'webm']:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ Downloaded ({format_size(file_size)})",
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            else:
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=f"✅ Downloaded ({format_size(file_size)})",
                    parse_mode='Markdown'
                )
        
        # Cleanup
        os.remove(file_path)
        await message.edit_text(f"✅ Download complete! ({format_size(file_size)})")
        
    except Exception as e:
        logger.error(f"Download error: {e}")
        await message.edit_text(f"❌ Download error: {str(e)[:200]}")

async def download_best(query, context, url: str):
    """Download best video+audio"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎯 Downloading best quality...")
    
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
            '--add-metadata',
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:200]
            await message.edit_text(f"❌ Download failed: {error_msg}")
            return
        
        # Send file
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp4'
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            with open(file_path, 'rb') as f:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=f"✅ Best quality downloaded ({format_size(file_size)})",
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            
            os.remove(file_path)
            await message.edit_text(f"✅ Best quality downloaded! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ File not found after download")
        
    except Exception as e:
        logger.error(f"Best quality download error: {e}")
        await message.edit_text(f"❌ Download error: {str(e)[:200]}")

async def download_audio(query, context, url: str):
    """Download audio only"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎵 Downloading audio...")
    
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
            url
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode()[:200]
            await message.edit_text(f"❌ Download failed: {error_msg}")
            return
        
        # Send file
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp3'
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            with open(file_path, 'rb') as f:
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=f"✅ Audio downloaded ({format_size(file_size)})",
                    parse_mode='Markdown'
                )
            
            os.remove(file_path)
            await message.edit_text(f"✅ Audio downloaded! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ File not found after download")
        
    except Exception as e:
        logger.error(f"Audio download error: {e}")
        await message.edit_text(f"❌ Download error: {str(e)[:200]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Error: {context.error}")
    
    try:
        if update.callback_query:
            await update.callback_query.message.reply_text("⚠️ An error occurred. Please try again.")
        elif update.message:
            await update.message.reply_text("⚠️ An error occurred. Please try again.")
    except:
        pass

def main():
    """Main function"""
    if not BOT_TOKEN:
        print("❌ ERROR: BOT_TOKEN not set")
        print("Please add your bot token to /opt/youtube_bot/.env")
        exit(1)
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("formats", formats_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 Advanced YouTube Bot starting...")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("✅ Bot ready to receive YouTube links")
    
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/youtube_bot/bot.py
    print_success "Advanced bot script created"
}

# Create enhanced environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/youtube_bot/.env.example << ENVEOF
# Telegram Bot Token from @BotFather
# Get it from: https://t.me/BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Optional: Maximum file size in bytes (Telegram limit is 2GB)
MAX_FILE_SIZE=2000000000

# Optional: Allowed user IDs (comma separated)
# Leave empty to allow all users
ALLOWED_USERS=

# Optional: Download directory
DOWNLOAD_DIR=/opt/youtube_bot/downloads

# Optional: Temp directory
TEMP_DIR=/tmp/youtube_bot
ENVEOF
    
    print_success "Environment file created"
}

# Create enhanced service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/youtube-bot.service << SERVICEEOF
[Unit]
Description=Advanced YouTube Downloader Bot with Quality Selection
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
ProtectSystem=strict
ReadWritePaths=/opt/youtube_bot/downloads /opt/youtube_bot/logs /tmp
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICEEOF
    
    systemctl daemon-reload
    print_success "Service file created"
}

# Create enhanced control script
create_control_script() {
    print_info "Creating enhanced control script..."
    
    cat > /usr/local/bin/youtube-bot << CONTROLEOF
#!/bin/bash

case "\$1" in
    start)
        if [ ! -f /opt/youtube_bot/.env ]; then
            echo "❌ Please setup bot first: youtube-bot setup"
            exit 1
        fi
        
        systemctl start youtube-bot
        echo "✅ YouTube Bot started"
        echo "📋 Check status: youtube-bot status"
        echo "📊 View logs: youtube-bot logs"
        ;;
    stop)
        systemctl stop youtube-bot
        echo "🛑 Bot stopped"
        ;;
    restart)
        systemctl restart youtube-bot
        echo "🔄 Bot restarted"
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
        echo "📝 Setting up Advanced YouTube Bot..."
        
        if [ ! -f /opt/youtube_bot/.env ]; then
            cp /opt/youtube_bot/.env.example /opt/youtube_bot/.env
            echo ""
            echo "📋 Created .env file at /opt/youtube_bot/.env"
            echo ""
            echo "🔑 Follow these steps to get BOT_TOKEN:"
            echo "1. Open Telegram"
            echo "2. Search for @BotFather"
            echo "3. Send /newbot"
            echo "4. Choose bot name (e.g., YouTube Downloader)"
            echo "5. Choose username (must end with 'bot', e.g., MyYouTubeDLBot)"
            echo "6. Copy the token (looks like: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)"
            echo ""
            echo "✏️ Edit config file:"
            echo "   nano /opt/youtube_bot/.env"
            echo ""
            echo "📁 Or use: youtube-bot config"
        else
            echo "✅ .env file already exists"
            echo "✏️ Edit it: youtube-bot config"
        fi
        ;;
    config)
        nano /opt/youtube_bot/.env
        ;;
    update)
        echo "🔄 Updating YouTube Bot..."
        echo "Updating Python packages..."
        pip3 install --upgrade pip python-telegram-bot yt-dlp
        
        echo "Updating yt-dlp..."
        yt-dlp -U
        
        echo "Restarting bot..."
        systemctl restart youtube-bot
        
        echo "✅ Bot updated successfully"
        ;;
    test)
        echo "🧪 Testing YouTube Bot installation..."
        echo ""
        
        echo "1. Testing Python packages..."
        python3 -c "import telegram, yt_dlp, json; print('✅ Python packages OK')"
        
        echo ""
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        
        echo ""
        echo "3. Testing FFmpeg..."
        ffmpeg -version | head -1
        
        echo ""
        echo "4. Testing service..."
        systemctl is-active youtube-bot &>/dev/null && echo "✅ Service is running" || echo "⚠️ Service is not running"
        
        echo ""
        echo "5. Testing directories..."
        ls -la /opt/youtube_bot/
        
        echo ""
        echo "✅ All tests completed"
        ;;
    clean)
        echo "🧹 Cleaning downloads..."
        rm -rf /opt/youtube_bot/downloads/*
        rm -rf /opt/youtube_bot/temp/*
        echo "✅ Cleaned downloads and temp"
        ;;
    backup)
        echo "💾 Backing up bot..."
        BACKUP_DIR="/opt/youtube_bot_backup_\$(date +%Y%m%d_%H%M%S)"
        mkdir -p "\$BACKUP_DIR"
        cp -r /opt/youtube_bot/* "\$BACKUP_DIR"/
        echo "✅ Backup created: \$BACKUP_DIR"
        ;;
    stats)
        echo "📊 Bot Statistics:"
        echo ""
        echo "Downloads folder:"
        du -sh /opt/youtube_bot/downloads
        echo ""
        echo "Log file size:"
        du -sh /opt/youtube_bot/logs/* 2>/dev/null || echo "No logs yet"
        echo ""
        echo "Service status:"
        systemctl status youtube-bot --no-pager -l | grep -A 3 "Active:"
        ;;
    *)
        echo "🤖 Advanced YouTube Downloader Bot"
        echo "Version: 2.0 | With Quality Selection"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test|clean|backup|stats}"
        echo ""
        echo "Commands:"
        echo "  start     - Start bot"
        echo "  stop      - Stop bot"
        echo "  restart   - Restart bot"
        echo "  status    - Check status"
        echo "  logs      - View logs (add -f to follow)"
        echo "  setup     - First-time setup"
        echo "  config    - Edit configuration"
        echo "  update    - Update bot and packages"
        echo "  test      - Run tests"
        echo "  clean     - Clean downloads"
        echo "  backup    - Create backup"
        echo "  stats     - Show statistics"
        echo ""
        echo "Quick Start:"
        echo "  1. youtube-bot setup"
        echo "  2. youtube-bot config  (add your token)"
        echo "  3. youtube-bot start"
        echo "  4. youtube-bot logs -f"
        echo ""
        echo "Features:"
        echo "  • Quality selection with file sizes"
        echo "  • Multiple format support"
        echo "  • Audio extraction"
        echo "  • Best quality auto-select"
        ;;
esac
CONTROLEOF
    
    chmod +x /usr/local/bin/youtube-bot
    print_success "Control script created"
}

# Create a simple test script
create_test_script() {
    print_info "Creating test script..."
    
    cat > /opt/youtube_bot/test.py << 'TESTEOF'
#!/usr/bin/env python3
"""
Test script for YouTube Bot
"""

import subprocess
import sys

def test_ytdlp():
    """Test yt-dlp installation"""
    try:
        result = subprocess.run(['yt-dlp', '--version'], 
                              capture_output=True, text=True)
        print(f"✅ yt-dlp version: {result.stdout.strip()}")
        return True
    except FileNotFoundError:
        print("❌ yt-dlp not found")
        return False

def test_ffmpeg():
    """Test FFmpeg installation"""
    try:
        result = subprocess.run(['ffmpeg', '-version'], 
                              capture_output=True, text=True)
        lines = result.stdout.split('\n')
        if lines:
            print(f"✅ FFmpeg: {lines[0]}")
        return True
    except FileNotFoundError:
        print("❌ FFmpeg not found")
        return False

def test_python_packages():
    """Test Python packages"""
    packages = ['telegram', 'yt_dlp', 'requests']
    all_ok = True
    
    for package in packages:
        try:
            if package == 'telegram':
                __import__('telegram')
            elif package == 'yt_dlp':
                __import__('yt_dlp')
            elif package == 'requests':
                __import__('requests')
            print(f"✅ {package} package OK")
        except ImportError as e:
            print(f"❌ {package} package missing: {e}")
            all_ok = False
    
    return all_ok

def main():
    """Run all tests"""
    print("🧪 Running YouTube Bot Tests...")
    print("=" * 50)
    
    tests = [
        ("Python Packages", test_python_packages),
        ("yt-dlp", test_ytdlp),
        ("FFmpeg", test_ffmpeg),
    ]
    
    all_passed = True
    for test_name, test_func in tests:
        print(f"\n📋 Testing: {test_name}")
        print("-" * 30)
        if not test_func():
            all_passed = False
    
    print("\n" + "=" * 50)
    if all_passed:
        print("✅ All tests passed! Bot is ready.")
    else:
        print("❌ Some tests failed. Please check installation.")
        sys.exit(1)

if __name__ == '__main__':
    main()
TESTEOF
    
    chmod +x /opt/youtube_bot/test.py
    print_success "Test script created"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}=============================================="
    echo "   ADVANCED YOUTUBE BOT INSTALLATION COMPLETE!"
    echo "=============================================="
    echo -e "${NC}"
    
    echo -e "\n${YELLOW}🚀 NEXT STEPS:${NC}"
    echo "1. ${GREEN}Setup bot:${NC}"
    echo "   youtube-bot setup"
    echo ""
    echo "2. ${GREEN}Get Bot Token from @BotFather:${NC}"
    echo "   • Open Telegram"
    echo "   • Search for @BotFather"
    echo "   • Send /newbot"
    echo "   • Choose name and username"
    echo "   • Copy token (looks like: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ)"
    echo ""
    echo "3. ${GREEN}Configure bot:${NC}"
    echo "   youtube-bot config"
    echo "   • Add your BOT_TOKEN"
    echo ""
    echo "4. ${GREEN}Test installation:${NC}"
    echo "   youtube-bot test"
    echo ""
    echo "5. ${GREEN}Start bot:${NC}"
    echo "   youtube-bot start"
    echo ""
    echo "6. ${GREEN}Monitor logs:${NC}"
    echo "   youtube-bot logs -f"
    echo ""
    
    echo -e "${YELLOW}🎬 NEW FEATURES:${NC}"
    echo "• ${GREEN}Quality selection${NC} - Choose from all available formats"
    echo "• ${GREEN}File size display${NC} - See size before downloading"
    echo "• ${GREEN}Multiple pages${NC} - Navigate through formats"
    echo "• ${GREEN}Best quality auto-select${NC}"
    echo "• ${GREEN}Audio extraction${NC}"
    echo "• ${GREEN}Enhanced controls${NC} - Backup, clean, stats"
    echo ""
    
    echo -e "${YELLOW}⚡ QUICK START:${NC}"
    echo "1. Send YouTube link to bot"
    echo "2. Bot shows all available formats with sizes"
    echo "3. Select your preferred quality"
    echo "4. Bot downloads and sends the file"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! Start with 'youtube-bot start'${NC}"
    echo ""
    
    echo -e "${CYAN}📞 Support:${NC}"
    echo "View logs: youtube-bot logs"
    echo "Check status: youtube-bot status"
    echo "Update bot: youtube-bot update"
    echo "Clean downloads: youtube-bot clean"
}

# Main installation
main() {
    show_logo
    print_info "Starting Advanced YouTube Bot installation..."
    
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
