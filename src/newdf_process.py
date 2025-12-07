import polars as pl

df: pl.DataFrame = pl.read_csv("")
df.min()
df.max()
