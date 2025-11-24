# Fortigate

This guide covers how to configure your Fortigate firewall to send syslog data to FortiDragon.

## Syslog Configuration

Configure syslog using RFC5424 format (recommended):

```bash
config log syslogd setting
    set status enable
    set server "elastic_agent_IP"
    set port 5140
    set format rfc5424
end
```

!!! warning "Firewall Naming Convention"
    When using syslog RFC5424 format, be careful with your firewall hostname:

    - ❌ `MY_FIREWALL_SITEA` will **NOT** work
    - ✅ `MY-FIREWALL-SITEA` will work
    
    Use hyphens instead of underscores in hostnames.

## Optional Configurations

### Extended Logging

Enable extended logging on webfilter for more detailed information:

```bash
config webfilter profile
    edit "test-webfilter"
        set extended-log enable
        set web-extended-all-action-log enable
    next
end
```

!!! info "Extended Log Limitations"
    You may get a warning about changing to reliable syslogd. Remember:

    - **Reliable Syslog servers**: Full rawdata field of 20KB
    - **Other devices** (disk, FortiAnalyzer, UDP): Maximum 2KB total log length

### SD-WAN Performance Logging

To collect metrics about SD-WAN Performance SLAs, configure health-check logging:

```bash
config health-check
    edit "Google"
        set server "8.8.8.8" "8.8.4.4"
        set sla-fail-log-period 10
        set sla-pass-log-period 30
        set members 0
        config sla
            edit 1
                set latency-threshold 100
                set jitter-threshold 10
                set packetloss-threshold 5
            next
        end
    next
end
```

### Custom Fields

You can inject custom fields into Fortigate's syslog for additional context:

```bash
config log custom-field
    edit "3"
        set name "org"
        set value "some_organization_name"
    next
end

config log setting
    set custom-log-fields "3"
end
```

## Verification

After configuration, verify that logs are being sent:

   ```bash
   # On your collector host (Vector)
   sudo tcpdump -i any port 5140
   ```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No logs received | Check firewall rules between Fortigate and collector |
| You do receive packets, but see no logs ingested | Use hyphens instead of underscores in hostname |

## Next Steps

Once Fortigate is configured:

1. [Install Vector](../ingest/vector.md)

2. Set up [Victoria Logs](../storage/victoria.md) or [Elasticsearch](../storage/elasticsearch.md)

3. Import dashboards in [Grafana](../viz/grafana.md) or [Kibana](../viz/kibana.md)

4. Start dancing with your logs!
