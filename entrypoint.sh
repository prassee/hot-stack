#!/bin/bash

# Set the Spark home directory
export SPARK_HOME=/opt/spark

# Add Spark binaries to the PATH
export PATH=$SPARK_HOME/bin:$PATH

# Start the Spark master or worker based on the environment variable
if [ "$SPARK_MODE" == "master" ]; then
    exec spark-class org.apache.spark.deploy.master.Master
elif [ "$SPARK_MODE" == "worker" ]; then
    exec spark-class org.apache.spark.deploy.worker.Worker "$SPARK_MASTER_URL"
else
    echo "Error: SPARK_MODE must be set to either 'master' or 'worker'."
    exit 1
fi