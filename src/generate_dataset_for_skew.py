from datetime import datetime, timedelta

import numpy as np
import pandas as pd

# Parameters
N_CUSTOMERS = 1_000_000
N_TRANSACTIONS = 100_000_000
HOT_CUSTOMERS = 10
HOT_RATIO = 0.7  # 70% of transactions to hot customers

# Generate customers
customer_ids = [f"CUST{str(i).zfill(7)}" for i in range(N_CUSTOMERS)]
countries = ["US", "UK", "IN", "DE", "FR", "CN", "JP", "BR", "CA", "AU"]
tiers = ["bronze", "silver", "gold", "platinum"]

customers_df = pd.DataFrame(
    {
        "customer_id": customer_ids,
        "country": np.random.choice(countries, N_CUSTOMERS),
        "tier": np.random.choice(tiers, N_CUSTOMERS),
    }
)

customers_df.to_csv("customers.csv", index=False)

# Select hot customer_ids
hot_customer_ids = customer_ids[:HOT_CUSTOMERS]
other_customer_ids = customer_ids[HOT_CUSTOMERS:]


# Transactions - write in batches to avoid OOM
N_BATCH = 1_000_000
n_batches = N_TRANSACTIONS // N_BATCH
remainder = N_TRANSACTIONS % N_BATCH

n_hot = int(N_TRANSACTIONS * HOT_RATIO)
n_other = N_TRANSACTIONS - n_hot

hot_txn_customer_ids = np.random.choice(hot_customer_ids, n_hot, replace=True)
other_txn_customer_ids = np.random.choice(other_customer_ids, n_other, replace=True)
txn_customer_ids = np.concatenate([hot_txn_customer_ids, other_txn_customer_ids])
np.random.shuffle(txn_customer_ids)

start_ts = datetime(2024, 1, 1)
end_ts = datetime(2025, 1, 1)
total_seconds = int((end_ts - start_ts).total_seconds())

import csv

with open("transactions.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["txn_id", "customer_id", "amount", "event_ts"])

    for batch_idx in range(n_batches):
        start = batch_idx * N_BATCH
        end = start + N_BATCH
        txn_ids = [f"TXN{str(i).zfill(9)}" for i in range(start, end)]
        cust_ids = txn_customer_ids[start:end]
        amounts = np.round(np.random.exponential(scale=100, size=N_BATCH), 2)
        event_seconds = np.random.randint(0, total_seconds, N_BATCH)
        event_ts = [start_ts + timedelta(seconds=int(x)) for x in event_seconds]
        rows = zip(txn_ids, cust_ids, amounts, event_ts)
        writer.writerows(rows)

    # Write remainder if any
    if remainder > 0:
        start = n_batches * N_BATCH
        end = start + remainder
        txn_ids = [f"TXN{str(i).zfill(9)}" for i in range(start, end)]
        cust_ids = txn_customer_ids[start:end]
        amounts = np.round(np.random.exponential(scale=100, size=remainder), 2)
        event_seconds = np.random.randint(0, total_seconds, remainder)
        event_ts = [start_ts + timedelta(seconds=int(x)) for x in event_seconds]
        rows = zip(txn_ids, cust_ids, amounts, event_ts)
        writer.writerows(rows)
