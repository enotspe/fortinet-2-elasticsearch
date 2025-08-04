# Vector Configuration

This page covers advanced Vector configuration for FortiDragon, based on the existing vector documentation.

## Service Configuration

Edit vector service to load config files from `/etc/vector`:

```bash
sudo systemctl edit vector
```

Insert config for overridden default config:

```ini
[Service]
ExecStartPre=
ExecStartPre=/usr/bin/vector validate --config-dir /etc/vector

ExecStart=
ExecStart=/usr/bin/vector --config-dir /etc/vector

ExecReload=
ExecReload=/usr/bin/vector validate --no-environment --config-dir /etc/vector
ExecReload=/bin/kill -HUP $MAINPID
```

Restart daemon and service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart vector
```

## Environment Variables

Create environment variables for Vector config:

```bash
sudo vim /etc/default/vector
```

Add environment variables:

```bash
FORTIGATE_SYSLOG_UDP_PORT=7140
FORTIGATE_SYSLOG_TCP_PORT=7140

#VICTORIA_LOGS_ENDPOINT="http://localhost:9428"
#VICTORIA_LOGS_USER=""
#VICTORIA_LOGS_PASS=""

ELASTICSEARCH_ENDPOINT="https://localhost:9200"
ELASTICSEARCH_USER="elastic"
ELASTICSEARCH_PASS="mypassword"

LOKI_ENDPOINT="http://localhost:3100"
LOKI_USER="loki"
LOKI_PASS="mypassword"

PROMETHEUS_ENDPOINT="http://localhost:9090"
PROMETHEUS_USER="prometheus"
PROMETHEUS_PASS="mypassword"

TENANT_NAME="mytenant"

INTERNAL_NETWORKS=["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]
```

## Configuration Files

Vector supports loading multiple configuration files from a directory. This allows you to organize your configuration by component:

- `sources.yaml` - Input sources
- `transforms.yaml` - Data transformations  
- `sinks.yaml` - Output destinations
- `global.yaml` - Global settings

### Example Directory Structure

```
/etc/vector/
├── sources.yaml
├── transforms.yaml
├── sinks.yaml
└── global.yaml
```

### Advanced Configuration

For production deployments, consider:

- **Buffer configuration** for high throughput
- **Health checks** for monitoring
- **Routing** for different log types
- **Enrichment** with additional metadata

Refer to the [Vector documentation](https://vector.dev/docs/) for detailed configuration options.
