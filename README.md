# HMT Stack - Hive Metastore + Minio + Trino Stack

## Trino Setup with Delta Connector 
Local Setup for running the trino Cluster 1 cordinator , 1 Worker 
- Trino 
- Delta Connector 
- Hive Metastore 
- Minio : an Object store which talks AWS S3 protocol

**Source**
- https://github.com/delta-incubator/delta-lake-definitive-guide/tree/main/ch04

**TODO**
- this repo has pre-filled Mysql data for the above URL - REMOVE THIS FEATURE
- Extract only the Artifacts required for the setup
- The minio object store should support writes following the S3 protocol.


####  
- Create empty data base and login as root and grant the following previleges
    `mysql> grant all privileges on metastore.* to 'dataeng'@'%' with grant option;`
- First time booting metastore should comment out in `docker-compose-metastore.yaml`
    `#- IS_RESUME="true"`