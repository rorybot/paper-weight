use std::sync::{
    Arc, Mutex,
    mpsc::{self, Receiver, Sender},
};

use crate::event::InputEvent;

#[derive(Clone, Default)]
pub struct EventBus {
    subscribers: Arc<Mutex<Vec<Sender<InputEvent>>>>,
}

impl EventBus {
    #[must_use]
    pub fn subscribe(&self) -> Receiver<InputEvent> {
        let (sender, receiver) = mpsc::channel();
        self.subscribers
            .lock()
            .expect("event bus lock poisoned")
            .push(sender);
        receiver
    }

    pub fn publish(&self, event: InputEvent) {
        self.subscribers
            .lock()
            .expect("event bus lock poisoned")
            .retain(|subscriber| subscriber.send(event.clone()).is_ok());
    }
}

#[cfg(test)]
mod tests {
    use super::EventBus;
    use crate::event::InputEvent;

    #[test]
    fn publishes_to_every_live_subscriber() {
        let bus = EventBus::default();
        let first = bus.subscribe();
        let second = bus.subscribe();

        bus.publish(InputEvent::Back);

        assert_eq!(first.recv().unwrap(), InputEvent::Back);
        assert_eq!(second.recv().unwrap(), InputEvent::Back);
    }
}
