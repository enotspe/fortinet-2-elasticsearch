# Edit vector service to load config files from /etc/vector

Edit vector.service
```
sudo systemctl edit vector
```

We want to make vector load config files from directory
Insert config for overriden default config
```
[Service]
ExecStartPre=
ExecStartPre=/usr/bin/vector validate --config-dir /etc/vector

ExecStart=
ExecStart=/usr/bin/vector --config-dir /etc/vector

ExecReload=
ExecReload=/usr/bin/vector validate --no-environment --config-dir /etc/vector
ExecReload=/bin/kill -HUP $MAINPID
```

restart daemon and service
```
sudo systemctl daemon-reload
sudo systemctl restart vector
```

# env variables for vector config

```
sudo vim /etc/default/vector
```

add env variables
```
FORTIGATE_SYSLOG_UDP_PORT=7140
FORTIGATE_SYSLOG_TCP_PORT=7140

#VICTORIA_LOGS_ENDPOINT="http://localhost:9428"
#VICTORIA_LOGS_USER=""
#VICTORIA_LOGS_PASS=""

ELASTICSEARCH_ENDPOINT="https://localhost:9200"
ELASTICSEARCH_USER="elastic"
ELASTICSEARCH_PASS="mypassword"

LOKI_ENDPOINT="http://localhost:3100"
LOKI_USER="loki"
LOKI_PASS="mypassword"

PROMETHEUS_ENDPOINT="http://localhost:9090"
PROMETHEUS_USER="prometheus"
PROMETHEUS_PASS="mypassword"

TENANT_NAME="mytenant"

INTERNAL_NETWORKS=["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]
```
