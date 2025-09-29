# -*- coding: utf-8 -*-
"""
Elasticsearch Component Template Generator for Fortigate Logs

Reads CSV files with Log Field Names and Data Types, and generates
Elasticsearch component templates that can be uploaded via API.
"""

import os
import json
import pandas as pd
import glob


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


def process_unique_fields_folder(unique_fields_folder, major_version, major_version_path):
    """
    Process all CSV files in a unique_fields folder and generate component templates.

    Args:
        unique_fields_folder: Path to the unique_fields folder
        major_version: Major version name (e.g., '7.6')
        major_version_path: Path to the major version folder
    """
    version_suffix = major_version.replace('.', '_')

    # Find all relevant CSV files
    csv_pattern = os.path.join(unique_fields_folder, f'unique_log_fields_data_types_*_{version_suffix}.csv')
    csv_files = glob.glob(csv_pattern)

    if not csv_files:
        print(f"No CSV files found in {unique_fields_folder} for version {major_version}")
        return

    print(f"\nProcessing version {major_version}:")
    print(f"Found {len(csv_files)} CSV files")

    # Create templates folder at major version level
    templates_folder = os.path.join(major_version_path, "elasticsearch_templates")
    if not os.path.exists(templates_folder):
        os.makedirs(templates_folder)

    for csv_file in csv_files:
        # Extract log type from filename
        filename = os.path.basename(csv_file)

        # Parse log type (traffic, event, utm)
        if 'traffic' in filename:
            log_type = 'traffic'
        elif 'event' in filename:
            log_type = 'event'
        elif 'utm' in filename:
            log_type = 'utm'
        else:
            print(f"  Skipping unknown file type: {filename}")
            continue

        # Read the CSV
        try:
            df = pd.read_csv(csv_file)
            print(f"  Processing {log_type}: {len(df)} fields")

            # Create component template
            template = create_component_template(log_type, version_suffix, df)

            # Save as JSON
            template_name = f"fortigate_{log_type}_{version_suffix}"
            output_file = os.path.join(templates_folder, f"{template_name}.json")

            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(template, f, indent=2, ensure_ascii=False)

            print(f"    ✓ Created: {output_file}")

        except Exception as e:
            print(f"  Error processing {csv_file}: {e}")


def main():
    """Main function to generate templates for all versions."""
    main_folder = "Fortigate"

    if not os.path.exists(main_folder):
        print(f"Error: Main folder '{main_folder}' not found!")
        return

    # Get all major version folders
    major_versions = [d for d in os.listdir(main_folder)
                     if os.path.isdir(os.path.join(main_folder, d))]

    if not major_versions:
        print(f"No version folders found in {main_folder}")
        return

    major_versions.sort()

    print(f"{'='*80}")
    print("Elasticsearch Component Template Generator")
    print(f"{'='*80}")
    print(f"Found major versions: {', '.join(major_versions)}")

    # Process each major version
    for major_version in major_versions:
        major_version_path = os.path.join(main_folder, major_version)
        unique_fields_folder = os.path.join(major_version_path, "unique_fields")

        if not os.path.exists(unique_fields_folder):
            print(f"\nSkipping {major_version}: No unique_fields folder found")
            continue

        process_unique_fields_folder(unique_fields_folder, major_version, major_version_path)

    print(f"\n{'='*80}")
    print("Template generation complete!")
    print(f"{'='*80}")
    print("\nGenerated files are in: Fortigate/<version>/elasticsearch_templates/")


if __name__ == "__main__":
    main()
