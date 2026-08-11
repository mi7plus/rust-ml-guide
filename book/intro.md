# Rust ML Guide

A hands-on introduction to machine learning in **Rust**, written as runnable
Jupyter notebooks powered by the [`evcxr`](https://github.com/evcxr/evcxr)
kernel. Every code cell in this book is real Rust, compiled and executed to
produce the outputs you see — plots, printed results, and all.

The guide follows a typical intro-ML arc, so if you're coming from Python's
scikit-learn / NumPy / pandas world, the concepts map across directly:

| This guide | Python analogue |
| ---------- | --------------- |
| `ndarray` | NumPy |
| `polars` | pandas |
| `linfa` / `smartcore` | scikit-learn |
| `plotters` | matplotlib |

## How to read this book

- **Read it online** — every chapter is pre-executed, so you can follow along
  without running anything.
- **Run it yourself** — clone the repo and launch the Docker environment
  (`make up`), then open any chapter notebook and re-run the cells. See
  [Setup](00-setup/environment.ipynb).

## Chapter arc

1. **Setup** — get the reproducible Docker / evcxr environment running.
2. **Foundations** — `ndarray` and `polars`, the array and dataframe layer.
3. **Exploratory Data Analysis** — confronting a messy dataset with `polars` + `plotters`.
4. **ETL & Data Preparation** — cleaning, encoding, and validating into a model-ready matrix.
5. **Model Evaluation** — train/test splitting, k-fold cross-validation, metrics.
6. **Regression** — linear and logistic regression.
7. **Clustering** — k-means and DBSCAN.
8. **Trees** — decision trees.
9. **Dimensionality reduction** — PCA.
10. **Optimization** — `argmin` for general optimization; grid/random/TPE hyperparameter search.
11. **AutoML** — automated model comparison with `automl`.
12. **Explainable ML** — permutation importance, Kernel SHAP, Shapley values.
13. **Persistence & Deployment** — saving models (`serde`/`bincode`) and serving them (`axum`).
14. **Model Monitoring** — structured logging, metrics, and a by-hand drift check.
15. **Time Series** — time-aware splitting, lag features, and `augurs` forecasting.
16. **Larger-Than-Memory Data** — `polars` lazy + streaming execution.
17. **Capstone** — every technique above, end-to-end on one dataset.
18. **Appendix** — a crate reference / cheat sheet and evcxr troubleshooting.

```{note}
This guide reflects the real, current state of the Rust ML ecosystem — **excellent
for the data and deployment layers, thinner but workable for ML-specific tooling**.
Later chapters flag crate maturity honestly and hand-roll techniques (permutation
importance, drift detection) where no mature crate exists.
```

```{note}
A quirk of the Rust kernel worth knowing up front: `evcxr` compiles each cell,
so cells that introduce new crates or heavy code take a few seconds. Types that
can't be named (like a fitted model) must stay inside a single `{ }` block —
you'll see this pattern throughout the book. The
[crate reference](appendix/crate-reference.md) explains why.
```
