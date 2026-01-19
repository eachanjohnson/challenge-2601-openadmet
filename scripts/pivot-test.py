#!/usr/bin/env python

import sys
import pandas as pd
import numpy as np

def print_err(*args, **kwargs):
    print(*args, **kwargs, file=sys.stderr)
    return None

INPUT_FILE = f"predictions/{sys.argv[1]}/prediction-melted.csv"
OUTPUT_FILE = f"predictions/{sys.argv[1]}/predictions.csv"

print_err(f"[INFO] Loading {INPUT_FILE}")
df = pd.read_csv(INPUT_FILE)[["Molecule Name", "SMILES", "endpoint", "prediction"]].drop_duplicates()
print(df.head())
df = df.pivot(
    index=["Molecule Name", "SMILES"],
    columns="endpoint",
    values="prediction",
)
print(df.head())
for col in df:
    print(col)
    if col.casefold().endswith("::log"):
        df[col.split("::log")[0]] = np.expm1(df[col])
        df = df.drop(columns=col)
print_err(f"[INFO] Writing {OUTPUT_FILE}")
df.to_csv(OUTPUT_FILE, index=True)

