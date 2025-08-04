# Victoria Logs Configuration

Victoria Logs is a high-performance log management system that can be integrated with FortiDragon.

## Installation as systemd Service

### Prerequisites

Set version, architecture and OS:

```bash
# Check for releases https://github.com/VictoriaMetrics/VictoriaMetrics/releases
VICTORIALOGS_VERSION=1.22.2
# amd64 arm64 386
VICTORIALOGS_ARCH=amd64
# darwin freebsd linux openbsd windows
VICTORIALOGS_SO=linux
```

### Download and Install

Download binary:

```bash
curl -L -O https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/v$VICTORIALOGS_VERSION-victorialogs/victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-v$VICTORIALOGS_VERSION-victorialogs.tar.gz
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

Create victorialogs data directory:

```bash
sudo mkdir -p /var/lib/victoria-logs-data && sudo chown -R victorialogs:victorialogs /var/lib/victoria-logs-data
```

### Service Configuration

Create victorialogs service:

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

### Retention Configuration

Note that `-retention*` parameters control lifecycle of ingested logs:

```bash
-retentionPeriod=365d
-retention.maxDiskSpaceUsageBytes=800GiB
```

Adjust these values based on your storage requirements and retention policies.

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

## Integration with FortiDragon

To integrate Victoria Logs with FortiDragon, you can:

1. **Use Vector** as a collector to send logs to both Elasticsearch and Victoria Logs
2. **Configure dual output** in your syslog collector
3. **Set up log forwarding** from Elasticsearch to Victoria Logs

Example Vector configuration for dual output:

```yaml
sinks:
  elasticsearch:
    type: elasticsearch
    # ... elasticsearch config
  
  victoria:
    type: http
    uri: "http://localhost:9428/insert/jsonline"
    method: post
    # ... victoria logs config
```

## Performance Tuning

For high-volume environments, consider:

- Adjusting `-search.maxQueryDuration`
- Increasing memory limits
- Using SSD storage for better performance
- Monitoring disk usage and retention policies

Refer to the [Victoria Logs documentation](https://docs.victoriametrics.com/VictoriaLogs/) for detailed configuration options.
