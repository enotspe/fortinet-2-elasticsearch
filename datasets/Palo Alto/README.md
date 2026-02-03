# Palo Alto PAN-OS Syslog Field Documentation Scraper

This directory contains a web scraper for extracting Palo Alto Networks PAN-OS syslog field documentation from the official documentation website.

## Files

- **`paloalto_scraper.py`** - Main scraper script
- **`paloalto_scraper_config.yaml`** - Configuration file with URLs and settings
- **`11.0/`** - Directory for PAN-OS 11.0 data (placeholder)
- **`11.1+/`** - Directory containing scraped data for PAN-OS 11.1+

## Scraped Log Types (PAN-OS 11.1+)

The scraper extracts data for the following 17 log types:

1. Traffic Log
2. Threat Log
3. URL Filtering Log
4. Data Filtering Log
5. HIP Match Log
6. GlobalProtect Log
7. IP-Tag Log
8. User-ID Log
9. Decryption Log
10. Tunnel Inspection Log
11. SCTP Log
12. Authentication Log
13. Config Log
14. System Log
15. Correlated Events Log
16. GTP Log
17. Audit Log

## Output Format

For each log type, two files are created:

1. **`{LogType}_format.csv`** - Contains the comma-separated syslog format string
   - Example: `FUTURE_USE, Receive Time, Serial Number, Type, ...`

2. **`{LogType}_fields.csv`** - Contains the field descriptions table
   - Columns: `Field Name`, `Description`
   - Each row describes one field from the format string

Additionally, a consolidated file is generated:

3. **`panos_syslog_fields.csv`** - A unified view of all log types with fields aligned by position
   - Each column represents a log type (Traffic, Threat, URL Filtering, etc.)
   - Each row represents the field at that position across all log types
   - Useful for comparing field structures and building parsers that handle multiple log types

## Usage

### Basic Usage

```bash
python3 paloalto_scraper.py
```

### Configuration Options

Edit `paloalto_scraper_config.yaml` to customize:

- **`versions`** - List of PAN-OS versions to scrape
- **`base_delay`** - Delay between requests (default: 1.0 seconds)
- **`force_rescrape`** - Re-scrape existing versions (default: false)
- **`dry_run`** - Preview what will be scraped without actually scraping (default: false)
- **`output_dir`** - Output directory (default: current directory)

### Dry Run Mode

To see what would be scraped without actually scraping:

```yaml
settings:
  dry_run: true
```

Then run:

```bash
python3 paloalto_scraper.py
```

### Force Re-scrape

To re-scrape versions that already exist:

```yaml
settings:
  force_rescrape: true
```

## Requirements

```bash
pip install requests beautifulsoup4 pandas lxml pyyaml
```

## Adding New Versions

To add a new PAN-OS version, edit `paloalto_scraper_config.yaml`:

```yaml
versions:
  - name: "11.2"
    log_types:
      - name: "Traffic_Log"
        url: "https://docs.paloaltonetworks.com/ngfw/11-2/..."
      # ... add more log types
```

## Example Output

### Traffic_Log_format.csv

```
FUTURE_USE, Receive Time, Serial Number, Type, Threat/Content Type, FUTURE_USE, Generated Time, Source Address, Destination Address, ...
```

### Traffic_Log_fields.csv

```csv
Field Name,Description
Receive Time (receive_time or cef-formatted-receive_time),Time the log was received at the management plane.
Serial Number (serial),"Serial number of the firewall that generated the log."
...
```

## Notes

- The scraper respects rate limiting with a configurable delay between requests
- Existing versions are skipped by default unless `force_rescrape` is enabled
- All scraped data is saved immediately to prevent data loss
- The scraper uses BeautifulSoup for HTML parsing and pandas for CSV generation
