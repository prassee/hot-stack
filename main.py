# %%
import ibis

con = ibis.trino.connect(
    host="localhost", port=8080, database="hive", schema="analytics"
)


# %%
con.list_tables()  # doctest: +SKIP
# %%
con.list_catalogs()  # doctest: +SKIP

# %%
customers: ibis.Table = con.table("customers")
customers.limit(5).execute()
