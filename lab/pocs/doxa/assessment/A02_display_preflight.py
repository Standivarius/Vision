"""Read-only A02 preflight: independent 3/4 display topology and unlock."""
import ctypes as c
import json
from win_observer import monitors, physical_lock
from A02_display_roles import roles


def main():
    u=c.WinDLL("user32",use_last_error=True)
    u.SetProcessDpiAwarenessContext(c.c_void_p(-4))
    detected=monitors()
    mapping=roles(detected)
    locked=physical_lock(mapping)
    kernel=c.WinDLL("kernel32",use_last_error=True)
    kernel.GetCurrentProcessId.restype=c.c_ulong
    kernel.WTSGetActiveConsoleSessionId.restype=c.c_ulong
    kernel.ProcessIdToSessionId.argtypes=[c.c_ulong,c.POINTER(c.c_ulong)]
    process_session=c.c_ulong(0)
    valid=bool(kernel.ProcessIdToSessionId(kernel.GetCurrentProcessId(),c.byref(process_session)))
    console_session=int(kernel.WTSGetActiveConsoleSessionId())
    is_console=valid and int(process_session.value)==console_session
    result={"display_count":len(detected),"roles":mapping,
            "unlocked":locked is False,"topology_ok":bool(mapping),
            "session_id":int(process_session.value) if valid else None,
            "console_session_id":console_session,
            "physical_console":is_console,
            "environment":"PHYSICAL_CONSOLE_SOFTWARE_OUTPUT_NOT_CAMERA"}
    print(json.dumps(result))
    return 0 if bool(mapping) and locked is False and is_console else 4


if __name__=="__main__":
    raise SystemExit(main())
