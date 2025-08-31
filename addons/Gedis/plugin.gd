@tool
extends EditorPlugin

func _enter_tree() -> void:
	# Register Gedis as an autoload singleton when the plugin is enabled
	add_autoload_singleton("Gedis", "res://addons/Gedis/gedis.gd")

func _exit_tree() -> void:
	# Remove the autoload when the plugin is disabled
	remove_autoload_singleton("Gedis")
