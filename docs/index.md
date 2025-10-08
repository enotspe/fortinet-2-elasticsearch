# Home

<div align="center">
    <img src="assets/logo_with_name_small.jpg" alt="FortiDragon" />
</div>

Welcome to **FortiDragon**! 

So you want to take your ~~Fortinet~~ firewalls logs (both Fortinet and Palo Alto) to ~~Elasticsearch~~ Victoria Logs, Elasticsearch and others??? You have come to the right place!!! 👍

We are the best analytics plataform for firewall logs. No kidding!!!

## How it all began

We actually use FortiDragon on our day to day operations for threat hunting, so we understand all the painpoints of a security analyst. After 10+ years experience with Fortinet and Palo Alto we could not find a solution that could extract all the juice out of our logs. We tried several SIEMs along the way and found out that firewall logs are just a checkmark on their datasheets. Full parsing and performance tuning for such volume of logs was not carefully considered by any SIEM vendor. Finally we decided we needed to build a solution ourselves having some core principles: flexibility, performance and cost. That is why FortiDragon is by far the best option out there.

## Requeriments

Lets build some ground together and make sure this prohect is right for you.

### What you need to have
- A firewall
- A firewall that produces logs
- A firewall that produces logs, and you want to make a report
- A firewall that produces logs, and you want to make a report, and a human is actually going to read it
- A firewall that produces logs, and you want to make a report, and a human is actually going to read it and take some action.

### What you **DO NOT** need to have
More important than what you need is what you dont need.

- Money

If you feel related to the previous statements, we got you covered.

If you are Splunk, QRadar, or [Elastic Serverless](https://www.elastic.co/pricing/serverless-search) users, you are welcome to stay and make a [contribution](engage.md#support-the-project) to support FortiDragon. You will get more value out of your 💵 here.

## Challenge

Firewall logs are unique beast. They are on the most chatty elements on your infraestructure generating high volumens of logs. That is pretty obvious because they concentrate all the connections from all your network in one system. 

However, each log provides very low information. Each log itself is almost irrelevant. The real value comes when you aggregate all the logs to find hidden behaivors.

Let's imagine this situation:
You got an IP that performs a DNS resolution to some external IP adrress. That log itself do not indicate malicious activity.
But if in a hour span, you see that IP doing DNS resolutions to a thousand different IPs. That is pretty weird behaivor because noramlly you only have configured 2 DNS servers for resolution. Such pattern can indicate a [C2C connection](https://attack.mitre.org/techniques/T1071/004/) or [Data Exfiltration](https://attack.mitre.org/techniques/T1048/003/).

The point is that every single DNS resolution is not relevant itself, just when you aggregate them is when you can see the full picture and spot an anomalus pattern.

That is why it is important to log all connections. And that is why it is unqique challenge. Integrating your firewalls to current SIEMs solutions can make them explote in storage, and get you broke in the process. 

## Key Benefits

### 1. **Ingestion**
- **Full field parsing**: Extracts all fields and values from Fortinet and Palo Alto logs.
- **ECS Naming Standardization**: Translates fields to [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/current/index.html) for consistent field naming.
- **Enrichment**: Enhances log data with additional contextual information.

### 2. **Analytics**
Here is where we shine! No other paid or free tool has such an in depth analysis of Fortinet logs. FortiDragon provides deep visibility into your network traffic. With comprehensive dashboards for threat hunting, you can easily monitor firewalls logs in real-time and perform long term analysis. 

### 3. **Quick Setup**
Detailed instructions for seting up. We are also security engineers, not data scientits. We understand you might not be familiar with tools like Elastic, Grafana or Victoria Logs (we also strugged as well), so we have made it super simple to spin up.

## Quick Start

Ready to get started? Check out our [Installation Guide](installation/index.md) to begin your FortiDragon journey!


## Authors

Logstash pipelines and Elasticsearch config [@hoat23](https://github.com/hoat23) and [@enotspe](https://github.com/enotspe) 🐉

Dataset analysis, Kibana and Grafana dashboards, Vector pipelines, Victoria Logs [@enotspe](https://github.com/enotspe) 🐉

Current maintenance [@enotspe](https://github.com/enotspe) 🐉
