# Elasticsearch

We got a script!!!! 🎉 FortiDragon provides an automated script to set up all necessary Elasticsearch components.

### Prerequisites

- Elasticsearch cluster running
- Access to Elasticsearch with appropriate permissions
- Curl

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

3. **Modify variables according to your environment**:
Either on
    1. Script itslelf (`# CONFIGURATION SECTION`)
    2. Via environment variables

4. **Run the installation script**:
   ```bash
   cd ELK
   ./load.sh
   ```

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


## Troubleshooting

| Problem | Solution |
|---------|----------|
| No logs received | Check firewall rules between Fortigate and collector |
| You do receive packets, but see no logs ingested | Use hyphens instead of underscores in hostnames |
| Truncated logs | Switch to reliable syslog or reduce log verbosity |
| Logs Drops | Increase buffers |


## Next Steps

Once Elasticsearch is configured:


2. [Configure Vector or Elastic Agent](vector.md)
3. Start sending logs from Fortigate!
