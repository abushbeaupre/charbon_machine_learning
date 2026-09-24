# Project status / handoff notes

Last updated: 2026-09-24. Written for a future agent/session picking this
project back up — read this before touching any files.

## Where things stand

Nothing has been run end-to-end yet. `01_data_cleaning.qmd` and
`02_modeling_template.qmd` are **templates with real column names and
working exploratory code**, but neither has been executed in full to
produce final cleaned `.rds` files or a fitted/finalized model. `app.R` is a
placeholder Shiny app that will error until real models are trained and
saved.

## Data

Two Excel files were copied from `../BD pour Alen/` (relative to this
directory; original path has spaces and accents) into this directory
(`analyses_Allen/`) with cleaned filenames:

- `../BD pour Alen/Données parcelles_2023-25.xlsx` → `donnees_parcelles_2023-25.xlsx`
  (**training set**, 595 rows). Two sheets exist:
  `"BD_23-25_compil"` (the one currently read in the cleaning template) and
  `"données dépistage"` (not yet inspected/used).
- `../BD pour Alen/Données composites_2023-25.xlsx` → `donnees_composites_2023-25.xlsx`
  (**independent test set**, 64 rows, collected in different fields than
  training data).

Both are gitignored (`*.xlsx` in the top-level `charbon/.gitignore`) — they
exist locally in this directory but are not tracked in git.

### Known training-set columns (from `"BD_23-25_compil"` sheet, `clean_names()`-ed)

```
numero_extraction, code_producteur, producteur, code_champ, champ,
groupe_parcelle, parcelle, station, date_semis,
date_au_stade_etendard_approx, traitement_de_semences, annee, cultivar,
n_pour_chaque_cultivar, type, type_stat,
percent_incidence_moyenne_maximale, spores_g_sol, jour_entre_semi_et_se,
date_stade_etandard_jour_julien, date_semi_jour_julien, semi_1w_temp_air,
se_3_w_temp_air, semi_se_temp_air, semi_3_week_temp_air, semi_1w_pluie,
se_3_w_pluie, semi_se_pluie, semi_3_week_pluie, seuil_1_percent_incidence,
seuil_2_percent_incidence, seuil_3_percent, seuil_4_percent, seuil_5_percent
```

Key columns:
- `percent_incidence_moyenne_maximale` — continuous maximum incidence (%),
  the source column for all derived outcome thresholds.
- `seuil_1_percent_incidence` ... `seuil_5_percent` — **pre-existing**
  binary indicator columns for the same five thresholds. We chose **not**
  to rely on these (per user instruction) and instead derive outcomes
  directly from `percent_incidence_moyenne_maximale`, but kept a
  sanity-check chunk comparing our derived outcomes against these columns
  (not yet run — worth checking for mismatches, which would indicate the
  `seuil_*` columns use a different boundary convention, e.g. `>` vs `>=`).

### Known composites (test) set columns

```
annee, ferme_2, champ, ferme_4, variete, traitement_de_semence,
date_de_semis, date_de_levee, date_evaluation, stade, densite_moy,
erreur_type_12, incidence_moy, erreur_type_14, numero_extraction, spores_g
```

Key column: `incidence_moy` — continuous mean incidence (%), used to derive
the same five thresholds on this set. **Not yet confirmed**: whether
`incidence_moy` (a mean) is measured comparably to
`percent_incidence_moyenne_maximale` (a max) in the training set — this is
an open question, see below.

### Empirical class balance (training set, 595 rows)

| Threshold | Positive rate (derived from `seuil_*` columns) |
|---|---|
| ≥ 1% | ~38% (227/595) |
| ≥ 2% | ~28% (169/595) |
| ≥ 3% | ~15% (89/595) |
| ≥ 4% | ~6% (38/595) |
| ≥ 5% | ~4% (21/595) |

The 4% and 5% thresholds have few positive cases — flagged throughout the
templates as needing special handling (fewer CV folds, possibly
upsampling/SMOTE over downsampling, since downsampling would discard a lot
of the already-small data set).

Composites (test) set class balance has **not yet been checked** — with
only 64 rows, it's plausible some thresholds have very few or zero positive
cases there, which would make test-set evaluation for those thresholds
unreliable (wide confidence intervals, or literally undefined metrics like
sensitivity if there are zero positives). Check this before evaluating
final models.

## Key decisions made so far

1. **Five separate binary classification problems**, not one multi-class
   outcome — one model per threshold (1%, 2%, 3%, 4%, 5%), since a row can
   be positive for one threshold and negative for another (they are not
   mutually exclusive levels of a single factor).
2. **Outcomes derived directly from continuous incidence columns**
   (`percent_incidence_moyenne_maximale` / `incidence_moy`), not from the
   training set's pre-existing `seuil_*` indicator columns — the user
   explicitly asked to leave the incidence calculations "to the side" of
   the pre-computed indicators and compute thresholds directly.
3. **Composites set is a true held-out test set**, not a random split of
   the training data — it was collected in different fields. The modeling
   template builds a `rsplit` manually via `make_splits(list(analysis =
   train, assessment = test))` rather than `initial_split()`, and only uses
   it once per model via `last_fit()`.
4. Three model types per threshold: decision tree (`rpart`), random forest
   (`ranger`), boosted trees (`xgboost`) — all fully tuned via
   `tune_grid()`.
5. Class imbalance handled via `themis` recipe steps
   (`step_downsample`/`step_upsample`/`step_smote`), commented as
   mutually-exclusive options in the recipe — no single choice has been
   locked in yet; comparing empirically was suggested to the user, not yet
   done.
6. Leakage columns identified for removal from predictors before modeling:
   `seuil_1_percent_incidence` ... `seuil_5_percent`,
   `percent_incidence_moyenne_maximale`, `incidence_moy` (plus the four
   *other* `outcome_*` columns not being modeled in a given template copy).
7. Eventual deployment target: a Shiny app (`analyses_Allen/app.R`), built
   with `bslib`, one form of predictor inputs, output showing predicted
   risk (probability) and predicted class per threshold. Hosting options
   discussed: self-hosted Posit Connect, Posit Connect Cloud (recommended
   starting point — lower friction, no server to manage), or `shinylive`
   for serverless/offline use.

## Open questions / decisions NOT yet made

These need a decision (likely from the domain expert / user) before modeling
can be finalized:

- **Predictor set**: no final list of which columns to use as predictors
  has been chosen. Candidates seen during exploration: `cultivar`,
  `traitement_de_semences`, `spores_g_sol`, temperature/rainfall windows
  (`semi_1w_temp_air`, `se_3_w_temp_air`, `semi_se_temp_air`,
  `semi_3_week_temp_air`, and the `_pluie` rainfall equivalents),
  `producteur`, `station`, `type`, `annee`. Identifier/date columns
  (`numero_extraction`, `code_producteur`, `code_champ`, `champ`,
  `groupe_parcelle`, `parcelle`, `date_semis`, etc.) probably should NOT be
  used as predictors (they'd likely leak field identity / cause
  overfitting to specific parcelles) but this hasn't been explicitly
  decided or excluded in code yet.
- **Whether `incidence_moy` (composites) is comparable to
  `percent_incidence_moyenne_maximale` (training)** — one is a mean, one is
  a "mean of maxima"; using the same threshold cutoffs on both assumes
  they're on the same scale and measure the same underlying quantity. Worth
  clarifying with whoever collected the composites data.
- **Boundary convention**: `>=` vs `>` for thresholds — assumed `>=`
  throughout, not yet verified against how `seuil_*` columns were
  originally computed (sanity-check chunk exists in
  `01_data_cleaning.qmd` but hasn't been run).
- **Sheet choice**: training data has a second sheet
  (`"données dépistage"`) that has not been inspected — may contain
  additional or different data relevant to the analysis.
- **Subsampling strategy** (`step_downsample`/`step_upsample`/`step_smote`)
  — not yet chosen; likely needs empirical comparison, especially for the
  imbalanced 4%/5% thresholds.
- **CV fold count** — `v = 10` is the default in the template; a comment
  suggests reducing to `v = 5` (or using repeated CV) for the 4%/5%
  thresholds given how few positive cases exist. Not yet changed.
- **Tuning metric for `select_best()`** — currently defaults to `roc_auc`;
  given the imbalance, `pr_auc` might be more appropriate, especially for
  rarer thresholds. Flagged with a TODO in the template but not decided.
- **Missing data** — `01_data_cleaning.qmd` has exploration code for
  missingness (per-column counts, by year, sample rows) but this has not
  actually been run against the real data yet, so the extent/pattern of
  missingness is unknown.

## Suggested next steps (in rough order)

1. Run `01_data_cleaning.qmd` end-to-end: inspect missingness, decide the
   final predictor set (exclude IDs/dates), verify the boundary convention
   via the `seuil_*` sanity-check chunk, and confirm `incidence_moy` vs.
   `percent_incidence_moyenne_maximale` comparability. Save the two cleaned
   `.rds` files.
2. Check composites-set class balance per threshold before relying on it
   for final evaluation — flag any threshold with too few (or zero)
   positive test cases.
3. Duplicate `02_modeling_template.qmd` per model × threshold (or convert
   to a `workflowsets`-based comparison / loop), decide on a subsampling
   strategy, tune, and compare model performance across the three model
   types per threshold.
4. Pick a winning model per threshold (5 total), fit each on the full
   training set, and save as `.rds`.
5. Fill in `app.R`'s `MODEL_PATHS`, sidebar inputs, and `build_new_data()`
   to match the final predictor set, then test locally with
   `shiny::runApp()`.
6. Deploy via Posit Connect Cloud (or self-hosted Connect, if available) —
   see conversation history / `rsconnect::deployApp()` for the deployment
   command once the app is working locally.

## File-by-file summary

All paths below are relative to this directory (`analyses_Allen/`).

- `01_data_cleaning.qmd` — imports both Excel files, cleans names, has
  exploratory code (distinct counts, missingness, categorical frequencies,
  histograms, boxplots of incidence by year/cultivar/treatment/producer,
  scatterplots vs. spores/temperature/rainfall), derives the five binary
  outcome columns (`outcome_1`...`outcome_5`) from continuous incidence
  columns for both data sets, includes a sanity check against the
  pre-existing `seuil_*` columns, and saves
  `donnees_parcelles_clean.rds` / `donnees_composites_clean.rds`.
- `02_modeling_template.qmd` — heavily tutorial-commented tidymodels
  workflow: loads the two cleaned `.rds` files, picks one threshold's
  outcome via `outcome_col`, drops leakage columns, builds `vfold_cv()`
  folds (stratified), a shared preprocessing `recipe()` with `themis`
  imbalance-handling options, three tunable model specs (tree/RF/boosted),
  `tune_grid()` + `grid_latin_hypercube()`, `select_best()` +
  `finalize_workflow()`, and evaluates once via `last_fit()` against a
  manually constructed `rsplit` using the composites set — followed by a
  confusion matrix, ROC curve, and `vip()` variable importance plot.
- `app.R` — placeholder Shiny app (bslib) with a sidebar form of
  illustrative predictor inputs, loads five per-threshold models from
  `MODEL_PATHS` (currently empty/placeholder paths), and on a button click
  predicts risk (%) and class per threshold, displayed in a table.
