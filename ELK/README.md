# ELK

Elasticsearch configuration for FortiDragon — index templates, ingest pipelines, Kibana dashboards, and tooling to deploy them.

## Folder structure

```
ELK/
├── load.sh                          # Deployment script — pushes everything to Elasticsearch
├── .env.example                     # Template for environment-based configuration
├── elasticsearch_mappings.py        # Generates fortigate_* component templates from flores CSVs
│
├── index_templates/
│   ├── component_templates/         # Building blocks composed into index templates
│   │   ├── ecs-*                    # ECS fieldsets (loaded from the elastic/ecs repo by load.sh)
│   │   ├── fortigate_{type}_{ver}   # FortiGate fgt.* field mappings per log type and FortiOS version
│   │   ├── logs-fortinet.*@ilm      # ILM policy references per data stream
│   │   ├── strings_as_keyword@mappings
│   │   ├── auto_expand_replicas@settings
│   │   └── refresh_interval@settings
│   ├── ilm/                         # ILM policy definitions (retention periods)
│   └── index_templates/             # Full index templates, each composing the above components
│
├── ingest_pipelines/                # Elasticsearch ingest pipelines for log parsing and ECS mapping
├── transforms/                      # Elasticsearch transforms for 1-minute traffic aggregations
├── kibana/                          # Kibana dashboard exports (.ndjson), one file per product/version
└── logstash (deprecated)/           # Legacy Logstash configs — do not use
```

Files with a `.deprecated` extension are kept for reference but are not loaded by `load.sh`.

## load.sh

Deploys all Elasticsearch components from this folder to a running cluster.

### Setup

```bash
cd ELK
cp .env.example .env
$EDITOR .env          # set ES_URL, credentials, and toggle what to load
chmod +x load.sh
./load.sh
```

If a `.env` file is present, `load.sh` sources it automatically — no need to export variables beforehand. For a one-off override, pass variables inline:

```bash
ES_URL=https://elastic.example.com:9200 AUTH_METHOD=apikey ES_API_KEY=your_key ./load.sh
```

### What it loads (in order)

| Step | Source | Elasticsearch API |
|------|--------|-------------------|
| ECS component templates | Cloned from `elastic/ecs` on GitHub | `_component_template/ecs-*` |
| Custom component templates | `index_templates/component_templates/*.json` | `_component_template/*` |
| ILM policies | `index_templates/ilm/*.json` | `_ilm/policy/*` |
| Index templates | `index_templates/index_templates/*.json` | `_index_template/*` |
| Ingest pipelines | `ingest_pipelines/*.json` | `_ingest/pipeline/*` |
| Transforms | `transforms/*.json` | `_transform/*` |

Ingest pipelines and transforms are **off by default** — set `LOAD_INGEST_PIPELINES=true` / `LOAD_TRANSFORMS=true` to enable them.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ES_URL` | `https://localhost:9200` | Elasticsearch endpoint |
| `AUTH_METHOD` | `user` | `user` or `apikey` |
| `ES_USERNAME` | `elastic` | Username (user auth) |
| `ES_PASSWORD` | `changeme` | Password (user auth) |
| `ES_API_KEY` | _(empty)_ | API key (apikey auth) |
| `INSECURE` | `false` | Skip SSL verification |
| `LOAD_ECS` | `true` | Load ECS component templates |
| `LOAD_COMPONENT` | `true` | Load custom component templates |
| `LOAD_ILM` | `true` | Load ILM policies |
| `LOAD_INDEX_TEMPLATES` | `true` | Load index templates |
| `LOAD_INGEST_PIPELINES` | `false` | Load ingest pipelines |
| `LOAD_TRANSFORMS` | `false` | Load transforms |
| `ECS_VERSION` | _(latest)_ | Pin a specific ECS tag |
| `USE_EXISTING_ECS` | `true` | Reuse an already-cloned `ecs/` directory |
| `CONTINUE_ON_ERROR` | `true` | Keep going if one upload fails |
| `VERBOSE` | `false` | Print full curl request/response detail |

To also load ingest pipelines (off by default), add `LOAD_INGEST_PIPELINES=true` to your `.env` or pass it inline.

### ECS handling

On first run, `load.sh` clones `elastic/ecs` into `ELK/ecs/` and uploads the generated component templates. On subsequent runs it reuses the existing clone (`USE_EXISTING_ECS=true`). Set `USE_EXISTING_ECS=false` to force a re-clone.

## elasticsearch_mappings.py

Generates the `fortigate_{type}_{version}.json` component templates by fetching field definition CSVs from the [flores](https://github.com/enotspe/flores) GitHub repository.

```bash
cd ELK
python elasticsearch_mappings.py
```

### What it does

1. Queries the flores GitHub API to discover all available version directories (`7.2`, `7.4`, `7.6`, …)
2. For each version and log type (`traffic`, `event`, `utm`), fetches the corresponding `unique_log_fields_data_types_<type>_<ver>.csv`
3. Maps CSV data types to Elasticsearch types:
   - `string` → `keyword`
   - `ip` → `ip`
   - `number` → `long`
4. Writes one JSON component template per (type, version) combination under the configured output directory

Generated files land directly in `index_templates/component_templates/`, ready to be picked up by `load.sh`.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OUTPUT_DIR` | `index_templates/component_templates` | Root output directory |
| `FLORES_REPO` | `enotspe/flores` | GitHub repo to fetch CSVs from |
| `FLORES_BRANCH` | `main` | Branch to fetch from |

### Multi-version strategy

Index templates compose all three FortiOS major versions oldest-first so that 7.6 wins on any type conflict:

```json
"composed_of": [
  ...
  "fortigate_traffic_7_2",
  "fortigate_traffic_7_4",
  "fortigate_traffic_7_6",
  ...
]
```

This means fields introduced in earlier versions are covered, and any type mismatch between versions is resolved by the newest definition.

## Kibana dashboards

Dashboards are exported as `.ndjson` files named `<product> ELK <stack_version>.ndjson`. Import them via **Kibana → Stack Management → Saved Objects → Import**.

Always import the file that matches your Elastic Stack version. Later versions are backwards compatible within the same major release.
