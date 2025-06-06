#!/bin/bash

# Script to download SQL file from S3 and import into local MySQL database
# Created: $(date +"%Y-%m-%d")

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
S3_BUCKET="clevercards-integration-internal-database-dump"
S3_PATH="$(date +"%Y/%m/%d")/products.sql"
TEMP_SQL_FILE="/tmp/products_$(date +%s).sql"
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="root"
DB_PASSWORD="Admin123@"
DB_NAME="products"

# Check if docker-compose is running
if ! docker-compose ps | grep -q "db.*Up"; then
  echo "MySQL container is not running. Starting with docker-compose..."
  docker-compose up -d db
  
  # Wait for MySQL to be ready
  echo "Waiting for MySQL to be ready..."
  sleep 10
fi

# Download SQL file from S3 using AWS CLI
echo "Downloading SQL file from S3..."
aws s3 cp "s3://${S3_BUCKET}/${S3_PATH}" "$TEMP_SQL_FILE"

# Check if download was successful
if [ ! -f "$TEMP_SQL_FILE" ]; then
  echo "Failed to download SQL file from S3"
  exit 1
fi

echo "SQL file downloaded successfully to $TEMP_SQL_FILE"

# Create database if it doesn't exist
echo "Creating database $DB_NAME if it doesn't exist..."
docker-compose exec -T db mysql -u"$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

# Import SQL file into MySQL
echo "Importing SQL file into $DB_NAME database..."
docker-compose exec -T db mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$TEMP_SQL_FILE"

# Check if import was successful
if [ $? -eq 0 ]; then
  echo "SQL file imported successfully into $DB_NAME database"
else
  echo "Failed to import SQL file"
  exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -f "$TEMP_SQL_FILE"

echo "Database import completed successfully!"
