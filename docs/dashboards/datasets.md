# Datasets

FortiDragon includes comprehensive datasets and field mappings for various Fortinet products.

## Available Datasets

### FortiGate Logs

The FortiGate datasets include field mappings for:

- **Traffic Logs**: Network traffic analysis with source/destination information
- **Event Logs**: System events and administrative actions
- **UTM Logs**: Unified Threat Management logs including:
  - Antivirus detection
  - Intrusion Prevention System (IPS)
  - Web filtering
  - DNS filtering
  - Application control

### Field Mapping

All FortiGate fields are mapped to Elastic Common Schema (ECS) format for standardization:

- Source and destination IP addresses
- Port information
- Protocol details
- Timestamps
- Action taken (allow/deny/block)
- Threat information

## Dataset Structure

```
datasets/
├── Fortinet/
│   ├── 7.2/
│   │   ├── unique_fields/
│   │   └── elasticsearch_templates/
│   ├── 7.4/
│   └── 7.6/
```

## Using the Datasets

The datasets are automatically processed when you run the installation scripts. They generate:

1. **Elasticsearch templates** for proper field mapping
2. **Index patterns** for Kibana visualization
3. **Field enrichment** rules for better data analysis

For more details on installation, see the [Installation Guide](../installation/index.md).

docs/installation/index.md

/home/dragon/fortinet-2-elasticsearch/docs/installation/index.md