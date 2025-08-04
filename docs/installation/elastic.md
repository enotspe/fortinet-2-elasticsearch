# Elastic Stack Setup

FortiDragon provides an automated script to set up all necessary Elasticsearch components.

## Quick Setup Script

We got a script!!!! 🎉

### Prerequisites

- Elasticsearch cluster running
- Access to Elasticsearch with appropriate permissions
- Curl or similar HTTP client

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/enotspe/fortinet-2-elasticsearch.git
   cd fortinet-2-elasticsearch
   ```

2. **Make the script executable**:
   ```bash
   chmod +x ELK/load.sh
   ```

3. **Run the installation script**:
   ```bash
   cd ELK
   ./load.sh
   ```

4. **Follow the interactive prompts** to configure:
   - Elasticsearch endpoint
   - Authentication credentials
   - Index settings

## What Gets Installed

The script automatically creates:

### Index Templates
- `logs-fortinet.fortigate.traffic`
- `logs-fortinet.fortigate.utm` 
- `logs-fortinet.fortigate.event`
- `logs-fortinet.forticlient`
- `logs-fortinet.fortiedr`
- `logs-fortinet.fortimail`

### Component Templates
- ECS field mappings and transforms
- ILM policy configurations
- Index settings (refresh intervals, field limits, etc.)

### Ingest Pipelines
- `logs-fortinet.fortigate` - Main Fortigate log processing
- `logs-fortinet.forticlient` - FortiClient log processing
- `logs-fortinet.fortiedr` - FortiEDR log processing
- `logs-fortinet.fortimail` - FortiMail log processing
- `logs-fortinet.fortiweb` - FortiWeb log processing
- `logs-fortinet.fortiadc` - FortiADC log processing

### ILM Policies
Automated lifecycle management for:
- Hot phase: 7 days
- Warm phase: 30 days  
- Cold phase: 90 days
- Delete phase: 365 days

## Manual Installation

If you prefer manual installation or need to customize settings:

### 1. Index Templates

```bash
# Create component templates first
curl -X PUT "localhost:9200/_component_template/ecs-transforms" \
  -H "Content-Type: application/json" \
  -d @component_templates/ecs-transforms.json

# Create index templates
curl -X PUT "localhost:9200/_index_template/logs-fortinet.fortigate" \
  -H "Content-Type: application/json" \
  -d @index_templates/logs-fortinet.fortigate.json
```

### 2. Ingest Pipelines

```bash
curl -X PUT "localhost:9200/_ingest/pipeline/logs-fortinet.fortigate" \
  -H "Content-Type: application/json" \
  -d @ingest_pipelines/logs-fortinet.fortigate.json
```

### 3. ILM Policies

```bash
curl -X PUT "localhost:9200/_ilm/policy/logs-fortinet.fortigate" \
  -H "Content-Type: application/json" \
  -d @ilm/logs-fortinet.fortigate.json
```

## Kibana Dashboards

After setting up Elasticsearch components:

1. **Navigate to Kibana**: Go to Management → Stack Management → Saved Objects
2. **Import dashboards**: Click "Import" and select the dashboard files from the `kibana/` directory
3. **Enable dashboard controls**: Go to Management → Kibana Advanced Settings → Presentation Labs → Enable dashboard controls

### Available Dashboards

- **Fortigate Traffic Analysis** - Network traffic monitoring
- **Fortigate UTM Events** - Security events and threats
- **Fortigate System Events** - Administrative and system logs
- **FortiClient Monitoring** - Endpoint security logs
- **FortiEDR Analysis** - Advanced threat detection
- **FortiMail Security** - Email security events

## Performance Tuning

### Elasticsearch Settings

For high-volume environments, consider these optimizations:

```json
{
  "index": {
    "refresh_interval": "30s",
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "mapping": {
      "total_fields": {
        "limit": 2000
      }
    }
  }
}
```

### ILM Optimization

Adjust ILM policies based on your retention requirements:

```json
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "5GB",
            "max_age": "1d"
          }
        }
      }
    }
  }
}
```

## Verification

After installation, verify everything is working:

```bash
# Check templates
curl -X GET "localhost:9200/_index_template/logs-fortinet*"

# Check pipelines  
curl -X GET "localhost:9200/_ingest/pipeline/logs-fortinet*"

# Check ILM policies
curl -X GET "localhost:9200/_ilm/policy/logs-fortinet*"
```

## Next Steps

Once Elasticsearch is configured:

1. [Set up your syslog collector](collectors.md)
2. [Configure Vector or Elastic Agent](collectors.md)
3. Start sending logs from Fortigate!
