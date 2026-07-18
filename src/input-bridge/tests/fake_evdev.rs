use std::collections::{BTreeMap, BTreeSet};

use paper_weight_input_bridge::{
    event::InputEvent,
    reducer::{Action, Bindings, KeyState, RawInput, State, reduce_all},
};

const WHEEL_REL: u16 = 8;
const WHEEL_PRESS: u16 = 28;
const PRESET_1: u16 = 2;
const PRESET_2: u16 = 3;
const PRESET_3: u16 = 4;
const PRESET_4: u16 = 5;
const BACK: u16 = 14;

fn bindings(hold_ms: u64) -> Bindings {
    Bindings {
        wheel_relative_code: WHEEL_REL,
        keys: BTreeMap::from([
            (WHEEL_PRESS, Action::WheelPress),
            (PRESET_1, Action::Preset(1)),
            (PRESET_2, Action::Preset(2)),
            (PRESET_3, Action::Preset(3)),
            (PRESET_4, Action::Preset(4)),
            (BACK, Action::Back),
        ]),
        home_hold_codes: BTreeSet::from([PRESET_1, PRESET_2, PRESET_3, PRESET_4]),
        hold_ms,
        debounce_ms: 30,
    }
}

fn key(code: u16, state: KeyState, at_ms: u64) -> RawInput {
    RawInput::Key { code, state, at_ms }
}

#[test]
fn fake_evdev_feed_produces_the_exact_versioned_event_stream() {
    let feed = [
        RawInput::Relative {
            code: WHEEL_REL,
            value: -2,
            at_ms: 0,
        },
        key(WHEEL_PRESS, KeyState::Pressed, 10),
        key(WHEEL_PRESS, KeyState::Repeat, 30),
        key(WHEEL_PRESS, KeyState::Released, 80),
        key(PRESET_1, KeyState::Pressed, 100),
        key(PRESET_1, KeyState::Released, 180),
        key(PRESET_2, KeyState::Pressed, 200),
        RawInput::Tick { at_ms: 850 },
        key(PRESET_2, KeyState::Released, 870),
        key(BACK, KeyState::Pressed, 900),
        key(BACK, KeyState::Released, 950),
    ];

    let output = reduce_all(State::default(), feed, &bindings(650));
    let json = output
        .events
        .iter()
        .map(InputEvent::to_json)
        .collect::<Vec<_>>();

    assert_eq!(
        json,
        [
            r#"{"v":1,"type":"wheel","ticks":-2}"#,
            r#"{"v":1,"type":"wheel_press"}"#,
            r#"{"v":1,"type":"preset","number":1}"#,
            r#"{"v":1,"type":"home"}"#,
            r#"{"v":1,"type":"back"}"#,
        ]
    );
}

#[test]
fn configurable_hold_threshold_changes_short_press_vs_home() {
    let feed = [
        key(PRESET_3, KeyState::Pressed, 0),
        RawInput::Tick { at_ms: 400 },
        key(PRESET_3, KeyState::Released, 410),
    ];

    let short_threshold = reduce_all(State::default(), feed, &bindings(300));
    let long_threshold = reduce_all(State::default(), feed, &bindings(700));

    assert_eq!(short_threshold.events, [InputEvent::Home]);
    assert_eq!(long_threshold.events, [InputEvent::Preset { number: 3 }]);
}

#[test]
fn every_preset_short_press_keeps_its_configured_number() {
    let feed = [
        key(PRESET_1, KeyState::Pressed, 0),
        key(PRESET_1, KeyState::Released, 40),
        key(PRESET_2, KeyState::Pressed, 100),
        key(PRESET_2, KeyState::Released, 140),
        key(PRESET_3, KeyState::Pressed, 200),
        key(PRESET_3, KeyState::Released, 240),
        key(PRESET_4, KeyState::Pressed, 300),
        key(PRESET_4, KeyState::Released, 340),
    ];

    let output = reduce_all(State::default(), feed, &bindings(650));

    assert_eq!(
        output.events,
        [
            InputEvent::Preset { number: 1 },
            InputEvent::Preset { number: 2 },
            InputEvent::Preset { number: 3 },
            InputEvent::Preset { number: 4 },
        ]
    );
}

#[test]
fn duplicate_press_repeat_and_electrical_bounce_do_not_duplicate_actions() {
    let feed = [
        key(PRESET_4, KeyState::Pressed, 0),
        key(PRESET_4, KeyState::Pressed, 1),
        key(PRESET_4, KeyState::Repeat, 10),
        key(PRESET_4, KeyState::Released, 20),
        key(PRESET_4, KeyState::Released, 21),
    ];

    let output = reduce_all(State::default(), feed, &bindings(650));

    assert!(output.events.is_empty());
}
