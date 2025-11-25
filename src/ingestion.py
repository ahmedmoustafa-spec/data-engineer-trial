import requests
import json
from datetime import datetime, timedelta
from azure.storage.blob import BlobServiceClient

"""
API Ingestion Function
Context: Azure Function or Databricks Notebook
Goal: Fetch daily usage stats and land raw JSON in Azure Blob Storage.
"""

def fetch_and_land_usage_data(api_key, target_date=None):
    # 1. Configuration
    base_url = "https://api.productusage.com/v1/stats"
    connection_string = "DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;"
    container_name = "bronze-usage-data"
    
    # 2. Determine Date (Default to Yesterday if not provided)
    if not target_date:
        yesterday = datetime.now() - timedelta(days=1)
        target_date_str = yesterday.strftime('%Y-%m-%d')
    else:
        target_date_str = target_date

    # 3. Call API
    params = {
        'date': target_date_str,
        'api_key': api_key
    }
    
    try:
        print(f"Fetching data for {target_date_str}...")
        response = requests.get(base_url, params=params)
        response.raise_for_status() # Alert on 4xx/5xx errors
        
        data = response.json()
        
        # 4. Land Data in Azure Blob
        file_name = f"usage_dump_{target_date_str}.json"
        
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        blob_client = blob_service_client.get_blob_client(container=container_name, blob=file_name)
        
        # Upload raw JSON
        blob_client.upload_blob(json.dumps(data), overwrite=True)
        
        return f"Success: Data landed in {container_name}/{file_name}"

    except requests.exceptions.RequestException as e:
        # Raise specific error for ADF to catch
        raise SystemError(f"API Connection Failed: {e}")
    except Exception as e:
        raise SystemError(f"Ingestion Process Failed: {e}")

# Example execution for testing
if __name__ == "__main__":
    # In a real scenario, API Key would be fetched from Azure Key Vault
    fetch_and_land_usage_data("TEST_API_KEY", "2023-10-27")