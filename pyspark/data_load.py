from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F

# Create Spark session with Hive support
spark = (
    SparkSession.builder.appName("MinIO to Hive Parquet")
    .master("spark://spark-master:7077")
    .config("hive.metastore.uris", "thrift://metastore:9083")
    .config("spark.sql.warehouse.dir", "s3a://com.dldgv2/delta")
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    # .config("spark.sql.adaptive.enabled", "true")
    .enableHiveSupport()
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000")
    .config("spark.hadoop.fs.s3a.access.key", "minio")
    .config("spark.hadoop.fs.s3a.secret.key", "minio_admin")
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .getOrCreate()
)

print("Spark session created successfully.")
print(f"Spark version: {spark.version}")


def show_tables():
    # list all the schemas
    schemas = spark.catalog.listDatabases()
    for schema in schemas:
        print(schema.name)

    # list all tables from analytics schema
    tables = spark.catalog.listTables("analytics")
    for table in tables:
        print(table.name)


def drop_duplicates(df: DataFrame) -> DataFrame:
    df = df.drop_duplicates(["credit_card_number"])
    # print(f""" {df.distinct().count()} """)
    return df


def normalize_column_names(df: DataFrame) -> DataFrame:
    for col in df.columns:
        df = df.withColumnRenamed(col, col.replace(" ", "_").lower())
    return df


def handle_credit_card_cust():
    spark.sql("drop table if exists base.credit_card_cust")
    # Read CSV from MinIO
    df: DataFrame = spark.read.csv(
        "s3a://stage/large_dataset.csv", header=True, inferSchema=True
    )
    df = normalize_column_names(df)
    df = drop_duplicates(df)
    print("Schema of the DataFrame:")
    df.printSchema()

    # Write as Parquet to MinIO
    df = (
        df.withColumn("obs_year", F.year(F.col("enrolled_date"))).withColumn(
            "obs_month", F.month(F.col("enrolled_date"))
        )
        # .withColumn("obs_day", F.dayofmonth(F.col("enrolled_date")))
    )

    # spark session is already configured to use hive metastore
    (
        df.write.mode("overwrite")
        .format("parquet")
        # .bucketBy(100, "credit_card_number")
        .partitionBy("obs_year")
        .saveAsTable("base.credit_card_cust")
    )


def on_board_skewed_data():
    skew_cust = spark.read.csv(
        "s3a://stage/customers.csv", header=True, inferSchema=True
    )
    skew_txn = spark.read.csv(
        "s3a://stage/transactions.csv", header=True, inferSchema=True
    )
    # skew_cust.printSchema()
    # skew_txn.printSchema()
    skew_cust.write.mode("overwrite").partitionBy("country", "tier").saveAsTable(
        "base.skewed_customers"
    )
    (
        skew_txn.withColumn("obs_year", F.year("event_ts"))
        .withColumn("obs_month", F.month("event_ts"))
        .write.mode("overwrite")
        .partitionBy("obs_year", "obs_month")
        .saveAsTable("base.skewed_transactions")
    )


def show_data():
    spark.sql("use base")
    # calculate total transactions per customer tier for the
    # transactions between 2024-06-01 and 2024-12-31
    # result = spark.sql(
    #     """
    #   SELECT c.tier, COUNT(t.txn_id) AS total_transactions, sum(t.amount) AS total_amount
    #   FROM skewed_customers c
    #   JOIN skewed_transactions t
    #   ON c.customer_id = t.customer_id
    #   WHERE t.event_ts >= '2024-06-01' AND t.event_ts < '2025-01-01'
    #   GROUP BY c.tier """
    # )
    # result.show(n=10, truncate=False)

    spark.sql(
        """
      SELECT c.country, COUNT(t.txn_id) AS total_transactions, sum(t.amount) AS total_amount
      FROM skewed_customers c
      JOIN skewed_transactions t
      ON c.customer_id = t.customer_id
      GROUP BY c.country """
    ).show(n=10, truncate=False)

    # # Force broadcast hash join by broadcasting the smaller table (customers)
    # broadcast_result = spark.sql(
    #     """
    #   SELECT /*+ BROADCAST(c) */ c.tier, COUNT(t.txn_id) AS total_transactions
    #   FROM skewed_customers c
    #   JOIN skewed_transactions t
    #   ON c.customer_id = t.customer_id
    #   WHERE t.event_ts >= '2024-06-01' AND t.event_ts < '2025-01-01'
    #   GROUP BY c.tier """
    # )
    # broadcast_result.explain(True)


# handle_credit_card_cust()
# on_board_skewed_data()
show_data()
spark.stop()
