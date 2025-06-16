#!/bin/bash

# 🇮🇷 Iran Server Optimizer for VPN/Xray Tunneling
# Version: 1.0.0
# Purpose: Optimize Iranian servers for stable VPN tunneling

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "این اسکریپت باید با دسترسی root اجرا شود!"
        echo "لطفاً با sudo اجرا کنید: sudo bash $0"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        error "نمی‌توان سیستم عامل را تشخیص داد!"
        exit 1
    fi
    
    log "سیستم عامل تشخیص داده شد: $OS $VER"
}

# Update system packages
update_system() {
    log "🔄 به‌روزرسانی سیستم..."
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get upgrade -y
        apt-get install -y curl wget unzip socat cron bash-completion
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y curl wget unzip socat cronie bash-completion
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        dnf install -y curl wget unzip socat cronie bash-completion
    else
        error "Package manager پیدا نشد!"
        exit 1
    fi
    
    log "✅ سیستم به‌روزرسانی شد"
}

# Configure Iranian DNS servers
setup_dns() {
    log "🌐 تنظیم DNS سرورهای ایرانی..."
    
    # Backup original resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.backup
    
    # Iranian DNS servers (reliable ones)
    cat > /etc/resolv.conf << 'EOF'
# Iranian DNS Servers - Optimized for Iran
nameserver 178.22.122.100    # Shecan Primary
nameserver 185.51.200.2      # Shecan Secondary
nameserver 10.202.10.202     # Pishgaman
nameserver 10.202.10.102     # Pishgaman Secondary
nameserver 8.8.8.8           # Google (backup)
nameserver 1.1.1.1           # Cloudflare (backup)

options timeout:2
options attempts:3
options rotate
EOF
    
    # Make it immutable to prevent overwriting
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    # Configure systemd-resolved if present
    if systemctl is-active --quiet systemd-resolved; then
        mkdir -p /etc/systemd/resolved.conf.d/
        cat > /etc/systemd/resolved.conf.d/iran-dns.conf << 'EOF'
[Resolve]
DNS=178.22.122.100 185.51.200.2 10.202.10.202 10.202.10.102
FallbackDNS=8.8.8.8 1.1.1.1
Cache=yes
DNSStubListener=yes
EOF
        systemctl restart systemd-resolved
    fi
    
    log "✅ DNS سرورهای ایرانی تنظیم شد"
}

# Optimize network settings for Iran
optimize_network() {
    log "⚡ بهینه‌سازی تنظیمات شبکه برای ایران..."
    
    # Backup original sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.backup
    
    # Network optimizations for Iranian servers
    cat >> /etc/sysctl.conf << 'EOF'

# 🇮🇷 Iran Server Network Optimizations
# TCP optimizations for high latency connections
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600

# TCP buffer sizes (min, default, max)
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP congestion control - BBR is best for high latency
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP optimizations for Iran's network conditions
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_mtu_probing = 1

# Reduce TIME_WAIT connections
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Increase connection tracking
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_established = 7200

# IP forwarding for tunneling
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Disable IPv6 if causing issues
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0

# Security optimizations
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# File descriptor limits
fs.file-max = 1000000
fs.nr_open = 1000000
EOF
    
    # Apply sysctl settings
    sysctl -p
    
    log "✅ تنظیمات شبکه بهینه شد"
}

# Configure firewall for VPN/Xray
setup_firewall() {
    log "🔥 تنظیم فایروال برای VPN/Xray..."
    
    # Install ufw if not present
    if ! command -v ufw >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get install -y ufw
        elif command -v yum >/dev/null 2>&1; then
            yum install -y ufw
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y ufw
        fi
    fi
    
    # Reset UFW rules
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Essential ports
    ufw allow ssh
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Common VPN/Xray ports
    ufw allow 8080/tcp
    ufw allow 8443/tcp
    ufw allow 2053/tcp
    ufw allow 2083/tcp
    ufw allow 2087/tcp
    ufw allow 2096/tcp
    ufw allow 8880/tcp
    
    # Enable UFW
    ufw --force enable
    
    log "✅ فایروال تنظیم شد"
}

# Optimize system limits
optimize_limits() {
    log "📊 بهینه‌سازی محدودیت‌های سیستم..."
    
    # Backup original limits
    cp /etc/security/limits.conf /etc/security/limits.conf.backup
    
    # Add optimized limits
    cat >> /etc/security/limits.conf << 'EOF'

# 🇮🇷 Iran Server Limits Optimization
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
EOF
    
    # Configure systemd limits
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
EOF
    
    # Configure systemd user limits
    mkdir -p /etc/systemd/user.conf.d/
    cat > /etc/systemd/user.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
EOF
    
    log "✅ محدودیت‌های سیستم بهینه شد"
}

# Install useful tools for Iran
install_tools() {
    log "🛠️ نصب ابزارهای مفید..."
    
    # Essential networking tools
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y \
            net-tools \
            dnsutils \
            traceroute \
            mtr-tiny \
            tcpdump \
            iftop \
            htop \
            iotop \
            ncdu \
            tree \
            jq \
            git \
            screen \
            tmux \
            nano \
            vim \
            zip \
            unzip \
            tar \
            gzip
    elif command -v yum >/dev/null 2>&1; then
        yum install -y \
            net-tools \
            bind-utils \
            traceroute \
            mtr \
            tcpdump \
            iftop \
            htop \
            iotop \
            ncdu \
            tree \
            jq \
            git \
            screen \
            tmux \
            nano \
            vim \
            zip \
            unzip \
            tar \
            gzip
    fi
    
    log "✅ ابزارهای مفید نصب شد"
}

# Setup automatic updates
setup_auto_updates() {
    log "🔄 تنظیم به‌روزرسانی خودکار..."
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y unattended-upgrades
        dpkg-reconfigure -plow unattended-upgrades
    fi
    
    # Setup cron job for system maintenance
    cat > /etc/cron.daily/iran-server-maintenance << 'EOF'
#!/bin/bash
# Daily maintenance for Iran server

# Clean package cache
if command -v apt-get >/dev/null 2>&1; then
    apt-get autoremove -y
    apt-get autoclean -y
elif command -v yum >/dev/null 2>&1; then
    yum autoremove -y
    yum clean all
fi

# Clean logs older than 7 days
find /var/log -name "*.log" -mtime +7 -delete 2>/dev/null || true
find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true

# Restart networking if needed
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    systemctl restart networking 2>/dev/null || true
    systemctl restart network 2>/dev/null || true
fi
EOF
    
    chmod +x /etc/cron.daily/iran-server-maintenance
    
    log "✅ به‌روزرسانی خودکار تنظیم شد"
}

# Create monitoring script
create_monitoring() {
    log "📊 ایجاد اسکریپت مانیتورینگ..."
    
    cat > /usr/local/bin/iran-server-status << 'EOF'
#!/bin/bash

# 🇮🇷 Iran Server Status Monitor

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🇮🇷 Iran Server Status Report${NC}"
echo "=================================="
echo

# System Info
echo -e "${GREEN}📊 System Information:${NC}"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "Disk Usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo

# Network Status
echo -e "${GREEN}🌐 Network Status:${NC}"

# DNS Test
if nslookup google.com >/dev/null 2>&1; then
    echo -e "DNS Resolution: ${GREEN}✅ Working${NC}"
else
    echo -e "DNS Resolution: ${RED}❌ Failed${NC}"
fi

# Internet Connectivity
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "Internet (IPv4): ${GREEN}✅ Connected${NC}"
else
    echo -e "Internet (IPv4): ${RED}❌ Disconnected${NC}"
fi

# Speed test to common Iranian sites
echo -e "Connection Speed Test:"
echo -n "  - Google.com: "
GOOGLE_TIME=$(curl -o /dev/null -s -w '%{time_total}' --connect-timeout 5 https://google.com 2>/dev/null || echo "timeout")
if [[ "$GOOGLE_TIME" != "timeout" ]]; then
    echo -e "${GREEN}${GOOGLE_TIME}s${NC}"
else
    echo -e "${RED}Timeout${NC}"
fi

echo -n "  - Cloudflare: "
CF_TIME=$(curl -o /dev/null -s -w '%{time_total}' --connect-timeout 5 https://1.1.1.1 2>/dev/null || echo "timeout")
if [[ "$CF_TIME" != "timeout" ]]; then
    echo -e "${GREEN}${CF_TIME}s${NC}"
else
    echo -e "${RED}Timeout${NC}"
fi
echo

# Active Connections
echo -e "${GREEN}🔗 Active Connections:${NC}"
echo "Total: $(ss -tuln | wc -l)"
echo "TCP: $(ss -tln | wc -l)"
echo "UDP: $(ss -uln | wc -l)"
echo

# Top Processes
echo -e "${GREEN}🔝 Top Processes (CPU):${NC}"
ps aux --sort=-%cpu | head -6 | tail -5
echo

# Firewall Status
echo -e "${GREEN}🔥 Firewall Status:${NC}"
if command -v ufw >/dev/null 2>&1; then
    ufw status | head -10
else
    echo "UFW not installed"
fi
EOF
    
    chmod +x /usr/local/bin/iran-server-status
    
    # Create alias
    echo "alias status='iran-server-status'" >> /root/.bashrc
    echo "alias iran-status='iran-server-status'" >> /root/.bashrc
    
    log "✅ اسکریپت مانیتورینگ ایجاد شد"
    info "برای مشاهده وضعیت سرور: iran-server-status یا status"
}

# Create backup script
create_backup_script() {
    log "💾 ایجاد اسکریپت پشتیبان‌گیری..."
    
    cat > /usr/local/bin/iran-server-backup << 'EOF'
#!/bin/bash

# 🇮🇷 Iran Server Configuration Backup

BACKUP_DIR="/root/server-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/iran-server-backup-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "🇮🇷 Creating Iran Server Configuration Backup..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)

# Copy important configurations
mkdir -p "$TEMP_DIR/etc"
cp -r /etc/sysctl.conf* "$TEMP_DIR/etc/" 2>/dev/null || true
cp -r /etc/resolv.conf* "$TEMP_DIR/etc/" 2>/dev/null || true
cp -r /etc/security/limits.conf* "$TEMP_DIR/etc/" 2>/dev/null || true
cp -r /etc/systemd/system.conf.d "$TEMP_DIR/etc/" 2>/dev/null || true
cp -r /etc/systemd/resolved.conf.d "$TEMP_DIR/etc/" 2>/dev/null || true

# Copy scripts
mkdir -p "$TEMP_DIR/scripts"
cp /usr/local/bin/iran-server-* "$TEMP_DIR/scripts/" 2>/dev/null || true

# Create info file
cat > "$TEMP_DIR/backup-info.txt" << EOL
Iran Server Backup Information
==============================
Date: $(date)
Hostname: $(hostname)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Uptime: $(uptime -p)
EOL

# Create archive
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .

# Cleanup
rm -rf "$TEMP_DIR"

echo "✅ Backup created: $BACKUP_FILE"
echo "📁 Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Keep only last 5 backups
cd "$BACKUP_DIR"
ls -t iran-server-backup-*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null || true

echo "🗂️ Backup directory: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
EOF
    
    chmod +x /usr/local/bin/iran-server-backup
    
    log "✅ اسکریپت پشتیبان‌گیری ایجاد شد"
    info "برای پشتیبان‌گیری: iran-server-backup"
}

# Test connectivity
test_connectivity() {
    log "🧪 تست اتصال و عملکرد..."
    
    echo
    info "تست DNS..."
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS working${NC}"
    else
        echo -e "${RED}❌ DNS failed${NC}"
    fi
    
    info "تست اتصال اینترنت..."
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Internet connectivity OK${NC}"
    else
        echo -e "${RED}❌ Internet connectivity failed${NC}"
    fi
    
    info "تست سرعت اتصال..."
    GOOGLE_TIME=$(curl -o /dev/null -s -w '%{time_total}' --connect-timeout 10 https://google.com 2>/dev/null || echo "timeout")
    if [[ "$GOOGLE_TIME" != "timeout" ]]; then
        echo -e "${GREEN}✅ Google response time: ${GOOGLE_TIME}s${NC}"
    else
        echo -e "${YELLOW}⚠️ Google timeout${NC}"
    fi
    
    echo
}

# Main execution
main() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════╗
║        🇮🇷 Iran Server Optimizer        ║
║     بهینه‌ساز سرور ایرانی برای VPN      ║
║                                      ║
║  • بهینه‌سازی DNS و شبکه              ║
║  • تنظیم فایروال                      ║
║  • نصب ابزارهای مفید                  ║
║  • مانیتورینگ و پشتیبان‌گیری          ║
╚══════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "🚀 شروع بهینه‌سازی سرور ایرانی..."
    
    check_root
    detect_os
    
    log "📦 مرحله 1: به‌روزرسانی سیستم"
    update_system
    
    log "🌐 مرحله 2: تنظیم DNS ایرانی"
    setup_dns
    
    log "⚡ مرحله 3: بهینه‌سازی شبکه"
    optimize_network
    
    log "🔥 مرحله 4: تنظیم فایروال"
    setup_firewall
    
    log "📊 مرحله 5: بهینه‌سازی محدودیت‌ها"
    optimize_limits
    
    log "🛠️ مرحله 6: نصب ابزارها"
    install_tools
    
    log "🔄 مرحله 7: تنظیم به‌روزرسانی خودکار"
    setup_auto_updates
    
    log "📊 مرحله 8: ایجاد مانیتورینگ"
    create_monitoring
    
    log "💾 مرحله 9: ایجاد پشتیبان‌گیری"
    create_backup_script
    
    log "🧪 مرحله 10: تست نهایی"
    test_connectivity
    
    echo
    echo -e "${GREEN}🎉 بهینه‌سازی سرور ایرانی با موفقیت تکمیل شد!${NC}"
    echo
    echo -e "${CYAN}📋 دستورات مفید:${NC}"
    echo -e "  • ${YELLOW}iran-server-status${NC} - مشاهده وضعیت سرور"
    echo -e "  • ${YELLOW}iran-server-backup${NC} - پشتیبان‌گیری از تنظیمات"
    echo -e "  • ${YELLOW}status${NC} - مشاهده سریع وضعیت"
    echo
    echo -e "${BLUE}🔄 برای اعمال کامل تنظیمات، سرور را ری‌استارت کنید:${NC}"
    echo -e "  ${YELLOW}reboot${NC}"
    echo
    
    # Create installation info
    cat > /root/iran-server-optimizer-info.txt << EOF
🇮🇷 Iran Server Optimizer Installation Info
==========================================

Installation Date: $(date)
Server IP: $(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
Hostname: $(hostname)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)

Optimizations Applied:
✅ Iranian DNS servers configured
✅ Network settings optimized for high latency
✅ Firewall configured for VPN/Xray
✅ System limits increased
✅ Monitoring tools installed
✅ Auto-updates configured

Useful Commands:
- iran-server-status  : Check server status
- iran-server-backup  : Backup configurations
- status              : Quick status check

DNS Servers Used:
- 178.22.122.100 (Shecan Primary)
- 185.51.200.2   (Shecan Secondary)
- 10.202.10.202  (Pishgaman)
- 10.202.10.102  (Pishgaman Secondary)

Next Steps:
1. Reboot server: reboot
2. Install your VPN/Xray software
3. Configure tunneling to foreign servers

For support: Check /var/log/iran-server-optimizer.log
EOF
    
    info "اطلاعات نصب در /root/iran-server-optimizer-info.txt ذخیره شد"
}

# Run main function
main "$@"
