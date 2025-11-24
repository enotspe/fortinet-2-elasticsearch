# Architecture

We have a modular architecture, each layer is independent from each other. 

![Archiecture](assets/architecture.png)

So, what technology should you choose at each layer????

This is a little tricky, because we are not trying to establish comparisons based on benchmarks, just based on our personal experience ingesting and dissecting firewall logs with these platforms. Our judgment could be biased. 


## Ingestion

|                   | Logstash          | Elastic Agent     | Vector            |
| ----------------- | ----------------- | ----------------- | ----------------- |
| Centrally Managed | Yes. Paid plan    | Yes               | Yes. [Paid plan](https://www.datadoghq.com/product/observability-pipelines/)    |
| Performance       | We were never able to go above 1k EPS. Above that threshold you need to make some [crazy tweaking](https://discuss.elastic.co/t/increase-udp-input-plugin-performance/130798). Probably because it is Java based. Anyway, it is not worth it. | Great. It has different [presets](https://www.elastic.co/guide/en/fleet/current/es-output-settings.html#es-output-settings-performance-tuning-settings) for different loads. | Great |
| Language          | Good              | Limited to Elastic functions. Can not make comments on the code. | Great. It even has a [playground](https://playground.vrl.dev/). Very detailed logging for debbuging. |
| **Conclusion**    | Migrate to Vector | Migrate to Vector | **Current development and maintenance** |

!!! success "Our Recommendation"
    **Use Vector!**
    
    It's fast, flexible, and powerfull. 
    
    We've migrated from Logstash and Elastic Agent to Vector.

## Storage



|  | **Victoria Logs** | **Elasticsearch Cluster** | **Elasticsearch Serverless** | **Quickwit** | **Loki** | **GreptimeDB** |
|------------|---------------|------------|----------|------------|------------|------------|
| Performance | Great! Go based | Too resource consuming, probably because it is based on Java | Great! | Great! Rust based | Slow. Fields are not [indexed](https://grafana.com/docs/loki/latest/#overview) | - |
| Serverless (Object Storage) | Not yet | No | Yes | Yes | Yes | Yes |
| Scalability | Limited. Horizontally scalable by adding more nodes, but queries depend on the capacity of each node | Limited. Horizontally scalable by adding more nodes. Data can be replicated for improved query performance, but increases resource consumption on writing | Truly decoupled storage from CPU. Infinite scaling in theory | Truly decoupled storage from CPU. Infinite scaling in theory | Decoupled storage from CPU. Grafana plans on integrating [Warpstream](https://www.youtube.com/watch?v=LWDeIHfAC9A) into the architecture | - |
| Schema | No | Yes | Yes | Yes | No | Yes |
| Simplicity | Super simple to setup! | Complicated | Less Complicated | Fairly simple | Too many components. Complicated to query | - |
| Query Language | Logsql: super complete | DSL: simple and good just for search, limited aggregations and piping, ES\|QL: Piped query language, faster than DSL. | DSL: simple and good just for search, limited aggregations and piping, ES\|QL: Piped query language, faster than DSL. | very limited DSL-like | LogQL: very complicated, slow and very limited analytics| - |
| Price | Cheap | Not that Cheap | [Super Expensive](https://www.elastic.co/pricing/serverless-security) | Cheap | [Expensive](https://grafana.com/pricing/#logs) | - |
| Managed Cloud Offering | Yes | Yes | Yes (only offering) | Yes | Yes | Yes |
| Support | Great! | OK | OK | Community | OK | - |
| Roadmap | [Object Storage](https://docs.victoriametrics.com/victorialogs/roadmap/). Looks promising! | - | - | [Sold to Datadog](https://quickwit.io/blog/quickwit-joins-datadog) 🥲 | Kafka, Iceberg. [Looks promising](https://www.youtube.com/watch?v=LWDeIHfAC9A)! | - |
| **Conclusion** | **Great**! | **RAM eater**  | **Too expensive** | **It was promising, but got discontinued** | **No analytics, very complicated and slow ... for [now](https://www.youtube.com/watch?v=LWDeIHfAC9A)** | **Want to test it** |


**Why Victoria Logs Wins:**

- 🚀 Blazing fast (Go-based)
- 💰 Cost-effective
- 🎯 Super simple to set up and maintain
- 🔍 Powerful LogsQL query language
- 📈 Great support and active development
- 🎁 Object storage support coming soon!

**When to Choose Elasticsearch:**

- You already have an ELK stack
- You need ES|QL for complex queries
- You want to use Kibana's specific features
- You need specific Elasticsearch integrations

!!! success "Chef's Recommendation"
    **Use Victoria Logs**
    
    It's the sweet spot of simplicity, performance, and query power.
    
    It's actively developed with a great roadmap!
    
## Visualization

|                   | Kibana            | Grafana           | 
| ----------------- | ----------------- | ----------------- | 
| Multiple datasources | No | Yes | 
| ES\|QL for Elasticsearch | Yes | No | 
| Simplicity | Yes | Steap learning curve | 
| Customization | Yes. Trough Vega | Super! | 
| Cache | No | Yes | 
| Snapshots | No | Yes | 
| Colapsable Pannels | Yes | Yes |
| Dynamic Pannels | No | Yes | 
| Filters | Yes | Yes | 
| Reports | Yes. Paid | Yes. Paid | 
| **Conclusion**    | Will keep suppoting it | **Current depevelopment and maintance** |

!!! success "Chef's Recommendation"
    Using Victoria Logs? → **Use Grafana**

    Using Elasticsearch? → **Use Kibana**
    
    
