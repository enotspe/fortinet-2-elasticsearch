# fortinet-2-elasticsearch
We want a full 360° monitoring: 
* syslog
* snmp
* snmptraps
* ping (via heartbeat)

## Scoope
We will cover all the road for squeezing Fortinet logs on Elasticseach
* Logstash pipelines
* ECS translation
* Geo enrichment
* Other manipulations (tenant enrichment, dropping guest networks, observer enrichment, etc.)
* fields mappings
* index templates strategy
* dashboards
* event alerts
* ML alerts

## Products 
Our focus is to cover security solutions
* Fortigate (of course!)
* Fortisandbox
* Fortiweb
* Fortimail
* Forticlient (EMS)

## ECS Translations
All the Fortinet 2 ECS will be managed by product on a Google sheet.

Fortigate logs are quite complicated, and we have decided to attack them by splitting all the dataset by type, so there are 3 datasets: traffic, utm, event. Each of them has its own translation
