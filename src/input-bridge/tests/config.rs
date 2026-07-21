use std::path::PathBuf;

use paper_weight_input_bridge::{config::parse_config, event::InputEvent};

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

    assert_eq!(config.devices, [PathBuf::from("/dev/input/event0")]);
    assert!(config.listen.ip().is_loopback());
    let home_holds = config
        .bindings
        .hold_actions
        .values()
        .filter(|hold| hold.event == InputEvent::Home)
        .count();
    assert_eq!(home_holds, 4);
    assert_eq!(config.bindings.hold_actions[&2].hold_ms, 650);
    assert_eq!(config.bindings.hold_actions[&2].event, InputEvent::Home);
    assert_eq!(config.bindings.hold_actions[&28].hold_ms, 3000);
    assert_eq!(
        config.bindings.hold_actions[&28].event,
        InputEvent::WheelLongPress
    );
}

#[test]
fn parses_multiple_input_devices() {
    let config = parse_config(&CONFIG.replace(
        "device=/dev/input/event0",
        "devices=/dev/input/event0,/dev/input/event1",
    ))
    .unwrap();

    assert_eq!(
        config.devices,
        [
            PathBuf::from("/dev/input/event0"),
            PathBuf::from("/dev/input/event1")
        ]
    );
}

#[test]
fn rejects_ambiguous_device_configuration() {
    let error = parse_config(&CONFIG.replace(
        "device=/dev/input/event0",
        "device=/dev/input/event0\ndevices=/dev/input/event0,/dev/input/event1",
    ))
    .unwrap_err();

    assert_eq!(error, "configure either device or devices, not both");
}

#[test]
fn rejects_duplicate_input_devices() {
    let error = parse_config(&CONFIG.replace(
        "device=/dev/input/event0",
        "devices=/dev/input/event0,/dev/input/event0",
    ))
    .unwrap_err();

    assert_eq!(error, "devices contains a duplicate path");
}

#[test]
fn permits_a_configured_hold_capable_button() {
    let config = parse_config(&CONFIG.replace("home_hold=2,3,4,5", "home_hold=14")).unwrap();

    assert_eq!(
        config
            .bindings
            .hold_actions
            .into_iter()
            .filter(|(_, hold)| hold.event == InputEvent::Home)
            .map(|(code, _)| code)
            .collect::<Vec<_>>(),
        [14]
    );
}

#[test]
fn rejects_a_hold_code_colliding_with_the_wheel_press_button() {
    let error = parse_config(&CONFIG.replace("home_hold=2,3,4,5", "home_hold=28")).unwrap_err();

    assert_eq!(error, "key code 28 has conflicting hold bindings");
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
