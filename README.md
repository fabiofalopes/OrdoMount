# OrdoMount

Wrapper for rclone that to help mount remote drives locally, integrating cloud storage with file system

---

'''

pip3 freeze > requirements.txt  # Python3

'''

Generate executable:

'''

pyinstaller main.py

'''

Generate executable with custom name in a single file:

'''
pyinstaller --onefile --name Ordo main.py
'''


TODO

- [ ] Evaluate what is mounted already and show appropriate message to user from the start
- [ ] Google Drive is anoying and as is we need to run 'rclone config reconnect <current drive>" every now and then