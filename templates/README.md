---
license: mit
pipeline_tag: tabular-regression
tags:
- chemistry
- ADMET
library_name: duvidnn
datasets:
- openadmet/openadmet-expansionrx-challenge-train-data
---

# OpenADMET-ExpansionRx Challenge entry

_Updated:_ __TODAY__

Trained on the OpenADMET-ExpansionRx Challenge dataset (__NROWS__ rows in total, [HF dataset](https://huggingface.co/datasets/openadmet/openadmet-expansionrx-challenge-train-data)).

## Model details

This model was trained using [our DuvidNN framework](https://github.com/scbirlab/duvidnn), 
as a result of hyperparameter searches and selecting the model that performs best on unseen test data 
(from a scaffold split). 

DuvidNN also saves the training data in this checkpoint to allows the calculation of uncertainty metrics 
based on that training data.

This model is the best regression model from a hyperparameter search, determined
by Pearson's _r_ on a held-out test set not seen in training or early stopping. 

### Model architecture

- **Regression**

```json
__CONFIG__

```

### Model usage

You can use this model with:

```python
from duvida.autoclasses import AutoModelBox
modelbox = AutoModelBox.from_pretrained("hf://eachanjohnson/openadmet-2601")
modelbox.predict(data=..., inputs=[...], columns=[...])  # make predictions on your own data
```

## Training details

- **Dataset:** [OpenADMET-ExpansionRx Challenge](https://huggingface.co/datasets/openadmet/openadmet-expansionrx-challenge-train-data) (__NROWS__ rows in total)
- **Input column:** __INPUTS__
- **Output column:** __OUTPUTS__
- **Split type:** Murcko scaffold
- **Split proportions:** 
    - 70% training (__NTRAIN__ rows)
    - 15% validation (for early stopping) (__NVAL__ rows)
    - 15% test (for selecting hyperparameters) (__NTEST__ rows)

Here is the training log:

<img src="training-log.png" width=450>

And these are the evaluation scores.

Train (__NTRAIN__ rows):

```json
__TRAIN_EVAL__

```

<img src="predictions_training.png" width=450>

Validation (__NVAL__ rows):

```json
__VAL_EVAL__

```

<img src="predictions_validation.png" width=450>

Test (__NTEST__ rows):

```json
__TEST_EVAL__

```

<img src="predictions_test.png" width=450>


### Data Collection and Processing

Data were processed using [schemist](https://github.com/scbirlab/schemist), a tool for processing chemical datasets.

The SMILES strings have been canonicalized, and split into training (70%), validation (15%), and test (15%) sets 
by Murcko scaffold for each species with more than 1000 entries. Additional features like molecular weight and 
topological polar surface area have also been calculated.
