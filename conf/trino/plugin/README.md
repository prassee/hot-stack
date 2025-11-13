REMOVED: OPA plugin installation instructions removed — this repository no longer includes or references the Trino OPA plugin.

If you need to re-enable OPA in future:

- place the plugin JAR into `conf/trino/plugin/opa/`
- configure `conf/trino/config.properties` with `access-control.name=<plugin-id>` and the plugin's config files
- restart Trino

Note: The `conf/trino` tree has been cleaned of active OPA configuration and plugin mounts. See project history for previous versions.
