extends Node

# این اسکریپت به‌صورت خودکار (Autoload) هنگام اجرا فعال می‌شود
# و رابط OpenXR را برای هدست کوئست ۲ راه‌اندازی می‌کند.
# اگر روی دسکتاپ (بدون هدست) اجرا شود، به‌آرامی رد می‌شود
# و بازی به‌صورت معمولی روی صفحه نمایش داده می‌شود.

func _ready() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR از قبل راه‌اندازی شده است.")
		get_viewport().use_xr = true
	elif xr_interface and xr_interface.initialize():
		print("OpenXR با موفقیت راه‌اندازی شد.")
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		print("هدست XR پیدا نشد — حالت پیش‌فرض دسکتاپ فعال است.")
