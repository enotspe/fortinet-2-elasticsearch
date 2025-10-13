# Home

<div align="center">
    <img src="assets/logos/logo_with_name_small.jpg" alt="FortiDragon" />
</div>

Welcome to **FortiDragon**! 

So you want to take your ~~Fortinet~~ firewalls logs (both Fortinet and Palo Alto) to ~~Elasticsearch~~ Victoria Logs, Elasticsearch and others??? You have come to the right place!!! 👍

We are the best analytics plataform for firewall logs. No kidding!!!

## How it all began

We actually use FortiDragon on our day to day operations for threat hunting, so we understand all the painpoints of a security analyst. After 10+ years experience with Fortinet and Palo Alto we could not find a solution that could extract all the juice out of our logs. We tried several SIEMs along the way and found out that firewall logs are just a checkmark on their datasheets. Full parsing and performance tuning for such volume of logs was not carefully considered by any SIEM vendor. Finally we decided we needed to build a solution ourselves having some core principles: flexibility, performance and cost. That is why FortiDragon is by far the best option out there.

## Requeriments

Lets build some ground together and make sure this prohect is right for you.

### What you need to have
- A firewall 🔥
- A firewall that produces logs 🔥🪵
- A firewall that produces logs, and you want to make a report 🔥🪵📔
- A firewall that produces logs, and you want to make a report, and a human is actually going to read it 🔥🪵📔🥸
- A firewall that produces logs, and you want to make a report, and a human is actually going to read it and take some action. 🔥🪵📔🥸🎬

### What you **DO NOT** need to have
More important than what you need is what you dont need.

- Money💰🚫

If you feel related to the previous statements, we got you covered.

If you are Splunk, QRadar, or [Elastic Serverless](https://www.elastic.co/pricing/serverless-search) users, you are welcome to stay and make a [contribution](engage.md#support-the-project) to support FortiDragon. You will get more value out of your 💵 here.

## The Challenge

Firewall logs are a unique beast. They're among the chattiest elements in your infrastructure, generating massive volumes of data. This makes perfect sense—your firewall sits at the chokepoint, seeing every single connection attempt from every device on your network. It's the ultimate network voyeur. 🔍

But here's the paradox: **each individual log is almost worthless**.

A single firewall log tells you almost nothing useful. "Host A connected to Host B on port 443. Status: allowed." So what? That's just... another Tuesday. One log entry is just worthless on a sea of data.

The real value emerges only when you aggregate logs to reveal hidden behavioral patterns.

### The Slow Port Scanner

Consider this situation

**Single log entry:**

10.0.8.15 → 192.168.1.50:445 | TCP SYN | DENIED

Looks like: A workstation tried to access SMB on another host. Maybe a misconfiguration? No big deal.

**Aggregated over 24 hours:**

10.0.8.15 scanned 2,847 different internal IPs
Ports targeted: 22, 23, 445, 3389, 5900
Success rate: 0%
Pattern: Sequential IP scan, 1 attempt every 30 seconds

**This is:** A compromised workstation performing slow reconnaissance to avoid detection. Traditional port scanners are noisy (thousands of attempts per second). This attacker is patient, spreading the scan over 24 hours to hide in normal network traffic.

**Without full logs?** You'd see maybe 5-10 scattered connection attempts. Looks random. Pattern invisible.

Missing some logs, and that behavioral pattern becomes invisible. The malware hides in your sampling gaps. The reconnaissance blends into the noise. The credential stuffing looks like innocent typos.

This is why you **must log everything**. Thre are no "safe" connections, no irrelevant traffic. Just log UTM type logs is not serious. You dont need a SIEM to tell you that there was a hit on the IPS engine, you need a data analytics plataform to uncover correlations hidden on regular events.


## SIEM Cost Trap

Here's where traditional SIEMs fail spectacularly.

Most organizations face this brutal choice:
Option A: Log everything → Go bankrupt from SIEM costs 💸
Option B: Sample/filter logs → Miss threats hiding in the gaps 🕳️

**The dirty secret of enterprise security:** Most companies choose Option B.

They implement "intelligent sampling" (translation: we can't afford to log everything). They filter out "noise" (translation: we're hoping the important stuff makes it through). They set retention policies measured in days, not months (translation: we're praying nothing bad happened last week).

And then they wonder why advanced threats dwell in their networks for an average of 200+ days before detection.

**You can't find patterns you can't see.** 

When you drop logs to save money, you're not just losing data points—you're losing context. You're losing the ability to:

- Correlate events across time windows
- Establish behavioral baselines
- Detect slow-burn attacks
- Perform historical threat hunting
- Conduct forensic investigations

Splunk charges per GB ingested. Elastic Serverless makes you cry when you see the bill. QRadar... let's not even go there. These platforms were built for diverse log types across your entire infrastructure. Firewall logs? They're just a checkbox on the datasheet. An afterthought.

**Nobody optimized for the firewall use case.**

Until now.

## FortiDragon Difference

We had one core constraint: **No money.** 💰🚫

And that constraint forced creativity.

We couldn't throw budget at the problem. We had to get smart about:

- **Storage efficiency** - Choosing databases optimized for log workloads (Victoria Logs)
- **Parsing performance** - Using Vector instead of resource-heavy Java-based tools
- **Cost-effective scaling** - Object storage, compression, smart retention
- **Query optimization** - Engines built for aggregation, not just search

The result? **You can log everything without going broke.**

No sampling. No filtering. **Full visibility. Full context. Full behavioral analysis.**

But we didn't stop there. Storing high volumes of logs efficiently was just the first step. *"Now that we have all the data, how do we actually use it?"*

That's when the real work began.

### 1. **Deep Ingestion**
- **Full field parsing**: Extracts ALL fields and values from Fortinet and Palo Alto logs—not just the "important" ones
- **ECS Naming Standardization**: Translates fields to [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/current/index.html) for consistent field naming across platforms
- **Enrichment**: Enhances log data with additional contextual information.


### 2. **Unmatched Analytics**
**Here is where we shine!** 

It's difficult to explain what "deep visibility" or "in-depth analysis" actually mean until you see it. We could list features like "comprehensive dashboards" or "real-time monitoring," but those are just marketing buzzwords that every vendor claims.

**The truth?** You'll understand it once you use our dashboards.

We're not a generic SIEM that happens to support firewall logs. We're a firewall log analytics platform that happens to be better than any SIEM. No other paid or free tool has such in-depth analysis of firewall logs. 

Don't take our word for it. [Install it](installation/index.md) and see for yourself. 🐉

### 3. **Security Engineer Friendly**
We are security engineers, not data scientists. We understand you might not be familiar with tools like Elasticsearch, Grafana, or Victoria Logs (we struggled too!). 

That's why we made it **super simple** to spin up:

- **One-script installation** for Elasticsearch components
- **Pre-configured Vector pipelines** ready to go
- **Production-ready dashboards** on day one
- **Clear documentation** written by practitioners, for practitioners
- **No vendor lock-in** - use what works for your environment

**You need it all. And now you got it.** 🐉

## Installation

Ready to get started? Check out our [Installation Guide](installation/index.md) to begin your FortiDragon journey!


## Authors

Logstash pipelines and Elasticsearch config [@hoat23](https://github.com/hoat23) and [@enotspe](https://github.com/enotspe) 🐉

Dataset analysis, Kibana and Grafana dashboards, Vector pipelines, Victoria Logs [@enotspe](https://github.com/enotspe) 🐉

Current maintenance [@enotspe](https://github.com/enotspe) 🐉

---

## Support the Project

If FortiDragon helps you:

- 💰 [Make a donation](https://www.paypal.com/paypalme/fortidragon). You are already saving a lot of money by using FortiDragon!
- ⭐ [Star the repository](https://github.com/enotspe/fortinet-2-elasticsearch)
- 📢 Share with colleagues
- 🤝 [Contribute](engage.md/#areas-for-contribution)
