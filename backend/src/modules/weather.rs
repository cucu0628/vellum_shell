//! Idojaras az Open-Meteo API-bol.
//!
//! Ez valtja ki a harom `curl` processzt (hely, geokodolas, elorejelzes), amit
//! a QML minden panelnyitaskor ujra elinditott. Itt egy HTTP kliens marad
//! nyitva, a geokodolas es az elorejelzes is gyorsitotarazva van.
//!
//! A megjelenitesi formazas (fokjel, "Feels like ...", "8 km/h") szandekosan
//! itt tortenik: a QML oldal igy tiszta binding marad, es a formatum egy helyen
//! van -- pontosan ugy, ahogy korabban a controllerben volt.

use crate::module::{Module, ModuleDescription, StateSink};
use crate::theme::paths;
use anyhow::{Context, Result};
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;

/// Ennyi ideig nem kerdezzuk ujra az API-t. Az idojaras nem valtozik percenkent,
/// es a korabbi valtozat minden panelnyitaskor ujra lekerte.
const REFRESH_EVERY: Duration = Duration::from_secs(15 * 60);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(6);

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct WeatherState {
    pub location: String,
    pub temp: String,
    pub feels: String,
    pub description: String,
    pub humidity: String,
    pub wind: String,
    pub pressure: String,
    pub precip: String,
    pub sunrise: String,
    pub sunset: String,
    pub forecast: Vec<ForecastDay>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct ForecastDay {
    pub day: String,
    pub icon: String,
    pub temp: String,
}

#[derive(Default)]
struct Cache {
    /// Hely -> koordinatak. A geokodolas eredmenye nem valtozik.
    coordinates: Option<(String, f64, f64)>,
    state: Option<WeatherState>,
}

pub struct Weather {
    client: reqwest::Client,
    cache: Mutex<Cache>,
}

impl Weather {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::builder()
                .timeout(REQUEST_TIMEOUT)
                .user_agent("vellum-shell")
                .build()
                .unwrap_or_default(),
            cache: Mutex::new(Cache::default()),
        }
    }
}

#[async_trait]
impl Module for Weather {
    fn name(&self) -> &'static str {
        "weather"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "weather",
            summary: "Aktualis idojaras es otnapos elorejelzes az Open-Meteo API-bol.",
            streams: true,
            methods: Vec::new(),
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        loop {
            // Ha a lekeres nem sikerul (nincs halozat), a korabbi allapotot
            // tartjuk meg: jobb egy kicsit regi ertek, mint egy ures panel.
            match self.refresh().await {
                Ok(state) => sink.push(json!(state)),
                Err(err) => {
                    tracing::warn!(error = format!("{err:#}"), "az idojaras nem frissitheto");
                    let cache = self.cache.lock().await;
                    if let Some(state) = cache.state.clone() {
                        sink.push(json!(state));
                    }
                }
            }

            tokio::time::sleep(REFRESH_EVERY).await;
        }
    }
}

impl Weather {
    async fn refresh(&self) -> Result<WeatherState> {
        let location = configured_location();
        let (latitude, longitude) = self.coordinates_for(&location).await?;

        let forecast: Forecast = self
            .client
            .get("https://api.open-meteo.com/v1/forecast")
            .query(&[
                ("latitude", latitude.to_string().as_str()),
                ("longitude", longitude.to_string().as_str()),
                (
                    "current",
                    "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,surface_pressure,wind_speed_10m",
                ),
                (
                    "daily",
                    "sunrise,sunset,temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max",
                ),
                ("timezone", "auto"),
                ("forecast_days", "5"),
            ])
            .send()
            .await
            .context("az elorejelzes nem kerheto le")?
            .error_for_status()?
            .json()
            .await
            .context("az elorejelzes valasza nem ertelmezheto")?;

        let state = build_state(&location, &forecast);
        self.cache.lock().await.state = Some(state.clone());
        Ok(state)
    }

    /// A geokodolas eredmenyet megtartjuk: ugyanahhoz a helyhez nem kerdezzuk
    /// meg ujra.
    async fn coordinates_for(&self, location: &str) -> Result<(f64, f64)> {
        // A koordinatak kozvetlenul is megadhatok, ilyenkor nincs geokodolas.
        if let Some(coordinates) = coordinates_from_env() {
            return Ok(coordinates);
        }

        {
            let cache = self.cache.lock().await;
            if let Some((cached, latitude, longitude)) = &cache.coordinates
                && cached == location
            {
                return Ok((*latitude, *longitude));
            }
        }

        let response: Geocoding = self
            .client
            .get("https://geocoding-api.open-meteo.com/v1/search")
            .query(&[("name", location), ("count", "1"), ("language", "en"), ("format", "json")])
            .send()
            .await
            .context("a geokodolas nem kerheto le")?
            .error_for_status()?
            .json()
            .await
            .context("a geokodolas valasza nem ertelmezheto")?;

        let place = response
            .results
            .into_iter()
            .next()
            .with_context(|| format!("ismeretlen hely: {location}"))?;

        self.cache.lock().await.coordinates =
            Some((location.to_string(), place.latitude, place.longitude));
        Ok((place.latitude, place.longitude))
    }
}

fn configured_location() -> String {
    if let Some(value) = std::env::var_os("WEATHER_LOCATION")
        && !value.is_empty()
    {
        return value.to_string_lossy().to_string();
    }
    paths::read_line_file(&paths::shell_dir().join("current-weather-location"))
        .unwrap_or_else(|| "Budapest".to_string())
}

fn coordinates_from_env() -> Option<(f64, f64)> {
    let value = std::env::var("WEATHER_COORDS").ok()?;
    let (latitude, longitude) = value.split_once(',')?;
    Some((latitude.trim().parse().ok()?, longitude.trim().parse().ok()?))
}

#[derive(Debug, Deserialize)]
struct Geocoding {
    #[serde(default)]
    results: Vec<Place>,
}

#[derive(Debug, Deserialize)]
struct Place {
    latitude: f64,
    longitude: f64,
}

#[derive(Debug, Default, Deserialize)]
struct Forecast {
    #[serde(default)]
    current: Current,
    #[serde(default)]
    daily: Daily,
}

#[derive(Debug, Default, Deserialize)]
struct Current {
    #[serde(default)]
    temperature_2m: f64,
    #[serde(default)]
    relative_humidity_2m: f64,
    #[serde(default)]
    apparent_temperature: Option<f64>,
    #[serde(default)]
    weather_code: i64,
    #[serde(default)]
    surface_pressure: f64,
    #[serde(default)]
    wind_speed_10m: f64,
}

#[derive(Debug, Default, Deserialize)]
struct Daily {
    #[serde(default)]
    time: Vec<String>,
    #[serde(default)]
    sunrise: Vec<String>,
    #[serde(default)]
    sunset: Vec<String>,
    #[serde(default)]
    temperature_2m_max: Vec<f64>,
    #[serde(default)]
    temperature_2m_min: Vec<f64>,
    #[serde(default)]
    weather_code: Vec<i64>,
    #[serde(default)]
    precipitation_probability_max: Vec<f64>,
}

fn build_state(location: &str, forecast: &Forecast) -> WeatherState {
    let current = &forecast.current;
    let daily = &forecast.daily;

    let days = (0..daily.time.len().min(5))
        .map(|index| ForecastDay {
            day: if index == 0 {
                "Today".to_string()
            } else {
                // "2026-08-29" -> "08-29", ahogy korabban is.
                daily.time[index].chars().skip(5).collect()
            },
            icon: weather_icon(weather_condition(
                daily.weather_code.get(index).copied().unwrap_or(0),
            ))
            .to_string(),
            temp: format!(
                "{}°/{}°",
                round(daily.temperature_2m_min.get(index).copied().unwrap_or(0.0)),
                round(daily.temperature_2m_max.get(index).copied().unwrap_or(0.0))
            ),
        })
        .collect();

    WeatherState {
        location: location.to_string(),
        temp: format!("{}°", round(current.temperature_2m)),
        feels: format!(
            "Feels like {}°",
            round(current.apparent_temperature.unwrap_or(current.temperature_2m))
        ),
        description: weather_condition(current.weather_code).to_string(),
        humidity: format!("{}%", round(current.relative_humidity_2m)),
        wind: format!("{} km/h", round(current.wind_speed_10m)),
        pressure: format!("{} hPa", round(current.surface_pressure)),
        precip: format!(
            "{}%",
            round(daily.precipitation_probability_max.first().copied().unwrap_or(0.0))
        ),
        sunrise: clock(daily.sunrise.first()),
        sunset: clock(daily.sunset.first()),
        forecast: days,
    }
}

fn round(value: f64) -> i64 {
    value.round() as i64
}

/// Az Open-Meteo `timezone=auto` mellett mar helyi idot ad
/// ("2026-08-29T05:12"), igy eleg a T utani ora:perc.
fn clock(value: Option<&String>) -> String {
    value
        .and_then(|value| value.split_once('T'))
        .map(|(_, time)| time.chars().take(5).collect())
        .unwrap_or_else(|| "--:--".to_string())
}

/// WMO idojaras-kodok. Ugyanaz a lekepezes, ami a QML-ben volt.
fn weather_condition(code: i64) -> &'static str {
    match code {
        0 => "Sunny",
        1 | 2 => "Partly Cloudy",
        3 => "Cloudy",
        45 | 48 => "Fog",
        51..=67 => "Drizzle",
        71..=77 => "Snow",
        80..=82 => "Rain Showers",
        code if code >= 95 => "Thunderstorm",
        _ => "Weather",
    }
}

fn weather_icon(condition: &str) -> &'static str {
    let lower = condition.to_lowercase();
    if lower.contains("rain") || lower.contains("shower") {
        "☂"
    } else if lower.contains("cloud") || lower.contains("overcast") {
        "☁"
    } else if lower.contains("snow") {
        "❄"
    } else if lower.contains("storm") || lower.contains("thunder") {
        "ϟ"
    } else {
        "☼"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn condition_mapping_matches_previous_behaviour() {
        assert_eq!(weather_condition(0), "Sunny");
        assert_eq!(weather_condition(2), "Partly Cloudy");
        assert_eq!(weather_condition(3), "Cloudy");
        assert_eq!(weather_condition(48), "Fog");
        assert_eq!(weather_condition(61), "Drizzle");
        assert_eq!(weather_condition(75), "Snow");
        assert_eq!(weather_condition(81), "Rain Showers");
        assert_eq!(weather_condition(99), "Thunderstorm");
        assert_eq!(weather_condition(-1), "Weather");
    }

    /// A korabbi QML a 61..65 kodokat "Rain"-nek szanta, de a 51..67 ag
    /// hamarabb illeszkedett, ezert azok is "Drizzle"-t adtak. A viselkedest
    /// szandekosan megtartjuk, hogy a kijelzes ne valtozzon.
    #[test]
    fn rain_codes_stay_drizzle_as_before() {
        assert_eq!(weather_condition(63), "Drizzle");
    }

    /// MEGORZOTT FURCSASAG: a 61-es kod "Drizzle"-t ad, az ikonvalaszto viszont
    /// csak a "rain"/"shower" szavakra figyel -- igy a szitalas NAPOS ikont kap.
    /// A korabbi QML pontosan igy mukodott; szandekosan nem javitjuk, mert az
    /// eszrevetlenul valtoztatna a kijelzest.
    #[test]
    fn drizzle_keeps_the_sunny_icon_quirk() {
        assert_eq!(weather_icon(weather_condition(61)), "☼");
        // Az esos zapor viszont helyesen kap ernyot.
        assert_eq!(weather_icon(weather_condition(81)), "☂");
    }

    #[test]
    fn icons_follow_the_condition_text() {
        assert_eq!(weather_icon("Rain Showers"), "☂");
        assert_eq!(weather_icon("Cloudy"), "☁");
        assert_eq!(weather_icon("Snow"), "❄");
        assert_eq!(weather_icon("Thunderstorm"), "ϟ");
        assert_eq!(weather_icon("Sunny"), "☼");
    }

    #[test]
    fn clock_takes_local_time_from_iso() {
        assert_eq!(clock(Some(&"2026-08-29T05:12".to_string())), "05:12");
        assert_eq!(clock(None), "--:--");
        assert_eq!(clock(Some(&"szemet".to_string())), "--:--");
    }

    #[test]
    fn state_is_formatted_for_display() {
        let forecast = Forecast {
            current: Current {
                temperature_2m: 32.6,
                relative_humidity_2m: 27.4,
                apparent_temperature: Some(33.2),
                weather_code: 0,
                surface_pressure: 991.8,
                wind_speed_10m: 8.3,
            },
            daily: Daily {
                time: vec!["2026-08-29".into(), "2026-08-30".into()],
                sunrise: vec!["2026-08-29T04:53".into()],
                sunset: vec!["2026-08-29T20:47".into()],
                temperature_2m_max: vec![33.4, 35.1],
                temperature_2m_min: vec![18.2, 18.9],
                weather_code: vec![0, 61],
                precipitation_probability_max: vec![0.0],
            },
        };

        let state = build_state("Budapest", &forecast);
        assert_eq!(state.temp, "33°");
        assert_eq!(state.feels, "Feels like 33°");
        assert_eq!(state.humidity, "27%");
        assert_eq!(state.wind, "8 km/h");
        assert_eq!(state.pressure, "992 hPa");
        assert_eq!(state.precip, "0%");
        assert_eq!(state.sunrise, "04:53");
        assert_eq!(state.sunset, "20:47");

        assert_eq!(state.forecast.len(), 2);
        assert_eq!(state.forecast[0].day, "Today");
        assert_eq!(state.forecast[0].temp, "18°/33°");
        assert_eq!(state.forecast[0].icon, "☼");
        // A masodik nap datuma "MM-DD" alakban.
        assert_eq!(state.forecast[1].day, "08-30");
    }

    #[test]
    fn missing_daily_arrays_do_not_panic() {
        let state = build_state("Sehol", &Forecast::default());
        assert_eq!(state.temp, "0°");
        assert!(state.forecast.is_empty());
        assert_eq!(state.sunrise, "--:--");
    }
}
