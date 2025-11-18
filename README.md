<div align="center">
  <img src="images/logo_with_name_small.jpg" alt="FortiDragon Logo" />

  <h1>FortiDragon</h1>
  <p><strong>The Best Analytics Platform for Firewall Logs. No Kidding.</strong></p>

  [![Discord](https://img.shields.io/discord/9qn4enV?color=7289da&label=Discord&logo=discord&logoColor=white)](https://discord.gg/9qn4enV)
  [![GitHub stars](https://img.shields.io/github/stars/enotspe/fortinet-2-elasticsearch?style=social)](https://github.com/enotspe/fortinet-2-elasticsearch/stargazers)
  [![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://enotspe.github.io/fortinet-2-elasticsearch/)
  [![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)](LICENSE)

  <h3>
    <a href="https://enotspe.github.io/fortinet-2-elasticsearch/">📚 Full Documentation</a> •
    <a href="https://enotspe.github.io/fortinet-2-elasticsearch/installation/">🚀 Quick Start</a> •
    <a href="https://discord.gg/9qn4enV">💬 Discord</a> •
    <a href="https://enotspe.github.io/fortinet-2-elasticsearch/roadmap/">🛣️ Roadmap</a>
  </h3>
</div>

---

## 🎯 What is FortiDragon?

**FortiDragon** is a full-featured analytics platform that transforms Fortinet (FortiGate, FortiEDR, FortiMail, FortiWeb) and Palo Alto PAN-OS logs into actionable threat intelligence—without breaking the bank.

After 10+ years fighting with overpriced SIEMs that treat firewall logs as an afterthought, we built the platform we always needed. **No sampling. No filtering. Full visibility. Full behavioral analysis.**

### 💰 The Problem We Solve

**Traditional SIEMs force you to choose:**
- **Option A:** Log everything → Go bankrupt from licensing costs
- **Option B:** Sample/filter logs → Miss threats hiding in the gaps

**We chose Option C:** Build a platform optimized specifically for high-volume firewall logs using modern, cost-effective tech.

## ✨ Key Features

### 🔍 Deep Ingestion
- **Full field parsing** - Every field from Fortinet and Palo Alto logs, not just the "important" ones
- **ECS standardization** - Translates to [Elastic Common Schema](https://www.elastic.co/guide/en/ecs/current/index.html)
- **Rich enrichment** - GeoIP, network community ID, registered domains, threat intel integration

### 📊 Unmatched Analytics
- **Purpose-built dashboards** for threat hunting (Kibana & Grafana)
- **Behavioral analysis** - Detect slow burns, lateral movement, beaconing
- **No other tool** (paid or free) has this depth of firewall log analysis

### 🛠️ Security Engineer Friendly
- **One-script deployment** for Elasticsearch components
- **Pre-configured pipelines** for Vector and Elastic Agent
- **Production-ready dashboards** on day one
- **No vendor lock-in** - swap components as needed

### 🏗️ Modular Architecture
```
Fortinet/Palo Alto → Vector/Elastic Agent → Elasticsearch/Victoria Logs → Kibana/Grafana
```
Mix and match: Every layer is swappable. Use what works for your environment.

## 🚀 Quick Start

### 1️⃣ Configure Your Firewall
```bash
# FortiGate syslog configuration (must use RFC5424)
config log syslogd setting
    set status enable
    set server "your-collector-ip"
    set port 5140
    set format rfc5424
end
```

### 2️⃣ Deploy Elasticsearch Components
```bash
git clone https://github.com/enotspe/fortinet-2-elasticsearch.git
cd fortinet-2-elasticsearch/ELK
chmod +x load.sh
./load.sh
```

### 3️⃣ Set Up Ingestion
Choose your collector: **Vector** (recommended), **Elastic Agent**

Pre-configured pipelines available in the repo for all options.

### 4️⃣ Import Dashboards
Load pre-built dashboards in Kibana or Grafana and start hunting! 🐉

**👉 See the [Full Installation Guide](https://enotspe.github.io/fortinet-2-elasticsearch/installation/) for detailed setup instructions.**

## 📖 Documentation

All detailed documentation has moved to our dedicated documentation site:

### **[📚 https://enotspe.github.io/fortinet-2-elasticsearch/](https://enotspe.github.io/fortinet-2-elasticsearch/)**

- **[Installation Guide](https://enotspe.github.io/fortinet-2-elasticsearch/installation/)** - Step-by-step setup for all components
- **[Architecture](https://enotspe.github.io/fortinet-2-elasticsearch/architecture/)** - How FortiDragon works under the hood
- **[Dashboards](https://enotspe.github.io/fortinet-2-elasticsearch/dashboards/)** - Dashboard structure and usage
- **[Roadmap](https://enotspe.github.io/fortinet-2-elasticsearch/roadmap/)** - What's next for FortiDragon
- **[Contributing](https://enotspe.github.io/fortinet-2-elasticsearch/engage/)** - Join the community

## 🎨 Dashboard Preview

<div align="center">
  <img src="images/header.png" alt="Dashboard Navigation" width="800"/>
  <p><em>Navigate seamlessly through traffic, UTM, and event dashboards</em></p>
</div>

## 🌟 Why FortiDragon?

| Feature | Traditional SIEM | FortiDragon |
|---------|------------------|-------------|
| **Cost** | $$$$$+ per GB | Free + your infrastructure |
| **Firewall Focus** | Generic checkbox | Purpose-built |
| **Full Parsing** | "Important fields" | Every field extracted |
| **Sampling** | Required for cost | Log everything |
| **Dashboards** | Generic templates | Threat hunting focused |
| **Vendor Lock-in** | Total | None - modular design |
| **Setup Time** | Weeks/months | Hours |

## 🤝 Community & Support

### Get Help
- 💬 [Join our Discord](https://discord.gg/9qn4enV) - Active community for questions and discussions
- 📖 [Read the Docs](https://enotspe.github.io/fortinet-2-elasticsearch/) - Comprehensive guides
- 🐛 [Report Issues](https://github.com/enotspe/fortinet-2-elasticsearch/issues) - Bug reports and feature requests

### Support the Project
You're already saving thousands on SIEM costs. Consider giving back:

- 💰 [Donate via PayPal](https://www.paypal.com/paypalme/fortidragon) - Support development
- ⭐ [Star this repo](https://github.com/enotspe/fortinet-2-elasticsearch/stargazers) - Show your support
- 📢 Share with colleagues - Spread the word
- 🤝 [Contribute](https://enotspe.github.io/fortinet-2-elasticsearch/engage/#areas-for-contribution) - Code, docs, datasets

## 🗺️ Supported Platforms

### Data Sources
- ✅ Fortinet FortiGate (v6.2+)
- ✅ Fortinet FortiEDR
- ✅ Fortinet FortiMail
- ✅ Fortinet FortiWeb
- ✅ Palo Alto PAN-OS
- 🚧 Fortinet FortiClient (WIP)

### Storage Backends
- ✅ Elasticsearch
- ✅ Victoria Logs (recommended for cost)
- 🚧 Quickwit (experimental)

### Visualization
- ✅ Kibana
- ✅ Grafana

### Ingestion
- ✅ Vector (recommended)
- ✅ Elastic Agent
- ⚠️ Logstash (deprecated)

## 📜 License

GPL-3.0 License - See [LICENSE](LICENSE) for details

## 👥 Authors

- Logstash pipelines, Elasticsearch config: [@hoat23](https://github.com/hoat23) & [@enotspe](https://github.com/enotspe)
- Datasets, Kibana/Grafana dashboards, Vector pipelines, Victoria Logs: [@enotspe](https://github.com/enotspe)
- Current maintenance: [@enotspe](https://github.com/enotspe)

---

<div align="center">
  <p><strong>Built by security analysts, for security analysts.</strong></p>
  <p>Tired of expensive SIEMs that don't understand firewall logs?</p>
  <p><strong>🐉 Welcome to FortiDragon. 🐉</strong></p>

  <h3><a href="https://enotspe.github.io/fortinet-2-elasticsearch/">Get Started →</a></h3>
</div>
