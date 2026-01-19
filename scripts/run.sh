#!/usr/bin/env bash

set -euox pipefail

bash scripts/prep.sh
bash scripts/split.sh
bash scripts/train.sh "$1"
bash scripts/predict.sh "$1"
python scripts/melt-training 
