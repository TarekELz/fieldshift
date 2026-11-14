package com.keplerians.fieldshift.provider;

import com.keplerians.fieldshift.model.ModelOutput;

/** The plug-in point. Today: a JSON file. Later: an HTTP call to a Python service. */
public interface ForecastProvider {
    ModelOutput load();
}
