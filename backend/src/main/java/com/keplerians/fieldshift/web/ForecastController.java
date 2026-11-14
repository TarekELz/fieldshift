package com.keplerians.fieldshift.web;

import com.keplerians.fieldshift.model.ForecastResponse;
import com.keplerians.fieldshift.service.ForecastService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ForecastController {

    private final ForecastService service;

    public ForecastController(ForecastService service) {
        this.service = service;
    }

    @GetMapping("/forecast")
    public ForecastResponse forecast() {
        return service.getForecast();
    }
}
