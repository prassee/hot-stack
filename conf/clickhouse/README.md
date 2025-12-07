Setup notes for local ClickHouse cluster

- This directory contains minimal ClickHouse configuration files for a 2-node
  local cluster using a single ZooKeeper instance (suitable for development).

Files:
- `config.xml` - server configuration including zookeeper and remote_servers. Replace
  `<replica>REPLICA_NAME</replica>` with the real node name per container. You can
  create a file under `config.d/` (e.g. `config.d/replica_name.xml`) on the host
  and mount it to `/etc/clickhouse-server/config.d/` to override the macro per node.

- `users.xml` - basic user configuration that allows unrestricted local access.

Usage:
1. Start services: `docker-compose up -d clickhouse-zookeeper clickhouse-1 clickhouse-2`
2. Update per-node replica macro if you need replicated tables. Example: create
   `./conf/clickhouse/config.d/replica_clickhouse-1.xml` with contents:

   <?xml version="1.0"?>
   <clickhouse>
     <macros>
       <replica>clickhouse-1</replica>
     </macros>
   </clickhouse>

3. Create replicated tables using ENGINE = ReplicatedMergeTree and Distributed tables
   to leverage the cluster.

Note: For production or more realistic testing, run a 3-node ZooKeeper ensemble and
secure the ClickHouse users/passwords.
