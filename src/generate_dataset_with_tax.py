import numpy as np
import pandas as pd

N_ROWS = 100_000  # You can adjust this as needed

if __name__ == "__main__":
    # Generate base data
    ids = [f"ID{str(i).zfill(7)}" for i in range(N_ROWS)]
    values = np.random.rand(N_ROWS) * 1000  # Random values between 0 and 1000

    df = pd.DataFrame(
        {
            "id": ids,
            "value": np.round(values, 2),
        }
    )

    # Apply tax based on value
    def apply_tax(value):
        if value < 100:
            tax_rate = 0.05  # 5%
        elif value < 500:
            tax_rate = 0.10  # 10%
        else:
            tax_rate = 0.15  # 15%
        tax_amount = value * tax_rate
        total_amount = value + tax_amount
        return pd.Series([tax_rate, tax_amount, total_amount])

    df[["tax_rate", "tax_amount", "total_amount"]] = df["value"].apply(apply_tax)

    # Save to CSV
    df.to_csv("dataset_with_tax.csv", index=False)
