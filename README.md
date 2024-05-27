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

Maybe aproach

```shell

OrdoMount/
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
├── common/
│   ├── __init__.py
│   ├── drive_manager.py    # Shared methods for drive management
│   └── other_common_module.py
│
├── main.py                # Main entry point of your application
└── requirements.txt       # Dependencies for your application

```