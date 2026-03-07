# -*- coding: utf-8 -*-
"""
Elasticsearch Component Template Generator for Fortigate Logs

Fetches unique_fields CSVs from the flores GitHub repository and generates
Elasticsearch component templates that can be uploaded via API.

Environment variables:
  FLORES_REPO   - GitHub repo in "owner/name" format (default: enotspe/flores)
  FLORES_BRANCH - Branch to fetch from (default: main)
"""

import io
import json
import os
import re

import pandas as pd
import requests


FLORES_REPO = os.environ.get("FLORES_REPO", "enotspe/flores")
FLORES_BRANCH = os.environ.get("FLORES_BRANCH", "main")

GITHUB_API_BASE = f"https://api.github.com/repos/{FLORES_REPO}/contents"
RAW_BASE = f"https://raw.githubusercontent.com/{FLORES_REPO}/{FLORES_BRANCH}"

VERSION_RE = re.compile(r"^\d+\.\d+$")


def map_data_type_to_es(data_type):
    """
    Map CSV data types to Elasticsearch field types with appropriate settings.

    Args:
        data_type: Data type from CSV (string, ip, number)

    Returns:
        Dictionary with Elasticsearch field type and settings
    """
    if data_type.lower() == 'string':
        return {
            "type": "keyword"
        }
    elif data_type.lower() == 'ip':
        return {
            "type": "ip"
        }
    elif data_type.lower() == 'number':
        return {
            "type": "long"
        }
    else:
        # Default to keyword
        return {
            "type": "keyword"
        }


def create_component_template(log_type, version, fields_df):
    """
    Create an Elasticsearch component template from field definitions.

    Args:
        log_type: Type of log (traffic, event, utm)
        version: Fortigate version (e.g., 7_6)
        fields_df: DataFrame with 'Log Field Name' and 'Data Type' columns

    Returns:
        Dictionary representing the component template
    """
    # Build the properties object for fields under 'fgt'
    fgt_properties = {}

    for _, row in fields_df.iterrows():
        field_name = row['Log Field Name']
        data_type = row['Data Type']
        es_field_config = map_data_type_to_es(data_type)

        fgt_properties[field_name] = es_field_config

    # Create the component template structure with fgt nested object
    template = {
        "template": {
            "mappings": {
                "properties": {
                    "fgt": {
                        "type": "object",
                        "properties": fgt_properties
                    }
                }
            }
        },
        "_meta": {
            "description": f"Fortigate {log_type} logs mapping for version {version.replace('_', '.')}",
            "version": version.replace('_', '.')
        }
    }

    return template


def discover_versions():
    """Return list of major version strings from the flores GitHub repo."""
    url = f"{GITHUB_API_BASE}/"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    entries = resp.json()
    versions = [
        e["name"] for e in entries
        if e["type"] == "dir" and VERSION_RE.match(e["name"])
    ]
    return sorted(versions)


def fetch_csv(version, log_type):
    """Fetch a unique_fields CSV for the given version and log_type."""
    version_suffix = version.replace(".", "_")
    filename = f"unique_log_fields_data_types_{log_type}_{version_suffix}.csv"
    url = f"{RAW_BASE}/{version}/unique_fields/{filename}"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return pd.read_csv(io.StringIO(resp.text))


def process_version(version, output_base):
    """Fetch CSVs for one major version and generate component templates."""
    version_suffix = version.replace(".", "_")
    templates_folder = output_base
    os.makedirs(templates_folder, exist_ok=True)

    print(f"\nProcessing version {version}:")

    for log_type in ("traffic", "event", "utm"):
        try:
            df = fetch_csv(version, log_type)
            print(f"  Processing {log_type}: {len(df)} fields")

            template = create_component_template(log_type, version_suffix, df)
            template_name = f"fortigate_{log_type}_{version_suffix}"
            output_file = os.path.join(templates_folder, f"{template_name}.json")

            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(template, f, indent=2, ensure_ascii=False)

            print(f"    \u2713 Created: {output_file}")

        except requests.HTTPError as e:
            if e.response.status_code == 404:
                print(f"  Skipping {log_type}: CSV not found in repo")
            else:
                print(f"  Error fetching {log_type}: {e}")
        except Exception as e:
            print(f"  Error processing {log_type}: {e}")


def main():
    """Main function to generate templates for all versions."""
    output_base = os.environ.get("OUTPUT_DIR", "index_templates/component_templates")

    print("=" * 80)
    print("Elasticsearch Component Template Generator")
    print(f"Source: https://github.com/{FLORES_REPO} (branch: {FLORES_BRANCH})")
    print("=" * 80)

    print("Discovering versions from GitHub...")
    try:
        versions = discover_versions()
    except Exception as e:
        print(f"Error fetching version list: {e}")
        return

    if not versions:
        print("No version directories found in the repository.")
        return

    print(f"Found major versions: {', '.join(versions)}")

    for version in versions:
        process_version(version, output_base)

    print(f"\n{'='*80}")
    print("Template generation complete!")
    print(f"{'='*80}")
    print(f"\nGenerated files are in: {output_base}/")


if __name__ == "__main__":
    main()
