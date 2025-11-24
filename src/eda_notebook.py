import marimo

__generated_with = "0.18.0"
app = marimo.App()


@app.cell
def _():
    import pandas as pd

    return (pd,)


@app.cell
def _(pd):
    d1_bank = pd.read_csv("../recon/daily/bank_20251119.csv")
    d1_bank
    return


@app.cell
def _(pd):
    d1_local = pd.read_csv("../recon/daily/local_20251119.csv")
    d1_local
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
