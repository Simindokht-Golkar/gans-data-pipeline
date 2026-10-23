/* ============================================================
   Gans – MySQL database setup
   Creates the database and all six tables used by the pipeline.

   Run ONCE on a fresh setup (MySQL Workbench: open this file,
   then execute statement by statement with Ctrl + Enter).
   Order matters: a table with a FOREIGN KEY can only be created
   after the table it points to.
   ============================================================ */

-- ⚠️ Uncomment ONLY if you really want to delete everything and start fresh:
-- DROP DATABASE IF EXISTS gans;

CREATE DATABASE IF NOT EXISTS gans;
USE gans;


/* ------------------------------------------------------------
   1. cities – static facts, one row per city (source of truth)
   Filled by: 01_cities_populations.ipynb (Wikipedia scraping)
   ------------------------------------------------------------ */
CREATE TABLE cities (
    city_id     INT AUTO_INCREMENT,
    city_name   VARCHAR(255) NOT NULL,      -- official Wikipedia page title (unique on Wikipedia)
    country     VARCHAR(255) NOT NULL,
    latitude    DECIMAL(8,5),               -- decimal degrees, used as input for the weather API
    longitude   DECIMAL(8,5),
    PRIMARY KEY (city_id),
    CONSTRAINT unique_coordinates UNIQUE (latitude, longitude)   -- names can repeat, coordinates can't
);


/* ------------------------------------------------------------
   2. populations – changes over time, one row per city per pipeline run
   Filled by: 01_cities_populations.ipynb (Wikipedia scraping)
   ------------------------------------------------------------ */
CREATE TABLE populations (
    population_id    INT AUTO_INCREMENT,
    population       INT  NOT NULL,         -- city proper (not urban / metro area)
    population_year  YEAR NOT NULL,         -- the year the figure describes (e.g. 2022 census)
    date_retrieved   DATE NOT NULL,         -- the day we collected it
    city_id          INT  NOT NULL,
    PRIMARY KEY (population_id),
    FOREIGN KEY (city_id) REFERENCES cities(city_id)
);


/* ------------------------------------------------------------
   3. weather – 5-day forecast in 3-hour slots (40 rows per city per run)
   Filled by: 02_weather.ipynb (OpenWeatherMap API)
   ------------------------------------------------------------ */
CREATE TABLE weather (
    weather_id     INT AUTO_INCREMENT,
    city_id        INT NOT NULL,
    forecast_time  DATETIME NOT NULL      COMMENT 'start of 3-hour forecast slot, UTC',
    outlook        VARCHAR(255),
    temperature_c  DECIMAL(5,2)           COMMENT 'degrees Celsius',
    feels_like_c   DECIMAL(5,2)           COMMENT 'degrees Celsius',
    wind_speed_ms  DECIMAL(5,2)           COMMENT 'metres per second',
    rain_prob      DECIMAL(3,2)           COMMENT 'probability of precipitation, 0 to 1',
    rain_3h_mm     DECIMAL(5,2) DEFAULT 0 COMMENT 'rain volume in the 3-hour slot, mm',
    snow_3h_mm     DECIMAL(5,2) DEFAULT 0 COMMENT 'snow volume in the 3-hour slot, mm',
    retrieved_at   DATETIME NOT NULL      COMMENT 'when the forecast was collected',
    PRIMARY KEY (weather_id),
    FOREIGN KEY (city_id) REFERENCES cities(city_id)
);


/* ------------------------------------------------------------
   4. airports – airports with flight data within 50 km of each city
   Filled by: 03_airports_flights.ipynb (AeroDataBox API)
   ------------------------------------------------------------ */
CREATE TABLE airports (
    airport_icao       CHAR(4)      NOT NULL,   -- official 4-letter code, e.g. EDDB (natural key)
    airport_iata       CHAR(3),                 -- 3-letter code on tickets, e.g. BER (can be missing)
    airport_name       VARCHAR(255) NOT NULL,
    airport_latitude   DECIMAL(8,5),            -- airport location, not the city centre
    airport_longitude  DECIMAL(8,5),
    time_zone          VARCHAR(50),             -- e.g. Europe/Berlin; flight times are local
    city_id            INT          NOT NULL,
    PRIMARY KEY (airport_icao),
    FOREIGN KEY (city_id) REFERENCES cities(city_id)
);


/* ------------------------------------------------------------
   5. flights – tomorrow's arrivals, one row per landing plane (codeshares excluded)
   Filled by: 03_airports_flights.ipynb (AeroDataBox API)
   ------------------------------------------------------------ */
CREATE TABLE flights (
    flight_id               INT AUTO_INCREMENT,
    arrival_airport_icao    CHAR(4)      NOT NULL,
    departure_airport_icao  CHAR(4),                 -- any airport worldwide, so no foreign key
    scheduled_arrival_time  DATETIME     NOT NULL  COMMENT 'local time of the arrival airport',
    flight_number           VARCHAR(20),
    airline                 VARCHAR(255),
    aircraft_model          VARCHAR(255),
    arrival_terminal        VARCHAR(20),
    retrieved_at            DATETIME     NOT NULL  COMMENT 'when the data was collected',
    PRIMARY KEY (flight_id),
    FOREIGN KEY (arrival_airport_icao) REFERENCES airports(airport_icao)
);


/* ------------------------------------------------------------
   Useful checks
   ------------------------------------------------------------ */
-- latest population per city
-- SELECT c.city_name, p.population, p.population_year, p.date_retrieved
-- FROM populations p JOIN cities c ON p.city_id = c.city_id
-- WHERE p.date_retrieved = (SELECT MAX(date_retrieved) FROM populations);

-- arrivals per city for the latest flights run
-- SELECT c.city_name, a.airport_iata, COUNT(*) AS arrivals
-- FROM flights f
-- JOIN airports a ON f.arrival_airport_icao = a.airport_icao
-- JOIN cities   c ON a.city_id = c.city_id
-- WHERE f.retrieved_at = (SELECT MAX(retrieved_at) FROM flights)
-- GROUP BY c.city_name, a.airport_iata
-- ORDER BY arrivals DESC;
