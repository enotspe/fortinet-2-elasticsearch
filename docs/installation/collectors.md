# Syslog Collectors

FortiDragon supports multiple syslog collectors to receive logs from Fortigate and forward them to Elasticsearch. All processing is done via ingest pipelines in Elasticsearch, so we can use any lightweight collector.

## Supported Collectors

- **[Elastic Agent](#elastic-agent)** - Recommended for Elastic Stack integration
- **[Vector](#vector)** - Lightweight, high-performance collector
- **[Rsyslog](#rsyslog)** - Traditional Unix syslog daemon
- **[Syslog-ng](#syslog-ng)** - Advanced syslog daemon

Choose **one** of the options below based on your preferences and environment.

---

## Elastic Agent

Elastic Agent is the recommended collector for Elastic Stack environments.

### Installation Options

#### Fleet-Managed Agent (Recommended)

1. **[Install Elastic Agent](https://www.elastic.co/guide/en/fleet/current/elastic-agent-installation.html)** as Fleet-managed

2. **Create an Agent Policy**:
   ![Create Policy](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/create_policy.png)

3. **Add Integration**:
   ![Add Integration](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/add_integration.png)

4. **Select Custom UDP Logs**:
   ![Custom UDP Logs](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/custom_udp_logs.png)

5. **Configure Integration**:
   ![Integration Parameters](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/integration_parameters.png)

#### Standalone Agent

If you prefer standalone deployment, create a configuration like this:

```yaml
inputs:
  - id: udp-udp-af7f0dce-57c0-498f-bc09-96ba51fd76a4
    name: fortinet.fortigate-1
    type: udp
    data_stream:
      dataset: fortinet.fortigate
      namespace: default
    host: '0.0.0.0:5140'
    pipeline: logs-fortinet.fortigate
    max_message_size: 50KiB
    tags:
      - preserve_original_event
    processors:
      - copy_fields:
          fields:
            - from: message
              to: event.original
      - syslog:
          field: message
    fields_under_root: true
    fields:
      internal_networks:
        - private
        - loopback
        - link_local_unicast
        - link_local_multicast
```

### Performance Tuning

For high-volume environments, optimize for throughput:

- **Fleet-managed**: Set Elasticsearch output to `Throughput` mode in Fleet settings
- **Standalone**: Add these settings to your `elastic-agent.yml`:

```yaml
outputs:
  default:
    type: elasticsearch
    preset: throughput
```

### Monitoring

Monitor for dropped UDP packets:

```bash
watch -d "column -t /proc/net/snmp | grep -w Udp"
```

---

## Vector

Vector is an excellent lightweight alternative with high performance.

### Installation

On RHEL/CentOS/Fedora:

```bash
# Install Vector
sudo dnf install -y vector

# Or using the official repo
curl --proto '=https' --tlsv1.2 -sSf https://sh.vector.dev | bash
```

### Configuration

Create `/etc/vector/vector.yaml`:

```yaml
sources:
  fortigate_syslog:
    type: "syslog"
    address: 0.0.0.0:5140
    mode: "udp"

transforms:
  remap_elastic:
    type: "remap"
    inputs: ["fortigate_syslog"]
    source: |
      # Rename syslog fields
      .log.syslog.facility.name = del(.facility)
      .log.source.address = del(.source_ip)
      .log.syslog.hostname = del(.hostname)
      .log.syslog.severity.name = del(.severity)
      .log.syslog.version = del(.version)
      .log.logger = del(.source_type)
      .@timestamp = del(.timestamp)

      # Internal networks
      .internal_networks = ["link_local_multicast","link_local_unicast","loopback","private"]

sinks:
  elastic:
    type: elasticsearch
    inputs:
      - remap_elastic
    auth:
      strategy: "basic"
      user: "YOUR_USER"
      password: "YOUR_PASSWORD"
    endpoints:
      - https://your_elasticsearch_endpoint
    mode: "data_stream"
    data_stream:
      type: "logs"
      dataset: "fortinet.fortigate"
      namespace: "default"
    pipeline: "logs-fortinet.fortigate"
```

### Environment Variables

For security, use environment variables in `/etc/default/vector`:

```bash
ELASTICSEARCH_ENDPOINT="https://localhost:9200"
ELASTICSEARCH_USER="elastic"
ELASTICSEARCH_PASS="mypassword"
FORTIGATE_SYSLOG_UDP_PORT=5140
INTERNAL_NETWORKS=["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]
```

### Service Configuration

Configure Vector to load from directory:

```bash
sudo systemctl edit vector
```

Add this override configuration:

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

Start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable vector
sudo systemctl start vector
```

---

## Rsyslog

Traditional rsyslog configuration for FortiDragon.

### Configuration

Add to `/etc/rsyslog.conf` or create `/etc/rsyslog.d/49-fortinet.conf`:

```bash
# UDP syslog reception
$ModLoad imudp
$UDPServerRun 5140
$UDPServerAddress 0.0.0.0

# Template for Elasticsearch
template(name="fortinet" type="list") {
    constant(value="{\"@timestamp\":\"")
    property(name="timereported" dateFormat="rfc3339")
    constant(value="\",\"message\":\"")
    property(name="msg" format="json")
    constant(value="\",\"host\":\"")
    property(name="hostname")
    constant(value="\",\"severity\":\"")
    property(name="syslogseverity-text")
    constant(value="\",\"facility\":\"")
    property(name="syslogfacility-text")
    constant(value="\"}\n")
}

# Forward to Elasticsearch
*.* @@your-elasticsearch-host:9200;fortinet
```

### Elasticsearch Output Module

For direct Elasticsearch integration:

```bash
# Install elasticsearch output module
sudo dnf install rsyslog-elasticsearch

# Configuration
module(load="omelasticsearch")

action(type="omelasticsearch"
       server="your-elasticsearch-host"
       serverport="9200"
       template="fortinet"
       searchIndex="logs-fortinet.fortigate"
       dynSearchIndex="on"
       searchType="logs"
       bulkmode="on"
       queue.type="linkedlist"
       queue.size="5000"
       queue.dequeuebatchsize="300"
       action.resumeretrycount="-1")
```

---

## Syslog-ng

Advanced syslog-ng configuration for FortiDragon.

### Configuration

Create `/etc/syslog-ng/conf.d/fortinet.conf`:

```bash
source s_fortinet {
    udp(ip("0.0.0.0") port(5140));
};

destination d_elasticsearch {
    elasticsearch-http(
        index("logs-fortinet.fortigate")
        type("logs")
        cluster("elasticsearch")
        cluster_url("http://your-elasticsearch-host:9200")
        template("$(format-json --scope rfc5424 --exclude DATE --key @timestamp=${ISODATE})")
    );
};

log {
    source(s_fortinet);
    destination(d_elasticsearch);
};
```

---

## Verification

After configuring your collector, verify log reception:

### Check Collector Logs

=== "Elastic Agent"
    ```bash
    # Fleet-managed
    sudo tail -f /opt/Elastic/Agent/data/logs/elastic-agent*.log
    
    # Standalone
    sudo tail -f /var/log/elastic-agent/elastic-agent*.log
    ```

=== "Vector"
    ```bash
    sudo journalctl -u vector -f
    ```

=== "Rsyslog"
    ```bash
    sudo tail -f /var/log/messages
    ```

=== "Syslog-ng"
    ```bash
    sudo tail -f /var/log/syslog-ng.log
    ```

### Check Elasticsearch

```bash
# Check if indices are being created
curl -X GET "localhost:9200/_cat/indices/logs-fortinet*?v"

# Check document count
curl -X GET "localhost:9200/logs-fortinet.fortigate/_count"

# Sample documents
curl -X GET "localhost:9200/logs-fortinet.fortigate/_search?size=1&pretty"
```

### Network Monitoring

Monitor UDP traffic on the collector:

```bash
# Monitor UDP packets
sudo tcpdump -i any port 5140 -n

# Check for dropped packets  
netstat -su | grep -i drop
```

## Performance Optimization

### Buffer Tuning

For high-volume environments:

=== "Elastic Agent"
    - Use `throughput` preset
    - Increase `max_message_size` if needed
    - Monitor queue metrics

=== "Vector"
    ```yaml
    sources:
      fortigate_syslog:
        max_connections: 100
        receive_buffer_bytes: 65536
    
    sinks:
      elastic:
        batch:
          max_events: 1000
          timeout_secs: 1
    ```

=== "Rsyslog"
    ```bash
    # Increase UDP buffer
    $UDPServerReceiveBufferSize 2097152
    
    # Queue settings
    $MainMsgQueueSize 50000
    $MainMsgQueueWorkerThreads 4
    ```

### System Tuning

Increase UDP buffer sizes:

```bash
# Temporary
sudo sysctl -w net.core.rmem_max=33554432
sudo sysctl -w net.core.rmem_default=33554432

# Permanent
echo "net.core.rmem_max = 33554432" >> /etc/sysctl.conf
echo "net.core.rmem_default = 33554432" >> /etc/sysctl.conf
```

## Troubleshooting

| Issue | Collector | Solution |
|-------|-----------|----------|
| Dropped packets | All | Increase UDP buffer sizes |
| High CPU usage | Vector | Enable batch processing |
| Memory issues | Elastic Agent | Reduce queue sizes |
| Connection refused | All | Check Elasticsearch connectivity |
| Authentication failed | All | Verify credentials and permissions |

**Hopefully you should be dancing with your logs by now!** 🕺💃
