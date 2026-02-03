# FortiGate Log Message Reference Tools

This directory contains tools for extracting FortiGate log field documentation from Fortinet's official documentation and generating Elasticsearch mappings.

## Files

- **`fortigate_scraper.py`** - Web scraper for FortiGate Log Message Reference
- **`fortigate_scraper_config.yaml`** - Configuration file with versions and settings
- **`unique_fields.py`** - Consolidates scraped fields into unique field/data-type combinations
- **`elasticsearch_mappings.py`** - Generates Elasticsearch component templates from consolidated fields
- **`Fortigate/`** - Output directory containing scraped data by version

## Workflow

The scripts are designed to be run in sequence:

```
1. fortigate_scraper.py    →  Scrapes log reference documentation
2. unique_fields.py        →  Consolidates fields per major version
3. elasticsearch_mappings.py →  Generates Elasticsearch templates
```

## Requirements

```bash
pip install requests beautifulsoup4 pandas lxml pyyaml
```

## Scripts

### 1. fortigate_scraper.py

Scrapes log message reference tables from Fortinet's documentation website for specified FortiOS versions.

**Usage:**

```bash
python3 fortigate_scraper.py
```

**Configuration (`fortigate_scraper_config.yaml`):**

```yaml
versions:
  - "7.6.0"
  - "7.6.1"
  # ... add more versions

settings:
  base_delay: 1.0        # Delay between requests (seconds)
  force_rescrape: false  # Re-scrape existing versions
  dry_run: false         # Preview without scraping
  output_dir: "Fortigate"
```

**Output:**

Creates `Fortigate/<major>/<minor>/` directories containing CSV files for each log ID with columns:
- `Type` - Log type (Traffic, Event, UTM subtypes)
- `Log Field Name` - Field name as it appears in logs
- `Description` - Field description
- `Data Type` - Data type (string, ip, uint32, etc.)

### 2. unique_fields.py

Processes all scraped CSV files within each major version and consolidates unique field/data-type combinations. Splits output by log category (traffic, event, utm) and normalizes integer types to `number`.

**Usage:**

```bash
python3 unique_fields.py
```

**Output:**

Creates `Fortigate/<major>/unique_fields/` with:
- `unique_log_fields_data_types_traffic_<version>.csv`
- `unique_log_fields_data_types_event_<version>.csv`
- `unique_log_fields_data_types_utm_<version>.csv`

Fields with inconsistent data types across log IDs are normalized to `string`.

### 3. elasticsearch_mappings.py

Generates Elasticsearch component templates from the consolidated field definitions. Maps raw Fortinet fields under the `fgt.*` namespace.

**Usage:**

```bash
python3 elasticsearch_mappings.py
```

**Output:**

Creates `Fortigate/<major>/elasticsearch_templates/` with:
- `fortigate_traffic_<version>.json`
- `fortigate_event_<version>.json`
- `fortigate_utm_<version>.json`

**Data Type Mapping:**

| CSV Data Type | Elasticsearch Type |
|---------------|-------------------|
| string        | keyword           |
| ip            | ip                |
| number        | long              |

## Folder Structure

```
Fortigate/
├── 7.2/
│   ├── 7.2.0/           # Scraped CSVs for each log ID
│   ├── 7.2.1/
│   ├── ...
│   ├── unique_fields/   # Consolidated field definitions
│   └── elasticsearch_templates/  # Generated ES templates
├── 7.4/
│   └── ...
└── 7.6/
    └── ...
```

## Current Coverage

- FortiOS 7.2.x (7.2.0 - 7.2.13)
- FortiOS 7.4.x (7.4.0 - 7.4.11)
- FortiOS 7.6.x (7.6.0 - 7.6.6)

## Notes

- The scraper respects rate limiting with configurable delays between requests
- Existing versions are skipped unless `force_rescrape: true`
- GTP logs are excluded from mappings (FortiGate Carrier only, causes type conflicts)
- Generated templates should be copied to `ELK/index_templates/component_templates/` for deployment
