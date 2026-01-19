#!/usr/bin/env python

import sys
import pandas as pd

def print_err(*args, **kwargs):
    print(*args, **kwargs, file=sys.stderr)
    return None

INPUT_FILE = "data/train/train-stacked.csv"
OUTPUT_FILE = "data/train/train-melted.csv"

print_err(f"[INFO] Loading {INPUT_FILE}")
df = pd.read_csv(INPUT_FILE)
df = df.melt(
    id_vars=["Molecule Name", "SMILES"],
    var_name="endpoint",
    value_name="endpoint_value",
)
print_err(f"[INFO] Writing {OUTPUT_FILE}")
df.dropna().to_csv(OUTPUT_FILE, index=False)

