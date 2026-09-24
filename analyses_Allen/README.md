# Charbon (Onion Smut) Disease Incidence Prediction

Machine learning project to predict onion smut ("charbon") disease incidence
risk in onion fields, using field, weather, and soil predictors collected in
Quebec onion parcelles over 2023-2025. The goal is a model — eventually
deployed as a Shiny app — that a non-technical user (producer, agronomist)
can query with field-level inputs to get a predicted risk that disease
incidence will exceed a given threshold.

## Project status

Data cleaning and modeling code exists as **templates with TODOs**, not yet
run end-to-end with final decisions locked in. See
[`PROJECT_STATUS.md`](PROJECT_STATUS.md) for a detailed handoff of what has
been decided, what remains open, and suggested next steps for continuing
this work.

## Repository structure

This README, `PROJECT_STATUS.md`, and all analysis code live in
`analyses_Allen/`, one directory below the top-level `charbon/` project
directory:

```
charbon/                               # top-level project directory
├── BD pour Alen/                      # Raw data as received (do not edit)
│   ├── Données parcelles_2023-25.xlsx     # Training data (experimental parcelles)
│   └── Données composites_2023-25.xlsx    # Independent test data (other fields)
├── analyses_Allen/                    # This directory — working analysis directory
│   ├── donnees_parcelles_2023-25.xlsx     # Copy of training data (renamed, no accents/spaces)
│   ├── donnees_composites_2023-25.xlsx    # Copy of test data (renamed, no accents/spaces)
│   ├── 01_data_cleaning.qmd               # Import, clean, explore, define outcome thresholds
│   ├── 02_modeling_template.qmd           # Tidymodels workflow: tune tree/RF/boosted models
│   ├── app.R                              # Shiny app template for eventual deployment
│   ├── README.md                          # This file
│   └── PROJECT_STATUS.md                  # Detailed handoff notes for continuing this work
└── rapports/                          # Reports (not covered by this README)
```

Excel, Word, and PDF files are gitignored (`.gitignore`, at the `charbon/`
top level), so raw and copied data files stay local and are not tracked in
this repository. Only code (`.qmd`, `.R`) and documentation are
version-controlled.

## Data

Two data sets, collected independently:

- **Training set** (`donnees_parcelles_2023-25.xlsx`, ~595 rows): collected
  in experimental parcelles, used for model tuning and cross-validation.
- **Test set** (`donnees_composites_2023-25.xlsx`, ~64 rows): collected in
  separate commercial fields, held out and touched only once per model to
  get an honest estimate of real-world performance.

## Outcome

Rather than one multi-class outcome, the disease incidence variable is
turned into **five separate binary classification problems**, one per
threshold: incidence ≥ 1%, ≥ 2%, ≥ 3%, ≥ 4%, ≥ 5%. Each threshold is modeled
independently (its own tuned decision tree / random forest / boosted tree),
since the underlying agronomic question — "will incidence cross this
specific threshold?" — may have a different answer/best model per
threshold.

## Modeling approach

For each of the 5 thresholds, three model types are tuned via the
`tidymodels` ecosystem in R:

- Decision tree (`rpart`)
- Random forest (`ranger`)
- Boosted trees (`xgboost`)

All hyperparameters are tuned via cross-validation (`tune_grid()`) on the
training set. Class imbalance (positive rates range from ~38% at the 1%
threshold down to ~4% at the 5% threshold) is addressed via `themis`
subsampling recipe steps. The best model per threshold is evaluated once,
at the end, on the independent composites test set.

## Requirements

R packages: `tidyverse`, `readxl`, `janitor`, `tidymodels`, `themis`, `vip`,
`shiny`, `bslib`. (`xgboost`, `ranger`, and `rpart` are pulled in
automatically by `tidymodels`/`parsnip` engines as needed.)

## Reproducing the analysis

1. Open [`01_data_cleaning.qmd`](01_data_cleaning.qmd) and run through it to
   import, clean, explore, and define the five threshold outcomes for both
   data sets, saving cleaned `.rds` files.
2. Duplicate [`02_modeling_template.qmd`](02_modeling_template.qmd) per
   model type × threshold combination (or adapt into a loop /
   `workflowsets` comparison), run tuning, and evaluate on the test set.
3. Once a final model is chosen per threshold, fit it on the full training
   set, save it, and wire it into [`app.R`](app.R) for deployment (see
   `PROJECT_STATUS.md` for details).
