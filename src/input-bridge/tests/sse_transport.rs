use std::{
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
    thread,
    time::Duration,
};

use paper_weight_input_bridge::{bus::EventBus, event::InputEvent, sse};

#[test]
fn loopback_subscriber_receives_the_exact_bus_event() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let bus = EventBus::default();
    let server_bus = bus.clone();
    thread::spawn(move || sse::serve(listener, server_bus).unwrap());

    let mut client = TcpStream::connect(address).unwrap();
    client
        .set_read_timeout(Some(Duration::from_secs(2)))
        .unwrap();
    client
        .write_all(b"GET /v1/events HTTP/1.1\r\nHost: 127.0.0.1\r\nOrigin: null\r\n\r\n")
        .unwrap();

    let mut reader = BufReader::new(client);
    let mut response_headers = String::new();
    loop {
        let mut line = String::new();
        reader.read_line(&mut line).unwrap();
        response_headers.push_str(&line);
        if line == "\r\n" {
            break;
        }
    }
    assert!(response_headers.starts_with("HTTP/1.1 200 OK\r\n"));
    assert!(response_headers.contains("Access-Control-Allow-Origin: null\r\n"));

    bus.publish(InputEvent::Wheel { ticks: 3 });

    let mut event = String::new();
    reader.read_line(&mut event).unwrap();
    let mut data = String::new();
    reader.read_line(&mut data).unwrap();

    assert_eq!(event, "event: input\n");
    assert_eq!(data, "data: {\"v\":1,\"type\":\"wheel\",\"ticks\":3}\n");
}
