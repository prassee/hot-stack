import os

import pandas as pd
from minio import Minio
from minio.error import S3Error


def read_csv_from_minio():
    """
    Connects to MinIO, reads a CSV file from a specified bucket
    into a pandas DataFrame, and displays its info and head.

    Configuration is read from environment variables:
    - MINIO_ENDPOINT: The endpoint of the MinIO server (e.g., 'localhost:9000').
    - MINIO_ACCESS_KEY: The access key for the MinIO server.
    - MINIO_SECRET_KEY: The secret key for the MinIO server.
    - MINIO_BUCKET: The name of the bucket (defaults to 'my-bucket').
    - MINIO_OBJECT_NAME: The name of the CSV file in the bucket (defaults to 'large_dataset.csv').
    """
    # --- MinIO Configuration ---
    try:
        minio_endpoint = os.environ.get("MINIO_ENDPOINT", "localhost:9000")
        minio_access_key = os.environ.get("MINIO_ACCESS_KEY", "minio")
        minio_secret_key = os.environ.get("MINIO_SECRET_KEY", "minio_admin")
        bucket_name = os.environ.get("MINIO_BUCKET", "my-bucket")
        object_name = os.environ.get(
            "MINIO_OBJECT_NAME", "raw/large_dataset/large_dataset.csv"
        )
    except KeyError as e:
        print(f"Error: Environment variable {e} not set.")
        print(
            "Please set MINIO_ENDPOINT, MINIO_ACCESS_KEY, and MINIO_SECRET_KEY environment variables."
        )
        return

    print(f"Attempting to connect to MinIO at '{minio_endpoint}'...")

    # --- Initialize MinIO Client ---
    try:
        # Set secure=True if your MinIO server uses HTTPS
        client = Minio(
            minio_endpoint,
            access_key=minio_access_key,
            secret_key=minio_secret_key,
            secure=False,
        )
        # Check if the bucket exists to verify the connection
        found = client.bucket_exists(bucket_name)
        if not found:
            print(f"Error: Bucket '{bucket_name}' does not exist.")
            return
        print("Successfully connected to MinIO.")
    except S3Error as e:
        print(f"Error connecting to MinIO or checking bucket: {e}")
        return
    except Exception as e:
        print(f"An unexpected error occurred during client initialization: {e}")
        return

    # --- Read Object from MinIO into Pandas ---
    response = None
    try:
        print(f"Reading object '{object_name}' from bucket '{bucket_name}'...")
        # Get the object from MinIO. This returns a stream.
        response = client.get_object(bucket_name, object_name)

        # Read the CSV data directly into a pandas DataFrame
        # pandas.read_csv can handle the byte stream from get_object
        df = pd.read_csv(response)

        print("-" * 30)
        print(f"Successfully loaded '{object_name}' into a pandas DataFrame.")
        print("DataFrame Info:")
        df.info()
        print("\nDataFrame Head:")
        print(df.head())
        print("-" * 30)

    except S3Error as e:
        print(f"Error reading object from MinIO: {e}")
    except Exception as e:
        print(f"An error occurred while processing the file with pandas: {e}")
    finally:
        # It's crucial to close the response stream
        if response:
            response.close()
            response.release_conn()


if __name__ == "__main__":
    print(None)
