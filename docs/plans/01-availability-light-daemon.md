# keyboardio2mqtt — the availability light daemon

## Why this exists

Etienne wants the keys of his Keyboardio Model 100 to show whether he is available. Home
Assistant already knows — it can see whether he is in a meeting, on a call, or free. What is
missing is a way for Home Assistant to colour the keyboard.

This daemon is that way. It runs on the computer the keyboard is plugged into, announces the
keyboard to Home Assistant as a single light, and turns Home Assistant's colour, brightness and
on/off commands into commands the keyboard understands.

It is deliberately built the same way as `~/Developer/ambx2mqtt`, which does the same job for a
Philips amBX light set. **Read that repository before starting.** Its shape, its naming, its
tests and its documentation are the reference for this one. Where this plan is silent, do what
ambx2mqtt does.

## What the keyboard offers

The keyboard runs custom Kaleidoscope firmware. That firmware is being built separately, in
`~/Developer/Kaleidoscope` and `~/Developer/keyboardio-config`, and is **not** part of this
work. It gives you exactly one thing, over the keyboard's USB serial port:

```
availability.color <red> <green> <blue>\n
```

Each value is 0–255. The whole board fades to that colour over about two seconds. Sending a new
colour part-way through a fade simply redirects the fade; there is no queue and no flicker. The
keyboard replies with a single line containing `.` and nothing else.

Black (`0 0 0`) fades the board to dark. That is how "off" is expressed.

There is no way to read the colour back. Like ambx2mqtt, what Home Assistant shows is always
*what was last asked for*, never a reading from the hardware.

The firmware also makes the availability light the board's default mode, so it is showing
whenever the keyboard is plugged in. **The daemon must never change the keyboard's LED mode.**
If Etienne switches to another mode by hand, the daemon carries on sending colours to a mode
nobody can see, and that is correct — it does not fight him for control of the board.

### Brightness is the daemon's job, not the keyboard's

The keyboard does have a brightness command of its own, but it writes the value to the
keyboard's permanent memory. Writing that four times a minute would wear the memory out. So the
daemon does what ambx2mqtt's `Colour#dimmed_to` does: it dims the colour itself and sends a
darker colour. Brightness never leaves the daemon.

### The firmware caps colours for power

Sixty-odd keys at full white draws more current than the keyboard's power budget allows, so the
firmware quietly scales any colour it is given down to something safe. The daemon does not need
to know or care — it sends the true colour it was asked for. A very bright white may come back
looking slightly dim. That is expected and is not a bug in this daemon.

## Finding the keyboard

Confirmed on Etienne's machine, keyboard attached:

| What | Value |
| --- | --- |
| USB vendor | `0x3496` (13462), "Keyboardio" |
| USB product | `0x0006` (6), "Model 100" |
| USB serial number | `65644FE61339` |
| Serial port | `/dev/cu.usbmodem65644FE613391` |

The port name is `usbmodem` + the USB serial number + a digit for the interface. So:

- **Identity** is the USB serial number, `65644FE61339`. It survives replugging and moving to a
  different socket, which is exactly what an identity has to do. Use it for the Home Assistant
  device id and in the topics, the way ambx2mqtt uses a set's identity.
- **Finding the port**: read `ioreg -p IOUSB -w0 -l`, find the device whose `idVendor` is 13462
  and `idProduct` is 6, take its `USB Serial Number`, then match `/dev/cu.usbmodem<serial>*`.

Keep all of that inside one small class — call it `KeyboardFinder` — so the rest of the daemon
never knows how a keyboard is found. **macOS only.** Linux discovery is out of scope; the finder
being one class is what makes adding it later cheap.

## Two hazards, both real

**The port is exclusive.** Only one process can hold it. Chrysalis, the keyboard's
configuration app, holds it whenever it is open — it was observed held by Microsoft Edge during
the conversation that produced this plan. Opening a held port raises `Errno::EBUSY`. The daemon
must survive that: log it, keep the colour it was asked for, try again next round. It must never
crash and never lose the colour.

This is also why the daemon **holds the port only for a moment**: open it, write one command,
drain the reply, close it. Never hold it open between commands. That way the daemon and
Chrysalis can coexist as long as they are not both talking at the same instant.

**Never open the port at 1200 baud.** On many boards a 1200-baud connection is the signal to
reboot into the firmware flashing mode. Pick any other rate — the rate is meaningless for a USB
serial device anyway, so 9600 or 115200 are both fine and neither will reset the keyboard.

## What the daemon does, as behaviours

These are the acceptance tests. Name them so Etienne would nod at them.

**Appearing in Home Assistant** (`test/appearing_in_home_assistant_test.rb`)
- A keyboard that is plugged in is announced to Home Assistant as one device with one light,
  taking a colour and a brightness.
- The light is only reachable while both the daemon and the keyboard are here — two availability
  topics, `availability_mode: "all"`, exactly as ambx2mqtt does it.

**Lighting the keyboard** (`test/lighting_the_keyboard_test.rb`)
- Asking for red sends `availability.color 255 0 0` to the keyboard.
- Asking for red reports the light red back to Home Assistant.
- A colour asked for without a brightness burns at full.
- Dimming to half sends half the colour to the keyboard, and reports the colour and the
  brightness separately.
- Turning the light off sends `availability.color 0 0 0`, and still remembers the colour.
- Turning it back on brings back the colour it had.

**Leaving the port alone** (`test/leaving_the_port_alone_test.rb`)
- Writing a colour opens the port, writes once, and closes it again — the daemon never holds it.
- A port another program is holding does not stop the daemon; the colour is kept and sent on a
  later round.
- Sending several colours in a row opens the port once per colour, never leaving it open in
  between.

**Losing the keyboard** (`test/losing_the_keyboard_test.rb`)
- An unplugged keyboard is reported unavailable to Home Assistant.
- A keyboard that comes back is painted with the colour it was last asked for, without Home
  Assistant saying anything.
- A keyboard gone for longer than the grace period is forgotten, and Home Assistant is told to
  drop the device. Use ambx2mqtt's 48-hour grace period.

**Remembering across restarts** (`test/remembering_across_restarts_test.rb`)
- A daemon that is restarted paints the keyboard the colour it was showing before.
- A daemon that dies is seen to have gone, because the last word was left with the broker before
  connecting.

## How often it looks

Four times a minute — a round every **fifteen seconds**. That is `Clock`'s
`SECONDS_BETWEEN_ROUNDS`. It means a keyboard that is replugged can take up to fifteen seconds
to come back to its colour. That is accepted, not a defect.

## The pieces

Copy freely from ambx2mqtt. Most of these are the same class with a different subject.

| Class | Job |
| --- | --- |
| `Colour` | Red, green, blue, and `dimmed_to`. Copy as it stands. |
| `AvailabilityLight` | The one light. Remembers colour, brightness and on/off; knows the Focus command line to send. This is ambx2mqtt's `Lamp`, singular. |
| `Keyboard` | One physical keyboard: its identity, its name, its light, and the port it is reached through. |
| `KeyboardFinder` | The only place that knows about `ioreg` and `/dev/cu.usbmodem*`. |
| `FocusPort` | Opens the port, writes one command line, drains until `.`, closes. Raises nothing the daemon cannot handle. |
| `LightCommand` | What Home Assistant asked for. Copy ambx2mqtt's `LampCommand`. |
| `Topics`, `Announcement`, `Broker` | Copy, adjusted for one light instead of five. |
| `Configuration`, `Secret` | Copy. Same broker block, same `op://` handling, same `state_file`, same `log_level`. |
| `Clock` | Copy, fifteen seconds instead of thirty. |
| `RememberedState` | Copy. |
| `Daemon` | Copy. Same arrive / depart / put-back / forget-the-long-gone shape. |

Keep them small and keep the names in the domain. "Availability light" is the word for this
thing — in the class names, in the topics, in the Home Assistant entity, and in conversation.

## A note on spelling

The firmware says `color`, because Kaleidoscope is American throughout and its command is
`availability.color`. The Ruby says `colour`, because ambx2mqtt does. Both are deliberate. The
only place they meet is the one line that builds the command to send, and that is fine. Do not
"fix" either side.

## Setting the repository up

The repository does not exist yet beyond this plan. Follow `~/.claude/skills/new-repo-setup`,
using ambx2mqtt as the reference rather than the skill's default reference repo, because
ambx2mqtt is the closest sibling — a headless daemon, no web surface, no user interface.

Specifically:

- `AGENTS.md` symlinked to `~/Developer/dotfiles/agents.md`; `CLAUDE.md` symlinked to `AGENTS.md`.
  Both committed.
- `.ruby-version` matching ambx2mqtt's. `rv` is the version manager.
- `Gemfile` with source `https://gem.coop`, `mqtt-ccutrer`, and ambx2mqtt's development group.
  There is no equivalent of the unpublished `libambx` gem — the keyboard is reached with plain
  Ruby file operations, so nothing extra is needed.
- Rubocop and solargraph configuration copied from ambx2mqtt.
- `lefthook.yml` extending the dotfiles one, excluding the `rails` tag, with the same comment
  explaining why Brakeman does not apply.
- GitHub Actions CI running the linters and the whole suite. Dependabot, minimal, all
  ecosystems, one week cooldown.
- **No locale files.** There is no user interface to translate, for the same reason ambx2mqtt has
  none. Say so in the README, as ambx2mqtt does.
- `README.md` and `docs/installing.md` in ambx2mqtt's voice: what you get, how to run it, the
  1Password reference for the broker password, how to keep it running in the background on
  macOS, and how to work on it.
- A `config/keyboardio2mqtt.example.yml` mirroring ambx2mqtt's, minus the `sets` section and
  plus whatever naming a keyboard needs.

The very first commit necessarily lands on `main`, because a new repository has nothing to
branch from. **Every slice after that goes in its own worktree under `.worktrees/`**, per
`~/Developer/dotfiles/WORKTREES.md`. Use the `worktree-first` skill.

## Order of work

Test-first throughout: one failing acceptance test, then small red/green/refactor unit cycles
until it passes. Commit on green, small commits, messages in domain language.

1. Repository scaffolding, per the section above. One commit on `main`.
2. **Lighting the keyboard.** The heart of it: a colour arrives, a command goes out. Do this
   first and everything else hangs off it.
3. **Leaving the port alone.** Open-write-close, and surviving a port somebody else is holding.
4. **Appearing in Home Assistant.** The announcement.
5. **Losing the keyboard.** Unavailability, re-painting on return, forgetting the long gone.
6. **Remembering across restarts.** The state file and the broker's last word.
7. `README.md` and `docs/installing.md`.

## Out of scope

Do not build any of this. If you think one of them is needed, say so and stop rather than
building it.

- **The firmware.** No changes in `~/Developer/Kaleidoscope` or `~/Developer/keyboardio-config`.
  The `availability.color` command is a given.
- **Changing the keyboard's LED mode.** The daemon only ever sends colours.
- **Reading the colour back from the keyboard.** It cannot be done and is not wanted.
- **Anything but macOS.** No Linux or Windows discovery.
- **More than one light per keyboard.** No per-key, per-region or per-layer colouring.
- **Named states.** No "available", "busy", "in a call". Home Assistant sends colours; what a
  colour *means* lives in Home Assistant's automations, not here.
- **The keyboard's brightness command.** Brightness is done by dimming the colour.
- **Effects.** No blinking, pulsing or animation. The firmware's two-second fade is the only
  movement there is.
- **Supporting several keyboards at once.** Write it so a second one would not be painful — the
  daemon already loops over what it finds — but do not test or document it.

## Done means

- Every acceptance test above green, and the unit tests under them green.
- `bundle exec rake test` green. `bundle exec rubocop` green.
  `bundle exec bundler-audit check --update` green.
- Tests never touch the real keyboard and never talk to a real broker, exactly as ambx2mqtt's
  never do. Stand-ins for both, asserting on the command lines sent and the payloads published.
- The diff self-reviewed against `AGENTS.md`.
- `README.md` and `docs/installing.md` written, in ambx2mqtt's voice.

## Decisions already made — do not reopen

All of these were settled with Etienne. Build to them.

- Whole board, one colour. Not per-key.
- A colour picker in Home Assistant, not a set of named states.
- The daemon owns what colours mean; the firmware owns the fade and the power cap.
- The port is held for a moment only.
- Four rounds a minute.
- Firmware fades, over a fixed couple of seconds. The daemon never sends a fade time.
- The availability light is the keyboard's default mode; the daemon never changes modes.
- A new repository, `keyboardio2mqtt`, shaped like ambx2mqtt.
