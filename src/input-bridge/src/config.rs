use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    net::SocketAddr,
    path::{Path, PathBuf},
};

use crate::reducer::{Action, Bindings};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BridgeConfig {
    pub devices: Vec<PathBuf>,
    pub listen: SocketAddr,
    pub bindings: Bindings,
}

impl BridgeConfig {
    pub fn from_file(path: impl AsRef<Path>) -> Result<Self, String> {
        let path = path.as_ref();
        let contents = fs::read_to_string(path)
            .map_err(|error| format!("could not read {}: {error}", path.display()))?;
        parse_config(&contents)
    }
}

pub fn parse_config(contents: &str) -> Result<BridgeConfig, String> {
    let values = parse_values(contents)?;
    let devices = parse_devices(&values)?;
    let listen = values
        .get("listen")
        .map(String::as_str)
        .unwrap_or("127.0.0.1:9137")
        .parse::<SocketAddr>()
        .map_err(|error| format!("invalid listen address: {error}"))?;
    if !listen.ip().is_loopback() {
        return Err("listen must use a loopback address".into());
    }

    let hold_ms = parse_optional_u64(&values, "hold_ms", 650)?;
    let debounce_ms = parse_optional_u64(&values, "debounce_ms", 30)?;
    if hold_ms <= debounce_ms {
        return Err("hold_ms must be greater than debounce_ms".into());
    }

    let wheel_relative_code = parse_required_u16(&values, "wheel_relative")?;
    let key_specs = [
        ("wheel_press", Action::WheelPress),
        ("preset_1", Action::Preset(1)),
        ("preset_2", Action::Preset(2)),
        ("preset_3", Action::Preset(3)),
        ("preset_4", Action::Preset(4)),
        ("back", Action::Back),
    ];

    let mut keys = BTreeMap::new();
    let mut preset_codes = BTreeSet::new();
    for (name, action) in key_specs {
        let code = parse_required_u16(&values, name)?;
        if keys.insert(code, action).is_some() {
            return Err(format!("duplicate key code {code}"));
        }
        if matches!(action, Action::Preset(_)) {
            preset_codes.insert(code);
        }
    }

    let home_hold_codes = match values.get("home_hold") {
        Some(value) => parse_hold_codes(value, &keys)?,
        None => preset_codes,
    };

    Ok(BridgeConfig {
        devices,
        listen,
        bindings: Bindings {
            wheel_relative_code,
            keys,
            home_hold_codes,
            hold_ms,
            debounce_ms,
        },
    })
}

fn parse_devices(values: &BTreeMap<String, String>) -> Result<Vec<PathBuf>, String> {
    match (values.get("device"), values.get("devices")) {
        (Some(_), Some(_)) => Err("configure either device or devices, not both".into()),
        (Some(device), None) => Ok(vec![PathBuf::from(device)]),
        (None, Some(devices)) => {
            let parsed = devices
                .split(',')
                .map(str::trim)
                .map(|device| {
                    if device.is_empty() {
                        Err("devices contains an empty path".to_string())
                    } else {
                        Ok(PathBuf::from(device))
                    }
                })
                .collect::<Result<Vec<_>, _>>()?;
            let unique = parsed.iter().collect::<BTreeSet<_>>();
            if unique.len() != parsed.len() {
                return Err("devices contains a duplicate path".into());
            }
            Ok(parsed)
        }
        (None, None) => Err("missing required config key device or devices".into()),
    }
}

fn parse_hold_codes(value: &str, keys: &BTreeMap<u16, Action>) -> Result<BTreeSet<u16>, String> {
    let mut codes = BTreeSet::new();
    for raw_code in value.split(',') {
        let code = raw_code
            .trim()
            .parse::<u16>()
            .map_err(|error| format!("invalid home_hold code: {error}"))?;
        if !keys.contains_key(&code) {
            return Err(format!("home_hold code {code} has no key binding"));
        }
        codes.insert(code);
    }
    if codes.is_empty() {
        return Err("home_hold must contain at least one key code".into());
    }
    Ok(codes)
}

fn parse_values(contents: &str) -> Result<BTreeMap<String, String>, String> {
    contents
        .lines()
        .enumerate()
        .try_fold(BTreeMap::new(), |mut values, (index, line)| {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                return Ok(values);
            }

            let (key, value) = line
                .split_once('=')
                .ok_or_else(|| format!("line {} must be key=value", index + 1))?;
            let key = key.trim().to_string();
            let value = value.trim().to_string();
            if key.is_empty() || value.is_empty() {
                return Err(format!("line {} has an empty key or value", index + 1));
            }
            if values.insert(key.clone(), value).is_some() {
                return Err(format!("duplicate config key {key}"));
            }
            Ok(values)
        })
}

fn required<'a>(values: &'a BTreeMap<String, String>, key: &str) -> Result<&'a str, String> {
    values
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| format!("missing required config key {key}"))
}

fn parse_required_u16(values: &BTreeMap<String, String>, key: &str) -> Result<u16, String> {
    required(values, key)?
        .parse::<u16>()
        .map_err(|error| format!("invalid {key}: {error}"))
}

fn parse_optional_u64(
    values: &BTreeMap<String, String>,
    key: &str,
    default: u64,
) -> Result<u64, String> {
    values.get(key).map_or(Ok(default), |value| {
        value
            .parse::<u64>()
            .map_err(|error| format!("invalid {key}: {error}"))
    })
}
