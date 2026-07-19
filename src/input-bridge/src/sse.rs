use std::{
    io::{self, Read, Write},
    net::{TcpListener, TcpStream},
    thread,
    time::Duration,
};

use crate::bus::EventBus;

const RESPONSE_HEADERS: &str = concat!(
    "HTTP/1.1 200 OK\r\n",
    "Content-Type: text/event-stream\r\n",
    "Cache-Control: no-cache\r\n",
    "Connection: keep-alive\r\n"
);
const FORBIDDEN_RESPONSE: &str =
    "HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
const KIOSK_ORIGIN: &str = "http://172.16.42.1:8080";

pub fn serve(listener: TcpListener, bus: EventBus) -> io::Result<()> {
    for stream in listener.incoming() {
        let stream = stream?;
        let client_bus = bus.clone();
        thread::spawn(move || {
            if let Err(error) = serve_client(stream, &client_bus) {
                eprintln!("input subscriber disconnected: {error}");
            }
        });
    }
    Ok(())
}

fn serve_client(mut stream: TcpStream, bus: &EventBus) -> io::Result<()> {
    stream.set_read_timeout(Some(Duration::from_secs(2)))?;
    let mut request_bytes = [0_u8; 2048];
    let bytes_read = stream.read(&mut request_bytes)?;
    let request = String::from_utf8_lossy(&request_bytes[..bytes_read]);
    let Ok(origin) = allowed_origin(&request) else {
        stream.write_all(FORBIDDEN_RESPONSE.as_bytes())?;
        return Ok(());
    };

    let receiver = bus.subscribe();
    stream.write_all(RESPONSE_HEADERS.as_bytes())?;
    if let Some(origin) = origin {
        write!(stream, "Access-Control-Allow-Origin: {origin}\r\n")?;
    }
    stream.write_all(b"\r\n")?;
    stream.flush()?;

    loop {
        match receiver.recv_timeout(Duration::from_secs(15)) {
            Ok(event) => {
                write!(stream, "event: input\ndata: {}\n\n", event.to_json())?;
                stream.flush()?;
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                stream.write_all(b": keepalive\n\n")?;
                stream.flush()?;
            }
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => return Ok(()),
        }
    }
}

fn allowed_origin(request: &str) -> Result<Option<&str>, ()> {
    let mut lines = request.lines();
    let request_line = lines.next().ok_or(())?.trim_end_matches('\r');
    if request_line != "GET /v1/events HTTP/1.1" && request_line != "GET /v1/events HTTP/1.0" {
        return Err(());
    }

    let origin = lines.find_map(|line| {
        let (name, value) = line.split_once(':')?;
        name.eq_ignore_ascii_case("origin").then_some(value.trim())
    });

    match origin {
        None => Ok(None),
        Some("null") => Ok(Some("null")),
        Some(KIOSK_ORIGIN) => Ok(Some(KIOSK_ORIGIN)),
        Some(value) if is_loopback_origin(value) => Ok(Some(value)),
        Some(_) => Err(()),
    }
}

fn is_loopback_origin(origin: &str) -> bool {
    ["http://127.0.0.1", "http://localhost"]
        .into_iter()
        .any(|allowed| {
            origin == allowed
                || origin.strip_prefix(allowed).is_some_and(|rest| {
                    rest.starts_with(':')
                        && rest[1..]
                            .chars()
                            .all(|character| character.is_ascii_digit())
                })
        })
}

#[cfg(test)]
mod tests {
    use super::allowed_origin;

    #[test]
    fn permits_file_and_loopback_ui_origins() {
        assert_eq!(
            allowed_origin("GET /v1/events HTTP/1.1\r\nOrigin: null\r\n\r\n"),
            Ok(Some("null"))
        );
        assert_eq!(
            allowed_origin("GET /v1/events HTTP/1.1\r\nOrigin: http://127.0.0.1:4173\r\n\r\n"),
            Ok(Some("http://127.0.0.1:4173"))
        );
        assert_eq!(
            allowed_origin("GET /v1/events HTTP/1.1\r\nOrigin: http://172.16.42.1:8080\r\n\r\n"),
            Ok(Some("http://172.16.42.1:8080"))
        );
    }

    #[test]
    fn rejects_remote_origins_and_unknown_paths() {
        assert_eq!(
            allowed_origin("GET /v1/events HTTP/1.1\r\nOrigin: https://example.com\r\n\r\n"),
            Err(())
        );
        assert_eq!(allowed_origin("GET /metrics HTTP/1.1\r\n\r\n"), Err(()));
    }
}
