import numpy as np
import pandas as pd

# Load the source dataset
src = pd.read_csv("dataset_with_tax.csv")

N = len(src)
N_MATCH = int(N * 0.7)
N_NONMATCH = N - N_MATCH

if __name__ == "__main__":
    # Create matched records
    matched = src.sample(n=N_MATCH, random_state=42).reset_index(drop=True)

    # Create non-matched records by modifying some fields
    non_matched = src.sample(n=N_NONMATCH, random_state=24).reset_index(drop=True)
    non_matched["value"] = non_matched["value"] * np.random.uniform(
        1.1, 1.5, size=N_NONMATCH
    )
    non_matched["tax_amount"] = non_matched["value"] * non_matched["tax_rate"]
    non_matched["total_amount"] = non_matched["value"] + non_matched["tax_amount"]

    # Combine matched and non-matched records
    final_df = pd.concat([matched, non_matched], ignore_index=True)

    # Shuffle the final dataset
    final_df = final_df.sample(frac=1, random_state=99).reset_index(drop=True)

    # Save to CSV
    final_df.to_csv("local_dataset_with_tax.csv", index=False)

    print("local_dataset_with_tax.csv generated with 70% matching rows.")
