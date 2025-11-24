# Grafana

There are many ways for [installing](https://grafana.com/docs/grafana/latest/setup-grafana/installation/) Grafana, or you can just use [Grafana Cloud](https://grafana.com/products/cloud/) which has a [free](https://grafana.com/pricing/?pg=prod-cloud&plcmt=pricing-details#grafana) tier.

## Victoria Logs

### Install Datasource Plugin

Install [VictoriaLogs datasource plugin](https://grafana.com/grafana/plugins/victoriametrics-logs-datasource/?tab=installation) just by selecting it udner [**Administration > Plugins and data > Plugins**](https://grafana.com/docs/grafana/latest/administration/plugin-management/#browse-plugins) in Grfana Cloud. 

Or via [`grafana cli`](https://grafana.com/docs/grafana/latest/administration/cli/) on a local deployment:

```
grafana-cli plugins install victoriametrics-logs-datasource
```

### Configure Datasource Plugin

Go to [**Home > Connections > Datasources**](https://grafana.com/docs/grafana/latest/datasources/) and click the **Add data source** button in the upper right.

Select **VictoriaLogs**.

Fill `URL` (and other relevant parameters).

Click **Save and Test** button.

## Import Dashbaords

[Import](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/#import-a-dashboard) Grafana dashboards from [here](https://github.com/enotspe/fortinet-2-elasticsearch/tree/main/grafana)

Currently, v2 Dashboards can not be uploaded to [Dashbaords page](https://grafana.com/grafana/dashboards/).

!!! warning "v2 Dynamic Dashboards"
    Make sure you [enable](https://grafana.com/docs/grafana/latest/observability-as-code/provision-resources/git-sync-setup/#enable-required-feature-toggles) on your instance [v2 Dynamic Dashboards](https://grafana.com/docs/grafana/latest/observability-as-code/schema-v2/)

    
!!! warning "v2 Dynamic Dashboards"
    Dynamic dashboards is an [experimental](https://grafana.com/docs/release-life-cycle/#experimental) feature

    
!!! warning "v2 Dynamic Dashboards"
    If the feature flag for dynamic dashboards is enabled, once an existing dashboard is migrated to a dynamic dashboard and using schema v2, it can’t be [migrated back](https://grafana.com/whats-new/2025-05-05-dashboard-v2-schema-and-dynamic-dashboards/)

**Hopefully you should be dancing with your logs by now.** 🕺💃

Enjoy!

## Elasticsearch

Soon...
