extends Button
class_name StationStorageSlot

signal item_hovered(slot: StationStorageSlot, item_data: SalvageItemData, quantity: int)
signal item_unhovered(slot: StationStorageSlot)

var item_data: SalvageItemData = null
var quantity: int = 0

@onready var _icon: TextureRect = $Icon
@onready var _quantity_label: Label = $QuantityLabel


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	Magnetide.apply_label_font(_quantity_label)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func setup(new_item_data: SalvageItemData, new_quantity: int) -> void:
	item_data = new_item_data
	quantity = maxi(new_quantity, 1)

	if not is_node_ready():
		return
	_refresh()


func _refresh() -> void:
	_icon.texture = item_data.sprite if item_data != null else null
	_quantity_label.text = "x%d" % quantity if quantity > 1 else ""

	if item_data != null:
		tooltip_text = item_data.item_name
	else:
		tooltip_text = ""


func _on_mouse_entered() -> void:
	item_hovered.emit(self, item_data, quantity)


func _on_mouse_exited() -> void:
	item_unhovered.emit(self)


func _on_focus_entered() -> void:
	item_hovered.emit(self, item_data, quantity)


func _on_focus_exited() -> void:
	item_unhovered.emit(self)
