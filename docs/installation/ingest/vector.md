# Vector

This page covers Vector configuration for FortiDragon, based on the existing vector documentation.

## Install as a service

There are many ways for [installing Vector](https://vector.dev/docs/setup/installation/). Normally, for a Linux environment, you will [install it as a service](https://vector.dev/docs/setup/installation/package-managers/yum/), so you may need to some adjustments for Vector to load multiple config files from a directory.

## Load multiple confif files

We have split Vector config files by plattaform, so FortiDragon Vector directory should look like:

```
/etc/vector/
├── panos.yaml
├── fortigate.yaml
├── fortiedr.yaml
└── fortiweb.yaml
...
└── vector.yaml
```

However, Vector only loads `vector.yaml` by [default](https://vector.dev/docs/reference/configuration/#location). We need to make some adjustments on the service so it will load all files on the folder.

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

FortiDragon Vector config files uses envioremental variables for passing specific values for your setup. All variables have defaults values in the config files.

`INTERNAL_NETWORKS` is the only variable that must be set.

`INTERNAL_NETWORKS` is used for infering `network.direction` of connections.

`INTERNAL_NETWORKS` must have your local private network addresses scopes as well as your public facing network addresses scopes.

Create environment variables for Vector config:

```bash
sudo vim /etc/default/vector
```

Add environment variables:

```bash
### Sources ###
#FORTIGATE_SYSLOG_UDP_PORT=5140
#FORTIGATE_SYSLOG_TCP_PORT=5140

#PANOS_SYSLOG_UDP_PORT=6140

#FORTIMAIL_SYSLOG_UDP_PORT=5150

#FORTIWEB_SYSLOG_TCP_PORT=5160
#FORTIAPPSEC_SYSLOG_UDP_PORT=5161

#FORTIEDR_SYSLOG_UDP_PORT=5180


### Sinks ###
#VICTORIA_LOGS_ENDPOINT="http://localhost:9428"
#VICTORIA_LOGS_USER=""
#VICTORIA_LOGS_PASS=""

#ELASTICSEARCH_ENDPOINT="https://localhost:9200"
#ELASTICSEARCH_USER="elastic"
#ELASTICSEARCH_PASS="mypassword"

#LOKI_ENDPOINT="http://localhost:3100"
#LOKI_USER="loki"
#LOKI_PASS="mypassword"

#QUICKWIT_ENDPOINT="http://localhost:7280"
#QUICKWIT_USER="quickwit"
#QUICKWIT_PASS="mypassword"

#PROMETHEUS_ENDPOINT="http://localhost:9090"
#PROMETHEUS_USER="prometheus"
#PROMETHEUS_PASS="mypassword"

### Transforms ###
#TENANT_NAME="mytenant"

INTERNAL_NETWORKS=["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]
```

## Sinks

Vector can send logs to multiple [sinks](https://vector.dev/docs/reference/configuration/sinks/)

Configuration files have set all supported [storages](../../architecture.md/#storage).

!!! warning "Sinks"
    Comment in the ones you will use

    Comment out the ones you will not use

!!! warning "Sinks"
    ✅ By default, [Victoria Logs](../storage/victoria.md) is enabled

    ❌ By default, [Elasticsearch](../storage/elasticsearch.md) is disabled.

```yaml
sinks:
  vlogs_fortigate_traffic:
    inputs:
      - remap_traffic
    type: elasticsearch
    endpoints:
      - ${VICTORIA_LOGS_ENDPOINT:-http://localhost:9428}/insert/elasticsearch/
    ...

  vlogs_fortigate:
    inputs:
      #- remap_traffic
      - remap_utm
      - remap_event
      - route._unmatched
    type: elasticsearch
    endpoints:
      - ${VICTORIA_LOGS_ENDPOINT:-http://localhost:9428}/insert/elasticsearch/
    ...

#  elastic_fortigate:
#    type: elasticsearch
#    inputs:
#      - remap_traffic
#      - remap_utm
#      - remap_event
#    auth:
#      strategy: "basic"
#      user: "${ELASTICSEARCH_USER:-elastic}"
#      password: "${ELASTICSEARCH_PASS:-myelasticsearchpassword}"
#    endpoints:
#      - ${ELASTICSEARCH_ENDPOINT:-https://localhost:9200}
#    ...
```

## Advanced Configuration

For production deployments, take into account every sink has a section that overrides Vector default values for [buffering](https://vector.dev/docs/architecture/buffering-model/) trying to mimic `Optimized for Throughput` Elastic Agent [settings](https://www.elastic.co/docs/reference/fleet/es-output-settings#es-output-settings-performance-tuning-settings). Vector works really well with defaults. Don't use this section unless you really need to fine-tune yor ingest.

```yaml
    buffer:
    - type: memory
      max_events: 12800 # default 500 https://www.elastic.co/docs/reference/fleet/es-output-settings#es-output-settings-performance-tuning-settings
      #when_full: drop_newest #default block
    batch:
      #max_bytes:
      max_events: 1600 # default 1000
      timeout_secs: 5 # default 1
```

## Monitoring

We have included 2 files for monitoring Vector itself.

```
/etc/vector/
├── vector_monitoring.yaml
└── vector.yaml
```

`vector.yaml` just enables API.

```yaml
 api:
   enabled: true
   address: "127.0.0.1:8686"
```

and `vector_monitoring.yaml` scrapes metrics and logs. Logs are sent to Loki because it has a [free tier](https://grafana.com/pricing/#logs) which is enough for most cases.

Refer to the [Vector documentation](https://vector.dev/docs/) for detailed configuration options.

## Troubleshooting

After configuration, verify that logs are being received:

1. Monitor network traffic:

   ```bash
   # On your Vector host
   sudo tcpdump -i any port 5140
   ```

2. Make sure you have enabled firewall incomming rules for your Vector ports:

   ```bash
   # On your Vector host
   sudo firewall-cmd --zone=public --permanent --add-port=5140/udp
   sudo firewall-cmd --reload
   ```

3. [Troubleshoot](https://vector.dev/guides/level-up/troubleshooting/) Vector:

   ```bash
   sudo journalctl -fu vector
   ```

## Next Steps

Once Vector is configured:

1. Set up [Victoria Logs](../storage/victoria.md) or [Elasticsearch](../storage/elasticsearch.md)

2. Import dashboards in [Grafana](../viz/grafana.md) or [Kibana](../viz/kibana.md)

3. Start dancing with your logs!
