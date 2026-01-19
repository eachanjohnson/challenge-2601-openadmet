#!/usr/bin/env bash

#SBATCH --job-name=split
#SBATCH --partition=ncpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=16G
#SBATCH --time=3-0:00:00
#SBATCH --mail-user=%u@crick.ac.uk
#SBATCH --mail-type=ALL
#SBATCH --output=split.log

# Some functions for convenience 
logger () (
    local message="$1"
    local _date=$(date)
    local prefix=${2:-"$_date"}
    >&2 echo "[INFO] :: [$prefix] :: $message"
)

pandas () (
    local cmd="$1"
    local sep1=${2:-,}
    local idx=${3:-False}
    local sep2=${4:-"$sep1"}
    python -c '
    import sys
    import pandas as pd
    df = pd.read_csv(
        sys.stdin, 
        sep="'"$sep1"'", 
        low_memory=False,
    )'"$cmd"'.to_csv(
        sys.stdout, 
        index='"$idx"', 
        sep="'"$sep2"'",
    )'
)

set -euox pipefail

INPUT=datasets.json
VENV_NAME=venv

# python -m venv "$VENV_NAME" \
# && "$VENV_NAME"/bin/pip install --upgrade pip \
# && "$VENV_NAME"/bin/pip install transformers tokenizers \
# && "$VENV_NAME"/bin/pip install -r requirements.txt

source "$VENV_NAME"/bin/activate

logger "Using $(python --version) at $(which python)"

python scripts/stack-training.py
python scripts/melt-training.py
python scripts/expand-test.py

logger "Done!"
