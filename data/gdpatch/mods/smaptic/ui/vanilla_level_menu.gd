extends Control

const VANILLA_LEVELS := [
    "mirraxis",
    "movement_playtest",
    "test_room",
]

func _ready() -> void:
    # placeholder label until i get around to implementation
    var label := Label.new()
    label.text = "Coming soon™!"
    label.size_flags_horizontal = SIZE_EXPAND_FILL
    label.size_flags_vertical = SIZE_EXPAND_FILL
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 24)
    add_sibling.call_deferred(label)