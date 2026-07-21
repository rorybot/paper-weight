use std::collections::BTreeMap;

use crate::event::InputEvent;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Action {
    WheelPress,
    Preset(u8),
    Back,
}

impl Action {
    fn into_event(self) -> InputEvent {
        match self {
            Self::WheelPress => InputEvent::WheelPress,
            Self::Preset(number) => InputEvent::Preset { number },
            Self::Back => InputEvent::Back,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum KeyState {
    Pressed,
    Released,
    Repeat,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RawInput {
    Relative {
        code: u16,
        value: i32,
        at_ms: u64,
    },
    Key {
        code: u16,
        state: KeyState,
        at_ms: u64,
    },
    Tick {
        at_ms: u64,
    },
}

impl RawInput {
    #[must_use]
    pub fn at_ms(self) -> u64 {
        match self {
            Self::Relative { at_ms, .. } | Self::Key { at_ms, .. } | Self::Tick { at_ms } => at_ms,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HoldAction {
    pub hold_ms: u64,
    pub event: InputEvent,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Bindings {
    pub wheel_relative_code: u16,
    pub keys: BTreeMap<u16, Action>,
    pub hold_actions: BTreeMap<u16, HoldAction>,
    pub debounce_ms: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct PressedKey {
    action: Action,
    started_ms: u64,
    hold: Option<HoldAction>,
    long_emitted: bool,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct State {
    pressed: BTreeMap<u16, PressedKey>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Transition {
    pub state: State,
    pub events: Vec<InputEvent>,
}

#[must_use]
pub fn reduce(mut state: State, raw: RawInput, bindings: &Bindings) -> Transition {
    let mut events = Vec::new();

    match raw {
        RawInput::Relative { code, value, .. }
            if code == bindings.wheel_relative_code && value != 0 =>
        {
            events.push(InputEvent::Wheel { ticks: value });
        }
        RawInput::Key {
            code,
            state: KeyState::Pressed,
            at_ms,
        } => {
            if state.pressed.contains_key(&code) {
                return Transition { state, events };
            }

            if let Some(action) = bindings.keys.get(&code).copied() {
                let hold = bindings.hold_actions.get(&code).cloned();
                let has_hold = hold.is_some();
                state.pressed.insert(
                    code,
                    PressedKey {
                        action,
                        started_ms: at_ms,
                        hold,
                        long_emitted: false,
                    },
                );

                if !has_hold {
                    events.push(action.into_event());
                }
            }
        }
        RawInput::Key {
            code,
            state: KeyState::Released,
            at_ms,
        } => {
            if let Some(pressed) = state.pressed.remove(&code) {
                let duration_ms = at_ms.saturating_sub(pressed.started_ms);

                if let Some(hold) = &pressed.hold {
                    if !pressed.long_emitted {
                        if duration_ms >= hold.hold_ms {
                            events.push(hold.event.clone());
                        } else if duration_ms >= bindings.debounce_ms {
                            events.push(pressed.action.into_event());
                        }
                    }
                }
            }
        }
        RawInput::Tick { at_ms } => {
            for pressed in state.pressed.values_mut() {
                let held_ms = at_ms.saturating_sub(pressed.started_ms);
                if let Some(hold) = pressed.hold.clone() {
                    if !pressed.long_emitted && held_ms >= hold.hold_ms {
                        pressed.long_emitted = true;
                        events.push(hold.event);
                    }
                }
            }
        }
        RawInput::Relative { .. }
        | RawInput::Key {
            state: KeyState::Repeat,
            ..
        } => {}
    }

    Transition { state, events }
}

#[must_use]
pub fn reduce_all(
    initial: State,
    raw_events: impl IntoIterator<Item = RawInput>,
    bindings: &Bindings,
) -> Transition {
    raw_events.into_iter().fold(
        Transition {
            state: initial,
            events: Vec::new(),
        },
        |accumulator, raw| {
            let next = reduce(accumulator.state, raw, bindings);
            Transition {
                state: next.state,
                events: accumulator.events.into_iter().chain(next.events).collect(),
            }
        },
    )
}
