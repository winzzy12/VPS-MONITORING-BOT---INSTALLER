#!/bin/bash

# VPS Monitoring Bot - Installation Script
# Usage: bash install_vps_monitor.sh

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  _"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Input VPS Name
echo "📝 Enter VPS Name (e.g., Mining VPS, Production Server):"
read -p "  VPS Name: " VPS_NAME
if [ -z "$VPS_NAME" ]; then
    VPS_NAME="Mining VPS"
    echo "  → Using default: $VPS_NAME"
fi
echo ""

# Input Bot Token
echo "🤖 Enter Telegram Bot Token:"
read -p "  Bot Token: " BOT_TOKEN
if [ -z "$BOT_TOKEN" ]; then
    echo "  ❌ Bot token is required!"
    exit 1
fi
echo ""

# Input Chat ID
echo "💬 Enter Telegram Chat ID (group ID, usually starts with -100):"
read -p "  Chat ID: " CHAT_ID
if [ -z "$CHAT_ID" ]; then
    echo "  ❌ Chat ID is required!"
    exit 1
fi
echo ""

# Input Thread ID
echo "🧵 Enter Telegram Topic/Thread ID (number):"
read -p "  Thread ID: " THREAD_ID
if [ -z "$THREAD_ID" ]; then
    echo "  ❌ Thread ID is required!"
    exit 1
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CONFIGURATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VPS Name    : $VPS_NAME"
echo "  Bot Token   : ${BOT_TOKEN:0:20}..."
echo "  Chat ID     : $CHAT_ID"
echo "  Thread ID   : $THREAD_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Continue with installation? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Installation cancelled."
    exit 0
fi
echo ""

# Install directory
INSTALL_DIR="$HOME/vps_monitor"
mkdir -p "$INSTALL_DIR"

echo "📦 Installing dependencies..."
pip install requests psutil -q 2>/dev/null || pip3 install requests psutil -q
echo "  ✓ Dependencies installed"
echo ""

# Create bot script
echo "📝 Creating bot script..."
cat > "$INSTALL_DIR/vps_monitor_bot.py" << 'BOTSCRIPT'
#!/usr/bin/env python3
import os
import json
import time
import subprocess
import requests
from datetime import datetime
import psutil
import socket

# Bot config (will be replaced by installer)
BOT_TOKEN = "{{BOT_TOKEN}}"
CHAT_ID = "{{CHAT_ID}}"
THREAD_ID = "{{THREAD_ID}}"
VPS_NAME = "{{VPS_NAME}}"

TELEGRAM_API = f"https://api.telegram.org/bot{BOT_TOKEN}"

def get_gpu_stats():
    """Get GPU statistics using nvidia-smi"""
    try:
        result = subprocess.check_output(
            "nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader,nounits",
            shell=True,
            timeout=5
        ).decode().strip()
        
        gpus = []
        for line in result.split('\n'):
            if line.strip():
                parts = [p.strip() for p in line.split(',')]
                gpu = {
                    "index": parts[0],
                    "name": parts[1],
                    "gpu_util": float(parts[2]),
                    "mem_util": float(parts[3]),
                    "mem_used": float(parts[4]),
                    "mem_total": float(parts[5])
                }
                gpus.append(gpu)
        
        return gpus
    except Exception as e:
        return []

def get_vps_stats():
    """Get VPS statistics"""
    try:
        # Uptime
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = int(float(f.read().split()[0]))
            days = uptime_seconds // 86400
            hours = (uptime_seconds % 86400) // 3600
            minutes = (uptime_seconds % 3600) // 60
            uptime = f"{days}d {hours}h {minutes}m"
        
        # OS
        os_info = subprocess.check_output("lsb_release -ds", shell=True).decode().strip()
        
        # CPU cores
        cpu_count = os.cpu_count()
        
        # CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # RAM usage
        ram = psutil.virtual_memory()
        ram_percent = ram.percent
        ram_used_gb = ram.used / (1024**3)
        ram_total_gb = ram.total / (1024**3)
        
        # GPU stats
        gpu_stats = get_gpu_stats()
        
        # Public IP
        try:
            public_ip = requests.get('https://api.ipify.org', timeout=5).text
        except:
            public_ip = "N/A"
        
        return {
            "uptime": uptime,
            "os": os_info,
            "cores": cpu_count,
            "cpu_percent": cpu_percent,
            "ram_percent": ram_percent,
            "ram_used": f"{ram_used_gb:.1f}GB",
            "ram_total": f"{ram_total_gb:.1f}GB",
            "gpu_stats": gpu_stats,
            "public_ip": public_ip,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        return {"error": str(e)}

def format_message(stats):
    """Format stats into Telegram message"""
    if "error" in stats:
        return f"❌ Error: {stats['error']}"
    
    # CPU bar
    cpu_bar = "█" * int(stats['cpu_percent'] / 5) + "░" * (20 - int(stats['cpu_percent'] / 5))
    
    # RAM bar
    ram_bar = "█" * int(stats['ram_percent'] / 5) + "░" * (20 - int(stats['ram_percent'] / 5))
    
    message = f"""━━━━━━━━━━━━━━━━━━━━━
🖥  VPS MONITOR  |  {VPS_NAME}
━━━━━━━━━━━━━━━━━━━━━
⏰  Uptime     : {stats['uptime']}
🛠  OS         : {stats['os']}
🔢  Cores      : {stats['cores']}
📊  CPU Usage  : {stats['cpu_percent']:.1f}% {cpu_bar}
💾  RAM Usage  : {stats['ram_percent']:.1f}% {ram_bar}
                ({stats['ram_used']}/{stats['ram_total']})
"""
    
    # Add GPU stats if available
    if stats['gpu_stats']:
        message += "━━━━━━━━━━━━━━━━━━━━━\n"
        for gpu in stats['gpu_stats']:
            gpu_bar = "█" * int(gpu['gpu_util'] / 5) + "░" * (20 - int(gpu['gpu_util'] / 5))
            mem_bar = "█" * int(gpu['mem_util'] / 5) + "░" * (20 - int(gpu['mem_util'] / 5))
            
            message += f"""🎮  GPU {gpu['index']}: {gpu['name']}
    GPU: {gpu['gpu_util']:.1f}% {gpu_bar}
    MEM: {gpu['mem_util']:.1f}% {mem_bar}
         ({gpu['mem_used']:.0f}MB/{gpu['mem_total']:.0f}MB)
"""
    
    message += f"""━━━━━━━━━━━━━━━━━━━━━
🌐  IP Public  : {stats['public_ip']}
━━━━━━━━━━━━━━━━━━━━━
🕐  Update: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC
"""
    return message

def send_telegram_message(text):
    """Send message to Telegram"""
    try:
        url = f"{TELEGRAM_API}/sendMessage"
        data = {
            "chat_id": CHAT_ID,
            "message_thread_id": THREAD_ID,
            "text": text,
            "parse_mode": "HTML"
        }
        response = requests.post(url, json=data, timeout=10)
        return response.status_code == 200
    except Exception as e:
        print(f"Error sending message: {e}")
        return False

def update_telegram_message(message_id, text):
    """Edit existing message"""
    try:
        url = f"{TELEGRAM_API}/editMessageText"
        data = {
            "chat_id": CHAT_ID,
            "message_id": message_id,
            "text": text,
            "parse_mode": "HTML"
        }
        response = requests.post(url, json=data, timeout=10)
        return response.status_code == 200
    except Exception as e:
        print(f"Error updating message: {e}")
        return False

def main():
    """Main monitoring loop"""
    print("VPS Monitoring Bot started...")
    print(f"VPS Name: {VPS_NAME}")
    print(f"Chat ID: {CHAT_ID}")
    print(f"Thread ID: {THREAD_ID}")
    print()
    
    message_id = None
    
    while True:
        try:
            # Get stats
            stats = get_vps_stats()
            message = format_message(stats)
            
            # Send or update message
            if message_id is None:
                # First message
                response = requests.post(
                    f"{TELEGRAM_API}/sendMessage",
                    json={
                        "chat_id": CHAT_ID,
                        "message_thread_id": THREAD_ID,
                        "text": message,
                        "parse_mode": "HTML"
                    },
                    timeout=10
                )
                if response.status_code == 200:
                    message_id = response.json()["result"]["message_id"]
                    print(f"[{datetime.utcnow().isoformat()}] Message sent (ID: {message_id})")
            else:
                # Update existing message
                response = requests.post(
                    f"{TELEGRAM_API}/editMessageText",
                    json={
                        "chat_id": CHAT_ID,
                        "message_id": message_id,
                        "text": message,
                        "parse_mode": "HTML"
                    },
                    timeout=10
                )
                if response.status_code == 200:
                    print(f"[{datetime.utcnow().isoformat()}] Message updated")
                else:
                    print(f"[{datetime.utcnow().isoformat()}] Update failed: {response.text}")
            
            # Wait 60 seconds
            time.sleep(60)
            
        except KeyboardInterrupt:
            print("\nBot stopped.")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(60)

if __name__ == "__main__":
    main()
BOTSCRIPT

# Replace placeholders
sed -i "s|{{BOT_TOKEN}}|$BOT_TOKEN|g" "$INSTALL_DIR/vps_monitor_bot.py"
sed -i "s|{{CHAT_ID}}|$CHAT_ID|g" "$INSTALL_DIR/vps_monitor_bot.py"
sed -i "s|{{THREAD_ID}}|$THREAD_ID|g" "$INSTALL_DIR/vps_monitor_bot.py"
sed -i "s|{{VPS_NAME}}|$VPS_NAME|g" "$INSTALL_DIR/vps_monitor_bot.py"

chmod +x "$INSTALL_DIR/vps_monitor_bot.py"
echo "  ✓ Bot script created"
echo ""

# Create systemd service
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/vps-monitor.service > /dev/null << SERVICECONFIG
[Unit]
Description=VPS Monitoring Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/vps_monitor_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICECONFIG

sudo systemctl daemon-reload
echo "  ✓ Systemd service created"
echo ""

# Create start/stop scripts
echo "📜 Creating helper scripts..."

cat > "$INSTALL_DIR/start.sh" << 'STARTSCRIPT'
#!/bin/bash
echo "Starting VPS Monitor Bot..."
sudo systemctl start vps-monitor
sudo systemctl status vps-monitor
STARTSCRIPT

cat > "$INSTALL_DIR/stop.sh" << 'STOPSCRIPT'
#!/bin/bash
echo "Stopping VPS Monitor Bot..."
sudo systemctl stop vps-monitor
echo "✓ Bot stopped"
STOPSCRIPT

cat > "$INSTALL_DIR/status.sh" << 'STATUSSCRIPT'
#!/bin/bash
echo "VPS Monitor Bot Status:"
sudo systemctl status vps-monitor
STATUSSCRIPT

cat > "$INSTALL_DIR/logs.sh" << 'LOGSSCRIPT'
#!/bin/bash
echo "VPS Monitor Bot Logs (last 50 lines):"
sudo journalctl -u vps-monitor -n 50 -f
LOGSSCRIPT

chmod +x "$INSTALL_DIR"/*.sh
echo "  ✓ Helper scripts created"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ INSTALLATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Installation Directory: $INSTALL_DIR"
echo ""
echo "🚀 To start the bot:"
echo "   bash $INSTALL_DIR/start.sh"
echo ""
echo "⏹️  To stop the bot:"
echo "   bash $INSTALL_DIR/stop.sh"
echo ""
echo "📊 To check status:"
echo "   bash $INSTALL_DIR/status.sh"
echo ""
echo "📋 To view logs:"
echo "   bash $INSTALL_DIR/logs.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✨ Bot will auto-start on system reboot"
echo ""
