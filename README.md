# keyboardio2mqtt

Makes a Keyboardio Model 100 available to Home Assistant over MQTT, so the keys of the keyboard
can show whether you are free.

Run it on the computer the keyboard is plugged into. It finds the keyboard, announces it to your
MQTT broker as a single light, and turns Home Assistant's colour, brightness and on/off commands
into commands the keyboard's firmware understands.

## What you get

The keyboard shows up in Home Assistant as one device with one light, called the **availability
light**. It takes a colour, a brightness and on/off, and remembers what it was last asked for.

The whole board is one colour. Point a colour picker at it, or let an automation decide: red
while you are in a meeting, green while you are free, dark while you are away. What a colour
*means* lives in your Home Assistant automations, not here.

The keyboard cannot be read back, so what Home Assistant shows is always *what was last asked
for*, never a reading from the keyboard itself.

Two things are the firmware's business rather than this daemon's:

- **The fade.** The board takes about two seconds to reach a new colour. Asking for another
  colour part-way through simply redirects the fade.
- **The power cap.** Sixty-odd keys at full white draw more current than the keyboard is allowed,
  so the firmware quietly scales a colour down to something safe. A very bright white can come
  back looking slightly dim. That is the firmware doing its job.

Brightness, on the other hand, is this daemon's business. The keyboard has a brightness command
of its own, but it writes to the keyboard's permanent memory, and writing four times a minute
would wear it out. So a dimmed light is simply a darker colour on the wire.

## Running it

```
rv install
bundle install
mkdir -p ~/.config/keyboardio2mqtt
cp config/keyboardio2mqtt.example.yml ~/.config/keyboardio2mqtt/config.yml
$EDITOR ~/.config/keyboardio2mqtt/config.yml
bin/keyboardio2mqtt --config ~/.config/keyboardio2mqtt/config.yml
```

`docs/installing.md` has the whole thing, including keeping it running in the background on
macOS.

It needs custom Kaleidoscope firmware on the keyboard, which is where the `availability.color`
command and the two-second fade come from. **macOS only** — finding a keyboard is the one thing
that is written for this machine.

## Secrets

The configuration file never holds your broker password — it holds a 1Password reference like
`op://Familie/MqttBroker/password`, which the daemon resolves at startup with the `op` command.
Unlock 1Password before the daemon starts.

## Working on it

```
bundle exec rake test        # the whole suite; no keyboard and no broker needed
bundle exec rubocop
bundle exec bundler-audit check --update
```

Tests never touch a real keyboard and never talk to a real broker. They assert the command lines
we send to a keyboard and the payloads we publish to a broker, using stand-ins for both.

Two departures from the usual personal-project setup, both on purpose:

- **No Brakeman.** It scans Rails applications; this is a headless daemon with no web surface.
- **No locale files.** There is no user interface to translate. The only name anyone reads is the
  one they write in their own configuration, and Home Assistant translates its own interface.

The firmware says `color`, because Kaleidoscope is American throughout. The Ruby says `colour`.
Both are deliberate, and they meet on the one line that builds the command to send.

Work happens in a worktree under `.worktrees/`, never in the main checkout.
