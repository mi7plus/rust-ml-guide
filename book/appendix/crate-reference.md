# Appendix: Crate reference & evcxr troubleshooting

## The crate stack

| Crate | Version | Role | Python analogue |
| ----- | ------- | ---- | --------------- |
| `ndarray` | 0.15 | N-dimensional arrays | NumPy |
| `polars` | 0.44 | DataFrames | pandas |
| `linfa` | 0.7 | ML toolkit (metatraits + datasets) | scikit-learn core |
| `linfa-linear` | 0.7 | Linear regression | `LinearRegression` |
| `linfa-logistic` | 0.7 | Logistic regression | `LogisticRegression` |
| `linfa-clustering` | 0.7 | k-means, DBSCAN | `KMeans`, `DBSCAN` |
| `linfa-trees` | 0.7 | Decision trees | `DecisionTreeClassifier` |
| `linfa-reduction` | 0.7 | PCA | `PCA` |
| `smartcore` | 0.3 | Alternative ML toolkit | scikit-learn |
| `plotters` | 0.3 | Plotting | matplotlib |
| `argmin` | 0.10 | Optimization | scipy.optimize |

```{important}
**`ndarray` is pinned to 0.15**, not the newer 0.16, because `linfa` 0.7 depends
on 0.15. Mixing 0.15 and 0.16 arrays in one kernel session breaks `linfa`'s
trait implementations (you'll see errors like `ArrayBase: Records is not
satisfied`). Every chapter uses 0.15 — the **one exception** is the ETL chapter's
SMOTE step, which runs [`imbalance-rs`](https://crates.io/crates/imbalance-rs) on
`ndarray` 0.16. That's safe only because the ETL notebook never loads `linfa`,
and it builds the SMOTE arrays from plain `Vec`s so the 0.15 and 0.16 types never
have to meet.
```

## evcxr patterns you'll see throughout the book

### 1. Declaring dependencies

```rust
:dep ndarray = { version = "0.15" }
:dep linfa = { version = "0.7" }
```

The first cell that `:dep`s a crate triggers a compile (seconds, thanks to the
pre-warmed cache — see the [environment chapter](../00-setup/environment.ipynb)).

### 2. Wrap fitted models in a block

`evcxr` persists variables between cells, but only if it can *name* their type.
A fitted model (e.g. `KMeans`, `DecisionTree`) often has an un-nameable type, so
evcxr errors with *"Couldn't automatically determine type of variable"*. The fix
is to keep the model inside a single `{ }` block so nothing complex escapes:

```rust
{
    let model = KMeans::params(2).fit(&dataset).expect("fit");
    let preds = model.predict(&dataset);
    println!("{:?}", preds);
}
```

If you need a result **in a later cell**, return it from the block and give the
binding an **explicit type** — evcxr can't infer the type of a block-bound
variable well enough to persist it across cells, and errors with *"Couldn't
automatically determine type of variable"*:

```rust
use ndarray::Array1;
let preds: Array1<usize> = {                      // <-- explicit type
    let model = KMeans::params(2).fit(&dataset).expect("fit");
    model.predict(&dataset)
};
// ... a later cell can now use `preds`
```

(A variable bound *directly* to an expression — `let c = dbscan.transform(&x)?;`
— doesn't need this; only block-bound bindings do.)

### 3. Datasets

- **Unsupervised** (clustering, PCA): `DatasetBase::from(records)` — records only.
- **Supervised** (regression, trees): `Dataset::new(records, targets)`.

## Common errors & fixes

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `Couldn't automatically determine type of variable` | Model type isn't nameable across cells | Wrap in a `{ }` block |
| `ArrayBase: Records is not satisfied` | ndarray 0.16 mixed with linfa's 0.15 | Pin `ndarray = "0.15"` everywhere |
| `feature edition2024 is required` | Rust toolchain too old | Image uses Rust ≥ 1.85 |
| First cell hangs for minutes | Crate not in the pre-warm set | Add it to `prewarm.evcxr`, rebuild |
| Kernel dies with **no error message** when using `rayon` | `rayon::prelude` at cell top level collides with evcxr's variable-store codegen | Keep all `rayon` code (uses, data, `par_iter`) **inside a `{ }` block** — no top-level `let`/`fn` under it |
| `the trait bound i64: Unsigned is not satisfied` | `smartcore`'s KNN / Naive Bayes / SVC want **unsigned** class labels | Use `Vec<u32>` for classification targets |
| `no method named unwrap ... DenseMatrix` | standalone `smartcore::...::DenseMatrix::from_2d_array` returns the matrix directly | Drop the `.unwrap()` (note: `automl`'s re-exported version *does* return `Result`) |
| SVC: `temporary value dropped while borrowed` | `SVC::fit` takes `&SVCParameters` | Bind the params to a `let` first, then pass `&params` |

## Crates used in the later (addenda) chapters

These power the evaluation, optimization, AutoML, explainability, deployment,
monitoring, and time-series chapters. **Maturity flags are load-bearing**: this
part of the Rust ecosystem is thinner and younger than the core modelling crates
above, so treat versions and APIs as moving targets and re-check before relying
on them.

| Crate | Version | Role | Maturity |
| ----- | ------- | ---- | -------- |
| `smartcore::model_selection` / `metrics` | 0.3 | train/test split, K-fold, accuracy/precision/recall/F1/RMSE/MAE/R²/`roc_auc_score` | Solid; **no `StratifiedKFold`, no `predict_proba`, no ROC/PR *curve points* or MAPE** — the curves are drawn with `plotters-statistical`, stratified/group/time-series splitting comes from `model-selection-rs`, MAPE is hand-rolled |
| `plotters-statistical` | 0.2 | statistical chart primitives as native `plotters` series/figures — box, violin, ECDF, Q–Q, correlation & missingness heatmaps, pair plot, ROC, precision-recall, calibration, regularization-path, residual | Newer, single-author; pins `plotters = "=0.3.7"`. Use with `default-features = false` (as the book does) to avoid the `font-kit`/`fontconfig` native stack |
| `smartcore` models | 0.3 | `neighbors` (KNN), `naive_bayes` (Gaussian NB), `svm` (SVC), `linear::{ridge_regression,lasso,elastic_net}`, `tree::{decision_tree_classifier,decision_tree_regressor}`, `ensemble::random_forest_{classifier,regressor}` | Solid core; **no Extra Trees / gradient boosting**, no hierarchical clustering — real gaps vs scikit-learn |
| `model-selection-rs` | 0.1 | cross-validation & model selection: `KFold`/`StratifiedKFold`/`GroupKFold`/`TimeSeriesSplit`/`ShuffleSplit`/repeated + `LeaveOneOut` splitters (return index folds), plus `cross_validate`, `nested_cross_validate`, `learning_curve`, `validation_curve`; optional `parallel` (rayon) and `smartcore` scorer features | Newer, single-author; fills `smartcore`'s `StratifiedKFold`/curve gaps. **Built on `ndarray` 0.16** — use where `linfa` (0.15) isn't loaded. Splitters are index-based (pair with any model); the evaluate fns take an ndarray fit-closure, so smartcore models need a small `DenseMatrix` bridge |
| `rayon` | 1.x | data parallelism (`par_iter`) for parallel grid search / bootstrap; also used *inside* `smartcore`'s random forests | Solid, ubiquitous |
| `imbalance-rs` | 0.5 | imbalanced-data resampling — `Smote` + `Adasyn`, Borderline/SVM/KMeans-SMOTE, `SmoteNc` (mixed numeric+categorical), under-samplers, combined `SmoteEnn`/`SmoteTomek`; a port of Python's `imbalanced-learn` | Newer but real & maintained; **built on `ndarray` 0.16** — use only where `linfa` (0.15) isn't also loaded (the ETL chapter's SMOTE step). Plain `Smote` interpolates every column, so use `SmoteNc` for one-hot/ordinal features |
| `argmin` | 0.10 | general numerical optimization | Solid, actively maintained |
| `tpe` | 0.3 | Tree-structured Parzen Estimator (Bayesian HPO) | **Focused single-algorithm crate, not a full HPO framework** |
| `automl` | git (`cmccomb/rust-automl`) | model-zoo comparison + CV | **git-only, smaller scope than auto-sklearn/TPO; active dev** |
| `rust_shap` | 0.1 | model-agnostic Kernel SHAP | **Early-stage (0.1.x)** |
| `shapley` | 0.1 | general Shapley-value calculator (not ML-specific) | **Early-stage; conceptual building block** |
| `serde` + `bincode` | 1.x | model serialization to/from disk | Solid |
| `tract-onnx` | 0.22 | load & run ONNX models (consume models trained elsewhere) | Solid |
| `axum` + `tokio` | 0.7 / 1.x | minimal HTTP inference server | Solid (general web stack, not ML-specific) |
| `tracing`, `metrics` | 0.1 / 0.24 | structured logging & metrics for monitoring | Solid (general-purpose) |
| `augurs` | 0.10 | time-series: MSTL decomposition, ETS forecasting | Real & maintained, but **TS ecosystem younger than Python's** |
| `perpetual` | — | gradient boosting w/ built-in SHAP/PDP | **Unavailable here — requires nightly Rust; excluded from this stable image** |

```{warning}
Rust's tooling for **hyperparameter optimization** (vs. Optuna/Hyperopt),
**explainability** (vs. SHAP/LIME), and **drift/monitoring** (vs. Evidently)
is markedly thinner than Python's. Several chapters therefore build primitives
**by hand** (grid/random search, permutation importance, a PSI drift check)
rather than leaning on a niche crate that may go unmaintained.
```

### Hand-rolled in the regression & optimization chapters

Library-backed where possible, hand-rolled where no maintained crate exists:

| Technique | Status |
| --------- | ------ |
| Linear / multiple regression, R² | `smartcore::linear::linear_regression` + `metrics::r2` (library) |
| **VIF** (multicollinearity) | **Hand-rolled** — `1/(1−R²_j)` from per-predictor regressions; no crate exposes it |
| Adjusted R², standardized coefficients | Hand-rolled formulas on top of the library fits |
| **Multi-output / multivariate OLS** | **Hand-rolled** `(XᵀX)⁻¹XᵀY` with `ndarray` — `smartcore`/`linfa` are single-target; a **Gauss-Jordan inverse** avoids an `ndarray-linalg` LAPACK backend |
| **Gradient descent** (batch/SGD/mini-batch, momentum, Adam) | **Hand-rolled** with `ndarray` for teaching; `argmin` is the production path |
| Logistic regression, **L2** | `smartcore::linear::logistic_regression` (`.with_alpha(...)` = L2) |
| Logistic **L1 / ElasticNet** | **Hand-rolled** cross-entropy GD + proximal soft-threshold — `smartcore`/`linfa` expose only L2 for logistic |
| **Anomaly detection** (Mahalanobis, k-NN outlier score) | **Hand-rolled** (`ndarray` + Gauss-Jordan inverse) — no maintained Isolation Forest / LOF crate; `augurs` covers *time-series* outliers |
| **Probability calibration** (reliability diagram, Brier, Platt scaling) | **Hand-rolled** — Platt = a 2-param logistic on the scores; no isotonic-regression crate (that fallback is hand-rolled too) |

## Data formats & I/O (`polars`)

| Format | Read | Write |
| ------ | ---- | ----- |
| CSV | `CsvReadOptions::default().try_into_reader_with_file_path(Some(path))?.finish()?` | `CsvWriter::new(file).finish(&mut df)?` |
| Parquet | `ParquetReader::new(file).finish()?` | `ParquetWriter::new(file).finish(&mut df)?` |
| JSON | `JsonReader::new(file).finish()?` | `JsonWriter::new(file).finish(&mut df)?` |

**Lazy API** — `LazyFrame` (`scan_csv` / `scan_parquet` + `.collect()`) builds a
query plan with predicate/projection pushdown and only materializes at the end.
Prefer it for pipelines and larger-than-memory data (see the ETL and
Larger-Than-Memory chapters). Requires the `parquet` feature for Parquet I/O.

## Chart type reference

Mirrors the [visualization gallery](../01b-eda/visualization-gallery.ipynb)'s
closing table, so it's discoverable outside the narrative chapter. `plotters`
itself has **no** statistical-chart primitives — box, violin, heatmap, pair-plot,
ECDF, Q–Q, ROC/PR, calibration, regularization-path or residual. Those all come
from [`plotters-statistical`](https://crates.io/crates/plotters-statistical),
which adds them as native `plotters` series/figures (so they compose with
`ChartBuilder` / `draw_series`). Histograms, bar charts and scatter/line plots use
`plotters`' own built-ins. The crate is pinned to `plotters = "=0.3.7"` and is used
with `default-features = false` so it needs no system font libraries.

| Your question | Chart | How it's drawn |
| --- | --- | --- |
| Shape/skew of one numeric variable | Histogram · ECDF | Histogram built-in; ECDF via `plotters-statistical` `Ecdf` |
| Is one variable normally distributed | Q–Q plot | `plotters-statistical` `QqPlot` |
| Quartiles & outliers of one variable | Box plot | `plotters-statistical` `BoxPlotSeries` |
| Full density/shape (skew, modes) of one variable | Violin plot | `plotters-statistical` `ViolinPlotSeries` |
| Strength of many pairwise relationships at once | Correlation heatmap | `plotters-statistical` `CorrelationHeatmap` |
| What a pairwise relationship looks like | Pair plot / scatter matrix | `plotters-statistical` `PairPlot` |
| Whether missing values cluster | Missingness heatmap | `plotters-statistical` `MissingnessHeatmap` |
| Frequency of each category · target class balance | Bar chart | Built-in (`Rectangle`) |
| Which points are outliers, in context | Scatter with flagged points | Built-in series |
| A quantity over an ordered axis | Line / time chart | Built-in (`LineSeries`) — see Time Series |
| Threshold-independent ranking quality | ROC curve / AUC | `plotters-statistical` `RocCurve` |
| Precision/recall trade-off (imbalanced) | Precision-recall curve | `plotters-statistical` `PrecisionRecallCurve` |
| Are predicted probabilities trustworthy | Calibration (reliability) curve | `plotters-statistical` `CalibrationCurve` |
| How coefficients shrink with the penalty | Regularization path | `plotters-statistical` `RegularizationPath` |
| Are regression errors patterned | Residual plot | `plotters-statistical` `ResidualPlot` |

## Adding a crate to the pre-warmed cache

See the repository README: add a pinned `:dep` line to `prewarm.evcxr`, then
`make build` (or `make rebuild-cache` for the running container).
