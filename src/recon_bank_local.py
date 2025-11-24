# %%
import pandas as pd


# %%
is_backfill = False
day_1_app = "../recon/daily/local_20251120.csv"
day_1_bank = "../recon/daily/bank_20251120.csv"
# %%
bank: pd.DataFrame = pd.read_csv(day_1_bank)
app: pd.DataFrame = pd.read_csv(day_1_app)
# if not is_backfill append recon/residual/app.csv to app dataframe
if not is_backfill:
    residual_app: pd.DataFrame = pd.read_csv("../recon/residual/app.csv")
    app = pd.concat([app, residual_app], ignore_index=True)

merged: pd.DataFrame = bank.merge(
    app, on="txnid", suffixes=("_bank", "_app"), how="outer"
)
merged["mismatch"] = merged["amount_bank"] != merged["amount_app"]
merged[merged["mismatch"]]
# %%
merged[~merged["mismatch"]].drop(columns=["mismatch"])

# %%
# Mismatch Scenario 1
# - Txns exist only in app file and not in bank file
# - These Txns expected in bank file for next day

# extract Txns which are only in app file
app_residual = merged[merged["amount_bank"].isna() & ~merged["amount_app"].isna()][
    ["txnid", "amount_app", "tax_app"]
]
assert isinstance(app_residual, pd.DataFrame)
# overwrite app_residual to a csv under recon/residual/app.csv
app_residual.to_csv("../recon/residual/app.csv", index=False)
app_residual
