FROM eclipse-temurin:17-jdk

# Set environment variables
ENV SPARK_VERSION=3.5.5
ENV SCALA_VERSION=2.13
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH=$SPARK_HOME/bin:$PATH

USER root
# Download and extract Spark
# https://stackoverflow.com/questions/79652910/overwrite-is-failing-with-pyspark-errors-exceptions-captured-analysisexception
RUN apt-get update && apt-get install -y curl && \
	curl -L https://archive.apache.org/dist/spark/spark-3.5.5/spark-3.5.5-bin-hadoop3-scala2.13.tgz -o spark.tgz && \
	mkdir -p $SPARK_HOME && \
	tar -xzf spark.tgz --strip-components=1 -C $SPARK_HOME && \
	rm spark.tgz && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*
# Install Python and pip
RUN apt-get update && apt-get install -y python3 python3-pip && \
	ln -s /usr/bin/python3 /usr/bin/python && \
	pip3 install --no-cache-dir --upgrade pip

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
# Set the entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
