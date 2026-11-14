package com.keplerians.fieldshift.model;

import java.util.List;

/** What the frontend receives: the model output plus honesty warnings. */
public record ForecastResponse(ModelOutput data, List<String> warnings) {}
