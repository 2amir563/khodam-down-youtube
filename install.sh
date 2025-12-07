#!/bin/bash

# Telegram YouTube Video Downloader Bot Installer
# With Video Caption Support

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
    echo "   YOUTUBE DOWNLOADER BOT WITH CAPTION"
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

# Create bot.py script with caption support
create_bot_script() {
    print_info "Creating bot script with caption support..."
    
    cat > /opt/youtube_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
YouTube Downloader Bot with Video Caption Support
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
        nav_buttons.append(InlineKeyboardButton("⬅️ Previous", callback_data=f"nav:{page-1}:{encoded_url}"))
    
    if end_idx < len(formats):
        nav_buttons.append(InlineKeyboardButton("Next ➡️", callback_data=f"nav:{page+1}:{encoded_url}"))
    
    if nav_buttons:
        keyboard.append(nav_buttons)
    
    # Add quick action buttons
    keyboard.append([
        InlineKeyboardButton("🎯 Best Quality", callback_data=f"best:{encoded_url}"),
        InlineKeyboardButton("🎵 Audio Only", callback_data=f"audio:{encoded_url}")
    ])
    
    keyboard.append([InlineKeyboardButton("❌ Cancel", callback_data="cancel")])
    
    return InlineKeyboardMarkup(keyboard)

def create_caption(video_info: Dict, file_size: str, quality: str = "") -> str:
    """Create caption for video with video title"""
    title = video_info.get('title', 'Untitled')
    uploader = video_info.get('uploader', 'Unknown')
    duration = video_info.get('duration', 0)
    view_count = video_info.get('view_count', 0)
    upload_date = video_info.get('upload_date', '')
    
    # Format duration
    if duration:
        hours = duration // 3600
        minutes = (duration % 3600) // 60
        seconds = duration % 60
        if hours > 0:
            duration_str = f"{hours}:{minutes:02d}:{seconds:02d}"
        else:
            duration_str = f"{minutes}:{seconds:02d}"
    else:
        duration_str = "Unknown"
    
    # Format upload date
    if upload_date and len(upload_date) == 8:
        formatted_date = f"{upload_date[0:4]}-{upload_date[4:6]}-{upload_date[6:8]}"
    else:
        formatted_date = "Unknown"
    
    # Create caption
    caption = f"📺 *{title}*\n\n"
    
    if quality:
        caption += f"📊 *Quality:* {quality}\n"
    
    caption += f"📦 *Size:* {file_size}\n"
    caption += f"👤 *Channel:* {uploader}\n"
    caption += f"⏱️ *Duration:* {duration_str}\n"
    
    if view_count:
        caption += f"👁️ *Views:* {view_count:,}\n"
    
    caption += f"📅 *Uploaded:* {formatted_date}\n"
    caption += f"\n✅ Downloaded via @YouTubeDownloaderBot"
    
    # Truncate if too long (Telegram limit is 1024 chars)
    if len(caption) > 1024:
        caption = caption[:1020] + "..."
    
    return caption

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    
    text = f"""
🎬 *YouTube Downloader Bot*

👋 Hello {user.first_name}!

I can download YouTube videos with *quality selection* and *video captions*.

✨ *Features:*
• Download in *multiple qualities*
• See *file sizes* before downloading
• Video titles in captions
• Audio extraction
• Fast and reliable

📌 *How to use:*
1. Send me a YouTube link
2. I'll show available qualities
3. Select your preferred quality
4. Receive your file with video title

🔗 *Supported URLs:*
• youtube.com/watch?v=...
• youtu.be/...
• youtube.com/shorts/...
• youtube.com/live/...

⚡ *Commands:*
/start - Show this message
/help - Help information
/formats <link> - Show formats directly

📊 *Quality Selection:*
I'll show you *all available formats* with their *file sizes*.
    """
    
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *YouTube Bot Help*

📌 *How to download:*
1. Send a YouTube link
2. I'll analyze available formats
3. Choose quality from list
4. Wait for download
5. Receive your file with video title

🎯 *Format Types:*
• 🎬 Video+Audio (complete)
• 📹 Video only
• 🎵 Audio only

📊 *File Sizes:*
All formats show estimated file size

🎬 *Video Captions:*
Videos will include:
• Video title
• Channel name
• Duration
• Views count
• Upload date

⚡ *Quick Commands:*
/formats <link> - Show formats directly
/audio <link> - Download best audio
/video <link> - Download best video

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
        await update.message.reply_text("❌ Usage: /formats <youtube-url>")
        return
    
    url = ' '.join(context.args)
    await show_formats(update, context, url)

async def show_formats(update: Update, context: ContextTypes.DEFAULT_TYPE, url: str):
    """Show available formats for a URL"""
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please send a valid YouTube URL")
        return
    
    message = None
    if update.message:
        message = await update.message.reply_text("🔍 Analyzing video formats...")
    elif update.callback_query:
        message = await update.callback_query.message.reply_text("🔍 Analyzing video formats...")
    
    try:
        # Clean URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
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
        title = video_info.get('title', 'No title')[:100]
        duration = video_info.get('duration', 0)
        duration_str = f"{duration // 60}:{duration % 60:02d}" if duration else "Unknown"
        uploader = video_info.get('uploader', 'Unknown')[:50]
        view_count = video_info.get('view_count', 0)
        
        info_text = f"""
📺 *Video Analysis Complete!*

🎬 *Title:* {title}
👤 *Uploader:* {uploader}
👁️ *Views:* {view_count:,}
⏱️ *Duration:* {duration_str}
🔢 *Formats Available:* {len(formats)}

*Select your preferred quality:*
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
                await query.edit_message_text("❌ No formats found")
                return
            
            keyboard = create_quality_keyboard(formats, url, page)
            await query.edit_message_reply_markup(reply_markup=keyboard)
        except Exception as e:
            logger.error(f"Navigation error: {e}")
            await query.edit_message_text("❌ Navigation error")
        return
    
    # Handle format selection
    elif callback_data.startswith('dl:'):
        try:
            _, format_id, encoded_url = callback_data.split(':', 2)
            url = urllib.parse.unquote(encoded_url)
            await download_format(query, context, url, format_id)
        except Exception as e:
            logger.error(f"Format selection error: {e}")
            await query.edit_message_text("❌ Error selecting format")
        return
    
    # Handle best quality
    elif callback_data.startswith('best:'):
        try:
            _, encoded_url = callback_data.split(':', 1)
            url = urllib.parse.unquote(encoded_url)
            await download_best(query, context, url)
        except Exception as e:
            logger.error(f"Best quality error: {e}")
            await query.edit_message_text("❌ Error downloading best quality")
        return
    
    # Handle audio only
    elif callback_data.startswith('audio:'):
        try:
            _, encoded_url = callback_data.split(':', 1)
            url = urllib.parse.unquote(encoded_url)
            await download_audio(query, context, url)
        except Exception as e:
            logger.error(f"Audio download error: {e}")
            await query.edit_message_text("❌ Error downloading audio")
        return
    
    # Handle cancel
    elif callback_data == 'cancel':
        await query.edit_message_text("❌ Cancelled")
        return

async def download_format(query, context, url: str, format_id: str):
    """Download specific format"""
    user_id = query.from_user.id
    message = query.message
    
    # Update message
    await message.edit_text(f"⬇️ Downloading format {format_id}...")
    
    try:
        # Get video info first for caption
        formats, video_info = get_video_formats(url)
        
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
                await message.edit_text("🔄 Trying alternative method...")
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
                    await message.edit_text(f"❌ Download failed: {stderr.decode()[:200]}")
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
            await message.edit_text("❌ File not found after download")
            return
        
        file_path = downloaded_files[0]
        file_size = os.path.getsize(file_path)
        
        # Check file size (Telegram limit: 2GB)
        if file_size > 2000 * 1024 * 1024:
            await message.edit_text("❌ File size exceeds 2GB (Telegram limit)")
            os.remove(file_path)
            return
        
        # Get quality info for caption
        quality = ""
        for fmt in formats:
            if fmt['id'] == format_id:
                quality = f"{fmt['resolution']} ({fmt['ext'].upper()})"
                break
        
        # Create caption with video title
        caption = create_caption(video_info, format_size(file_size), quality)
        
        # Send file based on type
        with open(file_path, 'rb') as f:
            if file_path.endswith(('.mp3', '.m4a', '.flac', '.wav', '.ogg')):
                # For audio files, create simpler caption
                audio_caption = f"🎵 {video_info.get('title', 'Audio')}\n\n"
                audio_caption += f"👤 {video_info.get('uploader', 'Unknown')}\n"
                audio_caption += f"📦 {format_size(file_size)}\n\n"
                audio_caption += "✅ Downloaded via @YouTubeDownloaderBot"
                
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=audio_caption,
                    parse_mode='Markdown'
                )
            elif file_path.endswith(('.mp4', '.mkv', '.webm', '.mov', '.avi')):
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=caption,
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            else:
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=caption,
                    parse_mode='Markdown'
                )
        
        # Cleanup
        try:
            os.remove(file_path)
        except:
            pass
        
        await message.edit_text(f"✅ Download complete! ({format_size(file_size)})")
        
    except Exception as e:
        logger.error(f"Download error: {str(e)}")
        await message.edit_text(f"❌ Download error: {str(e)[:200]}")

async def download_best(query, context, url: str):
    """Download best video+audio"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎯 Downloading best quality...")
    
    try:
        # Get video info for caption
        _, video_info = get_video_formats(url)
        
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
                await message.edit_text(f"❌ Download failed: {stderr.decode()[:200]}")
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
                await message.edit_text("❌ File size exceeds 2GB")
                os.remove(file_path)
                return
            
            # Create caption
            caption = create_caption(video_info, format_size(file_size), "Best Quality")
            
            with open(file_path, 'rb') as f:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=caption,
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ Best quality downloaded! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ File not found after download")
        
    except Exception as e:
        logger.error(f"Best quality download error: {str(e)}")
        await message.edit_text(f"❌ Download error: {str(e)[:200]}")

async def download_audio(query, context, url: str):
    """Download audio only"""
    user_id = query.from_user.id
    message = query.message
    
    await message.edit_text("🎵 Downloading audio...")
    
    try:
        # Get video info for caption
        _, video_info = get_video_formats(url)
        
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
                await message.edit_text(f"❌ Download failed: {stderr.decode()[:200]}")
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
            
            # Create audio caption
            caption = f"🎵 {video_info.get('title', 'Audio')}\n\n"
            caption += f"👤 {video_info.get('uploader', 'Unknown')}\n"
            caption += f"📦 {format_size(file_size)}\n\n"
            caption += "✅ Downloaded via @YouTubeDownloaderBot"
            
            with open(file_path, 'rb') as f:
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=caption,
                    parse_mode='Markdown'
                )
            
            try:
                os.remove(file_path)
            except:
                pass
            
            await message.edit_text(f"✅ Audio downloaded! ({format_size(file_size)})")
        else:
            await message.edit_text("❌ File not found after download")
        
    except Exception as e:
        logger.error(f"Audio download error: {str(e)}")
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
    app.add_handler(CommandHandler("audio", download_audio_command))
    app.add_handler(CommandHandler("video", download_video_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 YouTube Bot starting...")
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("✅ Bot ready to receive YouTube links")
    
    app.run_polling()

async def download_audio_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command handler for /audio"""
    if not context.args:
        await update.message.reply_text("❌ Usage: /audio <youtube-url>")
        return
    
    url = ' '.join(context.args)
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Invalid YouTube URL")
        return
    
    msg = await update.message.reply_text("🎵 Downloading audio...")
    await download_audio_simple(update, context, url, msg)

async def download_video_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command handler for /video"""
    if not context.args:
        await update.message.reply_text("❌ Usage: /video <youtube-url>")
        return
    
    url = ' '.join(context.args)
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Invalid YouTube URL")
        return
    
    msg = await update.message.reply_text("🎬 Downloading video...")
    await download_video_simple(update, context, url, msg)

async def download_audio_simple(update, context, url: str, message):
    """Simple audio download for command"""
    user_id = update.effective_user.id
    
    try:
        # Get video info for caption
        _, video_info = get_video_formats(url)
        
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
            await message.edit_text(f"❌ Error: {stderr.decode()[:200]}")
            return
        
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp3'
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            # Create caption
            caption = f"🎵 {video_info.get('title', 'Audio')}\n\n"
            caption += f"👤 {video_info.get('uploader', 'Unknown')}\n"
            caption += f"📦 {format_size(file_size)}\n\n"
            caption += "✅ Downloaded via @YouTubeDownloaderBot"
            
            with open(file_path, 'rb') as f:
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=caption,
                    parse_mode='Markdown'
                )
            os.remove(file_path)
            await message.edit_text("✅ Download complete!")
        else:
            await message.edit_text("❌ File not found")
            
    except Exception as e:
        logger.error(f"Simple audio error: {e}")
        await message.edit_text(f"❌ Error: {str(e)[:200]}")

async def download_video_simple(update, context, url: str, message):
    """Simple video download for command"""
    user_id = update.effective_user.id
    
    try:
        # Get video info for caption
        _, video_info = get_video_formats(url)
        
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
            await message.edit_text(f"❌ Error: {stderr.decode()[:200]}")
            return
        
        file_path = f'/opt/youtube_bot/downloads/{filename}.mp4'
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            
            # Create caption
            caption = create_caption(video_info, format_size(file_size), "Best Quality")
            
            with open(file_path, 'rb') as f:
                await context.bot.send_video(
                    chat_id=user_id,
                    video=f,
                    caption=caption,
                    parse_mode='Markdown',
                    supports_streaming=True
                )
            os.remove(file_path)
            await message.edit_text("✅ Download complete!")
        else:
            await message.edit_text("❌ File not found")
            
    except Exception as e:
        logger.error(f"Simple video error: {e}")
        await message.edit_text(f"❌ Error: {str(e)[:200]}")

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/youtube_bot/bot.py
    print_success "Bot script with caption support created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/youtube_bot/.env.example << ENVEOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Maximum file size in bytes (Telegram limit is 2GB)
MAX_FILE_SIZE=2000000000

# Allowed user IDs (comma separated)
# Leave empty to allow all users
ALLOWED_USERS=

# Download directory
DOWNLOAD_DIR=/opt/youtube_bot/downloads

# Temp directory
TEMP_DIR=/tmp/youtube_bot
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/youtube-bot.service << SERVICEEOF
[Unit]
Description=YouTube Downloader Bot with Caption Support
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
        echo "📝 Setting up YouTube Bot..."
        
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
        echo "🤖 YouTube Downloader Bot with Caption"
        echo "Version: 2.2 | With Video Title in Caption"
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
        echo "  • Video titles in captions"
        echo "  • Multiple format support"
        echo "  • Audio extraction"
        echo "  • Best quality auto-select"
        ;;
esac
CONTROLEOF
    
    chmod +x /usr/local/bin/youtube-bot
    print_success "Control script created"
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}=============================================="
    echo "   YOUTUBE BOT INSTALLATION COMPLETE!"
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
    echo "• ${GREEN}Video titles in captions${NC} - Shows title below video"
    echo "• ${GREEN}Quality selection${NC} - Show all formats with file sizes"
    echo "• ${GREEN}Video information${NC} - Channel, duration, views, upload date"
    echo "• ${GREEN}Pagination${NC} - For videos with many formats"
    echo "• ${GREEN}Audio captions${NC} - Audio files also include title"
    echo ""
    
    echo -e "${YELLOW}⚡ QUICK START:${NC}"
    echo "1. Send YouTube link to bot"
    echo "2. Bot shows all available formats with sizes"
    echo "3. Select your preferred quality"
    echo "4. Bot downloads and sends the file with video title"
    echo ""
    
    echo -e "${GREEN}✅ Bot is ready! Start with 'youtube-bot start'${NC}"
    echo ""
    
    echo -e "${CYAN}📞 SUPPORT:${NC}"
    echo "View logs: youtube-bot logs"
    echo "Check status: youtube-bot status"
    echo "Update bot: youtube-bot update"
    echo "Clean downloads: youtube-bot clean"
}

# Main installation
main() {
    show_logo
    print_info "Starting YouTube Bot installation..."
    
    install_deps
    install_python_packages
    create_bot_dir
    create_bot_script
    create_env_file
    create_service_file
    create_control_script
    
    # Create log files
    touch /opt/youtube_bot/logs/bot.log
    chmod 666 /opt/youtube_bot/logs/bot.log
    
    show_completion
}

# Run installation
main "$@"
