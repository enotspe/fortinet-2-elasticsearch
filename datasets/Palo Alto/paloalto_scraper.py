#!/usr/bin/env python3

"""
Palo Alto PAN-OS Syslog Field Scraper

This script scrapes syslog field descriptions from Palo Alto Networks documentation
for different PAN-OS versions and saves them as separate files for format and field descriptions.

Requirements:
    pip install requests beautifulsoup4 pandas lxml pyyaml
"""

import requests
from bs4 import BeautifulSoup
import pandas as pd
import os
import time
from urllib.parse import urljoin
import re
import logging
import yaml
from typing import List, Dict, Optional, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class PaloAltoLogScraper:
    def __init__(self, config_file='paloalto_scraper_config.yaml', base_delay=None):
        """
        Initialize the scraper with rate limiting and configuration

        Args:
            config_file: Path to the YAML configuration file
            base_delay: Base delay between requests in seconds (overrides config file if provided)
        """
        # Load configuration from file
        config = self._load_config(config_file)
        
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        
        # Use provided base_delay or fall back to config file value
        self.base_delay = base_delay if base_delay is not None else config.get('settings', {}).get('base_delay', 1.0)

        # Load PAN-OS versions from configuration file
        self.versions = config.get('versions', [])
        if not self.versions:
            logger.warning("No versions found in configuration file. Scraper will not process any versions.")

        # Set output directory (defaults to current working directory)
        self.output_dir = config.get('settings', {}).get('output_dir', os.getcwd())
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Load force_rescrape and dry_run flags
        self.force_rescrape = config.get('settings', {}).get('force_rescrape', False)
        self.dry_run = config.get('settings', {}).get('dry_run', False)
        
        logger.info(f"Loaded {len(self.versions)} versions from configuration file")
        logger.info(f"Force rescrape: {self.force_rescrape}")
        logger.info(f"Dry run mode: {self.dry_run}")
    
    def _load_config(self, config_file: str) -> dict:
        """
        Load configuration from YAML file
        
        Args:
            config_file: Path to the YAML configuration file
            
        Returns:
            Dictionary containing configuration
        """
        # Get the directory where this script is located
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, config_file)
        
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                logger.info(f"Successfully loaded configuration from {config_path}")
                return config
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {config_path}")
            raise
        except yaml.YAMLError as e:
            logger.error(f"Error parsing YAML configuration: {e}")
            raise
    
    def _version_exists(self, version: dict) -> bool:
        """
        Check if a version has already been scraped
        
        Args:
            version: Version dictionary with 'name' and 'log_types' keys
            
        Returns:
            True if the version directory exists and contains files, False otherwise
        """
        version_dir = self.get_version_directory(version['name'])
        
        # Check if the version directory exists and has files
        if os.path.exists(version_dir):
            files = [f for f in os.listdir(version_dir) if f.endswith('.csv')]
            if files:
                logger.info(f"Version {version['name']} already exists with {len(files)} files")
                return True
        
        return False
    
    def _get_versions_to_scrape(self) -> List[dict]:
        """
        Get the list of versions to scrape based on force_rescrape flag
        
        Returns:
            List of version dictionaries to scrape
        """
        if self.force_rescrape:
            logger.info("Force rescrape enabled - will scrape all versions")
            return self.versions
        
        # Filter out existing versions
        versions_to_scrape = [v for v in self.versions if not self._version_exists(v)]
        
        existing_count = len(self.versions) - len(versions_to_scrape)
        logger.info(f"Found {existing_count} existing versions, {len(versions_to_scrape)} new versions to scrape")
        
        return versions_to_scrape

    def get_version_directory(self, version_name: str) -> str:
        """
        Get the version directory path

        Args:
            version_name: Version name like '11.1+'

        Returns:
            Path to version directory
        """
        return os.path.join(self.output_dir, version_name)

    def get_page_content(self, url: str) -> Optional[BeautifulSoup]:
        """
        Fetch and parse a web page

        Args:
            url: URL to fetch

        Returns:
            BeautifulSoup object or None if failed
        """
        try:
            logger.info(f"Fetching: {url}")
            response = self.session.get(url, timeout=30)
            response.raise_for_status()

            # Rate limiting
            time.sleep(self.base_delay)

            return BeautifulSoup(response.content, 'html.parser')

        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching {url}: {e}")
            return None

    def extract_format_string(self, soup: BeautifulSoup) -> Optional[str]:
        """
        Extract the syslog format string from the page
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Format string or None if not found
        """
        # Look for text that starts with "Format:"
        text_content = soup.get_text()
        
        # Pattern to match "Format:" followed by the comma-separated list
        format_match = re.search(r'Format\s*:\s*(.+?)(?:\n\s*\n|\n{2,})', text_content, re.IGNORECASE | re.DOTALL)
        
        if format_match:
            format_string = format_match.group(1).strip()
            # Clean up any extra whitespace
            format_string = re.sub(r'\s+', ' ', format_string)
            logger.info(f"Found format string: {format_string[:100]}...")
            return format_string
        
        logger.warning("No format string found on page")
        return None

    def _extract_variable_name(self, field_name: str) -> str:
        """
        Extract variable name from Field Name.
        Format: "Field Long Name (variable_name ...)" -> "variable_name"
        """
        match = re.match(r"^.+?\s+\(([^)]+)\)", str(field_name))
        if match:
            # Take first word in parentheses (handles "x or y" cases)
            return match.group(1).split()[0].strip()
        return ""

    def _build_name_map(self, field_table: pd.DataFrame) -> Dict[str, str]:
        """Build mapping from long field names to variable names."""
        name_map = {}
        if 'Field Name' not in field_table.columns or 'Variable Name' not in field_table.columns:
            return name_map

        for _, row in field_table.iterrows():
            field_name = str(row['Field Name'])
            var_name = str(row['Variable Name'])
            if not var_name:
                continue
            # Extract long name (text before parentheses)
            match = re.match(r"^(.+?)\s+\(", field_name)
            if match:
                long_name = match.group(1).strip()
                name_map[long_name] = var_name
                # Normalized versions for matching
                normalized = re.sub(r'\s+', ' ', long_name)
                name_map[normalized] = var_name
                name_map[normalized.lower()] = var_name
        return name_map

    def _transform_format_string(self, format_string: str, name_map: Dict[str, str]) -> str:
        """Transform format string: replace long names with variable names."""
        format_items = [item.strip() for item in format_string.split(',')]
        new_items = []

        for item in format_items:
            # Special case: Device Group Hierarchy Level X
            match_dg = re.match(r"Device Group Hierarchy Level (\d+)", item, re.IGNORECASE)
            if match_dg:
                new_items.append(f"dg_hier_level_{match_dg.group(1)}")
                continue

            # Special case: Protocol -> ip protocol
            if item == "Protocol" and "ip protocol" in name_map:
                new_items.append(name_map["ip protocol"])
                continue

            # Try direct match, then normalized, then lowercase
            normalized = re.sub(r'\s+', ' ', item)
            if item in name_map:
                new_items.append(name_map[item])
            elif normalized in name_map:
                new_items.append(name_map[normalized])
            elif normalized.lower() in name_map:
                new_items.append(name_map[normalized.lower()])
            else:
                new_items.append(item)  # Keep original (e.g., FUTURE_USE)

        # Enclose each item in double quotes for CSV format
        return ",".join(f'"{item}"' for item in new_items)

    def _get_cell_text_with_formatting(self, cell) -> str:
        """
        Extract text from a BeautifulSoup cell while preserving
        line breaks from HTML block elements.
        """
        # Get the inner HTML
        html = str(cell)

        # First, normalize all whitespace (including newlines) to single spaces
        # This removes spurious line breaks from HTML source formatting
        html = re.sub(r'\s+', ' ', html)

        # Now add intentional line breaks for block elements
        # Replace <br> tags with newlines
        html = re.sub(r'<br\s*/?>', '\n', html, flags=re.IGNORECASE)

        # Add newlines before block-level opening tags
        block_tags = r'<(p|div|li|dt|dd|tr|h[1-6])\b[^>]*>'
        html = re.sub(block_tags, r'\n<\1>', html, flags=re.IGNORECASE)

        # Add newlines after </p> tags (paragraph separation)
        html = re.sub(r'</p>', '</p>\n', html, flags=re.IGNORECASE)

        # Add newlines after list containers
        html = re.sub(r'</(ul|ol|dl)>', r'</\1>\n', html, flags=re.IGNORECASE)

        # Parse and extract text
        soup = BeautifulSoup(html, 'html.parser')
        text = soup.get_text()

        # Clean up whitespace
        text = re.sub(r'[^\S\n]+', ' ', text)  # Multiple spaces to single (preserve newlines)
        text = re.sub(r'\n{3,}', '\n\n', text)  # 3+ newlines to double
        lines = [line.strip() for line in text.split('\n')]
        text = '\n'.join(lines)

        return text.strip()

    def extract_field_table(self, soup: BeautifulSoup) -> Optional[pd.DataFrame]:
        """
        Extract the field description table from the page
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            DataFrame with field descriptions or None if not found
        """
        # Look for tables that contain field descriptions
        tables = soup.find_all('table')
        
        for table in tables:
            # Check if this table contains field information
            headers = [th.get_text(strip=True).lower() for th in table.find_all('th')]
            
            # Look for tables with "field name" and "description" headers
            if 'field name' in ' '.join(headers) or 'field' in ' '.join(headers):
                try:
                    # Extract table data
                    data = []
                    rows = table.find_all('tr')
                    
                    if not rows:
                        continue
                    
                    # Get headers
                    header_row = rows[0]
                    headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
                    
                    # Get data rows
                    for row in rows[1:]:
                        cells = row.find_all(['td', 'th'])
                        if len(cells) >= len(headers):
                            row_data = [self._get_cell_text_with_formatting(cell) for cell in cells[:len(headers)]]
                            data.append(row_data)
                    
                    if data:
                        df = pd.DataFrame(data, columns=headers)

                        # Add Variable Name column extracted from Field Name
                        if 'Field Name' in df.columns:
                            variable_names = [self._extract_variable_name(fn) for fn in df['Field Name']]
                            # Insert after Field Name column
                            field_name_idx = df.columns.get_loc('Field Name')
                            df.insert(field_name_idx + 1, 'Variable Name', variable_names)

                        logger.info(f"Extracted field table: {len(df)} rows")
                        return df
                
                except Exception as e:
                    logger.error(f"Error parsing field table: {e}")
                    continue
        
        logger.warning("No field description table found")
        return None

    def scrape_log_type(self, log_type: dict, version_dir: str) -> bool:
        """
        Scrape a specific log type and save format and table files
        
        Args:
            log_type: Dictionary with 'name' and 'url' keys
            version_dir: Directory to save files
            
        Returns:
            True if successful, False otherwise
        """
        logger.info(f"Processing log type: {log_type['name']}")
        
        soup = self.get_page_content(log_type['url'])
        if not soup:
            logger.error(f"Failed to fetch page for {log_type['name']}")
            return False
        
        # Extract format string
        format_string = self.extract_format_string(soup)

        # Extract field table
        field_table = self.extract_field_table(soup)
        if field_table is not None:
            # Save table to CSV
            table_filename = f"{log_type['name']}_fields.csv"
            table_filepath = os.path.join(version_dir, table_filename)

            try:
                field_table.to_csv(table_filepath, index=False)
                logger.info(f"Saved field table to {table_filepath}")
            except Exception as e:
                logger.error(f"Error saving field table: {e}")

        # Save format file: line 1 = original, line 2 = transformed
        if format_string and field_table is not None:
            format_filename = f"{log_type['name']}_format.csv"
            format_filepath = os.path.join(version_dir, format_filename)

            name_map = self._build_name_map(field_table)
            transformed = self._transform_format_string(format_string, name_map)

            try:
                with open(format_filepath, 'w', encoding='utf-8') as f:
                    f.write(f"{format_string}\n")
                    f.write(f"{transformed}\n")
                logger.info(f"Saved format to {format_filepath}")
            except Exception as e:
                logger.error(f"Error saving format file: {e}")
        elif format_string:
            # Save format without transformation if no field table
            format_filename = f"{log_type['name']}_format.csv"
            format_filepath = os.path.join(version_dir, format_filename)

            try:
                with open(format_filepath, 'w', encoding='utf-8') as f:
                    f.write(f"{format_string}\n")
                logger.info(f"Saved format to {format_filepath} (no transformation - field table missing)")
            except Exception as e:
                logger.error(f"Error saving format file: {e}")

        return format_string is not None or field_table is not None

    def scrape_version(self, version: dict) -> int:
        """
        Scrape all log types for a specific PAN-OS version
        
        Args:
            version: Version dictionary with 'name' and 'log_types' keys
            
        Returns:
            Number of successfully processed log types
        """
        logger.info(f"Starting scrape for PAN-OS version {version['name']}")
        
        # Create version directory
        version_dir = self.get_version_directory(version['name'])
        os.makedirs(version_dir, exist_ok=True)
        
        # Process each log type
        successful_count = 0
        
        for log_type in version['log_types']:
            if self.scrape_log_type(log_type, version_dir):
                successful_count += 1
        
        return successful_count

    def run(self, specific_versions: Optional[List[dict]] = None):
        """
        Run the complete scraping process
        
        Args:
            specific_versions: Optional list of specific versions to scrape
        """
        # Determine which versions to scrape
        if specific_versions:
            # If specific versions provided, use them directly
            versions_to_scrape = specific_versions
            logger.info(f"Using {len(specific_versions)} specific versions provided by caller")
        else:
            # Otherwise, use the smart filtering based on force_rescrape flag
            versions_to_scrape = self._get_versions_to_scrape()

        logger.info(f"Starting scrape for {len(versions_to_scrape)} versions")
        
        # Dry run mode - just print what would be scraped
        if self.dry_run:
            logger.info("=" * 60)
            logger.info("DRY RUN MODE - No actual scraping will be performed")
            logger.info("=" * 60)
            logger.info(f"\nVersions that would be scraped ({len(versions_to_scrape)} total):")
            for i, version in enumerate(versions_to_scrape, 1):
                version_dir = self.get_version_directory(version['name'])
                logger.info(f"  {i}. Version {version['name']} -> {version_dir}")
                for log_type in version['log_types']:
                    logger.info(f"      - {log_type['name']}: {log_type['url']}")
            logger.info("\n" + "=" * 60)
            logger.info(f"Total versions to scrape: {len(versions_to_scrape)}")
            logger.info("=" * 60)
            return

        total_processed = 0
        for version in versions_to_scrape:
            try:
                logger.info(f"Processing version {version['name']}")
                successful_count = self.scrape_version(version)
                total_processed += successful_count
                logger.info(f"Completed version {version['name']} - {successful_count} log types processed")

                # Brief pause between versions
                time.sleep(2)

            except Exception as e:
                logger.error(f"Error processing version {version['name']}: {e}")
                continue

        logger.info(f"Scraping completed! Total log types processed: {total_processed}")

def main():
    """Main execution function"""
    scraper = PaloAltoLogScraper(base_delay=1.0)

    # Scrape all versions from config
    scraper.run()

if __name__ == "__main__":
    main()
