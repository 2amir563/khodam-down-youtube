



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
