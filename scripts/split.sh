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
    python -c 'import sys; import pandas as pd; df = pd.read_csv(sys.stdin, sep="'"$sep1"'", low_memory=False)'"$cmd"'.to_csv(sys.stdout, index='"$idx"', sep="'"$sep2"'")'
)

set -euox pipefail

INPUT=data/train/train-melted.csv
TEST_INPUT=data/test/test-expanded.csv
TEST_OUTPUT=data/test/test-cleaned.csv
VENV_NAME=venv

# python -m venv "$VENV_NAME" \
# && "$VENV_NAME"/bin/pip install -r requirements.txt

source "$VENV_NAME"/bin/activate


logger "Using $(python --version) at $(which python)"
logger "Using $(schemist --version) at $(which schemist)"

logger "Splitting chemical data from $INPUT"

temp_output="$(dirname $INPUT)/temp"
mkdir -p "$temp_output"
# replace windows \r with \n
tr $'\r' $'\n' < "$INPUT" \
| schemist convert \
    -f csv \
    --column SMILES \
    --to id inchikey smiles scaffold mwt clogp tpsa \
    --options prefix=SCB- \
| schemist split \
    -f csv \
    --column SMILES \
    --type scaffold \
    --train 0.7 \
    --test 0.15 \
    --seed 42 \
> "$temp_output/temp.csv"

for split in "train" "test" "validation"
do
    this_output="$(dirname $INPUT)/$split"
    mkdir -p "$this_output"
    logger "Processing $split..."
    pandas '.query("is_'"$split"'")' \
    < "$temp_output/temp.csv" \
    > "$this_output"/data.csv
    # gzip --best -f "$this_output"
done

rm -r $temp_output

schemist convert "$TEST_INPUT"\
    -f csv \
    --column SMILES \
    --to id inchikey smiles scaffold mwt clogp tpsa \
    --options prefix=SCB- \
    > "$TEST_OUTPUT"

logger "Done!"
