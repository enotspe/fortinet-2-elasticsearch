# FortiDragon (fortinet-2-elasticsearch)

![logo](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/FortiUnicorn%20Fortinet-2-Elasticsearch.png)

## FortiDragon vs Filebeat

So you want to take you Fortinet logs to Elasticseach??? You have come to the right place!!

But wait! Doesn't Elastic provide a [Filebeat module for Fortinet](https://github.com/elastic/beats/pull/17890)???

Why should you go with all the logstash hassle??

Well, Filebeat module and Fortidragon are like causins. Filebeat module logic for Fortigate was based on FortiDragon, we colaborated with Elastic when they built that module.

The main differences would be

| Category | FortiDragon | Filebeat |
| -------- | ----------- | ---------|
| Dashboard | We got super cool dashboards!!! | None yet :( |
| Updates | Much more often | Dependant to Elastic releases |
| Installation | Harder| Easier |

The real reason behind is that we use FortiDragon on our day to day operations for threat hunting, so updates and constant evolution is more fluid.

If you can handle the hassle of logstash installation, it is worth the effort.

## TL;DR

Let's get this party on!!!

### On Fortigate

1. Configure syslog

```
    config log syslogd setting
        set status enable
        set server "logstash_IP"
        set port 5140
    end
```

2. [Extendend logging on webfilter](https://docs.fortinet.com/document/fortigate/7.2.0/fortios-log-message-reference/496081/enabling-extended-logging) **OPTIONAL**

```
    config webfilter profile
        edit "test-webfilter"
            set extended-log enable
            set web-extended-all-action-log enable
        next
    end
```
    No need for syslogd on mode reliable

### On Logstash

1. [Install Logstash](https://www.elastic.co/guide/en/logstash/current/installing-logstash.html)

2. A good idea would be to setup your ES password as a [secret](https://www.elastic.co/guide/en/logstash/current/keystore.html#add-keys-to-keystore)

2. Install tld filter plugin

    cd /usr/share/logstash
    sudo bin/logstash-plugin install logstash-filter-tld

3. Copy [pipelines.yml](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/logstash/pipelines.yml) to your logstash folder
4. Copy [conf.d](https://github.com/enotspe/fortinet-2-elasticsearch/tree/master/logstash/conf.d) content to your conf.d folder
5. Start logstash


## Update !!!

Turns out that our use case (many fw, many logstash, many clients) was far way more complicated than normal use cases (just one fw). So we have simplified the pipelines logic (no more dictionaries) to make it easier for everybody to implement the pipelines. 

Now it is just

Input --> kv --> fortigate_2_ecs --> common_ecs --> output 

We will be updating docs!

Discord Channel:: https://discord.gg/9qn4enV

## Scope

We want to make sense out of Fortinet logs,
We will cover all the road for squeezing all possible information out of Fortinet logs on Elasticseach:

- [x] Dataset analisys & ECS translation

- [x] Logstash pipelines

- [x] Datastreams (ILM, index component, index template)

- [x] Dashboards

- [ ] Transforms

- [ ] ML alerts



## Products 

Our focus is to cover security solutions, but we are mainly focused on Fortigate logs

- [x] Fortigate (of course!)

- [x] Fortisandbox

- [X] Fortiweb

- [ ] Fortimail.......someday

- [X] Forticlient (via FAZ forwarding)

- [ ] FortiEDR







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



* checksum: `string  | uint32`

* from: `ip  | string`

* to: `ip  | string`

* version: `string  | uint32`


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


## Pipelines sequence

The overall pipeline flow is as follows:

```mermaid
graph LR;
    Input-->kv;
    kv-->fortigate_2_ecs;
    kv-->forticlient_2_ecs;
    kv-->fortimail_2_ecs;
    kv-->fortisandbox_2_ecs;
    kv-->fortiweb_2_ecs;
    fortigate_2_ecs-->common_ecs;
    forticlient_2_ecs-->common_ecs;
    fortimail_2_ecs-->common_ecs;
    fortisandbox_2_ecs-->common_ecs;
    fortiweb_2_ecs-->common_ecs;
    common_ecs-->output;
```


It is important the sequence of the pipelines, mainly for HA scenarios. We are doing some enrichments via dictionaries that then get overriden with log data. Take for example `observer.serial_number`: it gets populated on `Observer Enrichment` pipeline, but it gets overriden on `FortiXXX 2 ECS` with the translation of `devid` field. This is on purpose, because it allows to have just one entry on the dictionary (on HA both devices are exactly the same) but have accuarate data about the specefic properties of the devices on an HA pair (serial_number, name)

### Input Syslog



Just receives syslog logs and populated event.module depending on udp port.



### KV Syslog



Splits the original log into key-value pairs, and sets the timestamp. Timezone is also dynamically obtained from a dictionary. Our firewalls live in different timezones.



### FortiXXX 2 ECS



Based on the spreadsheet: 



* Validates nulls on IP fields (Fortinet loves to fill with "N/A" null fields, which turns into ingestion errors if your field has IP mapping)



* Renames fortinet fields that overlaps with ECS



* Translates fortinet field to ECS. We are doing ECS "enrichment", leaving original fortinet fields as well. If you want to replace fields, just change "copy" to "rename".



* Populates other ECS fields based on ECS recommendations. (related ip, source.address, event.start, etc.)






### Output



This is crucial for index strategy:





## Dashboards

Fortinet dataset has 500+ fields, so we need many dashboards for exploring it. 

We have tried to follow Fortigate´s Logs & Report section. Main objective of these dashboards is to do an exploration of the dataset in order to spot anomalies on it, it is not intended to be a C-level report in any way. We would be using Canvas for C-level visualizations.

There a lot of visualizations on each dashboars so keep in mind performance can be impacted (loading times)

### Structure

All dashboards are connected via its header structure. Making it easy to navigate trough them.

![header](https://github.com/enotspe/fortinet-2-elasticsearch/blob/master/images/header.png)

Dashboards follow a (max) 3 layer structure, going from more general to more specific.

1. Top level reference Fortinet´s type field: traffic, utm or event. UTM is already disaggregated so it can be easier to go to an specif UTM type, just like in Fortigate´s Logs & Report section.

2. Second level dives into *traffic direction* (if possible). For example: On traffic´s dashboard, we have `Outbound | Inbound | LAN 2 LAN | VPN | FW Local`. It makes total sense to analyze it separetly.

*firewalls have been configured with `interface role` following this premise:*
* *LAN interfaces = `LAN` interface role*
* *WAN interfaces = `WAN` interface role*
* *VPN interfaces = `undefeined` interface role*
* *MPLS interfaces = `LAN` interface role*

3. Third level refers to which metric are we using for exploring the dataset: We only use sessions and bytes.
*we need to filter out [logid=20](https://kb.fortinet.com/kb/documentLink.do?externalID=FD43912), so we dont get duplicate data when running aggregations. You can filter out this logid on the firewall itself, but we make sure we dont use it.

```
config log fortianalyzer filter
        set filter "logid(00020)"
        set filter-type exclude
   end
```

* sessions: we consider each log as a unique session.

* bytes: we analyze `source.bytes` and `destination.bytes` by both sum and average.


## Authors

Logstash pipelines and Elasticsearch config [@hoat23](https://github.com/hoat23) and [@enotspe](https://github.com/enotspe)

Dataset analysis and Kibana [@enotspe](https://github.com/enotspe)

