# %%
import pandas as pd
from trino.auth import BasicAuthentication
from trino.dbapi import connect

# %%
conn = connect(
    user="trino",
    auth=BasicAuthentication("trino", "trino123"),
    http_scheme="https",
    host="localhost",
    port=8443,
    verify=False,  # <-- Add this line
)
# %%
cur = conn.cursor()
cur.execute("select * from hive.analytics.customers")
# %%
cur.execute("select count(*) from hive.analytics.customers")
cur.fetchall()

# %%
# cur.execute(
#     """CREATE TABLE hive.analytics.customer_cc (
#     name VARCHAR,
#     email VARCHAR,
#     address VARCHAR,
#     phone_number VARCHAR,
#     job VARCHAR,
#     company VARCHAR,
#     credit_card_number VARCHAR,
#     enrolled_date DATE
# ) with (format = 'PARQUET')"""
# )

# %%
# S3/MinIO config
s3_url = "s3://stage/large_dataset.csv"
storage_options = {
    "key": "minio",  # Your MinIO access key
    "secret": "minio_admin",  # Your MinIO secret key
    "client_kwargs": {"endpoint_url": "http://localhost:9000"},  # MinIO endpoint
}

# Read CSV into DataFrame
df: pd.DataFrame = pd.read_csv(s3_url, storage_options=storage_options)
df.head()
# %%
len(df)
# %%
# read the df and insert row to trino table hive.analytics.customer_cc
# using the existing cur object
# insert in batch than one by one

batch_size = 1000
for start in range(0, len(df), batch_size):
    end = start + batch_size
    batch = df.iloc[start:end]
    rows = [
        (
            row["Name"],
            row["Email"],
            row["Address"],
            row["Phone Number"],
            row["Job"],
            row["Company"],
            str(row["Credit Card Number"]),
            pd.to_datetime(row["Enrolled Date"]).date(),
        )
        for _, row in batch.iterrows()
    ]
    cur.executemany(
        "INSERT INTO hive.analytics.customer_cc (name, email, address, phone_number, job, company, credit_card_number, enrolled_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        rows,
    )
# %%
cur.execute("SELECT distinct name FROM hive.analytics.customer_cc")
cur.fetchall()
# %%
cur.execute(
    """CREATE TABLE hive.base.customer_cc (
    name VARCHAR,
    email VARCHAR,
    address VARCHAR,
    phone_number VARCHAR,
    job VARCHAR,
    company VARCHAR,
    credit_card_number VARCHAR,
    enrolled_date VARCHAR
) WITH (
    external_location = 's3a://stage/',
    format = 'CSV',
    csv_separator = ',',
    skip_header_line_count = 1
)"""
)
cur.fetchall()
# %%
cur.execute("SELECT count(*) FROM hive.base.customer_cc")
cur.fetchall()

# %%
""" drop table hive.analytics.customer_cc """
cur.execute("DROP TABLE hive.analytics.customer_cc")
cur.fetchall()
# %%
""" create table hive.analytics.customer_cc as select * from hive.base.customer_cc & partition by enrolled_date """
cur.execute(
    """CREATE TABLE hive.analytics.customer_cc AS(
    SELECT * FROM hive.base.customer_cc
    )
"""
)
cur.fetchall()
