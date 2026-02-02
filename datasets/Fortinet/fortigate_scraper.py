
"""
FortiGate Log Message Reference Scraper

This script scrapes all log message reference tables from Fortinet documentation
for different FortiOS versions and saves them as CSV files.

Requirements:
    pip install requests beautifulsoup4 pandas lxml pyyaml
"""

import requests
from bs4 import BeautifulSoup
import pandas as pd
import os
import time
from urllib.parse import urljoin, urlparse
import re
import logging
import yaml
from typing import List, Dict, Optional

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FortiGateLogScraper:
    def __init__(self, config_file='fortigate_scraper_config.yaml', base_delay=None):
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

        # Load FortiOS versions from configuration file
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
    
    def _version_exists(self, version: str) -> bool:
        """
        Check if a version has already been scraped
        
        Args:
            version: Version string like '7.6.4'
            
        Returns:
            True if the version directory exists and contains files, False otherwise
        """
        major_version_dir, minor_version_dir = self.get_version_directories(version)
        
        # Check if the minor version directory exists and has CSV files
        if os.path.exists(minor_version_dir):
            csv_files = [f for f in os.listdir(minor_version_dir) if f.endswith('.csv')]
            if csv_files:
                logger.info(f"Version {version} already exists with {len(csv_files)} files")
                return True
        
        return False
    
    def _get_versions_to_scrape(self) -> List[str]:
        """
        Get the list of versions to scrape based on force_rescrape flag
        
        Returns:
            List of version strings to scrape
        """
        if self.force_rescrape:
            logger.info("Force rescrape enabled - will scrape all versions")
            return self.versions
        
        # Filter out existing versions
        versions_to_scrape = [v for v in self.versions if not self._version_exists(v)]
        
        existing_count = len(self.versions) - len(versions_to_scrape)
        logger.info(f"Found {existing_count} existing versions, {len(versions_to_scrape)} new versions to scrape")
        
        return versions_to_scrape

    def get_version_directories(self, version: str) -> tuple:
        """
        Get the major and minor version directory paths

        Args:
            version: Version string like '7.6.4'

        Returns:
            Tuple of (major_version_dir, minor_version_dir)
        """
        # Split version into major (7.6) and full version (7.6.4)
        version_parts = version.split('.')
        if len(version_parts) >= 2:
            major_version = f"{version_parts[0]}.{version_parts[1]}"  # e.g., "7.6"
        else:
            major_version = version  # Fallback if version format is unexpected

        # Create directory paths
        major_version_dir = os.path.join(self.output_dir, major_version)
        minor_version_dir = os.path.join(major_version_dir, version)

        return major_version_dir, minor_version_dir#!/usr/bin/env python3

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

    def get_version_url(self, version: str) -> str:
        """
        Generate the documentation URL for a specific version

        Args:
            version: FortiOS version (e.g., '7.6.4')

        Returns:
            Documentation URL
        """
        return f"https://docs.fortinet.com/document/fortigate/{version}/fortios-log-message-reference/1/log-messages"



    def extract_logid_links(self, soup: BeautifulSoup, base_url: str) -> Dict[str, str]:
        """
        Extract all LOGID links from a page using the specific URL pattern

        Args:
            soup: BeautifulSoup object of the page
            base_url: Base URL for resolving relative links

        Returns:
            Dictionary mapping LOGID description to full URL
        """
        logid_links = {}

        # URL pattern: ends with {logid}-{keyword}-...
        # Where logid = 1-6 digits, keyword = logid|log-id|mesgid
        url_pattern = r'/(\d{1,6})-(logid|log-id|mesgid)-[^/]*$'

        # Look for all links that match the specific pattern
        for link in soup.find_all('a', href=True):
            href = link.get('href')
            text = link.get_text(strip=True)

            # Skip empty links
            if not href or not text:
                continue

            # Check if the URL matches our specific pattern
            if re.search(url_pattern, href, re.IGNORECASE):
                full_url = urljoin(base_url, href)
                logid_links[text] = full_url
                logger.debug(f"Found LOGID link: {text} -> {full_url}")
                continue

        return logid_links

    def extract_log_metadata(self, soup: BeautifulSoup) -> Dict[str, str]:
        """
        Extract log metadata from the page (Message ID, Description, etc.)

        Args:
            soup: BeautifulSoup object of the LOGID page

        Returns:
            Dictionary with metadata fields
        """
        metadata = {
            'Message_ID': '',
            'Message_Description': '',
            'Message_Meaning': '',
            'Type': '',
            'Category': '',
            'Severity': ''
        }

        # Look for the metadata section - typically in bold text or specific formatting
        text_content = soup.get_text()

        # Pattern to match the metadata structure
        patterns = {
            'Message_ID': r'Message ID:\s*(\d+)',
            'Message_Description': r'Message Description:\s*([^\n\r]+)',
            'Message_Meaning': r'Message Meaning:\s*([^\n\r]+)',
            'Type': r'Type:\s*([^\n\r]+)',
            'Category': r'Category:\s*([^\n\r]+)',
            'Severity': r'Severity:\s*([^\n\r]+)'
        }

        # Extract each field using regex
        for field, pattern in patterns.items():
            match = re.search(pattern, text_content, re.IGNORECASE | re.MULTILINE)
            if match:
                metadata[field] = match.group(1).strip()
                logger.debug(f"Found {field}: {metadata[field]}")

        # Also try to extract from the main header (like "20002 - LOG_ID_DOMAIN_UNRESOLVABLE")
        header_match = re.search(r'(\d+)\s*-\s*([A-Z_]+)', text_content)
        if header_match:
            if not metadata['Message_ID']:
                metadata['Message_ID'] = header_match.group(1).strip()
            if not metadata['Message_Description']:
                metadata['Message_Description'] = header_match.group(2).strip()

        # Try alternative patterns if standard ones don't work
        if not metadata['Message_ID']:
            # Look for any number that might be the message ID
            id_match = re.search(r'\b(\d{4,6})\b', text_content)
            if id_match:
                metadata['Message_ID'] = id_match.group(1)

        return metadata

    def extract_log_table(self, soup: BeautifulSoup, logid: str) -> Optional[pd.DataFrame]:
        """
        Extract log message table from a LOGID page along with metadata

        Args:
            soup: BeautifulSoup object of the LOGID page
            logid: LOGID identifier

        Returns:
            DataFrame with log fields and metadata or None if not found
        """
        # First extract metadata
        metadata = self.extract_log_metadata(soup)

        # Look for tables that contain log field information
        tables = soup.find_all('table')

        for table in tables:
            # Check if this table contains log field information
            headers = [th.get_text(strip=True).lower() for th in table.find_all('th')]

            # Common header patterns for log field tables
            expected_headers = ['field', 'description', 'type', 'length', 'data type', 'field name']

            if any(header in ' '.join(headers) for header in expected_headers):
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
                            row_data = [cell.get_text(strip=True) for cell in cells[:len(headers)]]
                            data.append(row_data)

                    if data:
                        df = pd.DataFrame(data, columns=headers)
                        df['LOGID'] = logid

                        # Add metadata columns
                        for meta_key, meta_value in metadata.items():
                            df[meta_key] = meta_value

                        logger.info(f"Extracted table for {logid}: {len(df)} rows with metadata")
                        return df

                except Exception as e:
                    logger.error(f"Error parsing table for {logid}: {e}")
                    continue

        # If no table found but we have metadata, create a basic DataFrame
        if any(metadata.values()):
            df = pd.DataFrame([{'LOGID': logid, 'Field': 'No field table found'}])
            for meta_key, meta_value in metadata.items():
                df[meta_key] = meta_value
            logger.info(f"No table found for {logid}, but extracted metadata")
            return df

        logger.warning(f"No suitable table or metadata found for {logid}")
        return None

    def scrape_version(self, version: str) -> int:
        """
        Scrape all log tables for a specific FortiOS version

        Args:
            version: FortiOS version

        Returns:
            Number of successfully processed LOGIDs
        """
        logger.info(f"Starting scrape for FortiOS version {version}")

        # Create version-specific directory structure
        major_version_dir, minor_version_dir = self.get_version_directories(version)
        os.makedirs(major_version_dir, exist_ok=True)
        os.makedirs(minor_version_dir, exist_ok=True)

        version_url = self.get_version_url(version)
        soup = self.get_page_content(version_url)

        if not soup:
            logger.error(f"Failed to fetch main page for version {version}")
            return 0

        # Extract all LOGID links from the main page
        logid_links = self.extract_logid_links(soup, version_url)

        if not logid_links:
            logger.warning(f"No LOGID links found for version {version}")
            return 0

        logger.info(f"Found {len(logid_links)} LOGID links for version {version}")

        # Process each LOGID and save immediately
        successful_count = 0

        for logid_description, url in logid_links.items():
            logger.info(f"Processing LOGID: {logid_description}")

            logid_soup = self.get_page_content(url)
            if not logid_soup:
                continue

            df = self.extract_log_table(logid_soup, logid_description)
            if df is not None:
                df['Version'] = version

                # Save immediately to CSV in the minor version directory
                safe_logid = re.sub(r'[^\w\-_\.]', '_', str(logid_description))
                filename = f"{safe_logid}.csv"
                filepath = os.path.join(minor_version_dir, filename)

                try:
                    df.to_csv(filepath, index=False)
                    logger.info(f"Saved {len(df)} rows to {filepath}")
                    successful_count += 1
                except Exception as e:
                    logger.error(f"Error saving {filepath}: {e}")

        return successful_count

    # Method removed - saving is now done immediately in scrape_version()


    def run(self, specific_versions: Optional[List[str]] = None):
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
                major_version_dir, minor_version_dir = self.get_version_directories(version)
                logger.info(f"  {i}. Version {version} -> {minor_version_dir}")
            logger.info("\n" + "=" * 60)
            logger.info(f"Total versions to scrape: {len(versions_to_scrape)}")
            logger.info("=" * 60)
            return

        total_processed = 0
        for version in versions_to_scrape:
            try:
                logger.info(f"Processing version {version}")
                successful_count = self.scrape_version(version)
                total_processed += successful_count
                logger.info(f"Completed version {version} - {successful_count} LOGIDs processed")

                # Brief pause between versions
                time.sleep(2)

            except Exception as e:
                logger.error(f"Error processing version {version}: {e}")
                continue

        logger.info(f"Scraping completed! Total LOGIDs processed: {total_processed}")

def main():
    """Main execution function"""
    scraper = FortiGateLogScraper(base_delay=1.0)

    # Option 1: Scrape all versions
    scraper.run()

    # Option 2: Scrape specific versions only (uncomment to use)
    # scraper.run(['7.6.4', '7.4.4'])

if __name__ == "__main__":
    main()
