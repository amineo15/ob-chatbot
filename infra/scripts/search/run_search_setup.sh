#!/bin/bash

set -e

product_info_file="product_info.tar.gz"
cwd=$(pwd)
script_dir=$(dirname $(realpath "$0"))
cd ${script_dir}

# Arguments:
storage_account_name=$1
blob_container_name=$2

# Fetch data:
cp ../../data/${product_info_file} .

# Unzip data:
if [ ! -d "product_info" ]; then
    mkdir product_info
fi
mv ${product_info_file} product_info/
cd product_info && tar -xvzf ${product_info_file} && cd ..

# Upload data to storage account blob container:
echo "Uploading files to blob container..."

# Retry logic for blob upload to handle role assignment propagation delays
max_retries=3
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    if az storage blob upload-batch \
        --auth-mode login \
        --destination ${blob_container_name} \
        --account-name ${storage_account_name} \
        --source "product_info" \
        --pattern "*.md" \
        --overwrite; then
        echo "Successfully uploaded files to blob container"
        break
    else
        retry_count=$((retry_count + 1))
        echo "Upload failed (attempt $retry_count/$max_retries). Waiting 30 seconds before retry..."
        if [ $retry_count -lt $max_retries ]; then
            sleep 30
        else
            echo "All upload attempts failed. Exiting."
            exit 1
        fi
    fi
done

# Install requirements:
echo "Installing requirements..."
python3 -m pip install -r requirements.txt

# Run setup:
echo "Running index setup..."
python3 index_setup.py

# Cleanup:
rm -rf product_info/
cd ${cwd}

echo "Search setup complete"
