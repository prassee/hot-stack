# HOT Stack - Hive Metastore + Object Store (MinIO) + Trino Stack

A modern data lakehouse stack for local development and testing, providing a complete analytics environment with:
- **Trino 476**: Distributed SQL query engine
- **Hive Metastore 3.1.3**: Metadata management for tables and schemas
- **MinIO**: S3-compatible object storage
- **MySQL 8.0.34**: Backend database for Hive Metastore

## Required JARS 

Download the following jars:

  - aws-java-sdk-bundle-1.12.367.jar
  - hadoop-aws-3.3.4.jar
  - mysql-connector-java-8.0.23.jar

      ↓
Place them in:
  data/jars/

## Architecture Overview
![Architecture Diagram](ChatGPT%20Image%20Nov%2018%2C%202025%2C%2008_10_10%20AM.png)

The HOT Stack architecture shows the data flow between components:
- **Trino** serves as the query engine, connecting to both Hive Metastore for metadata and MinIO for data storage
- **Hive Metastore** manages table schemas and locations, using MySQL as its backend database
- **MinIO** provides S3-compatible object storage for actual data files
- **OPA** (Open Policy Agent) provides authorization policies through mounted volumes
- **Apache Spark** can also connect to MinIO for data processing workloads

## Components

### 1. Trino (trinodb/trino:476)
- **Role**: Distributed SQL query engine for analytics
- **Port**: 8080 (HTTP/Web UI)
- **Configuration**: `/conf/trino/`
- **Catalogs**: 
  - `hive`: Main catalog for data lake tables (backed by Hive Metastore + MinIO)
  - `memory`: In-memory tables for testing
  - `tpch`: Built-in TPC-H benchmark dataset
  - `system`: System catalog for monitoring

**Key Features**:
- Native S3 filesystem support for MinIO
- Parquet format with Snappy compression
- Support for both managed and external tables
- Partitioned table support
- ANSI SQL compliant

### 2. Hive Metastore (apache/hive:3.1.3)
- **Role**: Centralized metadata repository for table schemas, partitions, and locations
- **Port**: 9083 (Thrift protocol)
- **Configuration**: `/conf/hive-site.xml`
- **Storage**: MySQL database backend
- **Warehouse Directory**: `s3a://com.dldgv2/delta/` (for managed tables)

**Key Features**:
- S3A filesystem support for MinIO
- Schema versioning and validation
- Supports Hive 3.1.0 metadata schema

### 3. MinIO (minio/minio:latest)
- **Role**: S3-compatible object storage for data lake files
- **Ports**: 
  - 9000: S3 API endpoint
  - 9001: Web Console UI
- **Credentials**:
  - Access Key: `minio`
  - Secret Key: `minio_admin`
- **Data Location**: `./data/minio/`

**Key Features**:
- Full S3 API compatibility
- Web-based console for bucket management
- Path-style access enabled
- No SSL (development mode)

### 4. MySQL (mysql:8.0.34)
- **Role**: Backend database for Hive Metastore metadata
- **Port**: 3306
- **Database**: `metastore`
- **Credentials**:
  - User: `dataeng` / Password: `dataengineering_user`
  - Root: `dataengineering`
- **Data Location**: `./data/mysqldir/`

## Quick Start

### 1. Start All Services
```bash
podman-compose up -d
```

### 2. Check Service Status
```bash
podman-compose ps
```

All services should show as "healthy" or "running".

### 3. Access Trino CLI
```bash
podman exec -it trino trino
```

### 4. Access Web Interfaces
- **Trino Web UI**: http://localhost:8080
- **MinIO Console**: http://localhost:9001 (login: minio/minio_admin)

## Creating Tables

### External Tables (User-Managed Data)
External tables allow you to specify exactly where data is stored. When dropped, only metadata is removed.

```sql
-- Create schema with specific location
CREATE SCHEMA IF NOT EXISTS hive.base 
WITH (location = 's3a://com.dldgv2/base/');

-- Create external table
CREATE TABLE hive.base.users (
    user_id BIGINT,
    username VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP
)
WITH (
    format = 'PARQUET',
    external_location = 's3a://com.dldgv2/base/users/'
);
```

**Use Cases**: 
- Data shared across multiple systems
- Data preservation required after table drop
- Custom data organization

### Managed Tables (Trino-Managed Data)
Managed tables are stored in the default warehouse directory. When dropped, both metadata AND data are deleted.

```sql
-- Create schema (uses default warehouse location)
CREATE SCHEMA IF NOT EXISTS hive.managed_db;

-- Create managed table (no external_location)
CREATE TABLE hive.managed_db.customers (
    customer_id BIGINT,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR
)
WITH (
    format = 'PARQUET'
);
-- Auto-stored at: s3a://com.dldgv2/delta/managed_db.db/customers/
```

**Use Cases**:
- Standard analytics tables
- Development and testing
- Full lifecycle management by Trino

### Partitioned Tables
Improve query performance by partitioning data:

```sql
CREATE TABLE hive.base.sales (
    sale_id BIGINT,
    product_name VARCHAR,
    amount DECIMAL(10, 2),
    sale_date DATE
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['sale_date'],
    external_location = 's3a://com.dldgv2/base/sales/'
);
```

See `create_table_example.sql` and `managed_tables_example.sql` for more examples.

## Configuration Details

### S3/MinIO Configuration
Trino uses native S3 filesystem with credentials provided via environment variables:
- `AWS_ACCESS_KEY_ID=minio`
- `AWS_SECRET_ACCESS_KEY=minio_admin`
- `AWS_REGION=us-east-1`

Endpoint and path-style access configured in `conf/trino/catalog/hive.properties`.

### Storage Formats
- **Default**: Parquet with Snappy compression
- **Supported**: Parquet, ORC, Avro, JSON, CSV
- **Recommended**: Parquet for analytics workloads

### Resource Configuration
- **Trino JVM Heap**: 4GB
- **Query Memory**: 4GB max (2GB per node)
- **Coordinator**: Includes coordinator in scheduling
- **Workers**: Single node setup (coordinator acts as worker)

## Common Operations

### List Available Catalogs
```sql
SHOW CATALOGS;
```

### List Schemas in a Catalog
```sql
SHOW SCHEMAS IN hive;
```

### List Tables in a Schema
```sql
SHOW TABLES IN hive.base;
```

### View Table Structure
```sql
DESCRIBE hive.base.users;
SHOW CREATE TABLE hive.base.users;
```

### Query Data
```sql
SELECT * FROM hive.base.users LIMIT 10;
```

### Insert Data
```sql
INSERT INTO hive.base.users VALUES
    (1, 'alice', 'alice@example.com', CURRENT_TIMESTAMP);
```

## Data Storage Locations

| Type | Location | Controlled By |
|------|----------|---------------|
| Managed Tables | `s3a://com.dldgv2/delta/<schema>/<table>/` | Hive Metastore |
| External Tables | User-specified (e.g., `s3a://com.dldgv2/base/<table>/`) | User |
| MinIO Data | `./data/minio/com.dldgv2/` | Local filesystem |
| MySQL Data | `./data/mysqldir/` | Local filesystem |

## Troubleshooting

### Check Trino Logs
```bash
podman logs trino
```

### Check Metastore Logs
```bash
podman logs metastore
```

### Verify MinIO Connectivity
```bash
podman exec -it trino curl http://minio:9000/minio/health/live
```

### Check Catalog Configuration
```sql
-- In Trino CLI
SHOW CATALOGS;
SELECT * FROM system.metadata.catalogs;
```

### Common Issues

**1. "Invalid location URI: s3a://"**
- Ensure Trino has restarted after configuration changes
- Verify S3 credentials in docker-compose environment variables

**2. Metastore connection failed**
- Check if MySQL is healthy: `podman ps`
- Verify metastore service is running
- Check `IS_RESUME="true"` is set in docker-compose (after first boot)

**3. Configuration property errors**
- Review `podman logs trino` for specific property names
- Trino 476 may not support older Hive properties
- Remove or update deprecated properties

## Initial Setup Notes

### First Time Setup
1. On first boot, Hive Metastore will initialize the MySQL schema
2. After successful initialization, ensure `IS_RESUME="true"` is set in docker-compose.yaml
3. Create the MinIO bucket `com.dldgv2` via console or CLI

### MySQL Permissions (if needed)
```sql
mysql> GRANT ALL PRIVILEGES ON metastore.* TO 'dataeng'@'%' WITH GRANT OPTION;
```

## Network

All services are connected via the `dldg` Docker network for internal communication.

## Files and Directories

```
.
├── docker-compose.yaml          # Service definitions
├── conf/
│   ├── hive-site.xml           # Hive Metastore configuration
│   └── trino/                  # Trino configuration
│       ├── config.properties   # Main Trino config
│       ├── jvm.config         # JVM settings
│       ├── node.properties    # Node configuration
│       └── catalog/           # Catalog configurations
│           ├── hive.properties    # Hive catalog
│           ├── memory.properties  # Memory catalog
│           └── tpch.properties    # TPC-H catalog
├── data/
│   ├── minio/                 # MinIO object storage
│   ├── mysqldir/             # MySQL data
│   └── jars/                 # Additional JAR files
├── create_table_example.sql   # External table examples
└── managed_tables_example.sql # Managed table examples
```

## Performance Tips

1. **Use Partitioning**: For large tables, partition by date or frequently filtered columns
2. **Choose Parquet**: Best compression and query performance for analytics
3. **Bucketing**: For large tables with frequent joins on specific columns
4. **Statistics**: Enable `hive.collect-column-statistics-on-write=true` (already enabled)
5. **File Size**: Aim for 128MB-1GB files (configured: max 1GB)

## Source & References
- Original source: https://github.com/delta-incubator/delta-lake-definitive-guide/tree/main/ch04
- Trino documentation: https://trino.io/docs/current/
- Hive Metastore: https://hive.apache.org/

## License
This setup is for local development and testing purposes.