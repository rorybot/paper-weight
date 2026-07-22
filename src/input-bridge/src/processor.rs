use std::collections::BTreeMap;

use crate::{
    device::{DeviceId, DeviceUpdate},
    event::InputEvent,
    reducer::{reduce, Bindings, RawInput, State},
};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct InputProcessor {
    states: BTreeMap<DeviceId, State>,
    next_tick_ms: u64,
    tick_interval_ms: u64,
}

impl InputProcessor {
    #[must_use]
    pub fn new(started_ms: u64, tick_interval_ms: u64) -> Self {
        assert!(tick_interval_ms > 0, "tick interval must be non-zero");
        Self {
            states: BTreeMap::new(),
            next_tick_ms: started_ms.saturating_add(tick_interval_ms),
            tick_interval_ms,
        }
    }

    #[must_use]
    pub fn milliseconds_until_tick(&self, now_ms: u64) -> u64 {
        self.next_tick_ms.saturating_sub(now_ms)
    }

    pub fn process(
        &mut self,
        update: Option<DeviceUpdate>,
        now_ms: u64,
        bindings: &Bindings,
    ) -> Vec<InputEvent> {
        let mut events = update.map_or_else(Vec::new, |update| self.apply(update, bindings));

        if now_ms >= self.next_tick_ms {
            events.extend(self.tick(now_ms, bindings));
            let elapsed_intervals =
                now_ms.saturating_sub(self.next_tick_ms) / self.tick_interval_ms;
            self.next_tick_ms = self
                .next_tick_ms
                .saturating_add((elapsed_intervals + 1).saturating_mul(self.tick_interval_ms));
        }

        events
    }

    fn apply(&mut self, update: DeviceUpdate, bindings: &Bindings) -> Vec<InputEvent> {
        match update {
            DeviceUpdate::Input { device, raw } => {
                let transition = reduce(
                    self.states.remove(&device).unwrap_or_default(),
                    raw,
                    bindings,
                );
                self.states.insert(device, transition.state);
                transition.events
            }
            DeviceUpdate::Reset { device } => {
                self.states.remove(&device);
                Vec::new()
            }
        }
    }

    fn tick(&mut self, at_ms: u64, bindings: &Bindings) -> Vec<InputEvent> {
        let mut events = Vec::new();
        for state in self.states.values_mut() {
            let transition = reduce(std::mem::take(state), RawInput::Tick { at_ms }, bindings);
            *state = transition.state;
            events.extend(transition.events);
        }
        events
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::InputProcessor;
    use crate::{
        device::{DeviceId, DeviceUpdate},
        event::InputEvent,
        reducer::{Action, Bindings, HoldAction, KeyState, RawInput},
    };

    fn bindings() -> Bindings {
        Bindings {
            wheel_relative_code: 8,
            keys: BTreeMap::from([(2, Action::Preset(1)), (14, Action::Back)]),
            hold_actions: BTreeMap::from([(
                2,
                HoldAction {
                    hold_ms: 650,
                    event: InputEvent::Home,
                },
            )]),
            debounce_ms: 25,
        }
    }

    fn key(device: usize, code: u16, state: KeyState, at_ms: u64) -> DeviceUpdate {
        DeviceUpdate::Input {
            device: DeviceId(device),
            raw: RawInput::Key { code, state, at_ms },
        }
    }

    #[test]
    fn resetting_one_device_preserves_a_held_key_owned_by_another() {
        let mut processor = InputProcessor::new(0, 10);
        let bindings = bindings();

        assert!(processor
            .process(Some(key(1, 2, KeyState::Pressed, 0)), 0, &bindings)
            .is_empty());
        assert!(processor
            .process(Some(key(2, 2, KeyState::Pressed, 0)), 0, &bindings)
            .is_empty());
        assert!(processor
            .process(
                Some(DeviceUpdate::Reset {
                    device: DeviceId(2),
                }),
                640,
                &bindings,
            )
            .is_empty());

        assert_eq!(processor.process(None, 650, &bindings), [InputEvent::Home]);
        assert!(processor
            .process(Some(key(1, 2, KeyState::Released, 700)), 700, &bindings,)
            .is_empty());
    }

    #[test]
    fn continuous_unrelated_input_does_not_starve_home_hold_deadline() {
        let mut processor = InputProcessor::new(0, 10);
        let bindings = bindings();

        processor.process(Some(key(1, 2, KeyState::Pressed, 0)), 0, &bindings);

        let events = (1..=65).flat_map(|step| {
            let at_ms = step * 10;
            processor.process(Some(key(2, 14, KeyState::Repeat, at_ms)), at_ms, &bindings)
        });

        assert_eq!(events.collect::<Vec<_>>(), [InputEvent::Home]);
    }
}
