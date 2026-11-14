package com.keplerians.fieldshift.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import java.util.Map;

/** Mirrors the results.json written by the modelling team's model.py. See MODEL_CONTRACT.md. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ModelOutput(List<Integer> years, List<Double> summerT, ModelInfo model) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ModelInfo(
            String best,
            Map<String, Metrics> backtest,
            @JsonProperty("forecast_jja") double forecastJja,
            double band,
            @JsonProperty("forecast_year") int forecastYear,
            @JsonProperty("sen_slope_per_decade") double senSlopePerDecade,
            @JsonProperty("kendall_p") double kendallP,
            boolean synthetic) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Metrics(
            @JsonProperty("MAE") double mae,
            @JsonProperty("RMSE") double rmse,
            @JsonProperty("JJA_MAE") double jjaMae,
            @JsonProperty("JJA_err_sd") double jjaErrSd,
            int folds) {}
}
