use std::{
    env,
    fs::File,
    net::TcpListener,
    ops::ControlFlow,
    process::ExitCode,
    sync::mpsc::{self, RecvTimeoutError},
    thread,
    time::{Duration, Instant},
};

use paper_weight_input_bridge::{
    bus::EventBus,
    config::BridgeConfig,
    device::{DeviceUpdate, ReconnectPolicy, reconnecting_read_loop},
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

    let started = Instant::now();
    let device_path = config.device.clone();
    let (device_sender, device_receiver) = mpsc::channel::<DeviceUpdate>();

    thread::spawn(move || {
        reconnecting_read_loop(
            || File::open(&device_path),
            || started.elapsed().as_millis() as u64,
            |delay| {
                thread::sleep(delay);
                ControlFlow::Continue(())
            },
            |update| match device_sender.send(update) {
                Ok(()) => ControlFlow::Continue(()),
                Err(_) => ControlFlow::Break(()),
            },
            |error, delay| {
                eprintln!(
                    "evdev {} unavailable: {error}; retrying in {}ms",
                    device_path.display(),
                    delay.as_millis()
                );
            },
            ReconnectPolicy::default(),
        );
    });

    let mut state = State::default();
    loop {
        let raw = match device_receiver.recv_timeout(Duration::from_millis(10)) {
            Ok(DeviceUpdate::Input(raw)) => raw,
            Ok(DeviceUpdate::Reset) => {
                state = State::default();
                continue;
            }
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
