# Symptom
Device was reachable, then suddenly `ping 172.16.42.2` / the kiosk UI can't be
reached, with nothing changed in app or host code.

# Root cause
The `172.16.42.1` address on the USB NCM gadget interface (`enp0s20f0u*u*` —
exact name shifts across replugs/ports) is sometimes only a short-lived
dynamic/link-local lease (`valid_lft` seen as low as ~28s), not a stable
static one. When the lease expires, the host side of the link silently drops
even though the interface itself stays `UP`.

# Fix
```
ip -4 -o link show up | grep enp0s20f0u   # find the current interface name
sudo ip addr replace 172.16.42.1/24 dev <iface>
```
Automated in `scripts/try-kick-device.sh`.

# Status
Mitigated (manual/scripted re-apply works every time it's recurred so far;
no permanent fix — e.g. a udev rule to force a static lease — has been added).
