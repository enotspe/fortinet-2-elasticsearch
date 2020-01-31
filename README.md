# FortiUnicorn (fortinet-2-elasticsearch)

![logo](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/FortiUnicorn%20Fortinet-2-Elasticsearch.png)


## Scope

We will cover all the road for squeezing all possible information out of Fortinet logs on Elasticseach:

- [x] ECS translation

- [x] Logstash pipelines (including geo enrichment, other manipulations as tenant enrichment, dropping guest networks, observer enrichment, etc.)

- [ ] index templates

- [ ] index patterns

- [ ] dashboards

- [ ] event alerts

- [ ] ML alerts



## Products 

Our focus is to cover security solutions

- [x] Fortigate (of course!)

- [x] Fortisandbox

- [X] Fortiweb

- [ ] Fortimail.......someday

- [ ] Forticlient (EMS).......is there even a way to get syslog from Forticlients?

- [ ] [enSilo](https://www.fortinet.com/products/fortinet-acquires-ensilo.html) (that would be great!)



## Inputs

We want a full 360° view for monitoring and analysis: 

* syslog

* snmp

* snmptraps

* ping (via heartbeat)

* ssh commands output (diag sys top) ...someday

* [streaming telemetry](http://www.openconfig.net/projects/telemetry/) ...someday it will be supported



## ECS Translations

*Disclaimer*

ECS is a work in progress, a baby just starting to breathe, still lacks a lot of fields, specially for networking security. However, ECS is probably the best effort out there for log normalization. 

So don't expect to have all fields translated to ECS, just Fortigate has 500+ unique fields and ECS is just reaching 400, do the math!!!



**Translations Sheets**

This is the start of the journey, we needed to fully understand the dataset we were facing before writing a single line of logstash pipeline. So, we got the Log Reference guides and turn them into spreadsheets so we can process the data. We need to denormalize data, merge fields, verify fields mapping (data type), look for filed that overlap with ECS fields, translate fields to ECS, make mapping and pipelines configs.  

All the Fortinet to ECS fields translation will be managed by product on a Google sheet.



### Fortigate

> Current dataset: [6.2.2](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/ed572394-e556-11e9-8977-00505692583a/FortiOS_6.2.2_Log_Reference.pdf), [6.2.0](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/be3d0e3d-4b62-11e9-94bf-00505692583a/FortiOS_6.2.0_Log_Reference.pdf)



**[FortiOS_6.2.X_Log_Reference - Public](https://docs.google.com/spreadsheets/d/1m4hHrjSSCvIMTNCliRDBL6cW_IlQCyhqOTfwHtjVHoQ/edit?usp=sharing)**



Fortigate logs are an ugly beast, mainly because its lack of (good) documentation. Current log reference lacks of field description, no field examples either, logids gets removed without any notice, etc. Starting from 6.2.1, type "utm" was documented, altough it existed long ago. On top of that, GTP events cause some field mismatch mapping like:



* checksum: string  | uint32

* from: ip  | string

* to: ip  | string

* version: string  | uint32


As far as we are concern, GTP is only part of Fortigate Carrier, which is a different product (¿?) How can Fortigate manage a field that has 2 different data types in its internal relational database? how does fortianalyzer do it? We have no idea, because we have never seent GTP events on a real scenario. In order to avoid any data type mismatch, GTP events are not going to be considered, and unless you use Fortigate Carrier, you are not going to see them either.


1. `Data 6.2.X` is the denormalized data set obtained from the Log Reference Guide of version 6.2.X. You can look at it as the Log Reference on spreadsheet format.

2. `Data` has all the datasets from `Data 6.2.X` sheets. You can look at it as the denormalize version of all datasets of major release 6.2.

3. On `Overlap ECS - Summary of fields`, we look for any field on Fortigate dataset that could overlap with ECS fields. First we consolidate all fields with a dynamic table, and then lookup for it over root fields on `ECS 1.X`. For example, Fortigate dataset has field `agent`, which overlaps with field `agent` on ECS. If we find an overlap, we propose a rename for Fortigate field: `fortios.agent`. We are doing ECS "enrichment", leaving original fortinet fields as well, just renaming the ones that overlaps with ECS.

4. We have decided to attack the full dataset by splitting them by type, resulting in 3 datasets: traffic, utm and event. Each of them has its own translation. So, on sheets `Summary of "traffic type" fields`, `Summary of "utm type" fields` and `Summary of "event type" fields` we consolidate the fields of each dataset independently.

5. On `ECS Translation of "XXX type" fields` is where the magic happens. Based on our criteria, we translate to ECS the fields we consider can fit. Although Fortinet is moving utm type logs to a [connection oriented approach](https://docs.fortinet.com/document/fortigate/6.2.0/new-features/199570/logging-session-versus-attack-direction), we are only considering client/source server/destination for traffic logs.

6. On `logstash - XXX` we consolidate the translated fields of previous sheets and generate logstash code.

7. On `fortigate mapping` we filter all fortigate fields that are not string and, based on it type, template mapping code is generated. The template we use consider keyword as default mapping, this is why we only explicitly define non-keyword fields. This sheet might be reviewed because some Fortinet fields are longer than 1024, which is are default lenght. We have not had any issue so far tough.


Translation is where we need more help from the community!!! We manage around 100s of firewalls, but is is very likely we have not covered it all.


### Fortisandbox

> Current dataset: [3.1.2](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/8bd13f46-f447-11e9-8977-00505692583a/FortiSandbox-3.1.2-Log_Reference.pdf)



**[FortiSandbox - Log Reference v3.1.2 - Public](https://docs.google.com/spreadsheets/d/1Dm8z1nnDI9G2ANJYn5Eaq2DVQhwiESFZPuFDro-JEHQ/edit?usp=sharing)**

Same logic as Fortigate. No type separation has been made tough.

### Fortiweb

> Current dataset: [6.2.0](https://fortinetweb.s3.amazonaws.com/docs.fortinet.com/v2/attachments/0d7bbf47-ee6d-11e9-8977-00505692583a/FortiWeb_6.2.0_Log_Reference.pdf)



**[FortiWeb_6.2.0_Log_Reference - Public](https://docs.google.com/spreadsheets/d/19YpCfLGtaU3DnDRWTLKaQXOoVc4up7lFCu1SfCIofT4/edit?usp=sharing)**


## Logstash



We have tried to make our pipelines as modular as possible, witout any "hardcoding" inside them. For enrichment, we manage "dictionaries", so we can dynamically enrich any data we want, and we can change each dictionary per logstash, which gives the flexibility we are looking for because we have a multitenant deployment, with many logstash deployed all over, and no direct correlation between a logstash and a tenant ( logstash != tenant). So we need to have a very flexible pipeline architecture. 

This might not be your case, no problem, just use the pipelines you need!


The overall pipeline flow is as follows:


![pipelien flow](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/pipeline%20flow.png)

It is important the sequence of the pipelines, mainly for HA scenarios. We are doing some enrichments via dictionaries that then get overriden with log data. Take for example `observer.serial_number`: it gets populated on `Observer Enrichment` pipeline, but it gets overriden on `FortiXXX 2 ECS` with the translation of `devid` field. This is on purpose, because it allows to have just one entry on the dictionary (on HA both devices are exactly the same) but have accuarate data about the specefic properties of the devices on an HA pair (serial_number, name)

### Input Syslog



Just receives syslog logs and populated event.module depending on udp port.



### Observer Enrichment



Depending on the IP of the firewall (IP sending logs), it looks up on two dictionaries. On the first one, it enriches observer (firewall) properties. On the second one, it enrichs observer (firewall) location. This 2 dictionaries could be merged into one, because the key is the same: *"[observer][ip]"*. 



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



### Drop

Security is a big data problem, that you have to pay for it. 
Here, guest networks (or any defined networks) are dropped. There is no need, at least in our case, for ingesting guest networks logs. Guest networks are looked up dynamically from a dictionary.



### Output



This is crucial for index strategy:


"ecs-%{[event][module]}-%{[organization][name]}-write"



3 index templates rule it all, each template points to its specific index pattern:

* [ecs-](https://github.com/elastic/ecs/blob/master/generated/elasticsearch/7/template.json): deals with ECS mapping.

* %{[event][module]} which could be fortigate, fortisandbox, fortiweb: deals with fortiX mapping.

* %{[organization][name]}: deals with ILM template, shard allocation specific to the tenant.


Because we have a multitenant scenario, we manage different retention policies per tenant, while ECS mapping is the same for all indexes, and every Fortinet product has its own mapping for original fields.

## Dashboards

Fortinet dataset has 500+ fields, so we need many dashboards for exploring the fields.

### Structure

All dashboards are connected via its header structure. Making it easy to navigate trough them.

Dashboards follow a (max) 3 layer structure, going from more general to more specific.



## Authors

Logstash and Elasticsearch [@hoat23](https://github.com/hoat23)

Dataset analysis and Kibana [@enotspe](https://github.com/enotspe)

