use paper_weight_input_bridge::config::parse_config;

const CONFIG: &str = r#"
device=/dev/input/event0
listen=127.0.0.1:9137
hold_ms=650
debounce_ms=30
home_hold=2,3,4,5
wheel_relative=8
wheel_press=28
preset_1=2
preset_2=3
preset_3=4
preset_4=5
back=14
"#;

#[test]
fn parses_a_complete_loopback_config() {
    let config = parse_config(CONFIG).unwrap();

    assert_eq!(config.device.to_string_lossy(), "/dev/input/event0");
    assert!(config.listen.ip().is_loopback());
    assert_eq!(config.bindings.hold_ms, 650);
    assert_eq!(config.bindings.home_hold_codes.len(), 4);
}

#[test]
fn permits_a_configured_hold_capable_button() {
    let config = parse_config(&CONFIG.replace("home_hold=2,3,4,5", "home_hold=28")).unwrap();

    assert_eq!(
        config
            .bindings
            .home_hold_codes
            .into_iter()
            .collect::<Vec<_>>(),
        [28]
    );
}

#[test]
fn rejects_a_hold_code_without_an_action_binding() {
    let error = parse_config(&CONFIG.replace("home_hold=2,3,4,5", "home_hold=99")).unwrap_err();

    assert_eq!(error, "home_hold code 99 has no key binding");
}

#[test]
fn rejects_non_loopback_event_servers() {
    let error = parse_config(&CONFIG.replace("127.0.0.1", "0.0.0.0")).unwrap_err();

    assert_eq!(error, "listen must use a loopback address");
}

#[test]
fn rejects_ambiguous_hold_and_debounce_thresholds() {
    let error = parse_config(&CONFIG.replace("hold_ms=650", "hold_ms=20")).unwrap_err();

    assert_eq!(error, "hold_ms must be greater than debounce_ms");
}
