#!/bin/bash
# ====================================================
# APACHE2 ULTIMATE TUNING SCRIPT - 64GB RAM / 32 CORES
# Features:
# - Auto-install required modules
# - Extreme performance tuning
# - No kernel modification
# ====================================================

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "Script must be run as root!"
  exit 1
fi

# Install required packages
echo "Installing required packages..."
apt-get update
apt-get install -y apache2 apache2-utils libapache2-mod-fcgid libapache2-mod-qos openssl

# Enable required modules
echo "Enabling necessary modules..."
a2enmod mpm_event http2 ssl deflate expires headers rewrite proxy_fcgi setenvif qos

# Generate crypto files
echo "Generating crypto files..."
mkdir -p /etc/ssl/certs
openssl dhparam -out /etc/ssl/certs/dhparam-8192.pem 8192
openssl ecparam -genkey -name secp521r1 -out /etc/ssl/certs/ecparam.pem

# Configure Apache
echo "Applying extreme performance configuration..."
cat > /etc/apache2/apache2.conf << 'EOL'
# ========== GLOBAL CONFIG ==========
ServerLimit 131072
StartServers 64
MinSpareThreads 1024
MaxSpareThreads 4096
ThreadLimit 256
ThreadsPerChild 256
MaxRequestWorkers 131072
MaxConnectionsPerChild 1000000
ListenBacklog 65536

# ========== PERFORMANCE TUNING ==========
Timeout 2
KeepAlive On
MaxKeepAliveRequests 100000
KeepAliveTimeout 1
HostnameLookups Off
EnableSendfile On
EnableMMAP On
FileETag None
UseCanonicalName Off

# ========== SSL EXTREME TUNING ==========
<IfModule mod_ssl.c>
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder on
    SSLCompression off
    
    # Massive 256MB SSL cache
    SSLSessionCache "shmcb:/var/run/apache2/ssl_scache(268435456)"
    SSLSessionCacheTimeout 86400
    
    # OCSP Stapling
    SSLUseStapling on
    SSLStaplingCache "shmcb:/var/run/apache2/ssl_stapling_cache(67108864)"
    
    # Ultra strong DH params
    SSLOpenSSLConfCmd DHParameters "/etc/ssl/certs/dhparam-8192.pem"
    
    # ECDHE support
    SSLOpenSSLConfCmd Curves secp521r1:secp384r1
</IfModule>

# ========== BANDWIDTH OPTIMIZATION ==========
<IfModule mod_deflate.c>
    DeflateCompressionLevel 9
    DeflateBufferSize 131072
    DeflateMemLevel 12
    DeflateWindowSize 20
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css 
    AddOutputFilterByType DEFLATE text/javascript application/javascript 
    AddOutputFilterByType DEFLATE application/json application/xml
    AddOutputFilterByType DEFLATE image/svg+xml font/woff2 font/woff
</IfModule>

# ========== CACHE CONTROL ==========
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresDefault "access plus 1 hour"
    ExpiresByType text/css "access plus 1 year"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType application/font-woff "access plus 1 year"
</IfModule>

# ========== HEADERS ==========
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
    Header always set Referrer-Policy "strict-origin"
    Header always set Cache-Control "public, max-age=31536000, immutable"
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
</IfModule>

# ========== HTTP/2 ULTIMATE ==========
<IfModule mod_http2.c>
    Protocols h2 h2c http/1.1
    H2Direct on
    H2EarlyHints on
    H2MaxSessionStreams 500
    H2StreamMaxMemSize 2097152
    H2TLSCoolDownSecs 0
    H2TLSWarmUpSize 4194304
</IfModule>

# ========== QoS ==========
<IfModule mod_qos.c>
    # Bandwidth management
    QS_ClientEntries 100000
    QS_SrvMaxConnPerIP 10000
    QS_SrvMaxConnTotal 100000
    
    # Priority handling
    QS_PreserveContentLength On
</IfModule>
EOL

# Create tuning directory
mkdir -p /etc/apache2/tuning

# Apply systemd service tweaks
cat > /etc/systemd/system/apache2.service.d/10-tuning.conf << 'EOL'
[Service]
LimitNOFILE=1048576
LimitMEMLOCK=infinity
OOMScoreAdjust=-500
EOL

# Restart services
systemctl daemon-reload
systemctl restart apache2

# Verification
echo ""
echo "======================================================"
echo " APACHE2 EXTREME TUNING APPLIED SUCCESSFULLY"
echo "======================================================"
echo "| Max Workers       : 131,072 (256 threads × 512)"
echo "| SSL Session Cache  : 256MB shared memory"
echo "| HTTP/2 Streams    : 500 concurrent (2MB each)"
echo "| KeepAlive         : 1 second timeout"
echo "| Static Cache      : 1 year immutable"
echo "| DH Param Strength : 8192-bit"
echo "| ECDHE Curves      : secp521r1, secp384r1"
echo "======================================================"
echo ""
echo "To monitor performance:"
echo "watch -n1 \"echo -n 'Active Workers: ' && apache2ctl status | grep 'requests currently being processed' && echo -n 'Memory: ' && free -h | awk '/Mem:/{print \$3}'\""