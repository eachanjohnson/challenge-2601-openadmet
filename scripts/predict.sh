#!/usr/bin/env bash

#SBATCH --job-name=2601-openadmet-predict
#SBATCH --partition=ga100
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=64G
#SBATCH --time=7-0:00:00
#SBATCH --mail-user=%u@crick.ac.uk
#SBATCH --mail-type=ALL
#SBATCH --output=2601-openadmet-predict.log

DATA=data/test/test-cleaned.csv
MODEL_OUTPUT_DIR=models/hyperopt
HYPERPARAMS="$1"

MD5="bebf3e298ca5476c7858f8ce7da4be0e" #$(cat "$MODEL_OUTPUT_DIR"/"$(basename "$HYPERPARAMS")" | md5sum | cut -f1 -d" ")
RUN_BATCH_NAME="$MD5"
MODEL_DIR_MD5="$MODEL_OUTPUT_DIR"/"$MD5"
OUTPUT_DIR=predictions/"$MD5"
CACHE=predictions/"$MD5"/cache

VENV_NAME=venv
# python -m venv "$VENV_NAME" \
# && "$VENV_NAME"/bin/pip install -r requirements.txt

source "$VENV_NAME"/bin/activate

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
    python -c 'import sys; import pandas as pd; df = pd.read_csv(sys.stdin, sep="'"$sep1"'", low_memory=False)'"$cmd"'.to_csv(sys.stdout, index='"$idx"', sep="'"$sep2"'")'
)

set -euox pipefail

best_model_dir="$MODEL_DIR_MD5"/_best-checkpoint
mkdir -p "$CACHE"

XDG_CACHE_HOME="$CACHE" DUVIDNN_CACHE="$CACHE" \
duvidnn predict \
    --test "$DATA" \
    --extras 'Molecule Name' 'SMILES' \
    --checkpoint "$best_model_dir" \
    --output "$OUTPUT_DIR"/prediction-melted.csv \
    --variance --tanimoto

python scripts/pivot-test.py "$MD5"
    