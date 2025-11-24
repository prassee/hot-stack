# %%
import pandas as pd

# %%
is_backfill = False
day_1_app = "../local_dataset_with_tax_100.csv"
day_1_bank = "../dataset_with_tax_100.csv"

day_2_app = "../local_dataset_with_tax_200.csv"
day_2_bank = "../dataset_with_tax_200.csv"
# %%
lhs = pd.read_csv(day_2_bank)
rhs = pd.read_csv(day_2_app)
rhs = rhs[["id", "value", "tax_amount", "total_amount"]]
assert isinstance(rhs, pd.DataFrame)
rhs["total_amount"] = rhs["total_amount"].round(2)
lhs, rhs


# %%
def join_and_recon(lhs: pd.DataFrame, rhs: pd.DataFrame) -> pd.DataFrame:
    loj = lhs.merge(rhs, on="id", suffixes=("_lhs", "_rhs"), how="outer")
    loj["mismatch"] = loj["total_amount_rhs"] != loj["total_amount_lhs"]
    return loj


loj = join_and_recon(lhs, rhs)
loj
# %%
mismatches = loj[loj["mismatch"]]
mismatches

# %%
# ids in rhs but not in lhs
rhs_ids = set(rhs["id"])
lhs_ids = set(lhs["id"])
rhs_only_ids = rhs_ids - lhs_ids
lhs_only_ids = lhs_ids - rhs_ids
rhs_only_ids, lhs_only_ids

# %%
rhs_residual = rhs[rhs["id"].isin(rhs_only_ids)]
lhs_residual = lhs[lhs["id"].isin(lhs_only_ids)]
rhs_residual, lhs_residual

# %% save the residuals as csv
new_outstanding = None
if is_backfill:
    rhs_residual.to_csv("../rhs_residual.csv", index=False)
    lhs_residual.to_csv("../lhs_residual.csv", index=False)
else:
    ## load the residuals from csv and append to lhs_residual and rhs_residual
    rhs_residual_existing = pd.read_csv("../rhs_residual.csv")
    lhs_residual_existing = pd.read_csv("../lhs_residual.csv")
    rhs_residual = pd.concat([rhs_residual_existing, rhs_residual], ignore_index=True)
    lhs_residual = pd.concat([lhs_residual_existing, lhs_residual], ignore_index=True)
    x = join_and_recon(lhs_residual, rhs_residual)
    new_outstanding = x

new_outstanding

# %%
