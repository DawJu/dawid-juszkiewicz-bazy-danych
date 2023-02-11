CREATE OR REPLACE FUNCTION a_utc_offset_ok(utc_offset INT) RETURN BOOLEAN IS
    BEGIN
        IF utc_offset / 3600 BETWEEN -12 AND 14 THEN
            IF utc_offset / 3600 = FLOOR(utc_offset / 3600) THEN
                RETURN TRUE;
            END IF;
        END IF;
        RETURN FALSE;
    END;


CREATE OR REPLACE PROCEDURE a_create_location(
        loc_name VARCHAR, loc_latitude NUMBER DEFAULT 0,
        loc_longitude NUMBER DEFAULT 0, loc_elevation NUMBER DEFAULT 0,
        utc_offset NUMBER DEFAULT 0,
        loc_timezone VARCHAR DEFAULT 'Europe/London',
        timezone_abr VARCHAR DEFAULT 'GMT') IS
    bad_utc_offset EXCEPTION;
    BEGIN
        IF NOT a_utc_offset_ok(utc_offset) THEN RAISE bad_utc_offset;
        END IF;
        INSERT INTO a_locations VALUES(loc_name, loc_latitude, loc_longitude,
            loc_elevation, utc_offset, loc_timezone, timezone_abr);
        EXCEPTION
            WHEN bad_utc_offset THEN
            DBMS_OUTPUT.PUT_LINE(
                'Error: ' || 'incorrect utc_offset_seconds value');
    END;


CREATE OR REPLACE PROCEDURE a_update_location(
        loc_name VARCHAR, loc_latitude NUMBER DEFAULT NULL,
        loc_longitude NUMBER DEFAULT NULL, loc_elevation NUMBER DEFAULT NULL,
        utc_offset NUMBER DEFAULT NULL, loc_timezone VARCHAR DEFAULT NULL,
        timezone_abr VARCHAR DEFAULT NULL) IS
    error_number error_log.error_number%TYPE;
    error_info error_log.error_msg%TYPE;
    no_locations_updated EXCEPTION;
    BEGIN
        UPDATE a_locations SET
            latitude = loc_latitude,
            longitude = loc_longitude,
            elevation = loc_elevation,
            utc_offset_seconds = utc_offset,
            timezone = loc_timezone,
            timezone_abbreviation = timezone_abr
        WHERE location_name = loc_name;
        IF SQL%NOTFOUND THEN RAISE no_locations_updated;
        END IF;
        EXCEPTION
            WHEN no_locations_updated THEN
            error_number := SQLCODE;
            error_info := SQLERRM;
            DBMS_OUTPUT.PUT_LINE(
                'Error ' || error_number || ' - ' || error_info);
    END;


CREATE OR REPLACE TRIGGER a_update_loc_trig
    BEFORE UPDATE ON a_locations
    FOR EACH ROW
    BEGIN
        IF :NEW.latitude IS NULL
            THEN :NEW.latitude := :OLD.latitude;
        END IF;
        IF :NEW.longitude IS NULL
            THEN :NEW.longitude := :OLD.longitude;
        END IF;
        IF :NEW.elevation IS NULL
            THEN :NEW.elevation := :OLD.elevation;
        END IF;
        IF :NEW.utc_offset_seconds IS NULL
            THEN :NEW.utc_offset_seconds := :OLD.utc_offset_seconds;
        END IF;
        IF :NEW.timezone IS NULL
            THEN :NEW.timezone := :OLD.timezone;
        END IF;
        IF :NEW.timezone_abbreviation IS NULL
            THEN :NEW.timezone_abbreviation := :OLD.timezone_abbreviation;
        END IF;
    END;


CREATE OR REPLACE PROCEDURE a_delete_location(loc_name VARCHAR) IS
    BEGIN
        DELETE FROM a_locations WHERE location_name = loc_name;
    END;


CREATE OR REPLACE PROCEDURE a_create_daily(loc_name VARCHAR, rec_date DATE) IS
    v_weathercode a_daily_data.weathercode%TYPE;
    v_temp_max a_daily_data.temperature_max%TYPE;
    v_temp_min a_daily_data.temperature_min%TYPE;
    v_rain_sum a_daily_data.rain_sum%TYPE;
    v_snowfall_sum a_daily_data.snowfall_sum%TYPE;
    v_windspeed_max a_daily_data.windspeed_max%TYPE;
    v_winddir_dom a_daily_data.winddirection_dominant%TYPE;
    BEGIN
        SELECT MAX(weathercode), MAX(temperature), MIN(temperature), SUM(rain),
                SUM(snowfall), MAX(wind_speed), AVG(wind_direction)
        INTO v_weathercode, v_temp_max, v_temp_min, v_rain_sum,
                v_snowfall_sum, v_windspeed_max, v_winddir_dom
        FROM a_hourly_data
        WHERE location = loc_name AND record_date = rec_date;
        INSERT INTO a_daily_data VALUES(loc_name, rec_date, v_weathercode,
                    v_temp_max, v_temp_min, v_rain_sum, v_snowfall_sum,
                    v_windspeed_max, v_winddir_dom);
    END;


CREATE OR REPLACE PROCEDURE a_update_daily(loc_name VARCHAR, rec_date DATE) IS
    v_weathercode a_daily_data.weathercode%TYPE;
    v_temp_max a_daily_data.temperature_max%TYPE;
    v_temp_min a_daily_data.temperature_min%TYPE;
    v_rain_sum a_daily_data.rain_sum%TYPE;
    v_snowfall_sum a_daily_data.snowfall_sum%TYPE;
    v_windspeed_max a_daily_data.windspeed_max%TYPE;
    v_winddir_dom a_daily_data.winddirection_dominant%TYPE;
    BEGIN
        SELECT MAX(weathercode), MAX(temperature), MIN(temperature), SUM(rain),
                SUM(snowfall), MAX(wind_speed), AVG(wind_direction)
        INTO v_weathercode, v_temp_max, v_temp_min, v_rain_sum,
                v_snowfall_sum, v_windspeed_max, v_winddir_dom
        FROM a_hourly_data
        WHERE location = loc_name AND record_date = rec_date;
        UPDATE a_daily_data SET
            weathercode = v_weathercode,
            temperature_max = v_temp_max,
            temperature_min = v_temp_min,
            rain_sum = v_rain_sum,
            snowfall_sum = v_snowfall_sum,
            windspeed_max = v_windspeed_max,
            winddirection_dominant = v_winddir_dom
        WHERE location = loc_name AND record_date = rec_date;
    END;


CREATE OR REPLACE PROCEDURE a_delete_daily(loc_name VARCHAR, rec_date DATE) IS
    BEGIN
        DELETE FROM a_daily_data
        WHERE location = loc_name AND record_date = rec_date;
    END;


CREATE OR REPLACE PROCEDURE a_create_hourly(
        loc_name VARCHAR, rec_date DATE, rec_time NUMBER, temp NUMBER DEFAULT 0,
        rel_humid NUMBER DEFAULT 80, rec_rain NUMBER DEFAULT 0,
        snow NUMBER DEFAULT 0, wcode NUMBER DEFAULT 0,
        windspeed NUMBER DEFAULT 15, wind_dir NUMBER DEFAULT 200) IS
    BEGIN
        INSERT INTO a_hourly_data VALUES(loc_name, rec_date, rec_time,
            temp, rel_humid, rec_rain, snow, wcode, windspeed, wind_dir);
    END;


CREATE OR REPLACE PROCEDURE a_update_hourly(
        loc_name VARCHAR, rec_date DATE, rec_time NUMBER,
        temp NUMBER DEFAULT NULL, rel_humid NUMBER DEFAULT NULL,
        rec_rain NUMBER DEFAULT NULL, snow NUMBER DEFAULT NULL,
        wcode NUMBER DEFAULT NULL, windspeed NUMBER DEFAULT NULL,
        wind_dir NUMBER DEFAULT NULL) IS
    error_number error_log.error_number%TYPE;
    error_info error_log.error_msg%TYPE;
    no_data_updated EXCEPTION;
    BEGIN
        UPDATE a_hourly_data SET
            temperature = temp,
            relative_humidity = rel_humid,
            rain = rec_rain,
            snowfall = snow,
            weathercode = wcode,
            wind_speed = windspeed,
            wind_direction = wind_dir
        WHERE location = loc_name
            AND record_date = rec_date
            AND record_time = rec_time;
        IF SQL%NOTFOUND THEN RAISE no_data_updated;
        END IF;
        EXCEPTION
            WHEN no_data_updated THEN
            error_number := SQLCODE;
            error_info := SQLERRM;
            DBMS_OUTPUT.PUT_LINE('Error ' || error_number || ' - ' || error_info);
    END;


CREATE OR REPLACE TRIGGER a_update_hourly_trig
    BEFORE UPDATE ON a_hourly_data
    FOR EACH ROW
    BEGIN
        IF :NEW.temperature IS NULL
            THEN :NEW.temperature := :OLD.temperature;
        END IF;
        IF :NEW.relative_humidity IS NULL
            THEN :NEW.relative_humidity := :OLD.relative_humidity;
        END IF;
        IF :NEW.rain IS NULL
            THEN :NEW.rain := :OLD.rain;
        END IF;
        IF :NEW.snowfall IS NULL
            THEN :NEW.snowfall := :OLD.snowfall;
        END IF;
        IF :NEW.weathercode IS NULL
            THEN :NEW.weathercode := :OLD.weathercode;
        END IF;
        IF :NEW.wind_speed IS NULL
            THEN :NEW.wind_speed := :OLD.wind_speed;
        END IF;
        IF :NEW.wind_direction iS NULL
            THEN :NEW.wind_direction := :OLD.wind_direction;
        END IF;
    END;


CREATE OR REPLACE PROCEDURE a_delete_hourly(
        loc_name VARCHAR, rec_date DATE, rec_time NUMBER) IS
    BEGIN
        DELETE FROM a_hourly_data
        WHERE location = loc_name
            AND record_date = rec_date
            AND record_time = rec_time;
    END;


CREATE TABLE a_archive_locations(archived_on DATE, location_name VARCHAR(20),
    latitude FLOAT, longitude FLOAT, elevation FLOAT, utc_offset_seconds INT,
    timezone VARCHAR(20), timezone_abbreviation VARCHAR(20));


CREATE TABLE a_archive_daily(archived_on DATE, location VARCHAR(20),
    record_date DATE, weathercode INT, temperature_max FLOAT,
    temperature_min FLOAT, rain_sum FLOAT, snowfall_sum FLOAT,
    windspeed_max FLOAT, winddirection_dominant INT);


CREATE TABLE a_archive_hourly(archived_on DATE, location VARCHAR(20),
    record_date DATE, record_time INT, temperature FLOAT, relative_humidity INT,
    rain FLOAT, snowfall FLOAT, weathercode INT, wind_speed FLOAT,
    wind_direction INT);


CREATE OR REPLACE TRIGGER a_delete_loc_trig
    AFTER DELETE ON a_locations
    FOR EACH ROW
    BEGIN
        INSERT INTO a_archive_locations VALUES(CURRENT_DATE, :OLD.location_name,
            :OLD.latitude, :OLD.longitude, :OLD.elevation,
            :OLD.utc_offset_seconds, :OLD.timezone, :OLD.timezone_abbreviation);
    END;


CREATE OR REPLACE TRIGGER a_delete_daily_trig
    AFTER DELETE ON a_daily_data
    FOR EACH ROW
    BEGIN
        INSERT INTO a_archive_daily VALUES(CURRENT_DATE, :OLD.location,
            :OLD.record_date, :OLD.weathercode, :OLD.temperature_max,
            :OLD.temperature_min, :OLD.rain_sum, :OLD.snowfall_sum,
            :OLD.windspeed_max, :OLD.winddirection_dominant);
    END;


CREATE OR REPLACE TRIGGER a_delete_hourly_trig
    AFTER DELETE ON a_hourly_data
    FOR EACH ROW
    BEGIN
        INSERT INTO a_archive_hourly VALUES(CURRENT_DATE, :OLD.location,
            :OLD.record_date, :OLD.record_time, :OLD.temperature,
            :OLD.relative_humidity, :OLD.rain, :OLD.snowfall, :OLD.weathercode,
            :OLD.wind_speed, :OLD.wind_direction);
    END;


CREATE TABLE a_logs(action_time TIMESTAMP, user_name VARCHAR(50),
    table_name VARCHAR(30), action_type VARCHAR(20));


CREATE OR REPLACE TRIGGER a_log_locations_trig
    AFTER INSERT OR UPDATE OR DELETE ON a_locations
    BEGIN
        IF INSERTING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_locations', 'INSERT');
        ELSIF UPDATING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_locations', 'UPDATE');
        ELSIF DELETING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_locations', 'DELETE');
        END IF;
    END;


CREATE OR REPLACE TRIGGER a_log_daily_trig
    AFTER INSERT OR UPDATE OR DELETE ON a_daily_data
    BEGIN
        IF INSERTING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_daily_data', 'INSERT');
        ELSIF UPDATING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_daily_data', 'UPDATE');
        ELSIF DELETING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_daily_data', 'DELETE');
        END IF;
    END;


CREATE OR REPLACE TRIGGER a_log_hourly_trig
    AFTER INSERT OR UPDATE OR DELETE ON a_hourly_data
    BEGIN
        IF INSERTING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_hourly_data', 'INSERT');
        ELSIF UPDATING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_hourly_data', 'UPDATE');
        ELSIF DELETING THEN INSERT INTO a_logs
            VALUES(CURRENT_TIMESTAMP, USER, 'a_hourly_data', 'DELETE');
        END IF;
    END;