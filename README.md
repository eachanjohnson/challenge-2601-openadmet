# 💊 OpenADMET + ExpansionRx Computational Blind Challenge

## Methodology Report

We combined open-source Biogen ADME data with the provided training data,
then used a [FiLM](https://arxiv.org/abs/1709.07871) multitask architecture along with Morgan fingerprints,
histogram-normalized 2D Descriptastorus descriptors, and embeddings from a BART transformer pretrained
on SMILES canonicalization.

Scripts that we used to prepare, train, and predict are under the `scripts` 
directory of this repo.

### Additional data

We additionally used the Biogen ADME dataset, hosted at 
[scbirlab/fang-2023-biogen-adme](https://huggingface.co/datasets/scbirlab/fang-2023-biogen-adme).

We renamed columns and transformed values according to `datasets.json` in this repo:

```json
"column_map": {
    "id": ["Molecule Name", null],
    "smiles": ["SMILES", null],
    "log_solubility": ["KSol", "exp"],
    "log_hlm": ["HLM CLint", "exp"]
}
```

Then we concatenated to the provided training data before a scaffold split.

We did not test whether this additional data affected model performance.

### Preprocessing

We melted the resulting compound x endpoint matrix (containing missing values)
so that we had a table with one row per compound x endpoint with a 
present value. We took the `np.log1p` of the non-LogD values.

We then used the preprocessors in [duvidnn](https://github.com/scbirlab/duvidnn)
to generate a binary hash of the task names.

Our model uses FiLM context head to learn affine transforms of layers based on
the hash of the task name. Similar or correlated tasks should in principle lead to similar
transforms, allowing learning between tasks for the same or similar molecules.

### Molecule featurization

We [tested multiple combinations of molecule featurizations](#hyperparameter-search), with
the best being a concatenation of Morgan fingerprints (radius 2), histogram-normalized 
2D descriptors from Descriptastorus, and the last encoder+decoder layers from 
a BART model pre-trained on a SMILES canonicalization task using [lchemme](https://github.com/scbirlab/lchemme). 

```json

{
    "class_name": "bilinear-fp",
    "context": [
        "endpoint:hash"
    ],
    "dropout": 0.0,
    "ensemble_size": 3,
    "features": [
        [
            "clogp",
            "transformer://models/llm/lchemme-1:clean_smiles"
        ]
    ],
    "learning_rate": 1e-05,
    "merge_method": "product",
    "n_hidden": 1,
    "n_units": 128,
    "residual_depth": 2
}
```

## Description of the Model

- **Type of model:** Deep neural network
- **Library:** [scbirlab/duvidnn](https://github.com/scbirlab/duvidnn) and pytorch
- **Architecture:** [FiLM](https://arxiv.org/abs/1709.07871)
- **Training split:** scaffold; 70% training, 15% validation, 15% test
- **Loss:** MSE

Additional architectures such as Chemprop or gradient-boosted trees are possible,
but we did not test them.

## Hyperparameter search

We arrived at these parameters using a brute force of 432 configurations using `duvidnn hyperopt` and on-prem HPC:

```json
{
    "features": [
        [
            ["clogp"]
        ],
        [
            ["clogp", "transformer://models/llm/lchemme-1:clean_smiles"]
        ],
        [
            ["clogp"], 
            ["transformer://models/llm/lchemme-1:clean_smiles"]
        ]
    ],
    "context": [
        null,
        [
            "endpoint:hash"
        ]
    ],
    "class_name": [
        "bilinear-fp"
    ],
    "use_3d": [
        false,
        true
    ],
    "use_2d": [
        false,
        true
    ],
    "use_fp": [
        false,
        true
    ],
    "n_units": [
        8,
        64,
        128
    ],
    "n_hidden": [
        1,
        4,
        8
    ],
    "learning_rate": [
        1e-05
    ],
    "residual_depth": [
        2
    ]
}
```

## Performance comments

Our best model had this configuration:

```json
{
    "class_name": "bilinear-fp",
    "context": [
        "endpoint:hash"
    ],
    "dropout": 0.0,
    "ensemble_size": 3,
    "features": [
        [
            "clogp",
            "transformer://models/llm/lchemme-1:clean_smiles"
        ]
    ],
    "learning_rate": 1e-05,
    "merge_method": "product",
    "n_hidden": 1,
    "n_units": 128,
    "residual_depth": 2
}
```

Here is the training log:

<img src="models/hyperopt/bebf3e298ca5476c7858f8ce7da4be0e/training-log.png" width=450>

And these are the evaluation scores.

Train (19847 rows):

```json

{
    "pearson_r": 0.91119962136608,
    "rmse": 0.7748369574546814,
    "spearman_rho": 0.9035741221688703
}
```

<img src="models/hyperopt/bebf3e298ca5476c7858f8ce7da4be0e/predictions_training.png" width=450>

Validation (4252 rows):

```json

{
    "pearson_r": 0.7913155721534122,
    "rmse": 1.093949794769287,
    "spearman_rho": 0.6601919453312246
}
```

<img src="predictions_validation.png" width=450>

Test (4253 rows):

```json

{
    "pearson_r": 0.8602896516281636,
    "rmse": 1.0420299768447876,
    "spearman_rho": 0.8559756780322346
}
```

<img src="models/hyperopt/bebf3e298ca5476c7858f8ce7da4be0e/predictions_test.png" width=450>
