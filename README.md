# fortinet-2-elasticsearch
We want a full 360° monitoring: 
* syslog
* snmp
* snmptraps
* ping (via heartbeat)

## Scope
We will cover all the road for squeezing Fortinet logs on Elasticseach
* ECS translation
* Logstash pipelines
* Geo enrichment
* Other manipulations (tenant enrichment, dropping guest networks, observer enrichment, etc.)
* fields mappings
* index templates
* index patterns
* dashboards
* event alerts
* ML alerts

## Products 
Our focus is to cover security solutions
- [x] Fortigate (of course!)
- [x] Fortisandbox
- [ ] Fortiweb
- [ ] Fortimail.......someday
- [ ] Forticlient (EMS).......someday

## ECS Translations
All the Fortinet to ECS fields translation will be managed by product on a Google sheet.

ECS is a work in progress, a baby just starting to breathe, still lacks a lot of fields, specially for networking security. However, ECS is probably the best effort out there for log normalization. 
So dont expect to have all fields translated to ECS, just Fortigate has 500+ unique fields and ECS is just reaching 400, do the math!!!

### Fortigate
> Current dataset: [6.2.0](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/be3d0e3d-4b62-11e9-94bf-00505692583a/FortiOS_6.2.0_Log_Reference.pdf)

**[FortiOS - Log Reference Version 6.2.0 - Public](https://docs.google.com/spreadsheets/d/1hZYIcozgZQhyXTekOJbXujFBAN-YnJ2cQFP_T0ejuio/edit?usp=sharing)**

Fortigate logs are complicated, it is a very large dataset, fw can be utm or ngfw (this affects logs), no field description, no field examples either, etc. So we have decided to attack them by splitting them by type, resulting in 3 datasets: traffic, utm and event. Each of them has its own translation.

Altough Fortinet is moving all types logs to a connection oriented approach for source.ip and destination.ip fields, we are only considering client/source server/destination for traffic logs

Right now only traffic and utm logs have been translated, because their usecase is the one which ECS have more coverage.
