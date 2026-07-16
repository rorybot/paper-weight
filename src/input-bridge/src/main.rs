use std::{
    env,
    fs::File,
    net::TcpListener,
    process::ExitCode,
    sync::mpsc::{self, RecvTimeoutError},
    thread,
    time::{Duration, Instant},
};

use paper_weight_input_bridge::{
    bus::EventBus,
    config::BridgeConfig,
    linux::read_raw_input,
    reducer::{RawInput, State, reduce},
    sse,
};

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("input_bridge: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let config_path = parse_config_path(env::args())?;
    let config = BridgeConfig::from_file(&config_path)?;
    let listener = TcpListener::bind(config.listen)
        .map_err(|error| format!("could not bind {}: {error}", config.listen))?;
    let bus = EventBus::default();
    let server_bus = bus.clone();
    thread::spawn(move || {
        if let Err(error) = sse::serve(listener, server_bus) {
            eprintln!("input event server stopped: {error}");
        }
    });

    let mut device = File::open(&config.device)
        .map_err(|error| format!("could not open {}: {error}", config.device.display()))?;
    let started = Instant::now();
    let (raw_sender, raw_receiver) = mpsc::channel::<Result<RawInput, String>>();

    thread::spawn(move || {
        loop {
            let at_ms = started.elapsed().as_millis() as u64;
            match read_raw_input(&mut device, at_ms) {
                Ok(Some(raw)) => {
                    if raw_sender.send(Ok(raw)).is_err() {
                        return;
                    }
                }
                Ok(None) => {}
                Err(error) => {
                    let _ = raw_sender.send(Err(format!("evdev read failed: {error}")));
                    return;
                }
            }
        }
    });

    let mut state = State::default();
    loop {
        let raw = match raw_receiver.recv_timeout(Duration::from_millis(10)) {
            Ok(Ok(raw)) => raw,
            Ok(Err(error)) => return Err(error),
            Err(RecvTimeoutError::Timeout) => RawInput::Tick {
                at_ms: started.elapsed().as_millis() as u64,
            },
            Err(RecvTimeoutError::Disconnected) => {
                return Err("evdev reader stopped unexpectedly".into());
            }
        };

        let transition = reduce(state, raw, &config.bindings);
        state = transition.state;
        for event in transition.events {
            bus.publish(event);
        }
    }
}

fn parse_config_path(mut args: impl Iterator<Item = String>) -> Result<String, String> {
    let program = args.next().unwrap_or_else(|| "input_bridge".into());
    match (args.next().as_deref(), args.next(), args.next()) {
        (Some("--config"), Some(path), None) => Ok(path),
        _ => Err(format!("usage: {program} --config <path>")),
    }
}
