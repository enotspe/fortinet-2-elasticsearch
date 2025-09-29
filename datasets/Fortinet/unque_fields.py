# -*- coding: utf-8 -*-
"""
Fortigate Data Types Log Reference - Multi-Version Analysis

Processes log files across different Fortigate versions and consolidates
unique combinations of "Log Field Name" and "Data Type" per "Type".
"""

import glob
import os
import pandas as pd

def process_major_version(major_version_path, major_version_name):
    """
    Process all CSV files in all minor version folders within a major version.

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

    # Process all files
    results_list = []
    for file_path in all_files:
        try:
            df = pd.read_csv(file_path)
            unique_combinations = df[['Type', 'Log Field Name', 'Data Type']].drop_duplicates()
            results_list.append(unique_combinations)
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

    if not results_list:
        print(f"No data could be processed for {major_version_name}")
        return

    # Consolidate results
    print("\nConsolidating results...")
    consolidated_df = pd.concat(results_list, ignore_index=True).drop_duplicates()
    print(f"Total unique combinations: {len(consolidated_df)}")

    # Normalize integer data types to 'number'
    integer_types = ['uint64', 'uint32', 'uint16', 'uint8', 'int8', 'int32', 'int64']
    consolidated_df['Data Type'] = consolidated_df['Data Type'].replace(integer_types, 'number')

    # Split into different log types
    df_traffic = consolidated_df[consolidated_df['Type'] == 'Traffic'].copy()
    df_event = consolidated_df[consolidated_df['Type'] == 'Event'].copy()
    utm_types = consolidated_df[~consolidated_df['Type'].isin(['Traffic', 'Event', 'GTP'])]['Type'].unique()
    df_utm = consolidated_df[consolidated_df['Type'].isin(utm_types)].copy()

    print(f"  - Traffic logs: {len(df_traffic)} entries")
    print(f"  - Event logs: {len(df_event)} entries")
    print(f"  - UTM logs: {len(df_utm)} entries")

    # Process each dataframe to resolve inconsistencies
    dataframes = {
        'traffic': df_traffic,
        'event': df_event,
        'utm': df_utm
    }

    processed_dfs = {}

    for log_type, df in dataframes.items():
        if df.empty:
            processed_dfs[log_type] = df
            continue

        # Find fields with inconsistent data types
        inconsistent_data_types = df.groupby('Log Field Name')['Data Type'].nunique()
        inconsistent_fields = inconsistent_data_types[inconsistent_data_types > 1]

        if not inconsistent_fields.empty:
            print(f"\n  Converting {len(inconsistent_fields)} inconsistent fields in {log_type} to 'string'")
            for log_field in inconsistent_fields.index:
                df.loc[df['Log Field Name'] == log_field, 'Data Type'] = 'string'

        processed_dfs[log_type] = df

    # Extract unique combinations
    unique_traffic = processed_dfs['traffic'][['Log Field Name', 'Data Type']].drop_duplicates()
    unique_event = processed_dfs['event'][['Log Field Name', 'Data Type']].drop_duplicates()
    unique_utm = processed_dfs['utm'][['Log Field Name', 'Data Type']].drop_duplicates()

    # Save results
    results_folder = os.path.join(major_version_path, "unique_fields")
    if not os.path.exists(results_folder):
        os.makedirs(results_folder)
        print(f"\nCreated results folder: {results_folder}")

    # Save with version suffix
    version_suffix = major_version_name.replace('.', '_')

    traffic_output = os.path.join(results_folder, f'unique_log_fields_data_types_traffic_{version_suffix}.csv')
    event_output = os.path.join(results_folder, f'unique_log_fields_data_types_event_{version_suffix}.csv')
    utm_output = os.path.join(results_folder, f'unique_log_fields_data_types_utm_{version_suffix}.csv')

    unique_traffic.to_csv(traffic_output, index=False)
    unique_event.to_csv(event_output, index=False)
    unique_utm.to_csv(utm_output, index=False)

    print(f"\nResults saved:")
    print(f"  - {traffic_output}")
    print(f"  - {event_output}")
    print(f"  - {utm_output}")


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
