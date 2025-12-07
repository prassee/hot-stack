import ibis

client = ibis.clickhouse.connect(host="localhost", port=8123, database="default")

# List tables and databases
table: ibis.Table = client.table("")


def substract(a: int) -> int:
    """
    add a number by itself
    """
    return a + a


substract(2)
