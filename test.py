import subprocess
import tkinter as tk
from tkinter import ttk
import getpass

from tkinter import filedialog
import getpass
import os

# Tkinter GUI Setup
root = tk.Tk()
root.title("Drive Manager")
root.geometry("600x500")
root.configure(bg='#1C1C1C')  # Dark background
root.attributes('-alpha', 0.97)  # Slightly transparent window


# User configuration
#user = getpass.getuser() # user = "fabio"
user = os.getlogin()  # Get the current username

if os.name == 'nt':  # Windows
    default_mount_path = f"C:\\Users\\{user}\\mounts"
else:  # Assume Linux for other OSes
    default_mount_path = f"/home/{user}/mounts"

mount_path_var = tk.StringVar(value=default_mount_path)

## -----

def select_mount_directory():
    directory = filedialog.askdirectory()
    if directory:
        mount_path_var.set(directory)

def get_available_drives():
    result = subprocess.run(["rclone", "listremotes"], capture_output=True, text=True)
    return result.stdout.strip().split("\n")

def mount_drive():
    selected_drive = drive_var.get()
    if not selected_drive:
        return

    update_status("Mounting...", "#FFC107")  # Yellow for processing
    log_text.insert(tk.END, f"Mounting {selected_drive}...\n")
    root.update_idletasks()  # Update the GUI immediately

    #mount_path = f"/home/{user}/mounts/{selected_drive.rstrip(':')}"
    mount_path = mount_path_var.get()
    
    #subprocess.run(["mkdir", "-p", mount_path])  # Create mount directory
    os.makedirs(mount_path, exist_ok=True)  # Create mount directory
    
    # rclone mount using subprocess
    subprocess.run(["rclone", "mount", "--daemon", selected_drive, mount_path, "--allow-non-empty"])
    command = ["rclone", "mount", selected_drive, mount_path, "--allow-non-empty", "--daemon"]
    result = subprocess.run(command, capture_output=True, text=True)
    log_text.insert(tk.END, f"{' '.join(command)}\n")
    log_text.insert(tk.END, result.stdout)

    update_status("Mounted", "#4CAF50")  # Green for mounted
    log_text.insert(tk.END, f"{selected_drive} mounted at {mount_path}\n")

def unmount_drive():
    selected_drive = drive_var.get()
    if selected_drive:
        update_status("Unmounting...", "#FFC107")  # Yellow for processing
        log_text.insert(tk.END, f"Unmounting {selected_drive}...\n")
        root.update_idletasks()  # Update the GUI immediately

        #mount_path = f"/home/{user}/mounts/{selected_drive.rstrip(':')}"
        mount_path = mount_path_var.get()

        command = ["fusermount", "-uz", mount_path]
        result = subprocess.run(command, capture_output=True, text=True)
        log_text.insert(tk.END, f"{' '.join(command)}\n")
        log_text.insert(tk.END, result.stdout)

        update_status("Unmounted", "#F44336")  # Red for unmounted
        log_text.insert(tk.END, f"{selected_drive} unmounted from {mount_path}\n")

def update_status(message, color):
    mount_status_label.config(text=message, fg=color)
    status_canvas.itemconfig(status_light, outline=color, fill=color)

def check_mount_status(*args):
    selected_drive = drive_var.get()
    mount_path = f"/home/{user}/mounts/{selected_drive.rstrip(':')}"
    result = subprocess.run(["mountpoint", "-q", mount_path])
    if result.returncode == 0:
        update_status("Mounted", "#4CAF50")  # Green if mounted
    else:
        update_status("Unmounted", "#F44336")  # Red if not mounted

def update_option_menu(menu, var, options):
    menu["menu"].delete(0, "end")
    for option in options:
        menu["menu"].add_command(label=option, command=tk._setit(var, option))
    var.set(options[0] if options else "")
'''
# Tkinter GUI Setup
root = tk.Tk()
root.title("Drive Manager")
root.geometry("600x500")
root.configure(bg='#1C1C1C')  # Dark background
root.attributes('-alpha', 0.97)  # Slightly transparent window
'''
# Initialize mount_path_var after creating root window
mount_path_var = tk.StringVar(value=default_mount_path)

# Create a header frame
header_frame = tk.Frame(root, bg='#333333')  # Header background
header_frame.pack(fill='x')

# Create a header label
header_label = tk.Label(header_frame, text="Ordo Mount", bg='#333333', fg='white', font=("Helvetica", 24, "bold"))
header_label.pack(pady=15)

# Create a main frame
main_frame = tk.Frame(root, bg='#1C1C1C')
main_frame.pack(expand=True, fill='both', padx=20, pady=20)

# Adding components to the main frame
tk.Label(main_frame, text="Select Drive:", bg='#1C1C1C', fg='white', font=("Helvetica", 14)).grid(row=0, column=0, sticky='w')

drives = get_available_drives()
drive_var = tk.StringVar(main_frame)
drive_var.set(drives[0] if drives else "")
drive_var.trace("w", check_mount_status)  # Check mount status when selection changes

# Styled OptionMenu
style = ttk.Style()
style.configure('TMenubutton', background='#555555', foreground='white', font=("Helvetica", 12))

drive_menu = ttk.OptionMenu(main_frame, drive_var, *drives)
drive_menu.grid(row=1, column=0, pady=20, sticky='w')

# Initial update of the menu with drive options
update_option_menu(drive_menu, drive_var, drives)




# Mount path selection
tk.Label(main_frame, text="Mount Path:", bg='#1C1C1C', fg='white', font=("Helvetica", 14)).grid(row=2, column=0, sticky='w')
mount_path_entry = tk.Entry(main_frame, textvariable=mount_path_var, font=("Helvetica", 12), width=40)
mount_path_entry.grid(row=4, column=1, pady=10, sticky='w')
select_dir_button = tk.Button(main_frame, text="Browse...", command=select_mount_directory, font=("Helvetica", 12), bg='#D1D1D1', fg='#1C1C1C')
select_dir_button.grid(row=3, column=1, pady=10, sticky='w')




# Styled Buttons
mount_button = tk.Button(main_frame, text="Mount Drive", command=mount_drive, font=("Helvetica", 14), bg='#D1D1D1', fg='#1C1C1C')
mount_button.grid(row=2, column=0, pady=10, sticky='w')

unmount_button = tk.Button(main_frame, text="Unmount Drive", command=unmount_drive, font=("Helvetica", 14), bg='#D1D1D1', fg='#1C1C1C')
unmount_button.grid(row=3, column=0, pady=10, sticky='w')

# Status Light indicator
status_frame = tk.Frame(main_frame, bg='#1C1C1C')
status_frame.grid(row=1, column=1, padx=30)
status_canvas = tk.Canvas(status_frame, width=40, height=40, bg='#1C1C1C', highlightthickness=0)
status_light = status_canvas.create_oval(5, 5, 35, 35, outline="#F44336", fill="#F44336")
status_canvas.pack()

# Status label to show Mount/Unmount status
mount_status_label = tk.Label(status_frame, text="Unmounted", fg="#F44336", bg='#1C1C1C', font=("Helvetica", 14))
mount_status_label.pack(pady=10)

# Log frame and text box
log_frame = tk.Frame(root, bg='#1C1C1C')
log_frame.pack(expand=True, fill='both', padx=20, pady=20)
log_text = tk.Text(log_frame, bg='#222222', fg='white', font=("Helvetica", 14), height=12)
log_text.pack(fill='both', expand=True)



root.mainloop()