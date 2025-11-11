# Trino Configuration for Hot Stack

This directory contains the configuration files for Trino, a distributed SQL query engine that can query data across multiple data sources.

## Overview

Trino is configured to:
- Connect to the Hive Metastore for table metadata
- Query parquet and ORC files stored in MinIO (S3-compatible storage)
- Create and manage tables using the Hive catalog
- Provide SQL interface for data analysis
- Access MinIO through S3A filesystem with Hadoop configuration

## Configuration Files

### Core Configuration
- `config.properties` - Main Trino server configuration
- `node.properties` - Node identification and environment settings
- `jvm.config` - JVM memory and performance settings
- `log.properties` - Logging configuration

### Catalogs
- `catalog/hive.properties` - Hive catalog for querying MinIO data
- `catalog/memory.properties` - In-memory catalog for temporary tables
- `catalog/tpch.properties` - TPCH sample data for testing

### Hadoop Configuration
- `hadoop/core-site.xml` - S3A filesystem configuration for MinIO access

### Authentication (Optional)
- `password-authenticator.properties` - File-based authentication config
- `password.db` - User credentials (admin/admin, trino/trino)

## Usage

### Starting the Services
```bash
docker-compose up -d
```

### Connecting to Trino
- **Web UI**: http://localhost:8080
- **JDBC URL**: `jdbc:trino://localhost:8080/hive/default`
- **CLI Connection**: 
  ```bash
  docker exec -it trino trino --server localhost:8080 --catalog hive --schema default
  ```

### Verify Installation
```bash
# Check available catalogs
docker exec -it trino trino --server localhost:8080 --execute "SHOW CATALOGS;"

# Check Hive schemas
docker exec -it trino trino --server localhost:8080 --execute "SHOW SCHEMAS FROM hive;"

# Test with sample data
docker exec -it trino trino --server localhost:8080 --execute "SELECT COUNT(*) FROM tpch.tiny.nation;"
```

### Basic SQL Operations

#### List available catalogs:
```sql
SHOW CATALOGS;
```

#### List schemas in hive catalog:
```sql
SHOW SCHEMAS FROM hive;
```

#### Create a new table from parquet files in MinIO:
```sql
CREATE TABLE hive.default.my_table (
    id bigint,
    name varchar,
    created_date date
)
WITH (
    external_location = 's3a://your-bucket/path/to/files/',
    format = 'PARQUET'
);
```

#### Query existing tables:
```sql
SELECT * FROM hive.default.my_table LIMIT 10;
```

#### Create table as select (CTAS):
```sql
CREATE TABLE hive.default.new_table
WITH (
    format = 'PARQUET',
    external_location = 's3a://your-bucket/new-table/'
)
AS SELECT * FROM hive.default.source_table WHERE condition = 'value';
```

### Working with Different File Formats

#### Parquet files:
```sql
CREATE TABLE hive.default.parquet_table (
    col1 varchar,
    col2 bigint
)
WITH (
    external_location = 's3a://bucket/parquet-data/',
    format = 'PARQUET'
);
```

#### ORC files:
```sql
CREATE TABLE hive.default.orc_table (
    col1 varchar,
    col2 bigint
)
WITH (
    external_location = 's3a://bucket/orc-data/',
    format = 'ORC'
);
```

## MinIO Integration

The Hive catalog is configured to work with MinIO through Hadoop S3A filesystem:
- **Endpoint**: http://minio:9000
- **Access Key**: minio
- **Secret Key**: minio_admin
- **Warehouse Location**: s3a://com.dldgv2/delta/
- **Configuration**: Located in `hadoop/core-site.xml`

### S3A Configuration Features
- Path style access enabled for MinIO compatibility
- SSL disabled for local development
- Optimized multipart upload settings
- Connection pooling and retry logic

## Troubleshooting

### Common Issues

1. **Connection refused to metastore**
   - Ensure the metastore service is running and healthy
   - Check network connectivity between containers

2. **S3 access errors**
   - Verify MinIO credentials in hive.properties
   - Ensure MinIO buckets exist and are accessible

3. **Table not found**
   - Check if the table exists in the Hive metastore
   - Verify the external location path in MinIO

### Log Analysis
Check Trino logs for detailed error information:
```bash
docker logs trino
```

### Health Checks
- Trino Web UI: http://localhost:8080
- MinIO Console: http://localhost:9001
- Metastore: Check `docker logs metastore`

## Performance Tuning

### Memory Settings
Adjust JVM memory in `jvm.config`:
- `-Xmx2G` - Maximum heap size
- Increase for larger datasets

### Query Performance
- Use appropriate file formats (Parquet recommended)
- Partition large tables by date or other common filters
- Use columnar storage for analytical workloads

## Security Notes

Authentication is currently disabled for easy setup. To enable:
1. Uncomment `http-server.authentication.type=PASSWORD` in config.properties
2. Use credentials from password.db (admin/admin or trino/trino)
3. Update passwords using bcrypt hashing

## Version Information

- Trino Version: 435 (latest stable)
- Hive Metastore: 3.1.3
- Hadoop S3A FileSystem for MinIO integration
- Compatible with Parquet, ORC, and other Hive-supported formats

## Quick Start Examples

### Create a test table
```sql
CREATE TABLE hive.default.test_table (
    id bigint,
    name varchar,
    created_date date
)
WITH (
    external_location = 's3a://com.dldgv2/delta/test-table/',
    format = 'PARQUET'
);
```

### Query sample data
```sql
-- Use TPCH sample data for testing
SELECT 
    n_name,
    n_regionkey
FROM tpch.tiny.nation 
ORDER BY n_name 
LIMIT 5;
```