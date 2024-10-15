extends CanvasLayer

onready var completions_number = get_node("ColorRect/VBoxContainer/Pause/HBoxContainer/CompletionsNumber")
onready var check_button = get_node("ColorRect/VBoxContainer/Pause/CheckButton")

func _ready():
  completions_number.value = Main.number_of_completions_to_pause
  check_button.pressed = Main.pause_on_completion


func _on_CheckButton_toggled(button_pressed:bool):
  Main.pause_on_completion = button_pressed
  completions_number.editable = button_pressed


func _on_CompletionsNumber_value_changed(value:float):
  Main.number_of_completions_to_pause = round(value)


func _on_Return_pressed():
  visible = false
