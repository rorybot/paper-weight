# Symptom
Fixture host is confirmed up and reachable (`curl http://172.16.42.1:8080/`
returns 200 from the host, ping to the device is clean), but the device
screen still shows a browser-level "can't be reached" error.

# Root cause
The on-device kiosk browser does not automatically retry a page it already
failed to load — it just sits on the cached error from whenever the host was
last down, even after connectivity is restored.

# Fix
Force a reload:
```
cd ~/repos/paper-weight/scripts && ./device-kiosk.sh restart
```
Then re-check the physical screen before assuming anything is still broken.

# Status
Resolved.
