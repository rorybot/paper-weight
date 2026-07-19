use std::{
    io::{self, Read},
    ops::ControlFlow,
    time::Duration,
};

use crate::{linux::read_raw_input, reducer::RawInput};

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub struct DeviceId(pub usize);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DeviceUpdate {
    Input { device: DeviceId, raw: RawInput },
    Reset { device: DeviceId },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ReconnectPolicy {
    pub initial_delay: Duration,
    pub max_delay: Duration,
}

impl ReconnectPolicy {
    #[must_use]
    pub fn delay_after(self, consecutive_failures: u32) -> Duration {
        let multiplier = 2_u32.checked_pow(consecutive_failures).unwrap_or(u32::MAX);
        self.initial_delay
            .saturating_mul(multiplier)
            .min(self.max_delay)
    }
}

impl Default for ReconnectPolicy {
    fn default() -> Self {
        Self {
            initial_delay: Duration::from_millis(250),
            max_delay: Duration::from_secs(5),
        }
    }
}

pub fn reconnecting_read_loop<Reader, Open, Clock, Sleep, Emit, Report>(
    device: DeviceId,
    mut open: Open,
    mut at_ms: Clock,
    mut sleep: Sleep,
    mut emit: Emit,
    mut report_retry: Report,
    policy: ReconnectPolicy,
) where
    Reader: Read,
    Open: FnMut() -> io::Result<Reader>,
    Clock: FnMut() -> u64,
    Sleep: FnMut(Duration) -> ControlFlow<()>,
    Emit: FnMut(DeviceUpdate) -> ControlFlow<()>,
    Report: FnMut(&io::Error, Duration),
{
    let mut consecutive_failures = 0_u32;

    loop {
        let error = match open() {
            Ok(mut reader) => loop {
                match read_raw_input(&mut reader, &mut at_ms) {
                    Ok(Some(raw)) => {
                        consecutive_failures = 0;
                        if emit(DeviceUpdate::Input { device, raw }).is_break() {
                            return;
                        }
                    }
                    Ok(None) => consecutive_failures = 0,
                    Err(error) => break error,
                }
            },
            Err(error) => error,
        };

        if emit(DeviceUpdate::Reset { device }).is_break() {
            return;
        }

        let delay = policy.delay_after(consecutive_failures);
        report_retry(&error, delay);
        consecutive_failures = consecutive_failures.saturating_add(1);

        if sleep(delay).is_break() {
            return;
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{
        collections::VecDeque,
        io::{self, Cursor},
        ops::ControlFlow,
        time::Duration,
    };

    use super::{reconnecting_read_loop, DeviceId, DeviceUpdate, ReconnectPolicy};
    use crate::reducer::{KeyState, RawInput};

    fn record(event_type: u16, code: u16, value: i32) -> Cursor<Vec<u8>> {
        let mut bytes = vec![0_u8; 24];
        bytes[16..18].copy_from_slice(&event_type.to_ne_bytes());
        bytes[18..20].copy_from_slice(&code.to_ne_bytes());
        bytes[20..24].copy_from_slice(&value.to_ne_bytes());
        Cursor::new(bytes)
    }

    #[test]
    fn reconnects_after_disconnect_and_resets_pressed_state() {
        let mut readers = VecDeque::from([record(0x01, 2, 1), record(0x01, 2, 0)]);
        let mut now = 40_u64;
        let mut updates = Vec::new();
        let mut input_count = 0;
        let mut delays = Vec::new();

        reconnecting_read_loop(
            DeviceId(7),
            || {
                readers
                    .pop_front()
                    .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "fixture exhausted"))
            },
            || {
                now += 1;
                now
            },
            |delay| {
                delays.push(delay);
                ControlFlow::Continue(())
            },
            |update| {
                updates.push(update);
                if matches!(update, DeviceUpdate::Input { .. }) {
                    input_count += 1;
                }
                if input_count == 2 {
                    ControlFlow::Break(())
                } else {
                    ControlFlow::Continue(())
                }
            },
            |_, _| {},
            ReconnectPolicy::default(),
        );

        assert_eq!(delays, [Duration::from_millis(250)]);
        assert_eq!(
            updates,
            [
                DeviceUpdate::Input {
                    device: DeviceId(7),
                    raw: RawInput::Key {
                        code: 2,
                        state: KeyState::Pressed,
                        at_ms: 41,
                    },
                },
                DeviceUpdate::Reset {
                    device: DeviceId(7),
                },
                DeviceUpdate::Input {
                    device: DeviceId(7),
                    raw: RawInput::Key {
                        code: 2,
                        state: KeyState::Released,
                        at_ms: 42,
                    },
                },
            ]
        );
    }

    #[test]
    fn reconnect_delay_is_exponential_and_bounded() {
        let policy = ReconnectPolicy {
            initial_delay: Duration::from_millis(100),
            max_delay: Duration::from_millis(400),
        };
        let mut delays = Vec::new();
        let mut resets = 0;

        reconnecting_read_loop(
            DeviceId(11),
            || -> io::Result<Cursor<Vec<u8>>> {
                Err(io::Error::new(io::ErrorKind::NotFound, "device absent"))
            },
            || 0,
            |delay| {
                delays.push(delay);
                if delays.len() == 5 {
                    ControlFlow::Break(())
                } else {
                    ControlFlow::Continue(())
                }
            },
            |update| {
                if update
                    == (DeviceUpdate::Reset {
                        device: DeviceId(11),
                    })
                {
                    resets += 1;
                }
                ControlFlow::Continue(())
            },
            |_, _| {},
            policy,
        );

        assert_eq!(
            delays,
            [
                Duration::from_millis(100),
                Duration::from_millis(200),
                Duration::from_millis(400),
                Duration::from_millis(400),
                Duration::from_millis(400),
            ]
        );
        assert_eq!(resets, 5);
    }
}
