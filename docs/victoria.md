# Install Victorialogs as systemd service

set version architecture and SO
```
# check for releases https://github.com/VictoriaMetrics/VictoriaMetrics/releases
VICTORIALOGS_VERSION=1.22.2
#amd64 arm64 386
VICTORIALOGS_ARCH=amd64
#darwin freebsd linux openbsd windows
VICTORIALOGS_SO=linux
```

download binary
```
curl -L -O https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v$VICTORIALOGS_VERSION-victorialogs/victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-v$VICTORIALOGS_VERSION-victorialogs.tar.gz
tar xzf victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-v$VICTORIALOGS_VERSION-victorialogs.tar.gz
```

move binary to /usr/lccal/bin
```
sudo mv victoria-logs-prod /usr/local/bin
```

create victorialogs user
```
sudo useradd -s /usr/sbin/nologin victorialogs
```

create victorialogs data directory
```
sudo mkdir -p /var/lib/victoria-logs-data && sudo chown -R victorialogs:victorialogs /var/lib/victoria-logs-data
```

create victorialogs service
```
sudo vim /etc/systemd/system/victorialogs.service
```

the file should look like
```
[Unit]
Description=VictoriaLogs service
After=network.target

[Service]
Type=simple
User=victorialogs
Group=victorialogs
ExecStart=/usr/local/bin/victoria-logs-prod -storageDataPath=/var/lib/victoria-logs-data -search.maxQueryDuration=60s -retentionPeriod=365d -retention.maxDiskSpaceUsageBytes=800GiB
SyslogIdentifier=victorialogs
Restart=always

PrivateTmp=yes
ProtectHome=yes
NoNewPrivileges=yes

ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

notice that  -retention* parameters will control lifecycle of ingested logs
```
-retentionPeriod=365d
-retention.maxDiskSpaceUsageBytes=800GiB
```

start service
```
sudo systemctl daemon-reload
sudo systemctl enable victorialogs
sudo systemctl start victorialogs
sudo systemctl status victorialogs
```

check version
```
victoria-logs-prod --version
```
