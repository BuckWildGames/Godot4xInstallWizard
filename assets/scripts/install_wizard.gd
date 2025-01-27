extends Control


@export_category("Game Info")
## The project name.
@export var project_name: String = "MyProject"
## The project version.
@export var project_version: String = "0.0.0"
## The main project file or launcher. (place all files in res://files)
@export var project_main_file: String = "project_name.exe"

@export_category("License")
## The selected license for project. (place new licenses in res://licenses)
@export var selected_license: String  =  "mit.txt" #all_rights_reserved.txt
## The current year or copyright year.
@export var year: String  =  "2025"
## Your company name.
@export var company_name: String  =  "MyCompany"
## Include the license file in the install location.
@export var include_license_install: bool = true

@export_category("Other")
## Custom theme for install wizard.
@export var custom_theme: Theme = null
## Slows loading to show the progress better.
@export var load_delay: float = 0.2

# UI Nodes
@onready var project_name_label: Label = $BG/VBoxContainer/ProjectNameLabel
@onready var project_version_label: Label = $BG/VBoxContainer/ProjectVersionLabel
@onready var install_dir_label: Label = $BG/VBoxContainer/HBoxContainer/InstallPath
@onready var install_dir_picker: Button = $BG/VBoxContainer/HBoxContainer/InstallPathButton
@onready var project_size: Label = $BG/VBoxContainer/HBoxContainer2/ProjectSize
@onready var install_path_size: Label = $BG/VBoxContainer/HBoxContainer2/InstallPathSize
@onready var shortcut_checkbox: CheckBox = $BG/VBoxContainer/HBoxContainer3/ShortcutCheckBox
@onready var start_menu_checkbox: CheckBox = $BG/VBoxContainer/HBoxContainer3/StartMenuCheckBox
@onready var license_text_label: Label = $BG/LicensePanelContainer/VBoxContainer/ScrollContainer/LicenseLabel
@onready var accept_checkbox: CheckBox = $BG/VBoxContainer/HBoxContainer4/AcceptLicenseCheckBox
@onready var view_license_button: Button = $BG/VBoxContainer/HBoxContainer4/ViewLicenseButton
@onready var license_panel_container: PanelContainer = $BG/LicensePanelContainer
@onready var install_button: Button = $BG/VBoxContainer/InstallButton
@onready var progress_bar: ProgressBar = $BG/VBoxContainer/ProgressBar
@onready var status_label: Label = $BG/VBoxContainer/StatusLabel
@onready var finish_button: Button = $BG/VBoxContainer/FinishButton
@onready var dir_dialog: FileDialog = $BG/FileDialog # Add a DirectoryDialog node to the scene

var install_dir: String = ""
var start_menu_folder = ""
var license_file_path: String = ""


func _ready() -> void:
		_run_as_admin()
		_get_default_install_location()
		_update_license_text()
		_update_ui()


func _update_ui() -> void:
	if install_dir_label:
		install_dir_label.set_text(install_dir)
	if project_size:
		project_size.set_text(_get_folder_size("res://files"))
	if install_path_size:
		var path = install_dir.replace(project_name, "")
		if not path.ends_with(":/"):
			path = path.rstrip("/")
		install_path_size.set_text(_get_free_disk_space(path))
	if project_name_label:
		project_name_label.set_text(project_name)
	if project_version_label:
		project_version_label.set_text(project_version)
	if custom_theme:
		set_theme(custom_theme)


# Open the FileDialog to select an installation directory
func _on_SelectInstallPathButton_pressed() -> void:
	dir_dialog.popup_centered()


# Handle directory selection
func _on_DirectoryDialog_dir_selected(directory) -> void:
	directory = directory.replace("\\", "/")
	install_dir = directory  + "/" + project_name
	install_dir = install_dir.replace("//", "/")
	_update_ui()


# Button press to view the license
func _on_ViewButton_pressed() -> void:
	var panel_visible = license_panel_container.is_visible()
	license_panel_container.set_visible(!panel_visible)


# Button press to accept the license and continue installation
func _on_AcceptButton_toggled(toggled_on: bool) -> void:
	install_button.set_disabled(!toggled_on)


# Start the installation process
func _on_InstallButton_pressed() -> void:
	accept_checkbox.set_disabled(true)
	start_menu_checkbox.set_disabled(true)
	install_button.set_disabled(true)
	install_dir_picker.set_disabled(true)
	_install_project()


# Close the program
func _on_FinishButton_pressed() -> void:
	get_tree().quit()


func _get_folder_size(folder_path: String) -> String:
	var total_size = 0
	var dir = DirAccess.open(folder_path)
	
	if dir == null:
		return "Error"

	# Loop through all files in the folder
	var error = dir.list_dir_begin()
	if error == OK:
		while true:
			var file = dir.get_next()
			if file == "":
				break  # End of folder
			
			var file_path = folder_path + "/" + file
			if dir.current_is_dir():  # If it's a folder, ignore it
				status_label.set_text("Folder detected in '/files' folder")
				print("res://files should only have the exported project files in it!")
			else:  # If it's a file, add its size
				var temp_file = FileAccess.open(file_path, FileAccess.READ)
				if temp_file != null:
					total_size += temp_file.get_length()
					temp_file.close()
		
		dir.list_dir_end()

	var file_size_mb = total_size / 1024.0 / 1024.0
	var file_size_gb = total_size / 1024.0 / 1024.0 / 1024.0

	if file_size_gb >= 1:
		return str(snapped(file_size_gb, 0.01)) + " GB"
	elif file_size_mb >= 1:
		return str(snapped(file_size_mb, 0.01)) + " MB"
	else:
		return str(total_size) + " bytes"


func _get_free_disk_space(folder_path: String) -> String:
	var output = []
	var exit_code = 0
	
	if OS.get_name() == "Windows":
		# On Windows, use the `dir` command to get drive information
		var drive = folder_path.substr(0, 2)  # Extract the drive letter (e.g., "D:")
		exit_code = OS.execute("cmd", ["/c", "dir", drive], output, true)
	else:
		# On Linux/macOS, use the `df` command to get folder information
		exit_code = OS.execute("df", ["-B1", folder_path], output, true)  # Use -B1 for bytes for easier math
	
	if exit_code != 0:
		return "Error1"

	# Parse the output to extract free space in bytes
	var folder_space_bytes = _parse_free_space_bytes(output)
	if folder_space_bytes == -1:
		return "Error2"

	# Convert bytes to a human-readable format
	var folder_space_mb = folder_space_bytes / 1024.0 / 1024.0
	var folder_space_gb = folder_space_bytes / 1024.0 / 1024.0 / 1024.0

	if folder_space_gb >= 1:
		return str(snapped(folder_space_gb, 0.01)) + " GB"
	elif folder_space_mb >= 1:
		return str(snapped(folder_space_mb, 0.01)) + " MB"
	else:
		return str(folder_space_bytes) + " bytes"


func _parse_free_space_bytes(output: Array) -> int:
	for line in output:
		var line_str = str(line).strip_edges()
		
		# Look for the line containing "bytes free"
		if line_str.find("bytes free") != -1:
			line_str = line_str.substr(line_str.find("Dir(s)"))
			print("Matched line: ", line_str)  # Debugging output
			
			# Extract all digits and commas from the line
			var free_space_str = ""
			for charr in line_str:
				if charr.is_valid_int() or charr == ",":
					free_space_str += charr
			
			if free_space_str != "":
				print("Extracted free space string: ", free_space_str)  # Debugging output
				var free_space = int(free_space_str.replace(",", ""))  # Remove commas and convert to int
				print("Parsed free space (bytes): ", free_space)  # Debugging output
				return free_space
	
	print("No matching line found for 'bytes free'.")  # Debugging output if no line matches
	return -1


func _run_as_admin() -> void:
	var platform = OS.get_name()
	var script_path = ""
	var temp_path = ""

	# Define the script paths based on the platform
	if platform == "Windows":
		script_path = "res://assets/admin/run_as_admin.bat"
	elif platform == "OSX":
		script_path = "res://assets/admin/run_as_admin.command"
	elif platform == "X11":
		script_path = "res://assets/admin/run_as_admin.sh"
	else:
		print("Unsupported platform")
		return

	# Load the script content from the packed resource
	var script_file = FileAccess.open(script_path, FileAccess.READ)
	if script_file == null:
		print("Failed to load script file")
		return

	var script_content = script_file.get_as_text()
	script_file.close()

	# Define the temporary file path for the platform
	if platform == "Windows":
		temp_path = OS.get_environment("TEMP") + "/run_as_admin.bat"
	elif platform == "OSX" or platform == "X11":
		temp_path = "/tmp/run_as_admin.sh"

	# Write the script content to the temporary file
	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		print("Failed to create temporary file")
		return

	temp_file.store_string(script_content)
	temp_file.close()

	# Make the script executable (for Unix-based platforms)
	if platform != "Windows":
		OS.execute("chmod", ["+x", temp_path])

	# Check if already running as admin/root
	if _is_elevated():
		print("Already running as admin/root. No relaunch needed.")
		return

	# Relaunch with elevated privileges
	print("Relaunching the program as admin/root...")
	var executable_path = OS.get_executable_path()  # Path to the current Godot executable
	var result = OS.execute(temp_path, [executable_path], [], true)

	if result != 0:
		print("Failed to relaunch the program with admin/root privileges.")
	else:
		print("Program has been relaunched as admin/root.")
		get_tree().quit()



# Function to check if the program is running with elevated privileges
func _is_elevated() -> bool:
	var platform = OS.get_name()
	
	if platform == "Windows":
		var result = OS.execute("cmd", ["/c", "NET SESSION"], [], true)
		return result == 0
	elif platform in ["OSX", "X11"]:
		var result = OS.execute("id", ["-u"], [], true)
		return result == 0
	else:
		print("Unsupported platform for elevation check.")
		return false


func _get_default_install_location() -> void:
	# Set the default installation directory based on the OS
	if OS.get_name() == "Windows":
		var program_files = OS.get_environment("ProgramFiles(x86)")
		if program_files == "":
			program_files = OS.get_environment("ProgramFiles")
		program_files = program_files.replace("\\", "/")
		install_dir = program_files + "/" + project_name
	elif OS.get_name() == "OSX":
		install_dir = "/Applications/" + project_name
	elif OS.get_name() == "Linux":
		install_dir = "/opt/" + project_name
	else:
		install_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/" + project_name
		install_dir = install_dir.replace("\\", "/")


# Update the license text based on the selected file
func _update_license_text() -> void:
	# Get the selected license filename
	license_file_path = "res://licenses/" + selected_license
	
	# Load the contents of the selected license file
	var file = FileAccess.open(license_file_path, FileAccess.READ)
	if file:
		var license_text = file.get_as_text()  # Read the file contents
		license_text = license_text.replace("<DATE>", year)
		license_text = license_text.replace("<NAME>", company_name)
		license_text_label.set_text(license_text)  # Display it on the label or TextEdit
		file.close()
	else:
		license_text_label.set_text("Failed to load the selected license file.")


# Install the project
func _install_project() -> void:
	status_label.set_text("Installing game...")
	progress_bar.set_value(0)

	# Ensure the installation directory exists
	var dir = DirAccess.open(install_dir)
	if not dir:
		dir = DirAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))  # A fallback in case the parent directory doesn't exist.
		dir.make_dir_recursive(install_dir)

	# Create an install log file
	var log_file_path = "%s/install_test.txt" % install_dir
	var log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if not log_file:
		status_label.set_text("Failed, needs access to folder!")
		accept_checkbox.set_disabled(false)
		start_menu_checkbox.set_disabled(false)
		install_button.set_disabled(false)
		install_dir_picker.set_disabled(false)
		return

	log_file.close()
	dir.remove(log_file_path)
	var complete = true

	# Copy game files
	var source_dir = "res://files/"
	var files_dir = DirAccess.open("res://files")
	var project_files = files_dir.get_files()
	for i in range(project_files.size()):
		var file_name = project_files[i]
		if not ".import" in file_name:
			var source_path = "%s%s" % [source_dir, file_name]
			var target_path = "%s/%s" % [install_dir, file_name]

			var source_file = FileAccess.open(source_path, FileAccess.READ)
			if not source_file:
				status_label.set_text("Failed To Get File: " + source_path)
				complete = false
				break
			else:
				var target_file = FileAccess.open(target_path, FileAccess.WRITE)
				if not target_file:
					status_label.set_text("Failed To Install File: " + target_path)
					complete = false
					break
				else:
					target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
					source_file.close()
					target_file.close()

			progress_bar.set_value(float(i + 1) / project_files.size() * 80)
			await get_tree().create_timer(load_delay).timeout

	# Optionally create a desktop shortcut
	if complete and shortcut_checkbox.is_pressed():
		progress_bar.set_value(85.0)
		status_label.set_text("Creating Desktop Shortcut...")
		var desktop = await _create_desktop_shortcut()
		if not desktop:
			complete = false
			status_label.set_text("Failed To Create Desktop Shortcut")

	if complete and start_menu_checkbox.is_pressed():
		progress_bar.set_value(85.0)
		status_label.set_text("Creating Start Menu Shortcut...")
		var start = await _create_start_menu_shortcut()
		if not start:
			complete = false
			status_label.set_text("Failed To Create Start Menu Shortcut")
	
	if complete:
		# Generate the uninstaller
		progress_bar.set_value(90.0)
		status_label.set_text("Creating Uninstaller...")
		var uninstaller = await _generate_uninstaller()
		if not uninstaller:
			complete = false
			status_label.set_text("Failed To Create Uninstaller")

	# Add license
	if complete and include_license_install:
		status_label.set_text("Wrapping Up...")
		var license = await _save_license_to_install_dir()
		if not license:
			complete = false
			status_label.set_text("Failed To Create License File")

	if complete:
		status_label.set_text("Installation complete!")
		progress_bar.set_value(100)
	else:
		var parent_dir = install_dir.replace("/" + project_name, "")
		var folder = DirAccess.open(parent_dir)
		if folder:
			folder.remove(project_name)
			folder.close()
		finish_button.set_text("Close")
	finish_button.set_disabled(false)


# Create a desktop shortcut
func _create_desktop_shortcut() -> bool:
	await get_tree().create_timer(load_delay).timeout
	if OS.get_name() == "Windows":
		return _create_windows_shortcut(OS.get_environment("USERPROFILE") + "/Desktop/")
	elif OS.get_name() == "Linux" or OS.get_name() == "OSX":
		return _create_unix_shortcut(OS.get_environment("HOME") + "/Desktop/")
	else:
		print("Unsupported platform for desktop shortcut creation.")
		return false


# Create a Start Menu shortcut
func _create_start_menu_shortcut() -> bool:
	await get_tree().create_timer(load_delay).timeout
	if OS.get_name() == "Windows":
		return _create_windows_shortcut(OS.get_environment("APPDATA") + "/Microsoft/Windows/Start Menu/Programs/")
	elif OS.get_name() == "Linux":
		# Linux typically uses ~/.local/share/applications for app shortcuts
		return _create_unix_shortcut(OS.get_environment("HOME") + "/.local/share/applications/")
	elif OS.get_name() == "OSX":
		return _create_unix_shortcut(OS.get_environment("HOME") + "/Applications/")
	else:
		print("Unsupported platform for Start Menu shortcut creation.")
		return false


# Create a shortcut on Windows
func _create_windows_shortcut(destination: String) -> bool:
	var shortcut_path = destination + project_name + ".lnk"
	var target_path = install_dir + "/" + project_main_file
	var icon_path = install_dir + "/icon.ico"  # Ensure an icon file exists in the install directory
	if not icon_path:
		icon_path = install_dir + "/icon.svg"
	if not icon_path:
		icon_path = install_dir + "/icon.png"

	# PowerShell command to create a proper .lnk file
	var cmd = """
	$WScriptShell = New-Object -ComObject WScript.Shell;
	$Shortcut = $WScriptShell.CreateShortcut('%s');
	$Shortcut.TargetPath = '%s';
	$Shortcut.IconLocation = '%s';
	$Shortcut.Save();
	""" % [shortcut_path.replace("\\", "/"), target_path.replace("\\", "/"), icon_path.replace("\\", "/")]

	var result = OS.execute("powershell", ["-Command", cmd], [], true)
	if result != OK:
		print("Failed to create .lnk shortcut at %s" % destination)
		return false

	print("Created .lnk shortcut at %s" % destination)
	return true


# Create a shortcut on Linux/MacOS
func _create_unix_shortcut(destination: String) -> bool:
	var shortcut_path = destination + project_name + ".desktop"
	var icon_path = install_dir + "/icon.icns"  # Ensure an icon file exists in the install directory
	if not icon_path:
		icon_path = install_dir + "/icon.svg"
	if not icon_path:
		icon_path = install_dir + "/icon.png"

	var shortcut_content = """
	[Desktop Entry]
	Name=%s
	Exec=%s/%s
	Type=Application
	Icon=%s
	""" % [project_name, install_dir, project_main_file, icon_path]

	var file = FileAccess.open(shortcut_path, FileAccess.WRITE)
	if not file:
		print("Failed to create .desktop shortcut at %s" % destination)
		return false

	file.store_string(shortcut_content)
	file.close()

	# Make the .desktop file executable
	OS.execute("chmod", ["+x", shortcut_path], [], true)

	print("Created .desktop shortcut at %s" % destination)
	return true


# Save the license text to a .txt file in the installation directory
func _save_license_to_install_dir() -> bool:
	await get_tree().create_timer(load_delay).timeout
	var license_file_in_install_dir = install_dir + "/LICENSE.txt"  # Create the LICENSE.txt file

	# Open the file in write mode to store the license text
	var file = FileAccess.open(license_file_in_install_dir, FileAccess.WRITE)
	if file:
		var license_text = license_text_label.get_text()  # Get the license text from the label or TextEdit
		file.store_string(license_text)  # Save the text to the file
		file.close()
	else:
		print("Failed to create LICENSE.txt in the installation directory.")
		return false
	print("Created LICENSE.txt in the installation directory.")
	return true


# Generates an uninstaller script for each OS, deletes shortcuts during uninstallation
func _generate_uninstaller() -> bool:
	await get_tree().create_timer(load_delay).timeout
	var uninstaller_script_path: String
	var script_content: String

	if OS.get_name() == "Windows":
		# Windows uninstaller script (batch)
		uninstaller_script_path = "%s/uninstall.bat" % install_dir
		script_content = """
@echo off
:: Check if running as admin
net session >nul 2>&1
if not %errorlevel%==0 (
	echo Requesting administrator privileges...
	powershell -Command "Start-Process '%~f0' -Verb runAs"
	exit /b
)

echo.
echo UNINSTALLER:
echo.
echo Do you want to keep your user data?
echo Press Y to keep data or N to delete data.
set /p KEEP_SAVE=

echo.
echo Are you sure you want to uninstall?
echo Press Y to confirm uninstall or N to cancel.
set /p CONFIRM_UNINSTALL=

if /i "%CONFIRM_UNINSTALL%"=="Y" (
	echo Uninstalling...

	if /i "%KEEP_SAVE%"=="N" (
		echo Deleting user data...
		rmdir /S /Q "%APPDATA%\\%project_name%"
	) else (
		echo Keeping user data...
	)

	echo Removing installed files...
	rmdir /S /Q "%install_dir%"

	echo Deleting shortcuts...
	del "%USERPROFILE%\\Desktop\\%project_name%.lnk" /Q
	del "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\%project_name%.lnk" /Q

	echo Uninstallation complete. Press any key to exit.
	pause
) else (
	echo Uninstall cancelled. Press any key to exit.
	pause
)
"""
		# Replace placeholders with actual values
		script_content = script_content.replace("%project_name%", project_name).replace("%install_dir%", install_dir)

	elif OS.get_name() == "Linux" or OS.get_name() == "OSX":
		# Linux/macOS uninstaller script (shell)
		uninstaller_script_path = "%s/uninstall.sh" % install_dir
		script_content = """
#!/bin/bash

if [ "$EUID" -ne 0 ]; then
	echo "This script requires administrative privileges. Restarting with sudo..."
	sudo bash "$0"
	exit
fi

echo
echo UNINSTALLER:
echo
echo "Do you want to keep your user data?"
echo "Press Y to keep data or N to delete data."
read KEEP_SAVE

echo
echo "Are you sure you want to uninstall?"
echo "Press Y to confirm uninstall or N to cancel."
read CONFIRM_UNINSTALL

if [ "$CONFIRM_UNINSTALL" == "Y" ]; then
	echo "Uninstalling..."
	
	if [ "$KEEP_SAVE" == "n" ]; then
		echo "Deleting user data..."
		sudo rm -rf "$HOME/.config/%project_name%"
	else
		echo "Keeping user data..."
	fi

	echo "Removing installed files..."
	sudo rm -rf "%install_dir%"

	echo "Deleting shortcuts..."
	rm -f "$HOME/Desktop/%project_name%.desktop"
	rm -f "$HOME/.local/share/applications/%project_name%.desktop"

	echo "Uninstallation complete. Press any key to exit."
	read -n 1 -s -r
else
	echo "Uninstall cancelled. Press any key to exit."
	read -n 1 -s -r
fi
"""
		# Replace placeholders with actual values
		script_content = script_content.replace("%project_name%", project_name).replace("%install_dir%", install_dir)

	else:
		print("Unsupported OS for uninstaller script.")
		return false

	# Write the script content to the appropriate file
	var file = FileAccess.open(uninstaller_script_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()

		# Make the script executable for Linux/macOS
		if OS.get_name() in ["Linux", "OSX"]:
			OS.execute("chmod", ["+x", uninstaller_script_path], [], false)

		print("Uninstaller script created at: %s" % uninstaller_script_path)
	else:
		print("Failed to create uninstaller script.")
		return false
	return true
