/// What the chat screen's controls do. The composer builds it, so the view stays free of feedback and view model calls.
struct PlantChatControls {
    let back: () -> Void
    let keyboard: () -> Void
    let mic: () -> Void
    let end: () -> Void
    let voice: () -> Void
    let send: (String) -> Void
}
