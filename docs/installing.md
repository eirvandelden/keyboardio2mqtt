# Installing keyboardio2mqtt

Run this on the computer the keyboard is plugged into. Installation is for developers: a checkout
and Bundler, not a package. **macOS only** — finding a keyboard is written against macOS, and
nothing else is.

## 1. The firmware

The keyboard needs custom Kaleidoscope firmware that understands:

```
availability.color <red> <green> <blue>
```

Each value is 0–255, and the whole board fades to that colour over about two seconds. The
firmware also makes the availability light the board's default mode, so it is showing whenever
the keyboard is plugged in.

Without that firmware the daemon runs, finds the keyboard and sends its commands, and nothing
lights up.

## 2. The checkout

```
git clone git@github.com:eirvandelden/keyboardio2mqtt.git
cd keyboardio2mqtt
rv install          # installs the Ruby named in .ruby-version
bundle install
```

## 3. The configuration

```
mkdir -p ~/.config/keyboardio2mqtt
cp config/keyboardio2mqtt.example.yml ~/.config/keyboardio2mqtt/config.yml
$EDITOR ~/.config/keyboardio2mqtt/config.yml
```

Fill in your broker. The password is never written in the file — put a 1Password reference like
`op://Familie/MqttBroker/password` and the daemon reads it at startup with the `op` command.
Unlock 1Password before the daemon starts.

Leave the `keyboards:` section alone for now. You cannot know what your keyboard is called until
the daemon has seen it.

## 4. Run it once by hand

```
bin/keyboardio2mqtt --config ~/.config/keyboardio2mqtt/config.yml
```

It says what it found:

```
found the keyboard 65644FE61339, calling it "Keyboardio Model 100"
```

That first word is the keyboard's identity: its USB serial number. It survives replugging and
moving to a different socket, so once you have named it, it stays named:

```yaml
keyboards:
  65644FE61339: Desk keyboard
```

Home Assistant should now show one device with one light on it.

## 5. Sharing the keyboard with Chrysalis

The keyboard's serial port belongs to one program at a time, and Chrysalis — the keyboard's
configuration app — holds it the whole time it is open. So the daemon holds the port only for the
moment it takes to send one colour, and lets go again. The two can be open at once as long as
they are not both talking at the same instant.

If Chrysalis has the port when a colour arrives, the daemon says so, keeps the colour, and sends
it on a later round. Nothing is lost, and nothing crashes.

The daemon never changes the keyboard's LED mode. If you switch the board to another mode by
hand, colours go on arriving at a mode nobody can see — which is deliberate. It does not fight
you for control of the board.

## 6. Keep it running

```
cp service/nl.eirvandelden.keyboardio2mqtt.plist ~/Library/LaunchAgents/
$EDITOR ~/Library/LaunchAgents/nl.eirvandelden.keyboardio2mqtt.plist   # replace CHECKOUT and USERNAME
launchctl load ~/Library/LaunchAgents/nl.eirvandelden.keyboardio2mqtt.plist
```

It is a LaunchAgent rather than a LaunchDaemon on purpose: it needs your 1Password session to
read the broker password, and your access to the keyboard's port. Logs go to
`~/Library/Logs/keyboardio2mqtt.log`.

To stop it:

```
launchctl unload ~/Library/LaunchAgents/nl.eirvandelden.keyboardio2mqtt.plist
```

## When something is wrong

| What you see | What it means |
| --- | --- |
| `1Password would not give up op://...` | 1Password is locked, or the reference is wrong. The message names the reference, never the password |
| `could not reach the keyboard on /dev/cu...: Resource busy` | Chrysalis or something else is holding the port. The colour is kept and goes out on a later round |
| `the keyboard ... has no port yet` | the keyboard is on the USB bus but its port has not appeared. It is tried again next round |
| the light greyed out in Home Assistant | the keyboard was unplugged, or the daemon stopped. Both report offline |
| the light gone from Home Assistant | the keyboard has been unseen for two days and was forgotten. Plug it back in and it returns |
| the light says a colour but the board is dark | the board is in another LED mode. The daemon never changes modes; switch back by hand |
| a bright white looking dim | the firmware capped it to stay inside the keyboard's power budget |

A keyboard that is replugged can take up to fifteen seconds to come back to its colour, because
the daemon looks around four times a minute. That is expected.

Turn `log_level` up to `debug` in the configuration for more.
