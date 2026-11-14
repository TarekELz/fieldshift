package com.keplerians.fieldshift.service;

import com.keplerians.fieldshift.model.ForecastResponse;
import com.keplerians.fieldshift.model.ModelOutput;
import com.keplerians.fieldshift.provider.ForecastProvider;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ForecastService {

    private final ForecastProvider provider;

    public ForecastService(ForecastProvider provider) {
        this.provider = provider;
    }

    public ForecastResponse getForecast() {
        ModelOutput out = provider.load();
        List<String> warnings = new ArrayList<>();
        if (out.model() == null) {
            warnings.add("results.json has no 'model' block.");
        } else if (out.model().synthetic()) {
            warnings.add("This forecast was produced from SYNTHETIC data, not NASA data. Do not present it as real.");
        }
        if (out.years() == null || out.years().size() < 30) {
            warnings.add("Series shorter than 30 years: trend estimates are weak.");
        }
        warnings.add("NASA POWER is gridded reanalysis: this is a regional trend, not field-level temperature.");
        return new ForecastResponse(out, warnings);
    }
}
