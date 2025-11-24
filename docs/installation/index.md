# Installation

Let's get this party started! 🤩

FortiDragon uses a modular [architecture](../architecture.md) where each layer is independent. Choose the technologies that best fit your needs.


## Installation Flow

Follow these steps in order:

1. **[Configure Data Sources](#1-data-sources)** - Set up your firewall to send logs
2. **[Install Ingestion Layer](#2-ingestion)** - Deploy Vector to collect and process logs
3. **[Set Up Storage](#3-storage)** - Choose Victoria Logs or Elasticsearch
4. **[Configure Visualization](#4-visualization)** - Import dashboards in Grafana or Kibana



## 1. Data Sources

| Platform | Status | Guide |
|----------|--------|-------|
| **Fortigate** | ✅ Fully Supported | [→ Setup Guide](datasource/fortigate.md) |
| **FortiEDR** | ✅ Supported | [→ Setup Guide](https://docs.fortinet.com/document/fortiedr/7.2.0/administration-guide/109591/syslog) |
| **FortiMail** | ✅ Supported | [→ Setup Guide](https://docs.fortinet.com/document/fortimail/7.6.3/administration-guide/332364/configuring-logging#logging_2063907032_1949484) |
| **FortiWeb / FortiAppSec** | ✅ Supported | [→ Setup Guide](https://docs.fortinet.com/document/fortiappsec-cloud/25.2.0/user-guide/681595/log-settings#SysLog) |
| **Palo Alto PAN-OS** | ✅ Fully Supported | [→ Setup Guide](https://docs.paloaltonetworks.com/pan-os/11-1/pan-os-admin/monitoring/use-syslog-for-monitoring/configure-syslog-monitoring) |

**Next:** After configuring your firewall, proceed to install the ingestion layer.


## 2. Ingestion

The ingestion layer receives syslog data, parses it, enriches it, and forwards it to storage.


| Platform | Status | Guide |
|------|--------|-------|
| **Vector** | ✅ **Recommended** | [→ Setup Guide](ingest/vector.md) |
| Logstash | ❌ Deprecated | [→ Setup Guide](ingest/logstash.md) |
| Elastic Agent | ❌ Deprecated |  [→ Setup Guide](ingest/elastic%20agent.md) |

!!! success "Chef's Choice"
    **Use Vector**
    
    It's fast, flexible, and powerfull.
    
    We've migrated from Logstash and Elastic Agent to Vector.

**Next:** After installing Vector, set up your storage backend.



## 3. Storage

Choose where to store your parsed logs for analysis.


| Platform | Status | Guide | 
|----------|-------|----------------|
| **Victoria Logs** |  ✅ **Recommended** | [→ Setup Guide](storage/victoria.md) | 
| **Elasticsearch** | 👴🏻 Supported | [→ Setup Guide](storage/elastic.md) | 

!!! success "Chef's Choice"
    **Use Victoria Logs**
    
    It's the sweet spot of simplicity, performance, and query power.
    
    It's actively developed with a great roadmap!


**Next:** After setting up storage, configure your visualization layer.



## 4. Visualization

Import pre-built dashboards to start analyzing your firewall logs immediately.


| Platform | Status | Guide | 
|----------|-------|----------------|
| **Grafana** |  ✅ **Recommended** | [→ Setup Guide](viz/grafana.md) | 
| **Kibana** | 👴🏻 Supported | [→ Setup Guide](viz/kibana.md) | 


!!! success "Chef's Choice"
    **Using Victoria Logs?** → Use Grafana
    
    **Using Elasticsearch?** → Use Kibana

**Next:** Import dashboards and start threat hunting!

---

## Quick Start Paths

Choose your path based on your needs:

### 🚀 Fast Path - Victoria Logs (Recommended)
**Best for: New deployments, maximum performance**

1. [Configure Fortigate](datasource/fortigate.md) → Syslog to Vector
2. [Install Vector](ingest/vector.md) → Parse and enrich logs
3. [Install Victoria Logs](storage/victoria.md) → Store logs efficiently
4. [Setup Grafana Cloud](viz/grafana.md) → Visualize and analyze

**Time to first dashboard:** ~30 minutes


### 🏢 Legacy Path - Elasticsearch
**Best for: Existing Elasticsearch deployments**

1. [Configure Fortigate](datasource/fortigate.md) → Syslog to Vector
2. [Install Vector](ingest/vector.md) → Parse and enrich logs
3. [Configure Elasticsearch](storage/elastic.md) → Use existing cluster
4. [Setup Kibana](viz/kibana.md) → Import dashboards

**Time to first dashboard:** ~45 minutes

**Ready to start?** Pick your path above and let's go! 🐉

---

## What You'll Get

After completing installation, you'll have:

- 📊 **Professional Dashboards** - Pre-built visualizations for immediate insights
- 🔍 **Deep Visibility** - Full parsing of all firewall fields
- 🎯 **User friendly UI** - Easy to navigate and consistent UI
- 🚀 **High Performance** - Handle massive log volumes
- 💰 **Cost Effective** - Free and open source

---

## Need Help?

- 💬 **Community Support:** [Discord](https://discord.gg/9qn4enV)
- 🐛 **Report Issues:** [GitHub Issues](https://github.com/enotspe/fortinet-2-elasticsearch/issues)
- 🗺️ **Future Plans:** [Roadmap](../roadmap.md)





