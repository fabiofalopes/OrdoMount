# OrdoMount

Wrapper for rclone that to help mount remote drives locally, integrating cloud storage with file system

---

## Save dependencies in requirements.txt
```

pip3 freeze > requirements.txt  # Python3

```

## Install Requirements
```

pip install -r requirements. txt

```

Generate executable:

```

pyinstaller main.py

```

Generate executable with custom name in a single file:

```

pyinstaller --onefile --name Ordo main.py

```


TODO

- [ ] Evaluate what is mounted already and show appropriate message to user from the start
- [ ] Google Drive is anoying and as is we need to run 'rclone config reconnect <current drive>" every now and then
- [ ] Must work with windwos


---

Maybe: aproach for restructuring the project

```shell

OrdoMount/
│
├── common/
│   ├── __init__.py
│   ├── ui.py               # UI-related functions
│   ├── utils.py            # General utility functions
│   └── other_common_module.py
│
├── windows/
│   ├── __init__.py
│   ├── drive_manager.py    # Windows-specific methods for drive management
│   └── other_windows_module.py
│
├── linux/
│   ├── __init__.py
│   ├── drive_manager.py    # Linux-specific methods for drive management
│   └── other_linux_module.py
│
├── main.py                # Main entry point of your application
└── requirements.txt       # Dependencies for your application


```

## code ideas on this new aproach


### ui.py
```python

# ui.py

import tkinter as tk
from tkinter import ttk
from tkinter import filedialog

def create_root_window():
    root = tk.Tk()
    root.title("Drive Manager")
    root.geometry("600x500")
    root.configure(bg='#1C1C1C')  # Dark background
    root.attributes('-alpha', 0.97)  # Slightly transparent window
    return root

def create_header_frame(root):
    header_frame = tk.Frame(root, bg='#333333')  # Header background
    header_frame.pack(fill='x')
    header_label = tk.Label(header_frame, text="Ordo Mount", bg='#333333', fg='white', font=("Helvetica", 24, "bold"))
    header_label.pack(pady=15)
    return header_frame

def create_main_frame(root):
    main_frame = tk.Frame(root, bg='#1C1C1C')
    main_frame.pack(expand=True, fill='both', padx=20, pady=20)
    return main_frame

def create_drive_menu(main_frame, drive_var, drives, check_mount_status):
    label = tk.Label(main_frame, text="Select Drive:", bg='#1C1C1C', fg='white', font=("Helvetica", 14))
    label.grid(row=0, column=0, sticky='w')
    drive_var.set(drives[0] if drives else "")
    drive_var.trace("w", check_mount_status)  # Check mount status when selection changes
    drive_menu = ttk.OptionMenu(main_frame, drive_var, *drives)
    drive_menu.grid(row=1, column=0, pady=20, sticky='w')
    return drive_menu

def create_mount_path_entry(main_frame, mount_path_var, select_mount_directory):
    label = tk.Label(main_frame, text="Mount Path:", bg='#1C1C1C', fg='white', font=("Helvetica", 14))
    label.grid(row=2, column=0, sticky='w')
    mount_path_entry = tk.Entry(main_frame, textvariable=mount_path_var, font=("Helvetica", 12), width=40)
    mount_path_entry.grid(row=4, column=1, pady=10, sticky='w')
    select_dir_button = tk.Button(main_frame, text="Browse...", command=select_mount_directory, font=("Helvetica", 12), bg='#D1D1D1', fg='#1C1C1C')
    select_dir_button.grid(row=3, column=1, pady=10, sticky='w')
    return mount_path_entry

def create_mount_button(main_frame, mount_drive):
    mount_button = tk.Button(main_frame, text="Mount Drive", command=mount_drive, font=("Helvetica", 14), bg='#D1D1D1', fg='#1C1C1C')
    mount_button.grid(row=2, column=0, pady=10, sticky='w')
    return mount_button

def create_unmount_button(main_frame, unmount_drive):
    unmount_button = tk.Button(main_frame, text="Unmount Drive", command=unmount_drive, font=("Helvetica", 14), bg='#D1D1D1', fg='#1C1C1C')
    unmount_button.grid(row=3, column=0, pady=10, sticky='w')
    return unmount_button

def create_status_widgets(main_frame):
    status_frame = tk.Frame(main_frame, bg='#1C1C1C')
    status_frame.grid(row=1, column=1, padx=30)
    status_canvas = tk.Canvas(status_frame, width=40, height=40, bg='#1C1C1C', highlightthickness=0)
    status_light = status_canvas.create_oval(5, 5, 35, 35, outline="#F44336", fill="#F44336")
    status_canvas.pack()
    mount_status_label = tk.Label(status_frame, text="Unmounted", fg="#F44336", bg='#1C1C1C', font=("Helvetica", 14))
    mount_status_label.pack(pady=10)
    return status_canvas, status_light, mount_status_label

def create_log_text(root):
    log_frame = tk.Frame(root, bg='#1C1C1C')
    log_frame.pack(expand=True, fill='both', padx=20, pady=20)
    log_text = tk.Text(log_frame, bg='#222222', fg='white', font=("Helvetica", 14), height=12)
    log_text.pack(fill='both', expand=True)
    return log_text

```

### utils.py
```python	

# utils.py

import subprocess
import os

def get_available_drives():
    result = subprocess.run(["rclone", "listremotes"], capture_output=True, text=True)
    return result.stdout.strip().split("\n")

def mount_drive(selected_drive, mount_path_var, log_text):
    update_status(log_text, "Mounting...", "#FFC107")  # Yellow for processing
    log_text.insert(tk.END, f"Mounting {selected_drive}...\n")
    root.update_idletasks()  # Update the GUI immediately

    mount_path = mount_path_var.get()

    os.makedirs(mount_path, exist_ok=True)  # Create mount directory
    
    # rclone mount using subprocess
    command = ["rclone", "mount", "--daemon", selected_drive, mount_path, "--allow-non-empty"]
    result = subprocess.run(command, capture_output=True, text=True)
    log_text.insert(tk.END, f"{' '.join(command)}\n")
    log_text.insert(tk.END, result.stdout)

    update_status(log_text, "Mounted", "#4CAF50")  # Green for mounted
    log_text.insert(tk.END, f"{selected_drive} mounted at {mount_path}\n")

def unmount_drive(selected_drive, mount_path_var, log_text):
    update_status(log_text, "Unmounting...", "#FFC107")  # Yellow for processing
    log_text.insert(tk.END, f"Unmounting {selected_drive}...\n")
    root.update_idletasks()  # Update the GUI immediately

    mount_path = mount_path_var.get()

    command = ["fusermount", "-uz", mount_path]
    result = subprocess.run(command, capture_output=True, text=True)
    log_text.insert(tk.END, f"{' '.join(command)}\n")
    log_text.insert(tk.END, result.stdout)

    update_status(log_text, "Unmounted", "#F44336")  # Red for unmounted
    log_text.insert(tk.END, f"{selected_drive} unmounted from {mount_path}\n")

def update_status(log_text, message, color):
    mount_status_label.config(text=message, fg=color)
    status_canvas.itemconfig(status_light, outline=color, fill=color)

def check_mount_status(drive_var, user, log_text):
    selected_drive = drive_var.get()
    mount_path = f"/home/{user}/mounts/{selected_drive.rstrip(':')}"
    result = subprocess.run(["mountpoint", "-q", mount_path])
    if result.returncode == 0:
        update_status(log_text, "Mounted", "#4CAF50")  # Green if mounted
    else:
        update_status(log_text, "Unmounted", "#F44336")  # Red if not mounted

def update_option_menu(menu, var, options):
    menu["menu"].delete(0, "end")
    for option in options:
        menu["menu"].add_command(label=option, command=tk._setit(var, option))
    var.set(options[0] if options else "")

```

---
 now:

```python
# common/drive_manager.py

import subprocess
import os

class DriveManager:
    def get_available_drives(self):
        raise NotImplementedError("Subclasses must implement get_available_drives method")

    def mount_drive(self, selected_drive, mount_path_var, log_text):
        raise NotImplementedError("Subclasses must implement mount_drive method")

    def unmount_drive(self, selected_drive, mount_path_var, log_text):
        raise NotImplementedError("Subclasses must implement unmount_drive method")

    def check_mount_status(self, drive_var, user, log_text):
        raise NotImplementedError("Subclasses must implement check_mount_status method")

    def update_option_menu(self, menu, var, options):
        raise NotImplementedError("Subclasses must implement update_option_menu method")

    def update_status(self, log_text, message, color):
        raise NotImplementedError("Subclasses must implement update_status method")

# linux/drive_manager.py

from common.drive_manager import DriveManager

class LinuxDriveManager(DriveManager):
    def get_available_drives(self):
        result = subprocess.run(["rclone", "listremotes"], capture_output=True, text=True)
        return result.stdout.strip().split("\n")

    def mount_drive(self, selected_drive, mount_path_var, log_text):
        self.update_status(log_text, "Mounting...", "#FFC107")  # Yellow for processing
        log_text.insert(tk.END, f"Mounting {selected_drive}...\n")
        root.update_idletasks()  # Update the GUI immediately

        mount_path = mount_path_var.get()

        os.makedirs(mount_path, exist_ok=True)  # Create mount directory
        
        # rclone mount using subprocess
        command = ["rclone", "mount", "--daemon", selected_drive, mount_path, "--allow-non-empty"]
        result = subprocess.run(command, capture_output=True, text=True)
        log_text.insert(tk.END, f"{' '.join(command)}\n")
        log_text.insert(tk.END, result.stdout)

        self.update_status(log_text, "Mounted", "#4CAF50")  # Green for mounted
        log_text.insert(tk.END, f"{selected_drive} mounted at {mount_path}\n")

    def unmount_drive(self, selected_drive, mount_path_var, log_text):
        self.update_status(log_text, "Unmounting...", "#FFC107")  # Yellow for processing
        log_text.insert(tk.END, f"Unmounting {selected_drive}...\n")
        root.update_idletasks()  # Update the GUI immediately

        mount_path = mount_path_var.get()

        command = ["fusermount", "-uz", mount_path]
        result = subprocess.run(command, capture_output=True, text=True)
        log_text.insert(tk.END, f"{' '.join(command)}\n")
        log_text.insert(tk.END, result.stdout)

        self.update_status(log_text, "Unmounted", "#F44336")  # Red for unmounted
        log_text.insert(tk.END, f"{selected_drive} unmounted from {mount_path}\n")

    def check_mount_status(self, drive_var, user, log_text):
        selected_drive = drive_var.get()
        mount_path = f"/home/{user}/mounts/{selected_drive.rstrip(':')}"
        result = subprocess.run(["mountpoint", "-q", mount_path])
        if result.returncode == 0:
            self.update_status(log_text, "Mounted", "#4CAF50")  # Green if mounted
        else:
            self.update_status(log_text, "Unmounted", "#F44336")  # Red if not mounted

    def update_option_menu(self, menu, var, options):
        menu["menu"].delete(0, "end")
        for option in options:
            menu["menu"].add_command(label=option, command=tk._setit(var, option))
        var.set(options[0] if options else "")
```
In this adaptation:

We created a common package to hold the drive_manager.py module, which contains the base class DriveManager.
We created a linux package to hold the Linux-specific implementation of the DriveManager class (LinuxDriveManager).
We implemented Linux-specific methods for mounting, unmounting, checking status, and updating options in drive_manager.py.
We left the Windows-specific implementation as a placeholder with //TODO comments to indicate that it needs to be implemented.
---