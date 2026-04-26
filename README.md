# caps

A pure-Swift Hyperkey replacement for macOS. Caps Lock becomes a Hyper key
(⌃⌥⌘⇧) when held, and Escape when tapped. ~80 lines of Swift, ~6 MB RAM,
no kernel extension, no AppKit UI.

## How it works

1. `hidutil` remaps Caps Lock (HID 0x39) → F19 (HID 0x6E) at the HID layer.
2. A `CGEventTap` watches for F19 keyDown/keyUp.
3. While F19 is held, the tap unions ⌃⌥⌘⇧ into every other key event.
4. If F19 is released within 200 ms with no other key pressed, Escape is posted.

F19 is used because it has a real virtual keycode but no default OS binding,
so the tap sees clean down/up events without macOS swallowing them.

## Requirements

- macOS 13+ (uses `SMAppService`-style LaunchAgents and modern `hidutil`)
- Apple Silicon or Intel — both fine
- `swiftc` (comes with Xcode Command Line Tools)
- `just` — `brew install just`

## Install

```bash
./build.sh                  # compile + sign caps.app
just install                # load both LaunchAgents (hidutil + caps)
```

On first run macOS will prompt for **Accessibility permission** for
`caps.app`. Grant it once in System Settings → Privacy & Security →
Accessibility. The signing identity is stable, so this grant survives
all future rebuilds — no re-permission dance.

System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys: leave
Caps Lock set to **"⇪ Caps Lock"** (the default). The hidutil remap
runs at the HID layer below it.

## Daily use

```bash
just reload     # rebuild + restart (after editing caps.swift)
just status     # show running state + hidutil remap
just logs       # tail stderr
just debug      # run in foreground with CAPS_DEBUG=1 verbose logging
just uninstall  # stop everything (files remain)
```

## Customizing

The behavior is small enough to edit directly in `caps.swift`:

- `HYPER_FLAGS` — which modifiers to inject. Default is the canonical
  Hyper combo. Change to e.g. `[.maskCommand, .maskAlternate]` for a
  different layer.
- `ESCAPE` — what tap-Caps fires. Replace with any virtual keycode.
- `TAP_TIMEOUT` — max ms held to count as a tap (default 200).
- `HYPER_TRIGGER` — virtual keycode of the trigger key. Stays at 0x50
  (F19) unless you also change the hidutil remap target.

After editing, `just reload`.

## Files

```
caps.swift                              # the implementation
build.sh                                # swiftc -O + codesign
justfile                                # task runner
caps.app/                               # signed bundle (output)
.signing/                               # self-signed code-signing cert
~/Library/LaunchAgents/
  dev.nymann.caps.plist                 # runs caps at login
  dev.nymann.caps.remap.plist           # applies hidutil remap at login
```

## Why a self-signed cert

macOS TCC pins Accessibility grants to a binary's Designated Requirement.
For ad-hoc-signed binaries the DR includes the code hash, so every
rebuild invalidates the grant. With a stable signing cert the DR
is `identifier "dev.nymann.caps" and certificate leaf = H"…"` —
both halves stable across rebuilds, so TCC preserves the grant.

The cert lives in a local `.signing/` directory (gitignored — never
commit a code-signing private key) and is imported into the login
keychain. To set this up on a new machine, regenerate the cert and
re-grant Accessibility once. See the `security create-keychain` /
`openssl req` flow if you need the exact commands.

## Performance

Measured against Hyperkey.app 1.56:

| Metric            | Hyperkey | caps    |
|-------------------|----------|---------|
| Resident memory   | 42 MB    | ~6 MB   |
| Threads           | 6–7      | 3       |
| Lifetime CPU rate | 0.19%    | <0.01%  |
| Binary / bundle   | MBs      | 76 KB   |

Both processes are asleep in the run loop almost 100% of the time;
the per-event callback is a few flag operations, well below
measurable latency.
