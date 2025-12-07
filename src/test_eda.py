import pandas as pd

df: pd.DataFrame = pd.DataFrame({"a": [1, 2, 3], "b": [4, 5, 6]})


def clean(a: pd.DataFrame):
    add(23, 34)
    return None


def doStuff(a: pd.DataFrame):
    print(f"{a.isna()}")
    return None


def normalize(a: pd.DataFrame):
    return a.dropna()


def overlap(a: pd.DataFrame, b: pd.DataFrame):
    print(f"{len(a)} {len(b)}")
    return pd.merge(a, b, how="inner")


def clean_df(a: pd.DataFrame):
    a.fillna()
    return a.fillna(0)


def add(a: int, b: int, c: int = 9):
    return a + b + c
