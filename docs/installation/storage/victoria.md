# Victoria Logs

[Victoria Logs](https://docs.victoriametrics.com/victorialogs/) is a high-performance log management system.

## Installation as a service

There are many ways for [installing](https://docs.victoriametrics.com/victorialogs/quickstart/#how-to-install-and-run-victorialogs) Victoria Logs. Normally, for a Linux environment, you may want to install it as a service. Based on how VictoriaMetrics is deployed as [binary](https://docs.victoriametrics.com/victoriametrics/quick-start/#starting-vm-single-from-a-binary), we have come up with this guide:

## Download

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

Download binary:

```bash
curl -L -O https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/$VICTORIALOGS_VERSION/victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-$VICTORIALOGS_VERSION.tar.gz
tar xzf victoria-logs-$VICTORIALOGS_SO-$VICTORIALOGS_ARCH-$VICTORIALOGS_VERSION.tar.gz
```

!!! info "UPGRADES"
    ℹ️ Repeat this step for upgrading Victoria Logs version

## Install

Move binary to `/usr/local/bin`:

```bash
sudo mv victoria-logs-prod /usr/local/bin
```

!!! info "UPGRADES"
    ℹ️ Repeat this step for upgrading Victoria Logs version

## System Setup

### Create VictoriaLogs user

```bash
sudo useradd -s /usr/sbin/nologin victoria
```

### Change ownership

```bash
sudo chown victoria:victoria /usr/local/bin/victoria-logs-prod
```

!!! info "UPGRADES"
    ℹ️ Repeat this step for upgrading Victoria Logs version

### SELlinux permission

In case you run SELlinux, change SELlinux permission:

```bash
sudo restorecon -v /usr/local/bin/victoria-logs-prod
```

!!! info "UPGRADES"
    ℹ️ Repeat this step for upgrading Victoria Logs version

### Create VictoriaLogs data directory

```bash
sudo mkdir -p /var/lib/victoria-logs-data && sudo chown -R victoria:victoria /var/lib/victoria-logs-data
```

## Service Configuration

Create `victorialogs` service:

```bash
sudo vim /etc/systemd/system/victorialogs.service
```

The file should look like:

```ini
[Unit]
Description=VictoriaLogs service
#After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=victoria
Group=victoria

EnvironmentFile=-/etc/default/victorialogs

ExecStart=/usr/local/bin/victoria-logs-prod \
-envflag.enable
SyslogIdentifier=victorialogs
Restart=always

PrivateTmp=yes
#ProtectHome=yes
NoNewPrivileges=yes

ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

Create `/etc/default/victorialogs` file:

```bash
sudo vim /etc/default/victorialogs
```

Add the following content:

```ini
storageDataPath=/var/lib/victoria-logs-data
search_maxQueryDuration=600s
search_maxQueueDuration=600s
retentionPeriod=365d
retention_maxDiskUsagePercent=80
#-retention.maxDiskSpaceUsageBytes=800GiB
```

### Retention Configuration

Note that `-retention*` parameters control lifecycle of ingested logs:

```ini
-retentionPeriod=365d
-retention.maxDiskUsagePercent=80
#-retention.maxDiskSpaceUsageBytes=800GiB
```

Adjust these values based on your storage capacity and retention requirements.

!!! warning "Important"
    ⚔️ `-retention.maxDiskSpaceUsageBytes` and `-retention.maxDiskUsagePercent` flags are mutually exclusive.

    **VictoriaLogs will refuse to start if both flags are set simultaneously.**

### Query Configuration

Note that `-search*` parameters control query execution timeouts:

```bash
-search.maxQueryDuration=600s 
-search.maxQueueDuration=600s
```

600s = 10 minutes

This is a very long value, useful for running queries over large datasets. Adjust these values based on your query requirements.

See full options for [Victoria Logs flags](https://docs.victoriametrics.com/victorialogs/#list-of-command-line-flags)

### Start Service

Start and enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable victorialogs
sudo systemctl start victorialogs
sudo systemctl status victorialogs
```

## Troubleshooting

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

## Next Steps

Once Victoria Logs is configured:

1. Import dashboards in [Grafana](../viz/grafana.md)

2. Start dancing with your logs!

## Extra Bonus

Consider deploying Victoria Logs [MCP](https://github.com/VictoriaMetrics-Community/mcp-victorialogs) server 😱🤖✨
