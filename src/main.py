# %%
import ibis

con: ibis.Client = ibis.trino.connect(
    host="localhost", port=8080, database="hive", schema="analytics"
)


# %% list tables and catalogs
_ = con.list_tables(), con.list_catalogs()

# %% query a table
customers: ibis.Table = con.table("customers")
customers.limit(5).execute()
