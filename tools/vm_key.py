#!/usr/bin/env python3
"""Send keystrokes to the libvirt VM through the QEMU monitor (no QMP socket)."""
import json, subprocess, sys, time

DOM = "WINMETA"
URI = "qemu:///session"

def mon(payload):
    r = subprocess.run(["virsh", "-c", URI, "qemu-monitor-command", DOM, json.dumps(payload)],
                       capture_output=True, text=True)
    return r.stdout.strip()

CH = {
    "a":"a","b":"b","c":"c","d":"d","e":"e","f":"f","g":"g","h":"h","i":"i",
    "j":"j","k":"k","l":"l","m":"m","n":"n","o":"o","p":"p","q":"q","r":"r",
    "s":"s","t":"t","u":"u","v":"v","w":"w","x":"x","y":"y","z":"z",
    "0":"0","1":"1","2":"2","3":"3","4":"4","5":"5","6":"6","7":"7","8":"8","9":"9",
    " ":"spc",".":"dot",",":"comma",";":"semicolon","'":"apostrophe","/":"slash",
    "\\":"backslash","-":"minus","=":"equal","[":"bracket_left","]":"bracket_right",
    ":":"shift-semicolon","_":"shift-minus","(":"shift-9",")":"shift-0",
}

def key(keys):
    mon({"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":k} for k in keys]}})

def type_text(text):
    for ch in text:
        if ch.isalpha() and ch.isupper():
            key(["shift", ch.lower()])
        else:
            q = CH.get(ch if not ch.isalpha() else ch.lower())
            if not q:
                continue
            if q.startswith("shift-"):
                key(["shift", q[6:]])
            else:
                key([q])
        time.sleep(0.03)

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "run":
        key(["meta_l", "r"]); time.sleep(1.5)
        type_text(sys.argv[2]); time.sleep(0.3)
        key(["ret"])
    elif mode == "type":
        type_text(sys.argv[2])
    elif mode == "key":
        key(sys.argv[2].split("+"))
    print("ok")
