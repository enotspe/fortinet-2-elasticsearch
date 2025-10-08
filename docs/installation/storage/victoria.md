# Victoria Logs

Victoria Logs is a high-performance log management system that can be integrated with FortiDragon.

## Installation as systemd Service

### Prerequisites

Set version, architecture and OS:

```bash
# Check for latest release of Victoria Logs
VICTORIALOGS_VERSION=$(curl --silent "https://api.github.com/repos/VictoriaMetrics/VictoriaLogs/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
# Choose your architecture
# amd64 arm64 386
VICTORIALOGS_ARCH=amd64
# Choose your S.O.
# darwin freebsd linux openbsd windows
VICTORIALOGS_SO=linux
```

### Download and Install

Download binary:

```bash
curl -L -O https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/v$VICTORIALOGS_VERSION-victorialogs/victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-v$VICTORIALOGS_VERSION-victorialogs.tar.gz
tar xzf victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-v$VICTORIALOGS_VERSION-victorialogs.tar.gz
```

Move binary to `/usr/local/bin`:

```bash
sudo mv victoria-logs-prod /usr/local/bin
```

### System Setup

Create victorialogs user:

```bash
sudo useradd -s /usr/sbin/nologin victorialogs
```

Change ownership to victorialogs user:

```bash
sudo chown victorialogs:victorialogs /usr/local/bin/victoria-logs-prod
```

In case you run SELlinux, change SELlinux permission:

```bash
sudo restorecon -v /usr/local/bin/victoria-logs-prod
```

Create victorialogs data directory:

```bash
sudo mkdir -p /var/lib/victoria-logs-data && sudo chown -R victorialogs:victorialogs /var/lib/victoria-logs-data
```

### Service Configuration

Create `victorialogs` service:

```bash
sudo vim /etc/systemd/system/victorialogs.service
```

The file should look like:

```ini
[Unit]
Description=VictoriaLogs service
After=network.target

[Service]
Type=simple
User=victorialogs
Group=victorialogs
ExecStart=/usr/local/bin/victoria-logs-prod -storageDataPath=/var/lib/victoria-logs-data -search.maxQueryDuration=600s -search.maxQueueDuration=600s -retentionPeriod=365d -retention.maxDiskUsagePercent=80
SyslogIdentifier=victorialogs
Restart=always

PrivateTmp=yes
ProtectHome=yes
NoNewPrivileges=yes

ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

### Retention Configuration

Note that `-retention*` parameters control lifecycle of ingested logs:

```bash
-retentionPeriod=365d
-retention.maxDiskUsagePercent=80
```
Adjust these values based on your storage requirements and retention policies.

### Query Configuration

Note that `-search*` parameters control query execution:

```bash
-search.maxQueryDuration=600s 
-search.maxQueueDuration=600s
```

[Victoria Logs flags](https://docs.victoriametrics.com/victorialogs/#list-of-command-line-flags)

### Start Service

Start and enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable victorialogs
sudo systemctl start victorialogs
sudo systemctl status victorialogs
```

### Verification

Check version:

```bash
victoria-logs-prod --version
```

Check service status:

```bash
sudo systemctl status victorialogs
```

Check logs:

```bash
sudo journalctl -u victorialogs -f
```


Refer to the [Victoria Logs documentation](https://docs.victoriametrics.com/VictoriaLogs/) for detailed configuration options.
