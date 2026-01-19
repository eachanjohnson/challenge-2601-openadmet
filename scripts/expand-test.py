#!/usr/bin/env python

import json
import sys
import pandas as pd

INPUT_CONFIG = "datasets.json"
INPUT_FILE = "data/train/train-stacked.csv"
OUTPUT_FILE = "data/test/test-expanded.csv"


def print_err(*args, **kwargs):
    print(*args, **kwargs, file=sys.stderr)
    return None


with open(INPUT_CONFIG, "r") as f:
    config = json.load(f)

core_test_data = config["core"]["test"]

print_err(f"[INFO] Loading {core_test_data}")
df = pd.read_csv(core_test_data)
print_err(f"[INFO] Peeking at {INPUT_FILE}")
df_train = pd.read_csv(
    INPUT_FILE,
    nrows=2,
)

extra_cols = pd.DataFrame({
    "endpoint": [
        col for col in df_train 
        if col not in ["Molecule Name", "SMILES"]
    ],
})
df = (
    df
    .drop_duplicates()
    .merge(
        extra_cols.drop_duplicates(),
        how="cross",
    )
    .dropna()
)
print_err(f"[INFO] Writing {OUTPUT_FILE}")
df.to_csv(OUTPUT_FILE, index=False)
