# -*- coding: utf-8 -*-
"""
Fortigate Traffic Fields Extractor

Processes log files across different Fortigate versions and extracts
unique Traffic log fields with their descriptions and data types.
"""

import glob
import os
from collections import Counter

import pandas as pd


def process_major_version(major_version_path, major_version_name):
    """
    Process all CSV files in all minor version folders within a major version.
    Extract only Traffic type logs with Log Field Name, Description, and Data Type.

    Args:
        major_version_path: Path to the major version folder (e.g., 'Fortigate/7.6')
        major_version_name: Name of the major version (e.g., '7.6')
    """
    print(f"\n{'='*80}")
    print(f"Processing Major Version: {major_version_name}")
    print(f"{'='*80}")

    # Get all minor version folders
    minor_version_folders = [d for d in os.listdir(major_version_path)
                            if os.path.isdir(os.path.join(major_version_path, d))]

    if not minor_version_folders:
        print(f"No minor version folders found in {major_version_path}")
        return

    print(f"Found minor versions: {', '.join(minor_version_folders)}")

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

    # Process all files - collect only Traffic type rows
    results_list = []
    for file_path in all_files:
        try:
            df = pd.read_csv(file_path)
            # Filter for Traffic type only
            traffic_df = df[df['Type'] == 'Traffic']
            if not traffic_df.empty:
                # Extract the three columns we need
                fields_df = traffic_df[['Log Field Name', 'Description', 'Data Type']].copy()
                results_list.append(fields_df)
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

    if not results_list:
        print(f"No Traffic data could be processed for {major_version_name}")
        return

    # Consolidate results
    print("\nConsolidating results...")
    consolidated_df = pd.concat(results_list, ignore_index=True)
    print(f"Total Traffic field entries: {len(consolidated_df)}")

    # Normalize integer data types to 'number'
    integer_types = ['uint64', 'uint32', 'uint16', 'uint8', 'int8', 'int32', 'int64']
    consolidated_df['Data Type'] = consolidated_df['Data Type'].replace(integer_types, 'number')

    # Group by field name to handle duplicates
    unique_fields = []
    grouped = consolidated_df.groupby('Log Field Name')

    for field_name, group in grouped:
        # Get unique data types for this field
        data_types = group['Data Type'].unique()

        # If multiple data types exist, normalize to 'string'
        if len(data_types) > 1:
            final_data_type = 'string'
        else:
            final_data_type = data_types[0]

        # Get the most common description (handle case-insensitivity for ties)
        descriptions = group['Description'].fillna('').tolist()
        if descriptions:
            # Count descriptions (case-sensitive first)
            desc_counts = Counter(descriptions)
            # Pick the most common one; if tie, pick the first one encountered
            most_common_desc = desc_counts.most_common(1)[0][0]
        else:
            most_common_desc = ''

        unique_fields.append({
            'Log Field Name': field_name,
            'Description': most_common_desc,
            'Data Type': final_data_type
        })

    # Create final dataframe sorted by field name
    result_df = pd.DataFrame(unique_fields)
    result_df = result_df.sort_values('Log Field Name').reset_index(drop=True)

    print(f"Unique Traffic fields: {len(result_df)}")

    # Check for fields with inconsistent data types
    inconsistent_count = 0
    for field_name, group in grouped:
        if len(group['Data Type'].unique()) > 1:
            inconsistent_count += 1

    if inconsistent_count > 0:
        print(f"  - Converted {inconsistent_count} fields with inconsistent data types to 'string'")

    # Save results
    results_folder = os.path.join(major_version_path, "unique_fields")
    if not os.path.exists(results_folder):
        os.makedirs(results_folder)
        print(f"\nCreated results folder: {results_folder}")

    # Save with version suffix
    version_suffix = major_version_name.replace('.', '_')
    output_file = os.path.join(results_folder, f'traffic_fields_{version_suffix}.csv')

    result_df.to_csv(output_file, index=False)

    print(f"\nResults saved:")
    print(f"  - {output_file}")


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
