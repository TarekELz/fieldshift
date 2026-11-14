package com.keplerians.fieldshift.provider;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.keplerians.fieldshift.model.ModelOutput;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class FileForecastProviderTest {

    @TempDir Path tmp;

    @Test
    void readsModelOutput() throws Exception {
        Path f = tmp.resolve("results.json");
        Files.writeString(f, """
            {"years":[2024,2025],"summerT":[33.1,32.9],
             "model":{"best":"trend_ols","backtest":{"trend_ols":{"MAE":1.5,"RMSE":2.0,"JJA_MAE":0.6,"JJA_err_sd":0.7,"folds":26}},
             "forecast_jja":33.03,"band":1.21,"forecast_year":2027,"sen_slope_per_decade":0.53,"kendall_p":0.0,"synthetic":false}}
            """);
        ModelOutput out = new FileForecastProvider(new ObjectMapper(), f.toString()).load();
        assertEquals("trend_ols", out.model().best());
        assertEquals(33.03, out.model().forecastJja(), 1e-9);
        assertEquals(2.0, out.model().backtest().get("trend_ols").rmse(), 1e-9);
    }

    @Test
    void missingFileIsReportedClearly() {
        var p = new FileForecastProvider(new ObjectMapper(), tmp.resolve("nope.json").toString());
        assertThrows(ModelUnavailableException.class, p::load);
    }
}
