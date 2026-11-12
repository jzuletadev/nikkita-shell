#!/usr/bin/env python3
# ~/nikkita-shell/scripts/bt-pair.py
#
# Pairs, trusts and connects one Bluetooth device, for Settings → Bluetooth.
#
#   bt-pair.py AA:BB:CC:DD:EE:FF
#
# Pairing needs an agent to answer BlueZ, and Quickshell has none. This one lives only
# for this run: it confirms this device (PIN "0000" for old ones) and refuses any
# other. A device that shows a code to type (some keyboards) needs `bluetoothctl`.
#
# Prints one JSON line: {"ok": true} or {"ok": false, "error": "..."}.
import json
import sys

from gi.repository import Gio, GLib

AGENT_PATH = "/dev/hyprlandfromscratch/agent"
AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
    <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
    <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
    <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
    <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
    <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="Cancel"/>
  </interface>
</node>"""

WORDS = {
    "org.bluez.Error.AuthenticationFailed": "it refused the pairing. Put it in pairing mode and try again",
    "org.bluez.Error.AuthenticationCanceled": "the pairing was cancelled. Put it in pairing mode and try again",
    "org.bluez.Error.AuthenticationRejected": "it refused the pairing. Put it in pairing mode and try again",
    "org.bluez.Error.AuthenticationTimeout": "it didn't answer in time. Put it in pairing mode and try again",
    "org.bluez.Error.ConnectionAttemptFailed": "it didn't answer. Is it on and close?",
    "org.bluez.Error.InProgress": "it is already pairing",
    "org.bluez.Error.NotReady": "Bluetooth is off",
}


def done(ok, error=""):
    print(json.dumps({"ok": True} if ok else {"ok": False, "error": error}), flush=True)
    loop.quit()


def words(err):
    name = Gio.DBusError.get_remote_error(err) or ""
    message = Gio.DBusError.strip_remote_error(err) if Gio.DBusError.is_remote_error(err) else str(err)
    if "profile-unavailable" in message:
        return "it paired, but no audio profile answered. Is PipeWire's Bluetooth support (pipewire-audio) installed?"
    if "page-timeout" in message or "Host is down" in message:
        return "it didn't answer. Is it on and close? If it is connected to a phone, disconnect it there"
    return WORDS.get(name, message or name or "unknown error")


def main():
    global loop
    if len(sys.argv) != 2:
        print(json.dumps({"ok": False, "error": "usage: bt-pair.py ADDRESS"}))
        return 2
    address = sys.argv[1].upper()
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    loop = GLib.MainLoop()

    objects = bus.call_sync("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
                            None, None, Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
    device = next((path for path, ifaces in objects.items()
                   if ifaces.get("org.bluez.Device1", {}).get("Address", "").upper() == address), None)
    if device is None:
        print(json.dumps({"ok": False, "error": "it isn't in range any more: search again"}))
        return 1

    # The agent: yes to this device, no to anyone else.
    def agent_call(conn, sender, path, iface, method, params, invocation):
        args = params.unpack()
        if method in ("Release", "Cancel", "DisplayPinCode", "DisplayPasskey"):
            invocation.return_value(None)
        elif args and args[0] != device:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Not the device being paired")
        elif method == "RequestPinCode":
            invocation.return_value(GLib.Variant("(s)", ("0000",)))
        elif method == "RequestPasskey":
            invocation.return_value(GLib.Variant("(u)", (0,)))
        else:   # RequestConfirmation, RequestAuthorization, AuthorizeService
            invocation.return_value(None)

    node = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
    reg = bus.register_object(AGENT_PATH, node.interfaces[0], agent_call, None, None)
    manager = ("org.bluez", "/org/bluez", "org.bluez.AgentManager1")
    bus.call_sync(*manager, "RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, "NoInputNoOutput")),
                  None, Gio.DBusCallFlags.NONE, 5000, None)
    bus.call_sync(*manager, "RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)),
                  None, Gio.DBusCallFlags.NONE, 5000, None)

    def connected(source, result):
        try:
            bus.call_finish(result)
            done(True)
        except GLib.Error as err:
            if Gio.DBusError.get_remote_error(err) == "org.bluez.Error.AlreadyConnected":
                done(True)
            else:
                done(False, "Paired, but couldn't connect: " + words(err))

    def paired(source, result):
        try:
            bus.call_finish(result)
        except GLib.Error as err:
            if Gio.DBusError.get_remote_error(err) != "org.bluez.Error.AlreadyExists":
                done(False, "Couldn't pair: " + words(err))
                return
        # Trusted: it may connect on its own next time.
        bus.call_sync("org.bluez", device, "org.freedesktop.DBus.Properties", "Set",
                      GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))),
                      None, Gio.DBusCallFlags.NONE, 5000, None)
        bus.call("org.bluez", device, "org.bluez.Device1", "Connect", None, None,
                 Gio.DBusCallFlags.NONE, 30000, None, connected)

    bus.call("org.bluez", device, "org.bluez.Device1", "Pair", None, None,
             Gio.DBusCallFlags.NONE, 40000, None, paired)
    GLib.timeout_add_seconds(75, lambda: done(False, "it took too long. Put it in pairing mode and try again"))
    loop.run()

    try:
        bus.call_sync(*manager, "UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)),
                      None, Gio.DBusCallFlags.NONE, 5000, None)
    except GLib.Error:
        pass
    bus.unregister_object(reg)
    return 0


loop = None
if __name__ == "__main__":
    sys.exit(main())
