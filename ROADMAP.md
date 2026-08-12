# Roadmap

Tracks every planned part/chapter of the **Rust ML Guide** and its status.
The single source of truth for what's built is [`book/_toc.yml`](book/_toc.yml);
this file adds status and groups chapters by the planning addendum that
introduced them.

**Status legend:** ✅ done (written & compile-verified) · 🚧 in progress · 📋 planned

## Base book plan

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Getting started | `00-setup/environment` | ✅ |
| Foundations | `01-foundations/ndarray-basics` | ✅ |
| Foundations | `01-foundations/polars-basics` | ✅ |
| Regression | `02-regression/linear-regression` | ✅ |
| Regression | `02-regression/logistic-regression` | ✅ |
| Clustering | `03-clustering/kmeans` | ✅ |
| Clustering | `03-clustering/dbscan` | ✅ |
| Trees | `04-trees/decision-trees` | ✅ |
| Dimensionality Reduction | `05-dimensionality-reduction/pca` | ✅ |
| Appendix | `appendix/crate-reference` | ✅ |

## EDA & ETL addendum

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Exploratory Data Analysis | `01b-eda/exploratory-data-analysis` | ✅ |
| Exploratory Data Analysis | `01b-eda/visualization-gallery` | ✅ |
| ETL & Data Preparation | `01c-etl/data-preparation` | ✅ |

## Eval / optimization / explainability addendum

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Model Evaluation | `01d-evaluation/cross-validation` | ✅ |
| Optimization | `05b-optimization/general-optimization` | ✅ |
| Optimization | `05b-optimization/hyperparameter-search` | ✅ |
| AutoML | `06-automl/automl-classification` | ✅ |
| Explainable ML | `07-explainability/model-interpretability` | ✅ |

## AutoML addendum

| Part | Chapter | Status |
| ---- | ------- | ------ |
| AutoML | `06-automl/automl-classification` (deepened) | ✅ |

## Deployment / time-series / capstone addendum

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Persistence & Deployment | `08-persistence-deployment/saving-and-loading-models` | ✅ |
| Persistence & Deployment | `08-persistence-deployment/serving-a-model` | ✅ |
| Model Monitoring | `09-monitoring/monitoring-a-served-model` | ✅ |
| Time Series | `10-time-series/time-series-fundamentals` | ✅ |
| Time Series | `10-time-series/forecasting` | ✅ |
| Larger-Than-Memory Data | `11-larger-than-memory/streaming-and-lazy-execution` | ✅ |
| Capstone Project | `12-capstone/end-to-end-project` | ✅ |

## Multithreading & ensemble addendum

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Multithreaded ML | `04b-multithreading/parallel-ml` | ✅ |
| Ensemble & Forest Models | `04c-ensemble/random-forests` | ✅ |
| Ensemble & Forest Models | `04c-ensemble/gradient-boosting` | ✅ |
| Ensemble & Forest Models | `04c-ensemble/bagging-and-stacking` | ✅ |
| Optimization | `05b-optimization/search-strategy-comparison` | ✅ |

## EDA / eval / optimization detail addendum

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Model Evaluation | `01d-evaluation/metrics-deep-dive` | ✅ |
| Model Evaluation | `01d-evaluation/learning-curves` | ✅ |
| Regression | `02-regression/regularized-regression` | ✅ |
| Classification | `02b-classification/knn-classification` | ✅ |
| Classification | `02b-classification/naive-bayes` | ✅ |
| Classification | `02b-classification/svm-classification` | ✅ |
| Clustering | `03-clustering/gaussian-mixture` | ✅ |

## Multiple-regression / gradient-descent / logistic-detail addenda

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Regression | `02-regression/multi-output-regression` | ✅ |
| Regression | `02-regression/regularized-logistic-regression` | ✅ |
| Optimization | `05b-optimization/gradient-descent-variants` | ✅ |

## User-requested extras (no addendum file)

| Part | Chapter | Status |
| ---- | ------- | ------ |
| Anomaly Detection | `13-anomaly-detection/detecting-outliers` | ✅ |
| Model Calibration | `14-model-calibration/calibrating-probabilities` | ✅ |
| Exploratory Data Analysis | line/time-series chart in `visualization-gallery` | ✅ |

## Repo housekeeping addendum

| Item | Status |
| ---- | ------ |
| Add `LICENSE` (MIT) | ✅ |
| Add `ROADMAP.md` | ✅ |
| Untrack `.idea/` + add to `.gitignore` | ✅ |
| README status badge + Pages link | ✅ |
| Set repo description & topics | 📋 (GitHub settings — see README/PR notes) |

## Known follow-ups

- 📋 **Full executing build for publish.** Chapters are each verified green in a
  fresh kernel, but the site is normally built with `execute_notebooks: 'off'`
  for fast structure validation, so the HTML shows no embedded plots. A full
  `make book` (execute=`force`) — heavy/OOM-prone on a constrained Docker VM —
  is what embeds outputs; run it with adequate RAM or via the Pages CI workflow.
- 📋 **EDA chart-type expansion** (additional gallery chart types), per the
  detail addendum's forward-looking note.
