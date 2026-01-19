#!/usr/bin/env bash

#SBATCH --job-name=2610-oa-run
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=16G
#SBATCH --time=3-0:00:00
#SBATCH --mail-user=%u@crick.ac.uk
#SBATCH --mail-type=ALL
#SBATCH --output=2610-oa-run.log

set -euox pipefail

bash scripts/prep.sh
bash scripts/split.sh
bash scripts/train.sh "$1"
bash scripts/predict.sh "$1"
