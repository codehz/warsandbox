const KeyboardStatus = extern struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    space: bool = false,
};

pub export var keyboard = KeyboardStatus{};