#!/bin/bash

# Telegram YouTube Video Downloader Bot Installer
# Fixed EOF Version

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
    echo "   TELEGRAM YOUTUBE DOWNLOADER BOT"
    echo "         COMPLETE INSTALLATION"
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
    pip3 install python-telegram-bot yt-dlp requests
    
    print_success "Python packages installed"
}

# Create bot directory
create_bot_dir() {
    print_info "Creating bot directory..."
    
    rm -rf /opt/youtube_bot
    mkdir -p /opt/youtube_bot
    cd /opt/youtube_bot
    
    print_success "Directory created: /opt/youtube_bot"
}

# Create bot.py script
create_bot_script() {
    print_info "Creating YouTube bot script..."
    
    # Create a simple bot script first
    cat > /opt/youtube_bot/bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
Simple Telegram YouTube Downloader Bot
"""

import os
import json
import logging
import subprocess
import re
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/opt/youtube_bot/bot.log'
)
logger = logging.getLogger(__name__)

# Bot token
BOT_TOKEN = os.getenv('BOT_TOKEN', '')

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    text = f"""
🎬 YouTube Downloader Bot

👋 Hello {user.first_name}!

I can download videos and audio from YouTube.

✨ Features:
• Download videos in multiple qualities
• Extract audio as MP3
• Fast and reliable

📌 How to use:
1. Send me any YouTube link
2. Choose video or audio
3. Select quality/format
4. Receive your file

🔗 Examples:
• https://youtube.com/watch?v=...
• https://youtu.be/...
• https://youtube.com/shorts/...

⚡ Commands:
/start - Show this message
/help - Help information
/audio <url> - Download audio
/video <url> - Download video
    """
    await update.message.reply_text(text)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    text = """
🤖 YouTube Bot Help

📌 How to download:
1. Send a YouTube link
2. Choose download type
3. Select quality/format
4. Wait for download
5. Receive your file

🎯 Quick Commands:
/audio <url> - Download audio
/video <url> - Download video

🎬 Video Qualities:
• 360p, 480p, 720p, 1080p
• Best quality

🎵 Audio Formats:
• MP3 (best quality)
• M4A

⚠️ Notes:
• Max video size: 2GB
• Max audio size: 500MB
    """
    await update.message.reply_text(text)

async def audio_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /audio command"""
    if not context.args:
        await update.message.reply_text("Usage: /audio <youtube-url>")
        return
    
    url = context.args[0]
    user_id = update.effective_user.id
    
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please provide a valid YouTube URL")
        return
    
    msg = await update.message.reply_text("🎵 Downloading audio...")
    
    try:
        # Download audio
        os.makedirs('/tmp/youtube_dl', exist_ok=True)
        os.chdir('/tmp/youtube_dl')
        
        cmd = [
            'yt-dlp',
            '-f', 'bestaudio',
            '-o', 'audio.%(ext)s',
            '--extract-audio',
            '--audio-format', 'mp3',
            '--add-metadata',
            '--embed-thumbnail',
            '--no-warnings',
            url
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            # Find audio file
            files = [f for f in os.listdir('.') if f.endswith('.mp3')]
            if files:
                audio_file = files[0]
                
                # Send audio
                with open(audio_file, 'rb') as f:
                    await context.bot.send_audio(
                        chat_id=user_id,
                        audio=f,
                        caption="✅ Downloaded from YouTube"
                    )
                
                # Cleanup
                os.remove(audio_file)
                await msg.delete()
            else:
                await msg.edit_text("❌ No audio file found")
        else:
            await msg.edit_text(f"❌ Download failed: {result.stderr[:200]}")
            
    except Exception as e:
        logger.error(f"Audio error: {e}")
        await msg.edit_text(f"❌ Error: {str(e)[:200]}")
    finally:
        os.chdir('/')

async def video_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /video command"""
    if not context.args:
        await update.message.reply_text("Usage: /video <youtube-url>")
        return
    
    url = context.args[0]
    user_id = update.effective_user.id
    
    if not is_youtube_url(url):
        await update.message.reply_text("❌ Please provide a valid YouTube URL")
        return
    
    msg = await update.message.reply_text("🎬 Downloading video...")
    
    try:
        # Download video
        os.makedirs('/tmp/youtube_dl', exist_ok=True)
        os.chdir('/tmp/youtube_dl')
        
        cmd = [
            'yt-dlp',
            '-f', 'best[ext=mp4]',
            '-o', 'video.%(ext)s',
            '--no-warnings',
            '--add-metadata',
            '--embed-thumbnail',
            url
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            # Find video file
            files = [f for f in os.listdir('.') if f.endswith('.mp4')]
            if files:
                video_file = files[0]
                
                # Send video
                with open(video_file, 'rb') as f:
                    await context.bot.send_video(
                        chat_id=user_id,
                        video=f,
                        caption="✅ Downloaded from YouTube",
                        supports_streaming=True
                    )
                
                # Cleanup
                os.remove(video_file)
                await msg.delete()
            else:
                await msg.edit_text("❌ No video file found")
        else:
            await msg.edit_text(f"❌ Download failed: {result.stderr[:200]}")
            
    except Exception as e:
        logger.error(f"Video error: {e}")
        await msg.edit_text(f"❌ Error: {str(e)[:200]}")
    finally:
        os.chdir('/')

def is_youtube_url(url):
    """Check if URL is from YouTube"""
    return 'youtube.com' in url.lower() or 'youtu.be' in url.lower()

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle incoming messages"""
    message = update.message
    url = message.text.strip()
    
    if not is_youtube_url(url):
        await message.reply_text("❌ Please send a valid YouTube URL")
        return
    
    # Show options
    keyboard = [
        [InlineKeyboardButton("🎬 Download Video", callback_data=f"video:{url}")],
        [InlineKeyboardButton("🎵 Download Audio", callback_data=f"audio:{url}")],
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await message.reply_text(
        "📺 YouTube Video Found!\n\nSelect download option:",
        reply_markup=reply_markup
    )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle callback queries"""
    query = update.callback_query
    await query.answer()
    
    callback_data = query.data
    user_id = query.from_user.id
    
    if callback_data.startswith('video:'):
        url = callback_data.split(':', 1)[1]
        await query.edit_message_text("🎬 Downloading video...")
        
        try:
            os.makedirs('/tmp/youtube_dl', exist_ok=True)
            os.chdir('/tmp/youtube_dl')
            
            cmd = [
                'yt-dlp',
                '-f', 'best[ext=mp4]',
                '-o', 'video.%(ext)s',
                '--no-warnings',
                url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                files = [f for f in os.listdir('.') if f.endswith('.mp4')]
                if files:
                    video_file = files[0]
                    
                    with open(video_file, 'rb') as f:
                        await context.bot.send_video(
                            chat_id=user_id,
                            video=f,
                            caption="✅ Downloaded from YouTube",
                            supports_streaming=True
                        )
                    
                    os.remove(video_file)
                    await query.edit_message_text("✅ Video sent!")
                else:
                    await query.edit_message_text("❌ No video file found")
            else:
                await query.edit_message_text("❌ Download failed")
                
        except Exception as e:
            logger.error(f"Callback video error: {e}")
            await query.edit_message_text(f"❌ Error: {str(e)[:200]}")
        finally:
            os.chdir('/')
    
    elif callback_data.startswith('audio:'):
        url = callback_data.split(':', 1)[1]
        await query.edit_message_text("🎵 Downloading audio...")
        
        try:
            os.makedirs('/tmp/youtube_dl', exist_ok=True)
            os.chdir('/tmp/youtube_dl')
            
            cmd = [
                'yt-dlp',
                '-f', 'bestaudio',
                '-o', 'audio.%(ext)s',
                '--extract-audio',
                '--audio-format', 'mp3',
                '--no-warnings',
                url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                files = [f for f in os.listdir('.') if f.endswith('.mp3')]
                if files:
                    audio_file = files[0]
                    
                    with open(audio_file, 'rb') as f:
                        await context.bot.send_audio(
                            chat_id=user_id,
                            audio=f,
                            caption="✅ Downloaded from YouTube"
                        )
                    
                    os.remove(audio_file)
                    await query.edit_message_text("✅ Audio sent!")
                else:
                    await query.edit_message_text("❌ No audio file found")
            else:
                await query.edit_message_text("❌ Download failed")
                
        except Exception as e:
            logger.error(f"Callback audio error: {e}")
            await query.edit_message_text(f"❌ Error: {str(e)[:200]}")
        finally:
            os.chdir('/')

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
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    app.add_error_handler(error_handler)
    
    print("🤖 YouTube Bot starting...")
    app.run_polling()

if __name__ == '__main__':
    main()
BOTEOF
    
    chmod +x /opt/youtube_bot/bot.py
    print_success "YouTube bot script created"
}

# Create environment file
create_env_file() {
    print_info "Creating environment file..."
    
    cat > /opt/youtube_bot/.env.example << ENVEOF
# Telegram Bot Token from @BotFather
# Example: 1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ
BOT_TOKEN=your_bot_token_here
ENVEOF
    
    print_success "Environment file created"
}

# Create service file
create_service_file() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/youtube-bot.service << SERVICEEOF
[Unit]
Description=Telegram YouTube Downloader Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/youtube_bot
EnvironmentFile=/opt/youtube_bot/.env
ExecStart=/usr/bin/python3 /opt/youtube_bot/bot.py
Restart=always
RestartSec=10

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
        journalctl -u youtube-bot -f
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
        pip3 install --upgrade yt-dlp python-telegram-bot
        systemctl restart youtube-bot
        echo "✅ Bot updated"
        ;;
    test)
        echo "🧪 Testing YouTube Bot..."
        echo ""
        echo "Testing packages..."
        python3 -c "import telegram, yt_dlp; print('✅ Packages OK')"
        echo ""
        echo "Testing yt-dlp..."
        yt-dlp --version
        ;;
    *)
        echo "🤖 YouTube Downloader Bot"
        echo ""
        echo "Usage: \$0 {start|stop|restart|status|logs|setup|config|update|test}"
        echo ""
        echo "Commands:"
        echo "  start     - Start bot"
        echo "  stop      - Stop bot"
        echo "  restart   - Restart bot"
        echo "  status    - Check status"
        echo "  logs      - View logs"
        echo "  setup     - Setup bot"
        echo "  config    - Edit config"
        echo "  update    - Update bot"
        echo "  test      - Test bot"
        echo ""
        echo "Quick start:"
        echo "  1. youtube-bot setup"
        echo "  2. youtube-bot config  (add token)"
        echo "  3. youtube-bot start"
        echo "  4. youtube-bot logs"
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
    
    echo -e "\n${YELLOW}📋 SETUP STEPS:${NC}"
    echo "1. Setup bot:"
    echo "   youtube-bot setup"
    echo ""
    echo "2. Add your bot token:"
    echo "   youtube-bot config"
    echo "   • Add BOT_TOKEN from @BotFather"
    echo ""
    echo "3. Start bot:"
    echo "   youtube-bot start"
    echo ""
    echo "4. Check status:"
    echo "   youtube-bot status"
    echo "   youtube-bot logs"
    echo ""
    
    echo -e "${YELLOW}🎬 HOW TO USE:${NC}"
    echo "1. Send YouTube link to bot"
    echo "2. Choose 'Download Video' or 'Download Audio'"
    echo "3. Wait for download"
    echo "4. Receive file"
    echo ""
    
    echo -e "${YELLOW}⚡ QUICK COMMANDS:${NC}"
    echo "/audio <url> - Download audio"
    echo "/video <url> - Download video"
    echo ""
    
    echo -e "${GREEN}✅ Ready to use!${NC}"
}

# Main installation
main() {
    show_logo
    print_info "Starting installation..."
    
    install_deps
    install_python_packages
    create_bot_dir
    create_bot_script
    create_env_file
    create_service_file
    create_control_script
    show_completion
}

# Run installation
main
