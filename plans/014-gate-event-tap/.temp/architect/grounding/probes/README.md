# Probes run on this machine (macOS 26.6, MacBook Pro, 2026-10-17)

All probes are command-line Swift programs under `tap-gating/`, compiled with `swiftc -O -swift-version 5` from the Xcode 26 toolchain and run from this session, which `AXIsProcessTrusted()` reports as trusted. Each installs a session event tap (`.cgSessionEventTap`, `.headInsertEventTap`, `.defaultTap`) on its own run-loop thread exactly as `ClickTap` does, posts zero-delta pixel scroll events (`scrollWheelEventScrollPhase = changed`) to the HID tap from the same process, and removes the tap before exiting. Nothing is left installed. Raw output is in the `*.txt` files beside each program.

## tap-gating/main.swift (runs: run-1.txt, run-2.txt)

| Phase | What was done | Printed |
|---|---|---|
| A, G | No tap installed; 2000 events posted | Process CPU 0.35 ms / 0.42 ms for the posting alone (the baseline) |
| B | Tap installed with the shipped mask (1,2,3,4,6,7,22,25,26,27,29,30,34), enabled; 2000 events posted | 2000 of 2000 callbacks; tap thread CPU 43.6 ms (21.8 µs/event) in run 1, 27.1 ms (13.5 µs/event) in run 2 |
| C | `CGEvent.tapEnable(tap:enable:false)` called from a thread that is neither main nor the tap thread; 2000 events posted | `tapIsEnabled` false; **0 of 2000 callbacks; tap thread CPU 0.000 ms**; process CPU 0.47 / 0.67 ms (the baseline) |
| D | `tapEnable(true)` from that foreign thread, one event posted right after the call returned | The call took 127 µs (run 1) / 2583 µs (run 2, one outlier); **the event posted right after it was delivered (1 of 1)** |
| F | 2000 enable/disable toggles from the foreign thread while 2000 events were posted from main | 143 / 150 ms total, **72-75 µs per toggle**; no crash; final `tapIsEnabled` matched the last call |
| E | Tap whose mask holds only left mouse down (1 << 1), enabled; 2000 scroll events posted | **0 callbacks; tap thread CPU 0.000 ms**; process CPU at the baseline |

Conclusions drawn: a disabled tap is not sent events and costs the tap thread nothing, the same as no tap; the window server applies the event mask on its side, so a tap whose mask excludes a type is not woken for it; `tapEnable` is safe to call from a thread that is neither main nor the tap thread, takes on the order of 0.1 ms, and takes effect before it returns.

## tap-gating/self-disable.swift (runs: self-disable-run-1.txt, -2-gap2ms.txt, -3-gap8ms.txt)

The callback calls `tapEnable(false)` on its 500th event while another thread keeps posting.

| Posting rate | Disable call from inside the callback took | Events delivered after the disable | Then enable twice, post one |
|---|---|---|---|
| As fast as possible (3000 events) | 50 ms | 10 | 1 callback |
| One every 2 ms (500 Hz) | 30 µs | 1 | 1 callback |
| One every 8 ms (125 Hz) | 61 µs | 1 | 33 callbacks (the poster was still running: `usleep(8000)` overshoots, so its last events landed after the re-enable; not a queued flood, since phase C above shows a disabled tap queues nothing) |

Conclusions drawn: the tap can disable itself from its own callback, and at trackpad event rates that costs tens of microseconds; the 50 ms case is the poster and the disable sharing the process's one connection to the window server under a storm the real app never produces. One event already in flight can still reach the callback after a disable, so the callback must keep deciding every event it is handed, gate or no gate. `tapEnable(true)` on an enabled tap is harmless.

## tap-gating/out-of-band.swift (run: out-of-band-run-1.txt)

Mask: scroll only. Nothing posted. Ten `tapEnable(false)` / `tapEnable(true)` cycles from a foreign thread, 200 ms apart.

Printed: out-of-band callbacks by type = `ffffffff:10`; real scroll events seen meanwhile = 0; other types = none.

Conclusion drawn: **every `tapEnable(false)` we issue ourselves delivers one `tapDisabledByUserInput` (0xFFFFFFFF) event to the callback**, asynchronously, on the tap thread; `tapEnable(true)` delivers nothing. Today's `ClickTap.handle` re-enables the tap on that type, so a gate that leaves that handler as it is re-enables itself on every disable. The handler has to tell our own disable's echo from a disable by the system.
