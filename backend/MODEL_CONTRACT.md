# Model contract (for the modelling team)

The backend reads ONE file: `data/results.json`. Produce it with `python model.py` on the real NASA data and commit it via pull request.

Required shape (extra keys are ignored):
```json
{
  "years": [1981, 1982],            // summer (Jun-Aug) mean T2M_MAX per year, same length as summerT
  "summerT": [31.15, 31.03],
  "model": {
    "best": "trend_ols",
    "backtest": { "<model_name>": {"MAE": 1.5, "RMSE": 2.0, "JJA_MAE": 0.6, "JJA_err_sd": 0.7, "folds": 26} },
    "forecast_jja": 33.03,           // forecast summer mean (C) for forecast_year
    "band": 1.21,                    // 90% half-width (C)
    "forecast_year": 2027,
    "sen_slope_per_decade": 0.53,
    "kendall_p": 0.0,
    "synthetic": false               // MUST be false for real data
  }
}
```
Rules
1. Never commit results produced with `--synthetic`. The API warns when `synthetic` is true.
2. Report the backtest honestly, including models that did worse than the baseline.
3. To improve the model, change `model.py` and regenerate this file. The Java code does not change.
4. Later (optional): expose the same JSON over HTTP from a Python service; only `ForecastProvider` changes.
