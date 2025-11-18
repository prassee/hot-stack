import csv
import io
import os
import random
from datetime import datetime

from faker import Faker
from minio import Minio
from minio.error import S3Error

# --- Configuration ---
NUM_ROWS = 1_000_000
NUM_DUPLICATES = 4
HEADERS = [
    "Name",
    "Email",
    "Address",
    "Phone Number",
    "Job",
    "Company",
    "Credit Card Number",
    "Enrolled Date",
]


# --- MinIO Configuration ---
# Read from environment variables, with defaults for convenience
MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minio")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minio_admin")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "my-bucket")
# Define a path within the bucket for the data
MINIO_OBJECT_NAME = os.environ.get(
    "MINIO_OBJECT_NAME", "raw/large_dataset/large_dataset.csv"
)

# --- Initialization ---
fake = Faker()
data = []
# Use a set for efficient duplicate checking of generated rows
unique_rows = set()

print(f"Generating {NUM_ROWS} rows of data...")

# --- Generate Unique Data ---
while len(data) < NUM_ROWS - NUM_DUPLICATES:
    enrolled_date = fake.date_between(start_date="-10y", end_date="today")
    row = (
        fake.name(),
        fake.email(),
        fake.address().replace("\n", ", "),
        fake.phone_number(),
        fake.job(),
        fake.company(),
        fake.credit_card_number(),
        enrolled_date.strftime("%Y-%m-%d"),
    )
    print(f"gernerated row {row}")

    # Ensure the generated row is unique before adding it
    if row not in unique_rows:
        unique_rows.add(row)
        data.append(list(row))  # Add as a list to allow modification if needed

# --- Generate Duplicate Data ---
print(f"Introducing {NUM_DUPLICATES} duplicates...")
# Select some random rows from the unique data to duplicate
duplicates_to_add = random.sample(data, NUM_DUPLICATES)
data.extend(duplicates_to_add)

# --- Shuffle Data ---
print("Shuffling dataset...")
random.shuffle(data)

# --- Convert to CSV in memory and Upload to MinIO ---
print("Converting data to CSV format in memory...")
# Use io.StringIO to create an in-memory text buffer
string_buffer = io.StringIO()
writer = csv.writer(string_buffer)
writer.writerow(HEADERS)
writer.writerows(data)

# Get the CSV data as a string and then encode it to bytes
csv_bytes = string_buffer.getvalue().encode("utf-8")
# Get the size of the byte buffer
csv_byte_stream = io.BytesIO(csv_bytes)

print(f"Uploading data to MinIO at '{MINIO_BUCKET}/{MINIO_OBJECT_NAME}'...")

try:
    # --- Initialize MinIO Client ---
    client = Minio(
        MINIO_ENDPOINT,
        access_key=MINIO_ACCESS_KEY,
        secret_key=MINIO_SECRET_KEY,
        secure=False,  # Set to True if using HTTPS
    )

    # Make sure the bucket exists.
    found = client.bucket_exists(MINIO_BUCKET)
    if not found:
        client.make_bucket(MINIO_BUCKET)
        print(f"Created bucket '{MINIO_BUCKET}'")
    else:
        print(f"Bucket '{MINIO_BUCKET}' already exists")

    # Upload the byte stream
    client.put_object(
        MINIO_BUCKET,
        MINIO_OBJECT_NAME,
        data=csv_byte_stream,
        length=len(csv_bytes),
        content_type="application/csv",
    )

    print("-" * 30)
    print(
        f"Successfully uploaded to '{MINIO_BUCKET}/{MINIO_OBJECT_NAME}' with {len(data)} rows."
    )
    print(f"Total unique rows: {len(unique_rows)}")
    print(f"Total duplicate rows added: {NUM_DUPLICATES}")
    print("-" * 30)

except S3Error as e:
    print(f"Error uploading to MinIO: {e}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")
