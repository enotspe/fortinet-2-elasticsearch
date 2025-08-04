# Dashboards

FortiDragon provides comprehensive Kibana dashboards for threat hunting and network analysis. These dashboards follow Fortigate's Logs & Report section structure.

## Available Dashboards

### Fortigate Dashboards

| Dashboard | Description | Version |
|-----------|-------------|---------|
| **Fortigate Traffic Analysis** | Network traffic monitoring and analysis | ELK 8.14.1 |
| **Fortigate UTM Events** | Security events, IPS, AV, Web Filter | ELK 8.14.1 |
| **Fortigate System Events** | Administrative and system logs | ELK 8.14.1 |
| **Fortigate SSL VPN** | SSL VPN connection monitoring | ELK 8.14.1 |
| **Fortigate Health** | Firewall health and performance | ELK 8.14.1 |

### Other Fortinet Products

| Product | Dashboard | Description |
|---------|-----------|-------------|
| **FortiClient** | Endpoint Monitoring | Client security events |
| **FortiEDR** | Advanced Threat Detection | EDR security events |
| **FortiMail** | Email Security | Mail security events |
| **FortiWeb** | Web Application Firewall | WAF security events |

### Third-Party Support

| Vendor | Product | Dashboard |
|--------|---------|-----------|
| **Palo Alto** | PAN-OS Firewalls | Traffic and threat analysis |
| **Palo Alto** | Cortex XDR | Advanced threat hunting |

## Dashboard Structure

All dashboards follow a consistent 3-layer structure:

### 1. Header Navigation
![Header](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/header.png)

Connected navigation between all dashboards for easy movement between different views.

### 2. Three-Layer Hierarchy

1. **Top Level**: Fortinet's type field (traffic, utm, event)
2. **Second Level**: Traffic direction (Outbound | Inbound | LAN 2 LAN)  
3. **Third Level**: Metrics (sessions vs bytes analysis)

### 3. Visualization Sections

#### Upper Section - Specific Fields
![Specific Fields](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/specific.png)

Shows dataset-specific fields split by `action` (allow/block).

#### Lower Section - Common Entities
![Common Fields](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/common.png)

- **First row**: `source.ip`, `destination.ip`, `network.protocol`
- **Second row**: Context-specific entities for analysis

## Installation

### Import Dashboards

1. **Navigate to Kibana**: Management → Stack Management → Saved Objects
2. **Import**: Click "Import" and select dashboard files from `kibana/` directory
3. **Enable Controls**: Management → Kibana Advanced Settings → Presentation Labs → Enable dashboard controls

### Dashboard Files

```
kibana/
├── forticlient ELK 851.ndjson
├── fortiedr ELK 8122.ndjson  
├── fortigate ELK 8141.ndjson
├── fortimail ELK 8142.ndjson
├── fortiweb ELK 8132.ndjson
├── panw panos ELK 8143.ndjson
└── panw cortex ELK 8132.ndjson
```

## Dashboard Features

### Controls and Filters

All dashboards include:
- **Time picker** for date range selection
- **Search bar** for quick filtering
- **Control panels** for common filters
- **Drill-down** capabilities

### Key Performance Indicators

#### Traffic Analysis
- **Sessions**: Each log treated as unique session
- **Bytes**: Analysis of `source.bytes` and `destination.bytes`
- **Direction**: Inbound, outbound, and LAN-to-LAN traffic
- **Applications**: Application-level visibility

#### Security Events
- **Threat Detection**: IPS, AV, and security events
- **Policy Actions**: Allow, deny, and security actions
- **User Activity**: User-based threat analysis
- **Geographic Analysis**: Location-based threat intelligence

### Sample Dashboards

#### Firewall Health
![Firewall Health](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/dashboards/Firewall%20Health%20[Fortigate].PNG)

#### IPS Events
![IPS Events](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/dashboards/IPS%20[Fortigate].PNG)

#### Traffic Analysis
![Outbound Traffic](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/dashboards/Outbound%20Sessions%20Traffic%20[Fortigate].PNG)

## Customization

### Performance Optimization

!!! warning "Dashboard Performance"
    These dashboards contain many visualizations. For optimal performance:
    
    - **Filter data** to relevant time ranges
    - **Customize visualizations** for your specific needs
    - **Remove unused panels** to improve loading times
    - **Use index patterns** appropriate for your data volume

### Adding Custom Fields

To add custom fields to dashboards:

1. **Identify the field** in your log data
2. **Create visualization** using Lens or TSVB
3. **Add to dashboard** in appropriate section
4. **Test performance** with your data volume

### Creating New Dashboards

When creating new dashboards:

1. **Follow the 3-layer structure**
2. **Use consistent naming** conventions
3. **Include proper filtering** controls
4. **Test with production** data volumes

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|--------|----------|
| Slow loading | Too many visualizations | Reduce panels or add filters |
| No data displayed | Index pattern mismatch | Verify index patterns |
| Missing fields | Field mapping issues | Check Elasticsearch mappings |
| Dashboard errors | Version compatibility | Use matching ELK versions |

### Log Filtering

!!! info "LogID 20 Filtering"
    [LogID=20](https://kb.fortinet.com/kb/documentLink.do?externalID=FD43912) introduces duplicate data in aggregations. These logs are filtered out in dashboards but retained for troubleshooting and forensic analysis.

### Version Compatibility

Ensure dashboard versions match your ELK stack:
- **ELK 8.14.x**: Use latest dashboard versions
- **ELK 8.12.x**: Use 8122 dashboard versions
- **Older versions**: May require dashboard migration

## Best Practices

### Analysis Workflow

1. **Start broad** with overview dashboards
2. **Drill down** to specific time ranges or entities
3. **Use filters** to focus on anomalies
4. **Correlate** across different dashboard types
5. **Export** findings for reporting

### Threat Hunting

Effective threat hunting workflow:

1. **Baseline** normal traffic patterns
2. **Identify anomalies** in KPIs
3. **Investigate** suspicious activities
4. **Correlate** across multiple data sources
5. **Document** findings and create alerts

### Reporting

Generate reports by:
- **Taking screenshots** of key visualizations
- **Exporting data** as CSV for further analysis
- **Creating Canvas** presentations for executives
- **Scheduling** automated reports via Watcher

**Happy threat hunting!** 🕵️‍♂️🔍
