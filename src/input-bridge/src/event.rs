#[derive(Clone, Debug, Eq, PartialEq)]
pub enum InputEvent {
    Wheel { ticks: i32 },
    WheelPress,
    WheelLongPress,
    Preset { number: u8 },
    Home,
    Back,
}

impl InputEvent {
    pub const VERSION: u8 = 1;

    #[must_use]
    pub fn to_json(&self) -> String {
        match self {
            Self::Wheel { ticks } => {
                format!(
                    r#"{{"v":{},"type":"wheel","ticks":{ticks}}}"#,
                    Self::VERSION
                )
            }
            Self::WheelPress => {
                format!(r#"{{"v":{},"type":"wheel_press"}}"#, Self::VERSION)
            }
            Self::WheelLongPress => {
                format!(r#"{{"v":{},"type":"wheel_long_press"}}"#, Self::VERSION)
            }
            Self::Preset { number } => {
                format!(
                    r#"{{"v":{},"type":"preset","number":{number}}}"#,
                    Self::VERSION
                )
            }
            Self::Home => format!(r#"{{"v":{},"type":"home"}}"#, Self::VERSION),
            Self::Back => format!(r#"{{"v":{},"type":"back"}}"#, Self::VERSION),
        }
    }
}
