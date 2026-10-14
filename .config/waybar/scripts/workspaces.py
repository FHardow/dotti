#!/usr/bin/python3
# Workspace state for the custom/ws#N modules.
#
# Waybar's hyprland/workspaces module switches workspaces with the legacy
# "dispatch workspace N" IPC call, which the Lua config rejects, so clicks did
# nothing. Instead, this listener watches Hyprland's event socket, writes one
# JSON file per workspace to $XDG_RUNTIME_DIR/waybar-ws/ and signals waybar so
# each custom/ws#N module re-reads its file. Clicks are handled in config.jsonc.

import fcntl
import json
import os
import signal
import socket
import subprocess

COUNT = 10        # modules custom/ws#1 .. custom/ws#COUNT
PERSISTENT = 5    # always shown; higher ones only while they exist
ICON = "󰊠"
SIGNAL = 8        # must match "signal" in config.jsonc

HYPR = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr",
                    os.environ["HYPRLAND_INSTANCE_SIGNATURE"])
OUT = os.path.join(os.environ["XDG_RUNTIME_DIR"], "waybar-ws")

# Events that never change workspace state; skipped to avoid needless redraws.
IGNORED = {"activewindow", "activewindowv2", "windowtitle", "windowtitlev2",
           "activelayout", "submap", "screencast", "configreloaded",
           "openlayer", "closelayer", "minimized", "bell"}

urgent = set()


def query(cmd):
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(os.path.join(HYPR, ".socket.sock"))
        s.sendall(f"j/{cmd}".encode())
        data = b""
        while chunk := s.recv(65536):
            data += chunk
    return json.loads(data)


def mark_urgent(address):
    for c in query("clients"):
        if c["address"].removeprefix("0x") == address.removeprefix("0x"):
            urgent.add(c["workspace"]["id"])


def render():
    workspaces = {w["id"]: w for w in query("workspaces")}
    monitors = query("monitors")
    visible = {m["activeWorkspace"]["id"] for m in monitors}
    focused = next((m["activeWorkspace"]["id"] for m in monitors if m["focused"]), None)
    urgent.discard(focused)

    for n in range(1, COUNT + 1):
        ws = workspaces.get(n)
        if ws is None and n > PERSISTENT:
            out = {"text": ""}  # empty text hides the module
        else:
            classes = []
            if n == focused:
                classes.append("active")
            elif n in visible:
                classes.append("visible")
            if ws and ws["windows"]:
                classes.append("occupied")
            if n in urgent:
                classes.append("urgent")
            out = {"text": ICON, "tooltip": f"Workspace {n}", "class": classes}
        tmp = os.path.join(OUT, f"{n}.json.tmp")
        with open(tmp, "w") as f:
            json.dump(out, f, ensure_ascii=False)
        os.replace(tmp, os.path.join(OUT, f"{n}.json"))

    subprocess.run(["pkill", f"-RTMIN+{SIGNAL}", "-x", "waybar"], check=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    # Waybar spawns one listener per bar; the extras wait here as standbys.
    lock = open(os.path.join(OUT, "lock"), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    render()
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(os.path.join(HYPR, ".socket2.sock"))
        for line in s.makefile(encoding="utf-8", errors="replace"):
            event, _, data = line.rstrip("\n").partition(">>")
            if event in IGNORED:
                continue
            if event == "urgent":
                mark_urgent(data)
            render()


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    main()
