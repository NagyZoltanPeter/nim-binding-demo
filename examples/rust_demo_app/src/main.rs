use rust_binding::{api, initialize, proto, register_handler, teardown};
use std::thread;
use std::time::Duration;

fn main() {
    // Initialize the Nim library/runtime
    initialize();
    // Register a handler for onReceivedEvent
    register_handler::<proto::OnReceivedEvent, _>(|evt| {
        if let Some(msg) = &evt.msg {
            let payload = String::from_utf8_lossy(&msg.payload);
            println!(
                "Rust side>Received message: {} with payload: {}",
                msg.content_topic, payload
            );
        } else {
            println!("Rust side>Received event with no message");
        }
    });

    // Call init via the higher-level API
    api::init();

    // Build and send a WakuMessage
    let mut m = proto::WakuMessage {
        payload: b"Hello from Rust!".to_vec(),
        content_topic: "test/1/waku/proto".to_string(),
        version: Some(1),
        timestamp: Some(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as i64,
        ),
        meta: None,
        ephemeral: Some(false),
        rate_limit_proof: None,
    };

    println!(
        "Rust side>Sending message with payload: {}",
        String::from_utf8_lossy(&m.payload)
    );

    api::send(&m);

    thread::sleep(Duration::from_millis(400));
    println!("Rust side>Slept 400!");

    m.payload = b"Now the second message from Rust".to_vec();
    api::send(&m);
    println!("Rust side>2nd Message sent successfully!");

    thread::sleep(Duration::from_secs(2));
    // Teardown the library
    teardown();
    println!("Rust side>Teardown complete");
}
