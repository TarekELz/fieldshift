package com.keplerians.fieldshift.provider;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.keplerians.fieldshift.model.ModelOutput;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class FileForecastProvider implements ForecastProvider {

    private final ObjectMapper mapper;
    private final Path path;

    public FileForecastProvider(ObjectMapper mapper,
                                @Value("${fieldshift.model.results-path}") String resultsPath) {
        this.mapper = mapper;
        this.path = Path.of(resultsPath);
    }

    @Override
    public ModelOutput load() {
        if (!Files.exists(path)) {
            throw new ModelUnavailableException(
                    "Model output not found at " + path + ". The modelling team must upload results.json (see MODEL_CONTRACT.md).");
        }
        try {
            return mapper.readValue(path.toFile(), ModelOutput.class);
        } catch (IOException e) {
            throw new ModelUnavailableException("results.json is not valid: " + e.getMessage(), e);
        }
    }
}
