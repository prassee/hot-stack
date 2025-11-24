from datetime import datetime, timedelta

import numpy as np
import pandas as pd

N_DAYS = 3  # Number of days to generate
N_TXNS_PER_DAY = 100  # Transactions per day
MATCH_RATIO = 0.9  # Fraction of matching txns per day

np.random.seed(42)


def gen_txn_ids(day, n):
    return [f"TXN{day}{str(i).zfill(6)}" for i in range(n)]


def gen_amounts(n):
    return np.round(np.random.uniform(10, 10000, n), 2)


def gen_taxes(amounts):
    rates = np.random.uniform(2, 18, len(amounts)) / 100.0
    return np.round(amounts * rates, 2)


# Track unmatched txnids to introduce on subsequent days
bank_unmatched_pool = []
local_unmatched_pool = []


used_combinations = set()

for day in range(N_DAYS):
    date_str = (datetime.today() - timedelta(days=N_DAYS - day - 1)).strftime("%Y%m%d")
    n_match = int(N_TXNS_PER_DAY * MATCH_RATIO)
    n_unmatch = N_TXNS_PER_DAY - n_match

    # Generate all txnids for the day (no B/L prefix)
    txnids = gen_txn_ids(date_str, N_TXNS_PER_DAY)

    # Matching rows
    match_amounts = []
    match_taxes = []
    for i in range(n_match):
        # Ensure uniqueness of (txnid, amount, tax) across all days
        while True:
            amt = np.round(np.random.uniform(10, 10000), 2)
            tax = np.round(amt * np.random.uniform(2, 18) / 100.0, 2)
            combo = (txnids[i], amt, tax)
            if combo not in used_combinations:
                used_combinations.add(combo)
                match_amounts.append(amt)
                match_taxes.append(tax)
                break

    # Unmatched rows for bank
    bank_amounts = []
    bank_taxes = []
    for i in range(n_match, N_TXNS_PER_DAY):
        while True:
            amt = np.round(np.random.uniform(10, 10000), 2)
            tax = np.round(amt * np.random.uniform(2, 18) / 100.0, 2)
            combo = (txnids[i], amt, tax)
            if combo not in used_combinations:
                used_combinations.add(combo)
                bank_amounts.append(amt)
                bank_taxes.append(tax)
                break

    # Unmatched rows for local (different from bank)
    local_amounts = []
    local_taxes = []
    for i in range(n_match, N_TXNS_PER_DAY):
        while True:
            amt = np.round(np.random.uniform(10, 10000), 2)
            tax = np.round(amt * np.random.uniform(2, 18) / 100.0, 2)
            combo = (txnids[i], amt, tax)
            if combo not in used_combinations:
                used_combinations.add(combo)
                local_amounts.append(amt)
                local_taxes.append(tax)
                break

    # Prepare bank and local datasets
    bank_data = pd.DataFrame(
        {
            "txnid": txnids,
            "amount": match_amounts + bank_amounts,
            "tax": match_taxes + bank_taxes,
        }
    )
    local_data = pd.DataFrame(
        {
            "txnid": txnids,
            "amount": match_amounts + local_amounts,
            "tax": match_taxes + local_taxes,
        }
    )

    bank_data.to_csv(f"recon/daily/bank_{date_str}.csv", index=False)
    local_data.to_csv(f"recon/daily/local_{date_str}.csv", index=False)

print("Recon datasets generated for", N_DAYS, "days.")
