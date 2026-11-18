#!/usr/bin/env python3
# ~/nikita-shell/scripts/system-stats.py
#
# The desktop's system stats, for Quickshell.
#
#   system-stats.py            one JSON line per second (CPU, memory, disk, network,
#                              GPU, fans), while the Performance tab is visible
#   system-stats.py --machine  a single line with what doesn't change: model, CPU,
#                              GPUs, kernel, packages... (the machine card).
#
# CPU and network are rates: they need two samples, so the first line comes out
# one second after starting.
import json
import os
import platform
import shutil
import subprocess
import sys
import time


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def read_int(path):
    v = read(path)
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def cpu_sample():
    fields = read("/proc/stat", "").split("\n")[0].split()[1:]
    n = [int(x) for x in fields[:8]] + [0] * (8 - len(fields[:8]))
    idle = n[3] + n[4]
    return idle, sum(n)


def hwmon():
    base = "/sys/class/hwmon"
    try:
        names = sorted(os.listdir(base))
    except OSError:
        return []
    return [(os.path.join(base, h), read(os.path.join(base, h, "name"), "")) for h in names]


def cpu_temp(sensors):
    for path, name in sensors:
        if name in ("coretemp", "k10temp", "zenpower"):
            t = read_int(os.path.join(path, "temp1_input"))
            if t is not None:
                return round(t / 1000, 1)
    for path, name in sensors:
        if name in ("acpitz", "x86_pkg_temp"):
            t = read_int(os.path.join(path, "temp1_input"))
            if t is not None:
                return round(t / 1000, 1)
    return None


def memory():
    kv = {}
    for line in read("/proc/meminfo", "").split("\n"):
        k, _, v = line.partition(":")
        parts = v.split()
        if parts:
            kv[k] = int(parts[0]) * 1024
    total = kv.get("MemTotal", 0)
    free = kv.get("MemAvailable", 0)
    return {"used": total - free, "total": total,
            "swap": kv.get("SwapTotal", 0) - kv.get("SwapFree", 0), "swapTotal": kv.get("SwapTotal", 0)}


def disk():
    try:
        d = shutil.disk_usage("/")
        return {"used": d.used, "total": d.total}
    except OSError:
        return None


def net_sample():
    rx = tx = 0
    for line in read("/proc/net/dev", "").split("\n")[2:]:
        name, _, data = line.partition(":")
        name = name.strip()
        if not name or name == "lo" or name.startswith(("docker", "veth", "br-", "virbr")):
            continue
        c = data.split()
        if len(c) >= 9:
            rx += int(c[0])
            tx += int(c[8])
    return rx, tx


def pci_name(vendor, device):
    """A card's name in pci.ids (vendor and device in hex, without 0x)."""
    try:
        with open("/usr/share/hwdata/pci.ids", encoding="utf-8", errors="replace") as f:
            in_vendor = False
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                if not line.startswith("\t"):
                    in_vendor = line[:4].lower() == vendor
                    continue
                if in_vendor and not line.startswith("\t\t") and line[1:5].lower() == device:
                    name = line[5:].strip()
                    # "UHD Graphics 620" rather than the whole family in brackets.
                    if "[" in name and "]" in name:
                        name = name[name.index("[") + 1:name.index("]")]
                    return name
    except OSError:
        pass
    return None


# hwmon chips that belong to a GPU: their fans are the card's, not the case's.
GPU_HWMON = ("amdgpu", "radeon", "nouveau")
MIB = 1024 * 1024


def first_int(*paths):
    for path in paths:
        v = read_int(path)
        if v is not None:
            return v
    return None


class Gpus:
    """Every GPU, sampled once a second.

    Usage comes from wherever each driver keeps it. AMD writes it
    (gpu_busy_percent). Intel only says how long the GPU slept (RC6 residency), so
    usage is the rest of the time: that needs two samples. NVIDIA's driver tells it
    through nvidia-smi, asked every 2 s and ONLY while the card is awake: asking a
    sleeping one would wake it (on a hybrid laptop it sleeps when unused). While
    the tab is open and the card awake, those queries may keep it from sleeping.

    Temperature and fan come from the card's own hwmon folder (AMD, nouveau) or
    nvidia-smi. Intel's GPU has neither: it lives on the CPU's chip and shares its
    temperature and fan; it gets its clock (now / top) instead."""

    def __init__(self):
        self.idle = {}                  # card -> (idle ms, monotonic s)
        self.smi, self.smi_at = {}, 0.0

    def sample(self, with_name=True):
        base = "/sys/class/drm"
        try:
            cards = sorted(c for c in os.listdir(base) if c.startswith("card") and c[4:].isdigit())
        except OSError:
            return []
        out = []
        for card in cards:
            dev = os.path.join(base, card, "device")
            uevent = dict(l.split("=", 1) for l in read(os.path.join(dev, "uevent"), "").split("\n") if "=" in l)
            driver = uevent.get("DRIVER", "")
            if not driver:
                continue
            g = {"card": card, "driver": driver, "name": driver, "usage": None, "temp": None,
                 "freq": None, "fan": None, "vram": None,
                 "awake": read(os.path.join(dev, "power/runtime_status"), "active") != "suspended"}
            if with_name and "PCI_ID" in uevent:
                a, _, b = uevent["PCI_ID"].lower().partition(":")
                g["name"] = pci_name(a, b) or driver
            used, total = read_int(os.path.join(dev, "mem_info_vram_used")), read_int(os.path.join(dev, "mem_info_vram_total"))
            if used is not None and total:
                g["vram"] = [used, total]

            if driver in ("i915", "xe"):
                self.intel(os.path.join(base, card), dev, g)
            elif driver == "amdgpu":
                self.amd(dev, g)
            elif driver == "nvidia":
                self.nvidia(uevent.get("PCI_SLOT_NAME", ""), g)

            # The card's own sensors (amdgpu, nouveau, radeon).
            try:
                own = [os.path.join(dev, "hwmon", h) for h in sorted(os.listdir(os.path.join(dev, "hwmon")))]
            except OSError:
                own = []
            for h in own:
                t = read_int(os.path.join(h, "temp1_input"))
                if g["temp"] is None and t is not None:
                    g["temp"] = round(t / 1000, 1)
                rpm = read_int(os.path.join(h, "fan1_input"))
                if g["fan"] is None and rpm is not None:
                    g["fan"] = {"rpm": rpm}

            apu = driver == "amdgpu" and (g["vram"] is None or g["vram"][1] < 2 * 1024 * MIB)
            g["kind"] = "integrated" if driver in ("i915", "xe") or apu else "dedicated"
            out.append(g)
        return out

    def intel(self, card, dev, g):
        idle = first_int(f"{card}/gt/gt0/rc6_residency_ms", f"{card}/power/rc6_residency_ms",
                         f"{dev}/tile0/gt0/gtidle/idle_residency_ms")
        now = time.monotonic()
        if idle is not None:
            prev = self.idle.get(card)
            self.idle[card] = (idle, now)
            if prev and now > prev[1]:
                wall = (now - prev[1]) * 1000
                g["usage"] = max(0, min(100, round(100 * (1 - (idle - prev[0]) / wall))))
        cur = first_int(f"{card}/gt/gt0/rps_act_freq_mhz", f"{card}/gt_act_freq_mhz", f"{dev}/tile0/gt0/freq0/act_freq")
        top = first_int(f"{card}/gt/gt0/rps_RP0_freq_mhz", f"{card}/gt_RP0_freq_mhz",
                        f"{card}/gt/gt0/rps_max_freq_mhz", f"{card}/gt_max_freq_mhz", f"{dev}/tile0/gt0/freq0/rp0_freq")
        if cur is not None and top:
            g["freq"] = [cur, top]

    def amd(self, dev, g):
        g["usage"] = read_int(os.path.join(dev, "gpu_busy_percent"))
        levels = [l for l in read(os.path.join(dev, "pp_dpm_sclk"), "").split("\n") if ":" in l]

        def mhz(line):
            digits = "".join(ch for ch in line.split(":", 1)[1].split("M")[0] if ch.isdigit())
            return int(digits) if digits else 0

        cur = next((mhz(l) for l in levels if "*" in l), None)
        if cur:
            g["freq"] = [cur, max(mhz(l) for l in levels)]

    def nvidia(self, slot, g):
        if not g["awake"] or not shutil.which("nvidia-smi"):
            return
        if time.monotonic() - self.smi_at >= 2:
            self.smi_at, self.smi = time.monotonic(), {}
            try:
                r = subprocess.run(["nvidia-smi", "--query-gpu=pci.bus_id,utilization.gpu,temperature.gpu,fan.speed,"
                                    "clocks.gr,clocks.max.gr,memory.used,memory.total", "--format=csv,noheader,nounits"],
                                   capture_output=True, text=True, timeout=3)
                for line in r.stdout.splitlines():
                    f = [x.strip() for x in line.split(",")]
                    if len(f) == 8:
                        self.smi[f[0].lower()[-7:]] = f
            except (OSError, subprocess.SubprocessError):
                pass
        row = self.smi.get(slot.lower()[-7:]) or (next(iter(self.smi.values())) if len(self.smi) == 1 else None)
        if not row:
            return

        def num(v):
            try:
                return float(v)
            except ValueError:
                return None     # "[N/A]": laptops often don't report the fan

        util, temp, fan, clk, top, used, total = (num(x) for x in row[1:])
        g["usage"] = None if util is None else round(util)
        g["temp"] = temp
        g["fan"] = None if fan is None else {"percent": round(fan)}
        if clk is not None and top:
            g["freq"] = [round(clk), round(top)]
        if used is not None and total:
            g["vram"] = [int(used * MIB), int(total * MIB)]


def gpus(sensors, with_name=True):
    """The GPUs once, without the usage that needs two samples (machine card)."""
    return Gpus().sample(with_name)


def fans(sensors):
    v = []
    for path, name in sensors:
        if name in GPU_HWMON:
            continue
        for i in range(1, 9):
            rpm = read_int(os.path.join(path, f"fan{i}_input"))
            if rpm is None:
                continue
            label = read(os.path.join(path, f"fan{i}_label")) or f"Fan {i}"
            v.append({"name": label, "rpm": rpm})
    return v


def machine():
    sensors = hwmon()
    cpu = None
    for line in read("/proc/cpuinfo", "").split("\n"):
        if line.startswith("model name"):
            cpu = line.split(":", 1)[1].strip()
            break
    cores = os.cpu_count()
    os_name = None
    for line in read("/etc/os-release", "").split("\n"):
        if line.startswith("PRETTY_NAME="):
            os_name = line.split("=", 1)[1].strip('"')
    model = " ".join(x for x in (read("/sys/class/dmi/id/sys_vendor"), read("/sys/class/dmi/id/product_name")) if x)
    try:
        packages = len(subprocess.run(["pacman", "-Qq"], capture_output=True, text=True, timeout=5).stdout.split())
    except (OSError, subprocess.SubprocessError):
        packages = None
    try:
        hypr = json.loads(subprocess.run(["hyprctl", "version", "-j"], capture_output=True, text=True, timeout=3).stdout).get("tag")
    except (OSError, ValueError, subprocess.SubprocessError):
        hypr = None
    boot = time.time() - float(read("/proc/uptime", "0").split()[0])
    m = memory()
    print(json.dumps({
        "model": model or None, "cpu": cpu, "cores": cores, "os": os_name,
        "kernel": platform.release(), "host": platform.node(), "user": os.environ.get("USER"),
        "shell": os.path.basename(os.environ.get("SHELL", "")) or None, "packages": packages,
        "hyprland": hypr, "gpus": [g["name"] for g in gpus(sensors)],
        "memory": m["total"], "disk": disk(), "boot": boot,
    }), flush=True)


def loop():
    sensors = hwmon()
    cpu_prev = cpu_sample()
    net_prev, t_prev = net_sample(), time.monotonic()
    sampler = Gpus()
    names = {g["card"]: g["name"] for g in sampler.sample()}     # also the first RC6 sample
    n = 0
    while True:
        time.sleep(1)
        cpu_now = cpu_sample()
        di, dt = cpu_now[0] - cpu_prev[0], cpu_now[1] - cpu_prev[1]
        cpu_prev = cpu_now
        net_now, t_now = net_sample(), time.monotonic()
        secs = max(0.001, t_now - t_prev)
        rx = max(0, (net_now[0] - net_prev[0]) / secs)
        tx = max(0, (net_now[1] - net_prev[1]) / secs)
        net_prev, t_prev = net_now, t_now
        gs = sampler.sample(with_name=False)
        for g in gs:
            g["name"] = names.get(g["card"], g["driver"])
        out = {
            "cpu": round(100 * (1 - di / dt)) if dt > 0 else 0,
            "cpuTemp": cpu_temp(sensors),
            "memory": memory(),
            "net": {"rx": rx, "tx": tx},
            "gpus": gs,
            "fans": fans(sensors),
        }
        # Disk usage changes slowly: every five seconds is enough.
        if n % 5 == 0:
            out["disk"] = disk()
        n += 1
        print(json.dumps(out), flush=True)


if __name__ == "__main__":
    try:
        machine() if "--machine" in sys.argv else loop()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
