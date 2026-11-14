# Field Shift - backend (Spring Boot 3, Java 21)
Run: `mvn spring-boot:run`  then open http://localhost:8080/api/forecast
Test: `mvn test`

Layout: web (controllers) -> service -> provider (data source, pluggable) -> data/results.json
Model team: read MODEL_CONTRACT.md. Raw NASA data: data/nasa_damietta.csv.
