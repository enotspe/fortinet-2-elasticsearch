# FortiUnicorn (fortinet-2-elasticsearch)



## Scope

We will cover all the road for squeezing all possible information out of Fortinet logs on Elasticseach:

* Logstash pipelines

* ECS translation

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

- [X] Fortiweb

- [ ] Fortimail.......someday

- [ ] Forticlient (EMS).......someday

- [ ] [enSilo](https://www.fortinet.com/products/fortinet-acquires-ensilo.html) (that would be great!)



## Inputs

We want a full 360° view for monitoring and analysis: 

* syslog

* snmp

* snmptraps

* ping (via heartbeat)

* ssh commands output (diag sys top)

* [streaming telemetry](http://www.openconfig.net/projects/telemetry/) ...someday it will be supported



## ECS Translations

*Disclaimer*

ECS is a work in progress, a baby just starting to breathe, still lacks a lot of fields, specially for networking security. However, ECS is probably the best effort out there for log normalization. 

So don't expect to have all fields translated to ECS, just Fortigate has 500+ unique fields and ECS is just reaching 400, do the math!!!



**Translations Sheets**

We got Log reference guides and turn them into sheets so we can process the data. We need to merge fields, verify fields mapping(data type), look for filed that overlap with ECS fields, translate fields to ECS, and make mapping and pipelines configs.  

All the Fortinet to ECS fields translation will be managed by product on a Google sheet.



### Fortigate

> Current dataset: [6.2.2](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/ed572394-e556-11e9-8977-00505692583a/FortiOS_6.2.2_Log_Reference.pdf)



**[FortiOS_6.2.X_Log_Reference - Public](https://docs.google.com/spreadsheets/d/1m4hHrjSSCvIMTNCliRDBL6cW_IlQCyhqOTfwHtjVHoQ/edit?usp=sharing)**



Fortigate logs are an ugly beast, mainly because its lack of (good) documentation. Current log reference lacks of field description, no field examples either, logids gets added/removed without any notice, etc. Just from 6.2.1, type "utm" was documented. On top of that, GTP events are part of the guide, causing some field mismatch mapping 



* checksum: string  | uint32

* from: ip  | string

* to: ip  | string

* version: string  | uint32



As far as we are concern, GTP is only part of Fortigate Carrier, which is a different product¿? How can Fortigate manage a field that has 2 different data types in its internal relational database? how does fortianalyzer do it?



So we have decided to attack them by splitting them by type, resulting in 3 datasets: traffic, utm and event. Each of them has its own translation.



Although Fortinet is moving utm type logs to a [connection oriented approach](https://docs.fortinet.com/document/fortigate/6.2.0/new-features/199570/logging-session-versus-attack-direction), we are only considering client/source server/destination for traffic logs.



Right now only traffic and utm logs have been translated, because their use case is the one which ECS have more coverage.



### Fortisandbox

> Current dataset: [3.1.2](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/8bd13f46-f447-11e9-8977-00505692583a/FortiSandbox-3.1.2-Log_Reference.pdf)



**[FortiSandbox - Log Reference v3.1.2 - Public](https://docs.google.com/spreadsheets/d/1Dm8z1nnDI9G2ANJYn5Eaq2DVQhwiESFZPuFDro-JEHQ/edit?usp=sharing)**


### Fortiweb

> Current dataset: [6.2.0](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/0d7bbf47-ee6d-11e9-8977-00505692583a/FortiWeb_6.2.0_Log_Reference.pdf)



**[FortiWeb_6.2.0_Log_Reference - Public](https://docs.google.com/spreadsheets/d/19YpCfLGtaU3DnDRWTLKaQXOoVc4up7lFCu1SfCIofT4/edit?usp=sharing)**


## Logstash



We have a multitenant deployment, with many logstash deployed all over, and no direct correlation between a logstash and a tenant ( logstash != tenant). So we need to have a very flexible pipeline architecture. 



Therefore, we have tried to make our pipelines as modular as possible, and witout any "hardcoding" inside them. For enrichment, we manage "dictionaries", so we can dynamically enrich any data we want, and we can change each dictionary on every logstash, which gives the flexibility we are looking for. This might not be your case, no problem, just use the pipelines you need!



The overall pipeline flow is as follows:



input_syslog --> observer_enrichment --> kv_syslog --> fortiXXX_2_ecs --> geo_enrichment --> geo_enrichment --> drop --> output



### Input Syslog



Just receives syslog logs and populated event.module depending on udp port.



### Observer Enrichment



Depending on the IP of the firewall (IP sending logs), it looks up on 2 dictionaries. On the first it enriches observer (firewall) properties. On the second one it enrichs observer (firewall) location. This 2 dictionaries could be merged into one, because the key is the same: *"[observer][ip]"*. 



If not found in the dictionary, it means we are receiving logs from an unknown firewall and it tags it as so.



**Properties Dictionary**



**"[observer][ip]"** : "[observer][name]","[observer][hostname]","[observer][mac]","[observer][product]","[observer][serial_number]","[observer][type]","[observer][vendor]","[observer][version]","[organization][id]","[organization][name]"



**Geo Dictionary**



**"[observer][ip]"** : "[observer][geo][city_name]","[observer][geo][continent_name]","[observer][geo][country_iso_code]","[observer][geo][country_name]","[observer][geo][location][lon]","[observer][geo][location][lat]","[observer][geo][name]","[observer][geo][region_iso_code]","[observer][geo][region_name]","[event][timezone]","[observer][geo][site]","[observer][geo][building]","[observer][geo][floor]","[observer][geo][room]","[observer][geo][rack]","[observer][geo][rack_unit]"



We have added some fields to ECS geo so we can have the exact location: site, building, floor, room, rack, rack_unit.

Maybe, this is not very critical for firewalls, because you usually have just a couple of firewalls per site. However, we added it as a part of our inventory because we also manage switches and APs, and for those you do need the exact location.



### KV Syslog



Splits the original log into key-value pairs, and sets the timestamp. Timezone is also dynamically obtained from a dictionary. Our firewalls live in different timezones.



### FortiXXX 2 ECS



Based on the spreadsheet: 



* Validates nulls on IP fields (Fortinet loves to fill with "N/A" null fields, which turns into ingestion errors if your field has IP mapping)



* Renames fortinet fields that overlaps with ECS



* Translates fortinet field to ECS. We are doing ECS "enrichment", leaving original fortinet fields as well. If you want to replace fields, just change "copy" to "rename".



* Populates other ECS fields based on ECS recommendations. (related ip, source.address, event.start, etc.)



### Geo Enrichment



source.ip/source.nat.ip and destination.ip/destination.nat.ip are inspected to decide whether they are public or private address with the help of [.locality](https://github.com/elastic/ecs/pull/288) fields. 

If they are public, then geo enrichment is applied.

Finally, request_path is inserted, for use on Maps UI.



### Drop

Security is a big data problem, the only issue is that you have to pay for it. Here, guest networks are dropped. There is no need, at least in our case, for ingesting guest networks logs. Guest networks are looked up dynamically from a dictionary.



### Output



This is crucial for index strategy:



"ecs-%{[event][module]}-%{[organization][name]}-write"



3 index templates rule it all:

* [ecs-* template](https://github.com/elastic/ecs/blob/master/generated/elasticsearch/7/template.json): deals with ECS mapping.

* fortiX* template: deals with fortiX mapping.

* tenantX template: deals with ILM template, shard allocation.



Because we have a multitenant scenario, we manage different retention policies per tenant, while ECS mapping is the same for all indexes, and every Fortinet product has its own mapping for original fields.
