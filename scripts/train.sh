#!/usr/bin/env bash

#SBATCH --job-name=2601-openadmet-train
#SBATCH --partition=ncpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=64G
#SBATCH --time=7-0:00:00
#SBATCH --mail-user=%u@crick.ac.uk
#SBATCH --mail-type=ALL
#SBATCH --output=2601-openadmet-train.log

TRAIN_DATA=data/train/train/data.csv
VAL_DATA=data/train/validation/data.csv
TEST_DATA=data/train/test/data.csv
MODEL_OUTPUT_DIR=models/hyperopt
README_TEMPLATE=templates/README.md
COLUMN=SMILES
LABEL=endpoint_value
HYPERPARAMS="$1"

EPOCHS=1000
EARLY=20
ENSEMBLE_SIZE=10
MD5=$(echo "$HYPERPARAMS" | md5sum | cut -f1 -d" ")
RUN_BATCH_NAME="$MD5"

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

# generate hyperopt params
mkdir -p "$MODEL_OUTPUT_DIR"

duvidnn hyperprep "$HYPERPARAMS" -o "$MODEL_OUTPUT_DIR"/"$(basename "$HYPERPARAMS")" \
2> "$MODEL_OUTPUT_DIR"/"$(basename "$HYPERPARAMS" .json)".log

MD5=$(cat "$MODEL_OUTPUT_DIR"/"$(basename "$HYPERPARAMS")" | md5sum | cut -f1 -d" ")
MODEL_DIR_MD5="$MODEL_OUTPUT_DIR"/"$MD5"
mkdir -p "$MODEL_DIR_MD5"
mv "$MODEL_OUTPUT_DIR"/"$(basename "$HYPERPARAMS" .json)".{log,json} "$MODEL_DIR_MD5"

n_configs=$(grep '^There are ' "$MODEL_DIR_MD5"/hyperopt.log | head -n1 | cut -f3 -d' ')
logger "Number of configs is $n_configs"
if [ "$n_configs" -gt 1000 ]
then 
    logger "Too many configs: $n_configs !!!"
    exit 1
fi

common_opts='-S '"$COLUMN"' -y '"$LABEL"' --epochs '"$EPOCHS"' --early-stopping '"$EARLY"' --ensemble-size '"$ENSEMBLE_SIZE"' --config "'"$MODEL_DIR_MD5"/"$(basename "$HYPERPARAMS")"'"'

CACHE="$MODEL_DIR_MD5"/cache
mkdir -p "$CACHE"

function train_model () {
    i="$1"
    this_hyperopt_dir="$MODEL_DIR_MD5"/configs/"$i"
    mkdir -p "$this_hyperopt_dir"
    if [ ! -e "$this_hyperopt_dir"/metrics.csv ]
    then
        sbatch -W \
            --output "$this_hyperopt_dir"/training.log \
            --job-name "hyper-train-oa" \
            --time 10:00:00 \
            --mem 32G \
            --partition=ga100 \
            --gres=gpu:1 \
            --wrap '
                source "'"$VENV_NAME"'"/bin/activate \
                && XDG_CACHE_HOME='"$CACHE"' DUVIDNN_CACHE='"$CACHE"' \
                duvidnn train \
                    -1 "'"$TRAIN_DATA"'" \
                    -2 "'"$VAL_DATA"'" \
                    --test "'"$TEST_DATA"'" \
                    -i '"$i"' \
                    --output "'"$this_hyperopt_dir"'" \
                    '"$common_opts"' 
            ' &
        sleep 3
    else
        logger "Config $i already done! Skipping"
    fi
}

function await_sbatch () {
    for job in `jobs -p`
    do
        logger "Waiting for job $job to finish..."
        wait $job
        logger "job $job finished!"
    done
}

for i in $(seq 0 $(($n_configs-1)))
do
    train_model "$i"
done
await_sbatch

outputs=("$MODEL_DIR_MD5"/configs/*/metrics.csv)

overall_metrics="$MODEL_DIR_MD5"/hyperopt-metrics.csv
head -n1 "${outputs[0]}" \
| cat - <(tail -n+2 -q "${outputs[@]}") \
> "$overall_metrics"

best_models="$MODEL_DIR_MD5"/hyperopt-best.csv
pandas '; df.pivot(
    index=[
        col for col in df 
        if col not in [
            "split", "pearson_r", "rmse", "spearman_rho"
        ] and not col.startswith("split")
    ], 
    columns="split", 
    values="pearson_r",
).reset_index().sort_values(["data", "test"]).groupby("data").tail(1)' \
< "$overall_metrics" \
> "$best_models"

best_chk="$MODEL_DIR_MD5"/best-checkpoint.txt
pandas '[["config_i"]].drop_duplicates()' , < "$best_models" \
| tail -n+2 \
> "$best_chk"
chk=$(tail -n1 "$best_chk")

if [ -n "$chk" ]
then
    best_model_dir="$MODEL_DIR_MD5"/_best-checkpoint
    mkdir -p "$best_model_dir"
    cp -r "$MODEL_DIR_MD5"/configs/"$chk"/* "$best_model_dir"
    sbatch -W \
        --output "$best_model_dir"/training-repeat.log \
        --job-name "hyper-train-oa2" \
        --time 10:00:00 \
        --mem 32G \
        --partition=ga100 \
        --gres=gpu:1 \
        --wrap '
            source "'"$VENV_NAME"'"/bin/activate \
            && XDG_CACHE_HOME='"$CACHE"' DUVIDNN_CACHE='"$CACHE"' \
            duvidnn train \
                -1 "'"$TRAIN_DATA"'" \
                -2 "'"$VAL_DATA"'" \
                --test "'"$TEST_DATA"'" \
                --checkpoint "'"$best_model_dir"'" \
                --epochs 1 \
                --output "'"$best_model_dir"'" \
                --save-data
        ' &
        await_sbatch
else
    logger "Failed to find best checkpoint!"
    exit 1
fi
ntrain=$(tail -n+2 "$best_model_dir"/predictions_training.csv | cut -f1 -d, | grep -v '^ ' | wc -l)
nval=$(tail -n+2 "$best_model_dir"/predictions_validation.csv | cut -f1 -d, | grep -v '^ ' | wc -l)
ntest=$(tail -n+2 "$best_model_dir"/predictions_test.csv | cut -f1 -d, | grep -v '^ ' | wc -l)
nrows=$(($ntrain + $nval + $ntest))

for csv_file in "$best_model_dir"/predictions_*.csv
do
    gzip --best -f "$csv_file"
done

sed '
    s/__NROWS__/'"$nrows"'/g;
    s/__NTRAIN__/'"$ntrain"'/g;
    s/__NVAL__/'"$nval"'/g;
    s/__NTEST__/'"$ntest"'/g;
    s/__INPUTS__/'"$COLUMN"'/g;
    s/__OUTPUTS__/'"$LABEL"'/g;
    s/__TODAY__/'"$(date)"'/g;

    ' \
    "$README_TEMPLATE" \
| sed '/__CONFIG__/r '"$best_model_dir"/modelbox-init-config.json \
| sed '/__TRAIN_EVAL__/r '"$best_model_dir"/eval-metrics_training.json \
| sed '/__VAL_EVAL__/r '"$best_model_dir"/eval-metrics_validation.json \
| sed '/__TEST_EVAL__/r '"$best_model_dir"/eval-metrics_test.json \
| sed 's/__CONFIG__//g;s/__TRAIN_EVAL__//g;s/__VAL_EVAL__//g;s/__TEST_EVAL__//g;' \
> "$best_model_dir"/README.md
cat "$best_model_dir"/README.md 1>&2

echo scbirlab/"$RUN_BATCH_NAME" > "$best_model_dir"/repo-name.txt

logger "Done!"
