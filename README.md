# Send GDP Aliases To GDSC

A set of bash scripts for retrieving IP aliases from Guardium Data Protection (GDP) and uploading them to Guardium Data Security Center (GDSC).

## Overview

This project provides two scripts that work together to:
1. **Retrieve IP aliases** from a Guardium Data Protection instance via REST API
2. **Upload those aliases** to a GDSC dataset for use in security policies and monitoring

## Prerequisites

### System Requirements

- **Operating System**: Linux, macOS, or Unix-like system with bash
- **Bash**: Version 4.0 or higher
- **curl**: For making HTTP requests
- **jq**: JSON processor (required for `upload_aliases_to_gdsc.sh`)

### Installing Dependencies

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install curl jq
```

#### RHEL/CentOS/Fedora
```bash
sudo yum install curl jq
```

#### macOS
```bash
brew install curl jq
```

#### Verify Installation
```bash
curl --version
jq --version
```

### Access Requirements

#### For GDP (Guardium Data Protection)
- **Guardium URL**: The base URL of your GDP instance (e.g., `https://your-gdp-server.com:8443`)
- **OAuth Credentials**:
  - Client ID
  - Client Secret
- **User Credentials**:
  - Username
  - Password
- **Permissions**: User must have access to read IP aliases via the REST API

#### For GDSC (Guardium Data Security Center)
- **GDSC URL**: The base URL of your GDSC instance (e.g., `https://your-gdsc-server.com`)
- **API Token**: Basic authentication token in the format `Basic <base64-encoded-credentials>`
- **Permissions**: API token must have permissions to:
  - Create datasets
  - Read dataset details
  - Delete dataset data (for purging)
  - Upload data to datasets

## Installation

1. **Clone or download this repository**:
   ```bash
   git clone https://github.com/johnhaldeman/SendGDPAliasesToGDSC.git
   cd SendGDPAliasesToGDSC
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x get_guardium_aliases.sh
   chmod +x upload_aliases_to_gdsc.sh
   ```

3. **Verify scripts are ready**:
   ```bash
   ./get_guardium_aliases.sh
   ./upload_aliases_to_gdsc.sh
   ```
   Both should display usage information.

## Usage

### Step 1: Retrieve Aliases from GDP

The `get_guardium_aliases.sh` script retrieves IP aliases from your Guardium Data Protection instance and saves them to a JSON file.

#### Syntax
```bash
./get_guardium_aliases.sh <guardium_url> <client_id> <client_secret> <username> <password>
```

#### Parameters
- `guardium_url`: Full URL of your GDP instance (including protocol and port)
- `client_id`: OAuth client ID for API access
- `client_secret`: OAuth client secret (UUID format)
- `username`: GDP username with API access
- `password`: User password (use quotes if it contains special characters)

#### Output
- Creates a file named `retrieved_aliases.json` containing all IP aliases

#### Example
```bash
./get_guardium_aliases.sh \
  https://example-collector.ibm.com:8443 \
  aliases \
  6c1b5f0c-1800-2145-86cb-6cf6cba9a1aa \
  admin \
  'GuardiumRocks!1'
```

#### What It Does
1. Authenticates with GDP using OAuth 2.0 password grant flow
2. Retrieves all IP aliases using the `/restAPI/alias` endpoint
3. Filters for IP group types
4. Saves the response to `retrieved_aliases.json`
5. Validates the output file

### Step 2: Upload Aliases to GDSC

The `upload_aliases_to_gdsc.sh` script uploads the retrieved aliases to a GDSC dataset.

#### Syntax
```bash
./upload_aliases_to_gdsc.sh <gdsc_url> <api_token> [dataset_name] [input_file]
```

#### Parameters
- `gdsc_url`: Full URL of your GDSC instance (required)
- `api_token`: Basic authentication token (required, use quotes)
- `dataset_name`: Name for the dataset (optional, default: `GDP_IP_ALIASES`)
- `input_file`: JSON file with aliases (optional, default: `retrieved_aliases.json`)

#### Output
- Creates or updates a GDSC dataset with IP aliases
- Displays detailed progress for each batch
- Shows upload summary at completion

#### Example
```bash
# Basic usage with defaults
./upload_aliases_to_gdsc.sh \
  https://guardium.security.ibm.com \
  'Basic OTNjZjM0MmUtZjU3ZC00OWJkLTg3ZDUtMmRiNjVmZDY1MDkxOmIwY2M5YzU1LTM0NmEtNDQ2My05MGUzLTcwMjExYWVjMTJlMw=='

# Custom dataset name
./upload_aliases_to_gdsc.sh \
  https://guardium.security.ibm.com \
  'Basic OTNjZjM0MmUtZjU3ZC00OWJkLTg3ZDUtMmRiNjVmZDY1MDkxOmIwY2M5YzU1LTM0NmEtNDQ2My05MGUzLTcwMjExYWVjMTJlMw==' \
  MY_CUSTOM_DATASET

# Custom dataset and input file
./upload_aliases_to_gdsc.sh \
  https://guardium.security.ibm.com \
  'Basic OTNjZjM0MmUtZjU3ZC00OWJkLTg3ZDUtMmRiNjVmZDY1MDkxOmIwY2M5YzU1LTM0NmEtNDQ2My05MGUzLTcwMjExYWVjMTJlMw==' \
  MY_CUSTOM_DATASET \
  custom_aliases.json
```

#### What It Does
1. Checks if the specified dataset exists in GDSC
2. Creates the dataset if it doesn't exist (with columns: `IP_ADDRESS`, `ALIAS_HOSTNAME`)
3. Purges any existing data from the dataset
4. Uploads aliases in batches of 250 entries
5. Displays progress and summary statistics


### Output File Name
The retrieval script saves to `retrieved_aliases.json` by default. To change this:

Edit `get_guardium_aliases.sh` and modify the `OUTPUT_FILE` variable:
```bash
OUTPUT_FILE="retrieved_aliases.json"  # Change this value as needed
```
