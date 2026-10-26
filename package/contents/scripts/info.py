#!/usr/bin/env python3
"""Print {connector: {"label": monitor name, "peak": calibrated max nits or null}} as JSON."""
import glob, json, os

def edid_label(path):
    try:
        data = open(path, "rb").read()
    except OSError:
        return None
    if len(data) < 128:
        return None
    for off in (54, 72, 90, 108):
        d = data[off:off + 18]
        if d[:3] == b"\0\0\0" and d[3] == 0xFC:
            name = d[5:].split(b"\n")[0].decode("ascii", "replace").strip()
            if name:
                return name
    m = (data[8] << 8) | data[9]
    return "".join(chr(((m >> s) & 31) + 64) for s in (10, 5, 0))

labels = {}
for p in glob.glob("/sys/class/drm/card*-*/edid"):
    connector = os.path.basename(os.path.dirname(p)).split("-", 1)[1]
    label = edid_label(p)
    if label:
        labels[connector] = label

peaks = {}
try:
    cfg = json.load(open(os.path.expanduser("~/.config/kwinoutputconfig.json")))
    for section in cfg:
        if section.get("name") == "outputs":
            for o in section["data"]:
                peaks[o.get("connectorName")] = o.get("maxPeakBrightnessOverride")
except (OSError, ValueError):
    pass

print(json.dumps({c: {"label": labels.get(c), "peak": peaks.get(c) or None}
                  for c in set(labels) | set(peaks)}))
