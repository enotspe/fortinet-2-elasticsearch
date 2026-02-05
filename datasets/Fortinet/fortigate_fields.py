# -*- coding: utf-8 -*-
"""
Fortigate Fields Extractor

Unified script to process log files across different Fortigate versions and extract
unique fields with their descriptions and data types for all log types:
- Traffic logs (using Category column for subtype labeling)
- Event logs (using Category column for subtype labeling)
- UTM logs (using Type column for subtype labeling, with special action field handling)

UTM logs include: APP-CTRL, Anomaly, DLP, DNS, EmailFilter, FILE-FILTER,
FORTI-SWITCH, ICAP, IPS, SSH, SSL, Virus, VoIP, WAF, Webfilter, casb, virtual-patch

Excludes: GTP (only present in FortiGate Carrier)
"""

import glob
import os
from collections import defaultdict

import pandas as pd


# Types to exclude from all processing
EXCLUDED_TYPES = {'GTP'}

# Log type definitions with their subtype column
LOG_TYPE_CONFIG = {
    'Traffic': {
        'filter_column': 'Type',
        'filter_value': 'Traffic',
        'subtype_column': 'Category',
        'output_prefix': 'traffic',
        'special_action': False,
    },
    'Event': {
        'filter_column': 'Type',
        'filter_value': 'Event',
        'subtype_column': 'Category',
        'output_prefix': 'event',
        'special_action': False,
    },
    'UTM': {
        'filter_column': 'Type',
        'filter_values_exclude': {'Traffic', 'Event', 'GTP'},
        'subtype_column': 'Type',
        'output_prefix': 'utm',
        'special_action': True,
    },
}


def normalize_description(desc):
    """Normalize description for comparison (lowercase, strip whitespace)."""
    if pd.isna(desc) or not desc:
        return ''
    return str(desc).strip().lower()


def get_canonical_description(descriptions):
    """
    Given a list of similar descriptions (case-insensitive matches),
    return the most common one with its original casing.
    """
    if not descriptions:
        return ''
    # Count occurrences
    counts = defaultdict(int)
    for desc in descriptions:
        counts[desc] += 1
    # Return most common
    return max(counts.keys(), key=lambda d: counts[d])


def process_field_descriptions(field_data):
    """
    Process descriptions for a single field across all subtypes.

    Args:
        field_data: dict mapping subtype -> list of descriptions

    Returns:
        str: final consolidated description
    """
    # Group descriptions by normalized form
    normalized_groups = defaultdict(list)  # normalized -> [(original_desc, subtype), ...]

    for subtype, descriptions in field_data.items():
        for desc in descriptions:
            norm = normalize_description(desc)
            if norm:  # Skip empty descriptions
                normalized_groups[norm].append((desc, subtype))

    if not normalized_groups:
        return ''

    # Build the final description
    # For each unique normalized description, find which subtypes use it
    unique_meanings = []  # [(canonical_desc, [subtypes]), ...]

    for norm, desc_subtype_pairs in normalized_groups.items():
        # Get canonical (most common) description text
        descs = [d for d, s in desc_subtype_pairs]
        canonical = get_canonical_description(descs)

        # Get all subtypes that use this description
        subtypes = sorted(set(s for d, s in desc_subtype_pairs))
        unique_meanings.append((canonical, subtypes))

    # Sort by first subtype name for consistent output
    unique_meanings.sort(key=lambda x: x[1][0] if x[1] else '')

    if len(unique_meanings) == 1:
        # Only one meaning across all subtypes - just use the description
        return unique_meanings[0][0]
    else:
        # Multiple different meanings - label by subtype
        labeled_parts = []
        for desc, subtypes in unique_meanings:
            # Label with all subtypes that share this meaning
            label = '/'.join(subtypes)
            labeled_parts.append(f"{label}: {desc}")

        return '\n\n'.join(labeled_parts)


def process_log_type(all_files, log_type_name, config):
    """
    Process all CSV files for a specific log type.

    Args:
        all_files: List of CSV file paths to process
        log_type_name: Name of the log type (Traffic, Event, UTM)
        config: Configuration dict for this log type

    Returns:
        tuple: (unique_fields_list, action_descriptions_dict or None, subtypes_found)
    """
    # Data structures to collect field information
    # field_name -> subtype -> [descriptions]
    field_descriptions = defaultdict(lambda: defaultdict(list))
    # field_name -> [data_types]
    field_data_types = defaultdict(list)
    # Track subtypes found
    subtypes_found = set()
    # Special handling for action field (UTM only)
    action_descriptions = defaultdict(list)  # subtype -> [descriptions]

    subtype_column = config['subtype_column']
    special_action = config['special_action']

    # Process all files
    for file_path in all_files:
        try:
            df = pd.read_csv(file_path)

            if 'Type' not in df.columns:
                continue

            # Filter rows based on log type
            if 'filter_value' in config:
                filtered_df = df[df['Type'] == config['filter_value']]
            elif 'filter_values_exclude' in config:
                filtered_df = df[~df['Type'].isin(config['filter_values_exclude'])]
            else:
                continue

            if filtered_df.empty:
                continue

            # Process each row
            for _, row in filtered_df.iterrows():
                field_name = row['Log Field Name']
                description = row.get('Description', '')
                data_type = row.get('Data Type', '')
                subtype = row.get(subtype_column, '')

                if pd.isna(field_name) or not field_name:
                    continue

                subtypes_found.add(subtype)

                # Collect data type
                if not pd.isna(data_type) and data_type:
                    field_data_types[field_name].append(data_type)

                # Collect description with subtype
                desc_str = '' if pd.isna(description) else str(description)

                if special_action and field_name == 'action':
                    # Special handling for action field in UTM
                    if desc_str:
                        action_descriptions[subtype].append(desc_str)
                else:
                    field_descriptions[field_name][subtype].append(desc_str)

        except Exception:
            pass  # Silently skip files that don't have the expected structure

    if not field_descriptions and not (special_action and action_descriptions):
        return None, None, subtypes_found

    # Normalize integer data types to 'number'
    integer_types = ['uint64', 'uint32', 'uint16', 'uint8', 'int8', 'int32', 'int64']

    # Process each field
    unique_fields = []
    inconsistent_types = 0
    labeled_fields = 0

    for field_name in sorted(field_descriptions.keys()):
        # Process data types
        data_types = list(set(field_data_types.get(field_name, ['string'])))
        # Normalize integer types
        normalized_types = set()
        for dt in data_types:
            if dt in integer_types:
                normalized_types.add('number')
            else:
                normalized_types.add(dt)

        if len(normalized_types) > 1:
            final_data_type = 'string'
            inconsistent_types += 1
        else:
            final_data_type = list(normalized_types)[0] if normalized_types else 'string'

        # Process descriptions
        subtype_descs = field_descriptions[field_name]
        final_desc = process_field_descriptions(subtype_descs)

        if '\n\n' in final_desc:
            labeled_fields += 1

        unique_fields.append({
            'Log Field Name': field_name,
            'Description': final_desc,
            'Data Type': final_data_type
        })

    # Handle action field for UTM
    if special_action:
        # Add action field with empty description
        action_data_types = list(set(field_data_types.get('action', ['string'])))
        normalized_action_types = set()
        for dt in action_data_types:
            if dt in integer_types:
                normalized_action_types.add('number')
            else:
                normalized_action_types.add(dt)

        action_data_type = 'string' if len(normalized_action_types) > 1 else (
            list(normalized_action_types)[0] if normalized_action_types else 'string'
        )

        unique_fields.append({
            'Log Field Name': 'action',
            'Description': '',
            'Data Type': action_data_type
        })

    return unique_fields, action_descriptions if special_action else None, subtypes_found, inconsistent_types, labeled_fields


def process_major_version(major_version_path, major_version_name):
    """
    Process all CSV files in all minor version folders within a major version.
    Extract fields for Traffic, Event, and UTM log types.

    Args:
        major_version_path: Path to the major version folder (e.g., 'Fortigate/7.6')
        major_version_name: Name of the major version (e.g., '7.6')
    """
    print(f"\n{'='*80}")
    print(f"Processing Major Version: {major_version_name}")
    print(f"{'='*80}")

    # Get all minor version folders (exclude special folders)
    minor_version_folders = [d for d in os.listdir(major_version_path)
                            if os.path.isdir(os.path.join(major_version_path, d))
                            and not d.startswith(('elasticsearch', 'unique'))]

    if not minor_version_folders:
        print(f"No minor version folders found in {major_version_path}")
        return

    print(f"Found minor versions: {', '.join(sorted(minor_version_folders))}")

    # Collect all CSV files from all minor versions
    all_files = []
    for minor_version in minor_version_folders:
        minor_path = os.path.join(major_version_path, minor_version)
        csv_files = glob.glob(os.path.join(minor_path, '*.csv'))
        all_files.extend(csv_files)
        print(f"  - {minor_version}: {len(csv_files)} CSV files")

    if not all_files:
        print(f"No CSV files found in any minor version of {major_version_name}")
        return

    print(f"\nTotal CSV files to process: {len(all_files)}")

    # Prepare results folder
    results_folder = os.path.join(major_version_path, "unique_fields")
    if not os.path.exists(results_folder):
        os.makedirs(results_folder)
        print(f"\nCreated results folder: {results_folder}")

    version_suffix = major_version_name.replace('.', '_')

    # Process each log type
    for log_type_name, config in LOG_TYPE_CONFIG.items():
        print(f"\n--- Processing {log_type_name} logs ---")

        result = process_log_type(all_files, log_type_name, config)

        if result[0] is None:
            print(f"No {log_type_name} data could be processed for {major_version_name}")
            continue

        unique_fields, action_descriptions, subtypes_found, inconsistent_types, labeled_fields = result

        print(f"{log_type_name} subtypes found: {', '.join(sorted(subtypes_found))}")

        # Create and save dataframe
        result_df = pd.DataFrame(unique_fields)
        result_df = result_df.sort_values('Log Field Name').reset_index(drop=True)

        print(f"Unique {log_type_name} fields: {len(result_df)}")
        if inconsistent_types > 0:
            print(f"  - Converted {inconsistent_types} fields with inconsistent data types to 'string'")
        if labeled_fields > 0:
            print(f"  - {labeled_fields} fields have subtype-labeled descriptions")

        output_file = os.path.join(results_folder, f'{config["output_prefix"]}_fields_{version_suffix}.csv')
        result_df.to_csv(output_file, index=False, na_rep='')
        print(f"  Saved: {output_file}")

        # Handle action descriptions for UTM
        if action_descriptions:
            action_output_file = os.path.join(results_folder, f'action_descriptions_{version_suffix}.csv')

            # Sort subtypes for consistent column order
            sorted_subtypes = sorted(action_descriptions.keys())

            if sorted_subtypes:
                # Create a single row with descriptions for each subtype
                action_data = {}
                for subtype in sorted_subtypes:
                    descs = action_descriptions[subtype]
                    # Get unique descriptions (deduplicated by normalized form)
                    seen = set()
                    unique_descs = []
                    for d in descs:
                        norm = normalize_description(d)
                        if norm and norm not in seen:
                            seen.add(norm)
                            unique_descs.append(d)

                    # Join multiple descriptions with double newline
                    action_data[subtype] = '\n\n'.join(unique_descs) if unique_descs else ''

                action_df = pd.DataFrame([action_data])
                action_df.to_csv(action_output_file, index=False)
                print(f"  - Action field has descriptions from {len(sorted_subtypes)} subtypes")
                print(f"  Saved: {action_output_file}")


def main():
    """Main function to process all major versions."""
    # Define the main Fortigate folder
    main_folder = "Fortigate"

    if not os.path.exists(main_folder):
        print(f"Error: Main folder '{main_folder}' not found!")
        print(f"Please ensure the script is in the same directory as the Fortigate folder,")
        print(f"or update the 'main_folder' variable with the correct path.")
        return

    # Get all major version folders (e.g., 7.2, 7.4, 7.6)
    major_versions = [d for d in os.listdir(main_folder)
                     if os.path.isdir(os.path.join(main_folder, d))]

    if not major_versions:
        print(f"No version folders found in {main_folder}")
        return

    # Sort versions for better output
    major_versions.sort()

    print(f"Found major versions: {', '.join(major_versions)}")

    # Process each major version
    for major_version in major_versions:
        major_version_path = os.path.join(main_folder, major_version)
        process_major_version(major_version_path, major_version)

    print(f"\n{'='*80}")
    print("All versions processed successfully!")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()
