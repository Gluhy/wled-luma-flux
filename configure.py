#!/usr/bin/env python3
"""Keeps the three things WLED stores separately in agreement:
LED outputs, segments and the boot preset.

    configure.py <host> sync                 # segments follow the current outputs
    configure.py <host> set 144 60 90 30 20  # new strip lengths + segments
    configure.py <host> check                # report only, changes nothing

Without this, changing a strip's length does nothing visible: the segment
bounds sit frozen in the boot preset and never follow the outputs.
"""
import json
import sys
import time
import urllib.request

PRESET = 1
PRESET_NAME = "Luma Flux"
FALLBACK_COLS = [[255, 169, 87], [255, 90, 20], [80, 180, 255],
                 [255, 60, 150], [80, 230, 150]]


def call(host, path, obj=None, timeout=20):
    url = "http://%s%s" % (host, path)
    if obj is None:
        return json.loads(urllib.request.urlopen(url, timeout=timeout).read().decode("utf-8"))
    data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json; charset=utf-8"})
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read().decode("utf-8"))


def set_lengths(host, lengths):
    """Rewrites the outputs to new lengths, keeping pins and LED type."""
    cfg = call(host, "/json/cfg")
    led = cfg["hw"]["led"]
    buses = led["ins"]
    if len(lengths) != len(buses):
        sys.exit("You have %d outputs but gave %d lengths." % (len(buses), len(lengths)))

    start = 0
    for bus, ln in zip(buses, lengths):
        bus["start"] = start
        bus["len"] = ln
        start += ln
    led["total"] = start

    call(host, "/json/cfg", {"hw": {"led": {"total": start, "ins": buses}}})
    time.sleep(2)


def rebuild_segments(host):
    """One segment per output, then store them in the boot preset."""
    buses = call(host, "/json/cfg")["hw"]["led"]["ins"]
    old = {s["id"]: s for s in call(host, "/json/state")["seg"]}

    segs = []
    for i, bus in enumerate(buses):
        prev = old.get(i, {})
        col = (prev.get("col") or [None])[0] or FALLBACK_COLS[i % len(FALLBACK_COLS)]
        segs.append({
            "id": i, "start": bus["start"], "stop": bus["start"] + bus["len"],
            "grp": 1, "spc": 0, "n": "Strip %d" % (i + 1), "on": True,
            "bri": prev.get("bri", 255), "sel": True,
            "col": [col[:3], [0, 0, 0], [0, 0, 0]],
            "fx": prev.get("fx", 0), "sx": prev.get("sx", 128),
            "ix": prev.get("ix", 128), "pal": prev.get("pal", 0),
            # mirror and reverse are layout choices, not decoration: losing them
            # on a rebuild silently changes how every effect looks
            "mi": prev.get("mi", False), "rev": prev.get("rev", False),
        })

    # segments beyond the output count must go, or they linger as orphans
    for i in old:
        if i >= len(buses):
            segs.append({"id": i, "stop": 0})

    call(host, "/json/state", {"mainseg": 0, "seg": segs})
    time.sleep(1)
    call(host, "/json/state",
         {"psave": PRESET, "n": PRESET_NAME, "ib": True, "sb": True})
    call(host, "/json/cfg", {"def": {"ps": PRESET}})


def report(host):
    buses = call(host, "/json/cfg")["hw"]["led"]["ins"]
    state = call(host, "/json/state")
    live = {s["id"]: s for s in state["seg"] if s["stop"] > s["start"]}

    print("\n strip  GPIO   output         segment        agree")
    ok = True
    for i, bus in enumerate(buses):
        b0, b1 = bus["start"], bus["start"] + bus["len"]
        seg = live.get(i)
        if seg:
            s0, s1 = seg["start"], seg["stop"]
            match = (b0, b1) == (s0, s1)
            segtxt = "%4d-%-4d" % (s0, s1)
        else:
            match, segtxt = False, "  none   "
        ok = ok and match
        print("   %d    %-5s  %4d-%-4d %4d   %s      %s"
              % (i + 1, bus["pin"][0], b0, b1, bus["len"], segtxt, "yes" if match else "NO"))
    print("\n %d LEDs total" % sum(b["len"] for b in buses))
    print(" boot preset: %s" % call(host, "/json/cfg")["def"].get("ps"))
    print(" %s\n" % ("Outputs and segments agree." if ok
                     else "WARNING: out of step — run 'sync'."))
    return ok


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    host, mode = sys.argv[1], sys.argv[2]

    if mode == "set":
        lengths = [int(x) for x in sys.argv[3:]]
        if not lengths:
            sys.exit("Give a length for every strip, e.g.: set 144 60 90 30 20")
        print("Setting strip lengths: %s" % ", ".join(str(x) for x in lengths))
        set_lengths(host, lengths)
        rebuild_segments(host)
    elif mode == "sync":
        print("Rebuilding segments to match the current outputs")
        rebuild_segments(host)
    elif mode == "check":
        sys.exit(0 if report(host) else 1)
    else:
        sys.exit(__doc__)

    report(host)


if __name__ == "__main__":
    main()
