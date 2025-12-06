#!/bin/bash

# Telegram YouTube Video Downloader Bot Installer
# Complete Version for YouTube

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
    cat << "EOF"
╔══════════════════════════════════════════════════╗
║                                                  ║
║     TELEGRAM YOUTUBE DOWNLOADER BOT             ║
║           COMPLETE INSTALLATION                 ║
║                                                  ║
╚══════════════════════════════════════════════════╝
EOF
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
        apt install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git ffmpeg curl wget nano
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git ffmpeg curl wget nano
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
    pip3 install "python-telegram-bot==20.7" "yt-dlp>=2024.04.09" requests python-dotenv
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/youtube_bot
    mkdir -p /opt/youtube_bot
    mkdir -p /opt/youtube_bot/downloads
    mkdir -p /opt/youtube_bot/logs
    
    cd /opt/youtube_bot
    
    print_success "Directory created: /opt/youtube_bot"
}

# Create bot.py script
create_bot_script() {
    print_info "Creating YouTube bot script..."
    
    cat > /opt/youtube_bot/bot.py << 'EOF'
#!/usr/bin/env python3
"""
Telegram YouTube Video Downloader Bot
Supports video and audio download
"""

import os
import json
import logging
import subprocess
import re
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
from dotenv import load_dotenv

# Load environment
load_dotenv()

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/youtube_bot/logs/bot.log'
)
logger = logging.getLogger(__name__)

# Configuration
BOT_TOKEN = os.getenv('BOT_TOKEN', '')
MAX_VIDEO_SIZE = 2000 * 1024 * 1024  # 2GB for videos
MAX_AUDIO_SIZE = 500 * 1024 * 1024   # 500MB for audio

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    text = f"""
🎬 *YouTube Downloader Bot*

👋 Hello {user.first_name}!

I can download videos and audio from YouTube for you.

✨ *Features:*
• Download videos in multiple qualities
• Extract audio as MP3
• Support for playlists
• Video information
• Fast and reliable

📌 *How to use:*
1. Send me any YouTube link
2. Choose video or audio
3. Select quality/format
4. Receive your file

🔗 *Supported URLs:*
• YouTube videos
• YouTube shorts
• YouTube playlists
• YouTube music

⚡ *Commands:*
/start - Show this message
/help - Help information
/audio <url> - Direct audio download
/video <url> - Direct video download (best quality)
/formats <url> - Show all available formats

📦 *Limits:*
• Max video: 2GB
• Max audio: 500MB
• Playlists: Up to 10 items
    """
    await update.message.reply_text(text, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 *YouTube Bot Help Guide*

📌 *How to download:*
1. Send a YouTube link
2. Choose download type (Video/Audio)
3. Select quality/format
4. Wait for download
5. Receive your file

🎯 *Quick Commands:*
/audio <url> - Download audio only
/video <url> - Download video (best quality)
/formats <url> - Show all formats

🎬 *Video Qualities:*
• 144p, 240p, 360p, 480p
• 720p (HD), 1080p (Full HD)
• 1440p (2K), 2160p (4K)
• Best available quality

🎵 *Audio Formats:*
• MP3 (128kbps, 192kbps, 320kbps)
• M4A, AAC, OPUS
• Best available quality

⚠️ *Notes:*
• Some videos may have restrictions
• Playlist downloads may take longer
• Check file size before downloading
    """
    await update.message.reply_text(text, parse_mode='Markdown')

async def audio_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /audio command for direct audio download"""
    if not context.args:
        await update.message.reply_text("Usage: /audio <youtube-url>\nExample: /audio https://youtube.com/watch?v=...")
        return
    
    url = context.args[0]
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please provide a valid YouTube URL")
        return
    
    user_id = update.effective_user.id
    context.user_data['url'] = url
    context.user_data['type'] = 'audio'
    
    msg = await update.message.reply_text("🔍 Analyzing audio...")
    
    # Show audio quality options
    keyboard = [
        [InlineKeyboardButton("🎵 MP3 128kbps", callback_data="audio:mp3:128")],
        [InlineKeyboardButton("🎵 MP3 192kbps", callback_data="audio:mp3:192")],
        [InlineKeyboardButton("🎵 MP3 320kbps", callback_data="audio:mp3:320")],
        [InlineKeyboardButton("🎵 Best Quality", callback_data="audio:best:best")],
        [InlineKeyboardButton("🎵 M4A (AAC)", callback_data="audio:m4a:aac")],
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await msg.edit_text(
        "🎵 *Audio Download Options*\n\n"
        "Select audio quality/format:",
        parse_mode='Markdown',
        reply_markup=reply_markup
    )

async def video_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /video command for direct video download"""
    if not context.args:
        await update.message.reply_text("Usage: /video <youtube-url>\nExample: /video https://youtube.com/watch?v=...")
        return
    
    url = context.args[0]
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please provide a valid YouTube URL")
        return
    
    user_id = update.effective_user.id
    context.user_data['url'] = url
    context.user_data['type'] = 'video'
    
    msg = await update.message.reply_text("🔍 Analyzing video...")
    
    # Get video info for quality options
    video_info = get_video_info(url)
    if not video_info:
        await msg.edit_text("❌ Could not get video information")
        return
    
    # Show video quality options
    keyboard = [
        [InlineKeyboardButton("📹 360p", callback_data="video:360")],
        [InlineKeyboardButton("📹 480p", callback_data="video:480")],
        [InlineKeyboardButton("📹 720p HD", callback_data="video:720")],
        [InlineKeyboardButton("📹 1080p Full HD", callback_data="video:1080")],
        [InlineKeyboardButton("📹 Best Quality", callback_data="video:best")],
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    title = video_info.get('title', 'Unknown')[:50]
    duration = video_info.get('duration_string', 'Unknown')
    
    await msg.edit_text(
        f"🎬 *Video Download Options*\n\n"
        f"📺 *Title:* {title}\n"
        f"⏱️ *Duration:* {duration}\n\n"
        f"Select video quality:",
        parse_mode='Markdown',
        reply_markup=reply_markup
    )

async def formats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /formats command to show all available formats"""
    if not context.args:
        await update.message.reply_text("Usage: /formats <youtube-url>\nExample: /formats https://youtube.com/watch?v=...")
        return
    
    url = context.args[0]
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please provide a valid YouTube URL")
        return
    
    msg = await update.message.reply_text("📊 Getting available formats...")
    
    try:
        # Get formats using yt-dlp
        cmd = ['yt-dlp', '-F', '--no-warnings', url]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            formats_text = result.stdout
            
            # Split long message if needed
            if len(formats_text) > 4000:
                parts = [formats_text[i:i+4000] for i in range(0, len(formats_text), 4000)]
                for i, part in enumerate(parts, 1):
                    await update.message.reply_text(f"```\n{part}\n```", parse_mode='Markdown')
            else:
                await msg.edit_text(f"```\n{formats_text}\n```", parse_mode='Markdown')
        else:
            await msg.edit_text("❌ Could not get format information")
            
    except Exception as e:
        logger.error(f"Formats error: {e}")
        await msg.edit_text(f"❌ Error: {str(e)[:200]}")

def is_youtube_url(url):
    """Check if URL is from YouTube"""
    youtube_domains = [
        'youtube.com',
        'youtu.be',
        'm.youtube.com',
        'youtube-nocookie.com',
        'y2u.be'
    ]
    url_lower = url.lower()
    return any(domain in url_lower for domain in youtube_domains)

def get_video_info(url):
    """Get video information"""
    try:
        cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', url]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            return json.loads(result.stdout)
        return None
        
    except Exception as e:
        logger.error(f"Video info error: {e}")
        return None

def format_size(size_bytes):
    """Format file size to human readable"""
    if not size_bytes:
        return "Unknown"
    
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages (YouTube URLs)"""
    message = update.message
    url = message.text.strip()
    
    if not is_youtube_url(url):
        await message.reply_text("❌ Please send a valid YouTube URL")
        return
    
    # Store URL
    context.user_data['url'] = url
    
    # Get video info
    msg = await message.reply_text("🔍 Analyzing YouTube video...")
    
    video_info = get_video_info(url)
    if not video_info:
        await msg.edit_text("❌ Could not get video information. The video might be private or unavailable.")
        return
    
    # Store video info
    context.user_data['video_info'] = video_info
    
    # Create main menu keyboard
    title = video_info.get('title', 'Unknown')[:60]
    duration = video_info.get('duration_string', 'Unknown')
    uploader = video_info.get('uploader', 'Unknown')
    
    keyboard = [
        [InlineKeyboardButton("🎬 Download Video", callback_data="menu:video")],
        [InlineKeyboardButton("🎵 Download Audio", callback_data="menu:audio")],
        [InlineKeyboardButton("📊 Show Formats", callback_data="menu:formats")],
        [InlineKeyboardButton("ℹ️ Video Info", callback_data="menu:info")],
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await msg.edit_text(
        f"📺 *YouTube Video Found!*\n\n"
        f"📝 *Title:* {title}\n"
        f"👤 *Channel:* {uploader}\n"
        f"⏱️ *Duration:* {duration}\n\n"
        f"Select what you want to do:",
        parse_mode='Markdown',
        reply_markup=reply_markup
    )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    callback_data = query.data
    user_id = query.from_user.id
    url = context.user_data.get('url')
    video_info = context.user_data.get('video_info')
    
    if not url:
        await query.edit_message_text("❌ URL not found. Please send the URL again.")
        return
    
    if callback_data.startswith('menu:'):
        menu_type = callback_data.split(':')[1]
        
        if menu_type == 'video':
            # Show video quality options
            keyboard = []
            row = []
            
            # Common video qualities
            qualities = [
                ('144p', '144'),
                ('240p', '240'),
                ('360p', '360'),
                ('480p', '480'),
                ('720p HD', '720'),
                ('1080p Full HD', '1080'),
                ('1440p 2K', '1440'),
                ('2160p 4K', '2160'),
                ('🎯 Best Quality', 'best'),
            ]
            
            for i, (label, quality) in enumerate(qualities):
                if i > 0 and i % 3 == 0:
                    keyboard.append(row)
                    row = []
                row.append(InlineKeyboardButton(label, callback_data=f"video:{quality}"))
            
            if row:
                keyboard.append(row)
            
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                "🎬 *Video Download*\n\n"
                "Select video quality:",
                parse_mode='Markdown',
                reply_markup=reply_markup
            )
            
        elif menu_type == 'audio':
            # Show audio format options
            keyboard = [
                [InlineKeyboardButton("🎵 MP3 128kbps", callback_data="audio:mp3:128")],
                [InlineKeyboardButton("🎵 MP3 192kbps", callback_data="audio:mp3:192")],
                [InlineKeyboardButton("🎵 MP3 320kbps", callback_data="audio:mp3:320")],
                [InlineKeyboardButton("🎵 M4A (AAC)", callback_data="audio:m4a:aac")],
                [InlineKeyboardButton("🎵 Best Audio", callback_data="audio:best:best")],
            ]
            
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                "🎵 *Audio Download*\n\n"
                "Select audio format:",
                parse_mode='Markdown',
                reply_markup=reply_markup
            )
            
        elif menu_type == 'formats':
            # Show formats
            await query.edit_message_text("📊 Getting available formats...")
            
            cmd = ['yt-dlp', '-F', '--no-warnings', url]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                formats = result.stdout
                if len(formats) > 4000:
                    await query.message.reply_text(f"```\n{formats[:4000]}\n```", parse_mode='Markdown')
                    await query.message.reply_text(f"```\n{formats[4000:8000]}\n```", parse_mode='Markdown')
                else:
                    await query.edit_message_text(f"```\n{formats}\n```", parse_mode='Markdown')
            else:
                await query.edit_message_text("❌ Could not get format information")
                
        elif menu_type == 'info':
            # Show video info
            if video_info:
                title = video_info.get('title', 'Unknown')
                uploader = video_info.get('uploader', 'Unknown')
                duration = video_info.get('duration_string', 'Unknown')
                view_count = video_info.get('view_count', 0)
                like_count = video_info.get('like_count', 0)
                description = video_info.get('description', '')[:300]
                
                info_text = (
                    f"📊 *Video Information*\n\n"
                    f"📺 *Title:* {title}\n"
                    f"👤 *Channel:* {uploader}\n"
                    f"⏱️ *Duration:* {duration}\n"
                    f"👁️ *Views:* {view_count:,}\n"
                    f"❤️ *Likes:* {like_count:,}\n\n"
                    f"📝 *Description:*\n{description}..."
                )
                
                await query.edit_message_text(info_text, parse_mode='Markdown')
    
    elif callback_data.startswith('video:'):
        # Video quality selected
        quality = callback_data.split(':')[1]
        
        await query.edit_message_text(f"🎬 Downloading {quality}p video...\nThis may take a while.")
        
        success = await download_video(url, quality, user_id, query.message, context, video_info)
        
        if success:
            await query.edit_message_text("✅ Video download completed!")
        else:
            await query.edit_message_text("❌ Video download failed. Try another quality.")
    
    elif callback_data.startswith('audio:'):
        # Audio format selected
        _, format_type, bitrate = callback_data.split(':')
        
        format_name = {
            'mp3': 'MP3',
            'm4a': 'M4A (AAC)',
            'best': 'Best Audio'
        }.get(format_type, format_type)
        
        await query.edit_message_text(f"🎵 Downloading {format_name} {bitrate}kbps...")
        
        success = await download_audio(url, format_type, bitrate, user_id, query.message, context, video_info)
        
        if success:
            await query.edit_message_text("✅ Audio download completed!")
        else:
            await query.edit_message_text("❌ Audio download failed. Try another format.")

async def download_video(url, quality, user_id, message, context, video_info=None):
    """Download YouTube video"""
    try:
        # Create temp directory
        temp_dir = f"/tmp/youtube_video_{user_id}"
        os.makedirs(temp_dir, exist_ok=True)
        os.chdir(temp_dir)
        
        # Clean previous files
        for f in os.listdir('.'):
            if f.endswith(('.mp4', '.mkv', '.webm')):
                try:
                    os.remove(f)
                except:
                    pass
        
        # Build download command based on quality
        output_template = 'video_%(title)s_%(resolution)s.%(ext)s'
        
        if quality == 'best':
            format_spec = 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'
        else:
            format_spec = f'bestvideo[height<={quality}][ext=mp4]+bestaudio[ext=m4a]/best[height<={quality}]'
        
        cmd = [
            'yt-dlp',
            '-f', format_spec,
            '--merge-output-format', 'mp4',
            '-o', output_template,
            '--no-warnings',
            '--add-metadata',
            '--embed-thumbnail',
            '--progress',
            url
        ]
        
        # Start download
        await message.edit_text(f"📥 Downloading {quality}p video...\n0%")
        
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Monitor progress
        last_progress = 0
        for line in process.stdout:
            if '[download]' in line and '%' in line:
                match = re.search(r'(\d+\.?\d*)%', line)
                if match:
                    progress = match.group(1)
                    if float(progress) - last_progress >= 5:  # Update every 5%
                        await message.edit_text(f"📥 Downloading {quality}p video...\n{progress}%")
                        last_progress = float(progress)
        
        process.wait()
        
        if process.returncode != 0:
            return False
        
        # Find downloaded file
        files = [f for f in os.listdir('.') if f.endswith('.mp4')]
        if not files:
            return False
        
        video_file = max(files, key=os.path.getctime)
        file_size = os.path.getsize(video_file)
        
        # Check file size
        if file_size > MAX_VIDEO_SIZE:
            await message.edit_text(f"❌ File too large ({format_size(file_size)} > 2GB)")
            try:
                os.remove(video_file)
            except:
                pass
            return False
        
        # Create caption
        caption = create_video_caption(video_info, quality)
        
        # Send video
        await message.edit_text("📤 Sending video...")
        
        with open(video_file, 'rb') as f:
            await context.bot.send_video(
                chat_id=user_id,
                video=f,
                caption=caption,
                supports_streaming=True,
                read_timeout=120,
                write_timeout=120,
                connect_timeout=120
            )
        
        # Cleanup
        try:
            os.remove(video_file)
        except:
            pass
        
        return True
        
    except subprocess.TimeoutExpired:
        await message.edit_text("❌ Download timeout")
        return False
    except Exception as e:
        logger.error(f"Video download error: {e}")
        await message.edit_text(f"❌ Error: {str(e)[:200]}")
        return False
    finally:
        os.chdir('/')
        # Clean temp directory
        try:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
        except:
            pass

async def download_audio(url, format_type, bitrate, user_id, message, context, video_info=None):
    """Download YouTube audio"""
    try:
        # Create temp directory
        temp_dir = f"/tmp/youtube_audio_{user_id}"
        os.makedirs(temp_dir, exist_ok=True)
        os.chdir(temp_dir)
        
        # Clean previous files
        for f in os.listdir('.'):
            if f.endswith(('.mp3', '.m4a', '.opus')):
                try:
                    os.remove(f)
                except:
                    pass
        
        # Build download command based on format
        output_template = 'audio_%(title)s.%(ext)s'
        
        if format_type == 'mp3':
            # For MP3, we need to convert
            cmd = [
                'yt-dlp',
                '-f', 'bestaudio[ext=m4a]',
                '-o', output_template,
                '--no-warnings',
                '--extract-audio',
                '--audio-format', 'mp3',
                '--audio-quality', bitrate,
                '--add-metadata',
                '--embed-thumbnail',
                '--progress',
                url
            ]
        elif format_type == 'm4a':
            cmd = [
                'yt-dlp',
                '-f', 'bestaudio[ext=m4a]',
                '-o', output_template,
                '--no-warnings',
                '--extract-audio',
                '--add-metadata',
                '--embed-thumbnail',
                '--progress',
                url
            ]
        else:  # best
            cmd = [
                'yt-dlp',
                '-f', 'bestaudio',
                '-o', output_template,
                '--no-warnings',
                '--extract-audio',
                '--add-metadata',
                '--embed-thumbnail',
                '--progress',
                url
            ]
        
        # Start download
        format_name = 'MP3' if format_type == 'mp3' else 'M4A' if format_type == 'm4a' else 'Best Audio'
        await message.edit_text(f"🎵 Downloading {format_name}...\n0%")
        
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Monitor progress
        last_progress = 0
        for line in process.stdout:
            if '[download]' in line and '%' in line:
                match = re.search(r'(\d+\.?\d*)%', line)
                if match:
                    progress = match.group(1)
                    if float(progress) - last_progress >= 5:
                        await message.edit_text(f"🎵 Downloading {format_name}...\n{progress}%")
                        last_progress = float(progress)
        
        process.wait()
        
        if process.returncode != 0:
            return False
        
        # Find downloaded file
        files = [f for f in os.listdir('.') if f.endswith(('.mp3', '.m4a', '.opus'))]
        if not files:
            return False
        
        audio_file = max(files, key=os.path.getctime)
        file_size = os.path.getsize(audio_file)
        
        # Check file size
        if file_size > MAX_AUDIO_SIZE:
            await message.edit_text(f"❌ File too large ({format_size(file_size)} > 500MB)")
            try:
                os.remove(audio_file)
            except:
                pass
            return False
        
        # Create caption
        caption = create_audio_caption(video_info, format_type, bitrate)
        
        # Send audio
        await message.edit_text("📤 Sending audio...")
        
        with open(audio_file, 'rb') as f:
            if audio_file.endswith('.mp3'):
                await context.bot.send_audio(
                    chat_id=user_id,
                    audio=f,
                    caption=caption,
                    read_timeout=120,
                    write_timeout=120,
                    connect_timeout=120
                )
            else:
                # For other formats, send as document
                await context.bot.send_document(
                    chat_id=user_id,
                    document=f,
                    caption=caption,
                    read_timeout=120,
                    write_timeout=120,
                    connect_timeout=120
                )
        
        # Cleanup
        try:
            os.remove(audio_file)
        except:
            pass
        
        return True
        
    except subprocess.TimeoutExpired:
        await message.edit_text("❌ Download timeout")
        return False
    except Exception as e:
        logger.error(f"Audio download error: {e}")
        await message.edit_text(f"❌ Error: {str(e)[:200]}")
        return False
    finally:
        os.chdir('/')
        # Clean temp directory
        try:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
        except:
            pass

def create_video_caption(video_info, quality):
    """Create caption for video"""
    if not video_info:
        return f"📺 YouTube Video\n\n🎬 Quality: {quality}p"
    
    title = video_info.get('title', 'Unknown Video')
    uploader = video_info.get('uploader', 'Unknown Channel')
    duration = video_info.get('duration_string', 'Unknown')
    
    caption = f"📺 {title}\n\n👤 {uploader}\n⏱️ {duration}\n🎬 Quality: {quality}p"
    
    return caption

def create_audio_caption(video_info, format_type, bitrate):
    """Create caption for audio"""
    if not video_info:
        format_name = 'MP3' if format_type == 'mp3' else 'M4A' if format_type == 'm4a' else 'Audio'
        return f"🎵 YouTube Audio\n\nFormat: {format_name} {bitrate}kbps"
    
    title = video_info.get('title', 'Unknown Track')
    uploader = video_info.get('uploader', 'Unknown Artist')
    
    format_name = 'MP3' if format_type == 'mp3' else 'M4A' if format_type == 'm4a' else 'Audio'
    quality_info = f"{bitrate}kbps" if bitrate != 'best' else 'Best Quality'
    
    caption = f"🎵 {title}\n\n👤 {uploader}\nFormat: {format_name} {quality_info}"
    
    return caption

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
    app.add_handler(CommandHandler("audio", audio_command))
    app.add_handler(CommandHandler("video", video_command))
    app.add_handler(CommandHandler("formats", formats_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 YouTube Downloader Bot starting...")
    print("📁 Logs: /opt/youtube_bot/logs/bot.log")
    print("✨ Features: Video + Audio download")
    
    app.run_polling()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/youtube_bot/bot.py
    print_success "YouTube bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/youtube_bot/.env.example << EOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here

# Optional: Admin Telegram User ID
# Get it from @userinfobot on Telegram
ADMIN_ID=123456789
EOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/youtube-bot.service << EOF
[Unit]
Description=Telegram YouTube Video/Audio Downloader Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/youtube_bot
EnvironmentFile=/opt/youtube_bot/.env
ExecStart=/usr/bin/python3 /opt/youtube_bot/bot.py
Restart=always
RestartSec=10
StandardOutput=append:/opt/youtube_bot/logs/bot.log
StandardError=append:/opt/youtube_bot/logs/error.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Service file created"
}

# Create control script
create_control_script() {
    print_info "Creating control script..."
    
    cat > /usr/local/bin/youtube-bot << 'EOF'
#!/bin/bash

case "$1" in
    start)
        if [ ! -f /opt/youtube_bot/.env ]; then
            echo "❌ Please setup bot first: youtube-bot setup"
            exit 1
        fi
        
        systemctl start youtube-bot
        echo "✅ YouTube Bot started"
        echo "✨ Features: Video & Audio download"
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
        if [ "$2" = "error" ]; then
            tail -f /opt/youtube_bot/logs/error.log
        else
            tail -f /opt/youtube_bot/logs/bot.log
        fi
        ;;
    setup)
        echo "📝 Setting up YouTube Bot..."
        
        if [ ! -f /opt/youtube_bot/.env ]; then
            cp /opt/youtube_bot/.env.example /opt/youtube_bot/.env
            echo ""
            echo "📋 Created .env file"
            echo "Please edit it and add your BOT_TOKEN:"
            echo "   nano /opt/youtube_bot/.env"
            echo ""
            echo "🔑 How to get BOT_TOKEN:"
            echo "1. Open Telegram"
            echo "2. Search for @BotFather"
            echo "3. Send /newbot"
            echo "4. Follow instructions"
            echo "5. Copy the token"
        else
            echo "✅ .env file already exists"
        fi
        ;;
    config)
        nano /opt/youtube_bot/.env
        ;;
    update)
        echo "🔄 Updating YouTube Bot..."
        
        # Update packages
        pip3 install --upgrade yt-dlp python-telegram-bot requests python-dotenv
        
        # Update yt-dlp for better YouTube support
        yt-dlp -U
        
        systemctl restart youtube-bot
        echo "✅ Bot updated and restarted"
        ;;
    test)
        echo "🧪 Testing YouTube Bot..."
        echo ""
        
        echo "1. Testing packages..."
        python3 -c "
try:
    import telegram, yt_dlp, requests, dotenv
    print('✅ All packages installed')
except Exception as e:
    print(f'❌ Missing packages: {e}')
        "
        echo ""
        
        echo "2. Testing yt-dlp..."
        yt-dlp --version
        echo ""
        
        echo "3. Testing configuration..."
        if [ -f /opt/youtube_bot/.env ]; then
            if grep -q "BOT_TOKEN=" /opt/youtube_bot/.env && ! grep -q "BOT_TOKEN=your_bot_token_here" /opt/youtube_bot/.env; then
                echo "✅ BOT_TOKEN configured"
            else
                echo "⚠️  BOT_TOKEN not configured"
            fi
        else
            echo "❌ .env file not found"
        fi
        ;;
    yt-test)
        echo "🎬 Testing YouTube download..."
        echo ""
        
        # Test with a sample YouTube URL
        SAMPLE_URL="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        echo "Testing URL: $SAMPLE_URL"
        echo ""
        
        cd /opt/youtube_bot
        python3 -c "
import subprocess, json
try:
    cmd = ['yt-dlp', '--skip-download', '--dump-json', '--no-warnings', '$SAMPLE_URL']
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    
    if result.returncode == 0:
        info = json.loads(result.stdout)
        title = info.get('title', 'No title')
        uploader = info.get('uploader', 'Unknown')
        duration = info.get('duration_string', 'Unknown')
        
        print(f'✅ Success!')
        print(f'Title: {title}')
        print(f'Channel: {uploader}')
        print(f'Duration: {duration}')
    else:
        print('❌ Failed to get video info')
except Exception as e:
    print(f'❌ Error: {e}')
        "
        ;;
    fix)
        echo "🔧 Fixing YouTube download issues..."
        
        # Update yt-dlp
        pip3 install --upgrade yt-dlp
        
        # Clear cache
        yt-dlp --rm-cache-dir 2>/dev/null || true
        
        # Restart bot
        systemctl restart youtube-bot
        
        echo "✅ Fixes applied and bot restarted"
        ;;
    *)
        echo "🤖 YouTube Video/Audio Downloader Bot"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|setup|config|update|test|yt-test|fix}"
        echo ""
        echo "Commands:"
        echo "  start     - Start YouTube bot"
        echo "  stop      - Stop bot"
        echo "  restart   - Restart bot"
        echo "  status    - Check status"
        echo "  logs      - View logs (add 'error' for error logs)"
        echo "  setup     - Initial setup"
        echo "  config    - Edit configuration"
        echo "  update    - Update bot & packages"
        echo "  test      - Test installation"
        echo "  yt-test   - Test YouTube download"
        echo "  fix       - Fix common issues"
        echo ""
        echo "✨ Features:"
        echo "• Download YouTube videos"
        echo "• Extract audio (MP3, M4A)"
        echo "• Multiple quality options"
        echo "• Video information"
        echo "• Format listing"
        echo ""
        echo "🎬 Video Qualities:"
        echo "• 144p to 4K"
        echo "• Best quality auto-select"
        echo "• HD and Full HD"
        echo ""
        echo "🎵 Audio Formats:"
        echo "• MP3 (128kbps, 192kbps, 320kbps)"
        echo "• M4A (AAC)"
        echo "• Best quality"
        echo ""
        echo "Quick start:"
        echo "  1. youtube-bot setup"
        echo "  2. youtube-bot config  (add your token)"
        echo "  3. youtube-bot start"
        echo "  4. youtube-bot logs"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/youtube-bot
    print_success "Control script created"
}

# Create README file
create_readme() {
    print_info "Creating README file..."
    
    cat > /opt/youtube_bot/README.md << 'EOF'
# Telegram YouTube Downloader Bot

A complete Telegram bot for downloading YouTube videos and audio.

## Features
- Download YouTube videos in multiple qualities
- Extract audio as MP3 or M4A
- Support for YouTube Shorts
- Video information display
- Format listing
- Fast and reliable downloads

## Quick Start

1. **Get a Telegram Bot Token:**
   - Open Telegram
   - Search for @BotFather
   - Send `/newbot`
   - Follow instructions
   - Copy the bot token

2. **Configure the Bot:**
   ```bash
   youtube-bot setup
   youtube-bot config
