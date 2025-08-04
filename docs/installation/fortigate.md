# Fortigate Configuration

This guide covers how to configure your Fortigate firewall to send syslog data to FortiDragon.

## Basic Syslog Configuration

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

## Extended Logging (Optional)

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

## SD-WAN Performance Logging (Optional)

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

## Custom Fields (Optional)

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

1. **Check Fortigate logs**:
   ```bash
   diagnose log test
   ```

2. **Monitor network traffic**:
   ```bash
   # On your collector host
   sudo tcpdump -i any port 5140
   ```

3. **Check syslog status**:
   ```bash
   get log syslogd setting
   ```

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| No logs received | Check firewall rules between Fortigate and collector |
| Invalid hostname errors | Use hyphens instead of underscores in hostnames |
| Truncated logs | Switch to reliable syslog or reduce log verbosity |
| High CPU usage | Reduce logging frequency or filter log types |

### Log Types

FortiDragon processes different types of Fortigate logs:

- **Traffic**: Connection and session logs
- **UTM**: Security events (AV, IPS, Web Filter, etc.)
- **Event**: System and administrative events

You can filter specific log types if needed:

```bash
config log syslogd filter
    set traffic enable
    set utm enable
    set event enable
end
```

## Next Steps

Once Fortigate is configured:

1. [Set up your Elastic Stack](elastic.md)
2. [Configure a syslog collector](collectors.md)
3. Start receiving and analyzing logs!
