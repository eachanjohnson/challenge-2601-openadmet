#!/usr/bin/env python

import json
import sys
import pandas as pd
import numpy as np

def print_err(*args, **kwargs):
    print(*args, **kwargs, file=sys.stderr)
    return None

INPUT_CONFIG = "datasets.json"
OUTPUT_FILE = "data/train/train-stacked.csv"

transformations = {
    "exp": np.exp,
    "log": np.log,
    "log1p": np.log1p,
}

with open(INPUT_CONFIG, "r") as f:
    config = json.load(f)

core_training_data = config["core"]["train"]
additional_training_data = config["extra"]["train"]

print_err(f"[INFO] Loading {core_training_data}")
dfs = [pd.read_csv(core_training_data)]
original_cols = dfs[0].columns.tolist()

for d in additional_training_data:
    this_file = d['location']
    print_err(f"[INFO] Loading {this_file}")
    try:
        new_df = pd.read_csv(this_file)
    except pd.errors.EmptyDataError as e:
        print_err(f"[ERROR] File '{this_file}' does not exist")
        raise e
    if "column_map" in d:
        for col_name, (rename_to, transform) in d["column_map"].items():
            new_df[rename_to] = transformations.get(transform, lambda x: x)(new_df[col_name])
            new_df = new_df.drop(columns=col_name)
    dfs.append(new_df)

dfs = (
    pd.concat(dfs, axis=0)
    [original_cols]
)
for col in dfs:
    if not col.casefold().startswith("log") and not col in ["Molecule Name", "SMILES"]:
        dfs[f"{col}::log"] = np.log1p(dfs[col])
        dfs = dfs.drop(columns=col)
print_err(f"[INFO] Writing {OUTPUT_FILE}")
dfs.to_csv(OUTPUT_FILE, index=False)
