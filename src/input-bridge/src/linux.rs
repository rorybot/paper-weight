use std::io::{self, Read};

use crate::reducer::{KeyState, RawInput};

const EV_KEY: u16 = 0x01;
const EV_REL: u16 = 0x02;

#[cfg(target_pointer_width = "64")]
const INPUT_EVENT_BYTES: usize = 24;

#[cfg(not(target_pointer_width = "64"))]
compile_error!("input_bridge currently targets 64-bit Linux hosts and aarch64 devices");

pub fn read_raw_input(
    reader: &mut impl Read,
    at_ms: impl FnOnce() -> u64,
) -> io::Result<Option<RawInput>> {
    let mut bytes = [0_u8; INPUT_EVENT_BYTES];
    reader.read_exact(&mut bytes)?;
    let at_ms = at_ms();

    let event_type = u16::from_ne_bytes([bytes[16], bytes[17]]);
    let code = u16::from_ne_bytes([bytes[18], bytes[19]]);
    let value = i32::from_ne_bytes([bytes[20], bytes[21], bytes[22], bytes[23]]);

    Ok(match event_type {
        EV_REL => Some(RawInput::Relative { code, value, at_ms }),
        EV_KEY => match value {
            0 => Some(RawInput::Key {
                code,
                state: KeyState::Released,
                at_ms,
            }),
            1 => Some(RawInput::Key {
                code,
                state: KeyState::Pressed,
                at_ms,
            }),
            2 => Some(RawInput::Key {
                code,
                state: KeyState::Repeat,
                at_ms,
            }),
            _ => None,
        },
        _ => None,
    })
}

#[cfg(test)]
mod tests {
    use std::{
        cell::Cell,
        io::{self, Read},
    };

    use super::read_raw_input;
    use crate::reducer::{KeyState, RawInput};

    struct ClockAdvancingReader<'a> {
        bytes: &'a [u8],
        now: &'a Cell<u64>,
    }

    impl Read for ClockAdvancingReader<'_> {
        fn read(&mut self, output: &mut [u8]) -> io::Result<usize> {
            let read = self.bytes.read(output)?;
            self.now.set(99);
            Ok(read)
        }
    }

    fn record(event_type: u16, code: u16, value: i32) -> Vec<u8> {
        let mut bytes = vec![0_u8; 24];
        bytes[16..18].copy_from_slice(&event_type.to_ne_bytes());
        bytes[18..20].copy_from_slice(&code.to_ne_bytes());
        bytes[20..24].copy_from_slice(&value.to_ne_bytes());
        bytes
    }

    #[test]
    fn parses_a_linux_key_record() {
        let record = record(0x01, 30, 1);
        let mut bytes = record.as_slice();
        assert_eq!(
            read_raw_input(&mut bytes, || 42).unwrap(),
            Some(RawInput::Key {
                code: 30,
                state: KeyState::Pressed,
                at_ms: 42,
            })
        );
    }

    #[test]
    fn ignores_sync_records() {
        let record = record(0x00, 0, 0);
        let mut bytes = record.as_slice();
        assert_eq!(read_raw_input(&mut bytes, || 42).unwrap(), None);
    }

    #[test]
    fn samples_the_clock_after_the_blocking_read() {
        let now = Cell::new(1);
        let record = record(0x01, 30, 1);
        let mut reader = ClockAdvancingReader {
            bytes: &record,
            now: &now,
        };

        assert_eq!(
            read_raw_input(&mut reader, || now.get()).unwrap(),
            Some(RawInput::Key {
                code: 30,
                state: KeyState::Pressed,
                at_ms: 99,
            })
        );
    }
}
