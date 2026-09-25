# Luma Flux

A lamp controller for an ESP32 running [WLED](https://kno.wled.ge/), with a
purpose-built interface in place of the stock panel: one fader per LED strip,
each glowing in that strip's actual colour.

![The Luma Flux interface](interface-preview.png)

Built for a lamp with five WS2812B strips on five GPIO pins, but nothing is
hard-coded to five — everything is derived from whatever the board reports, so
two strips or eight work the same way.

*[Polska wersja tego dokumentu](README.pl.md) · [polski interfejs](index.pl.htm)*

## What you need

- An ESP32 board (a plain ESP32-WROOM with 4 MB flash — the kind sold as
  "ESP32 DevKit")
- Addressable LED strips: WS2812B, SK6812 or similar
- A 5 V power supply sized for the strips — see [Power](#power) below, this is
  the part people get wrong
- A computer with a USB cable that carries data (many charging cables don't)

## Getting it running

**1. Put WLED on the board.** Plug the ESP32 into USB and run:

```sh
./install.sh
```

It finds the board, downloads WLED and everything around it, and writes it all.
It asks before erasing anything. If `esptool` is missing it tells you how to
install it.

**2. Tell it your WiFi.** The board now broadcasts its own network, **WLED-AP**,
password `wled1234`. Connect a phone to that, open `http://4.3.2.1`, enter your
home WiFi, save. The board reboots and joins your network. Your router's device
list will show the address it was given.

**3. Set up the strips and the interface:**

```sh
./deploy.sh <the-address-from-step-2>
```

Then open that address in a browser. That's the lamp.

Don't know how many LEDs each strip has? You don't need to — see
[Measuring](#measuring-a-strip-whose-length-you-dont-know).

## Wiring

Any free GPIO works for data. These five avoid the pins that cause trouble —
flash (6–11), the strapping pins (0, 2, 12, 15), UART (1, 3) and the
input-only pins (34–39):

| Strip | GPIO |
|---|---|
| 1 | 16 |
| 2 | 17 |
| 3 | 18 |
| 4 | 19 |
| 5 | 23 |

GPIO 21 and 22 are left free in case you add an I²C sensor or a rotary encoder.

## Power

A single WS2812B LED at full white draws about **60 mA**. Five hundred of them
is 30 A. This is the number that surprises people.

WLED has a current limiter: tell it what your supply can give and it trims
brightness to stay under that. `deploy.sh` sets it, and you should set it to
match your actual supply — not higher.

The rest, in rough order of how often each one bites:

- **The supply ground and the ESP32 ground must be connected.** Without a shared
  ground the data line has no reference and the strips flicker at random. This
  is the single most common wiring mistake.
- **Never power the strips from the ESP32's 5 V pin or over USB.** Neither the
  trace on the board nor the USB cable will carry it.
- Inject power at both ends of any strip longer than about a metre. Otherwise
  the far end drifts to a muddy red as the voltage sags.
- A 330–470 Ω resistor in each data line, right at the board.
- A 1000 µF capacitor across 5 V at each strip's input.
- The ESP32 drives 3.3 V where WS2812B wants about 3.5 V at the threshold. It
  usually works anyway, but gets temperamental over longer wires — a
  **74AHCT125** level shifter settles it for good.

If a strip shows the wrong colours (red where green belongs), that's the channel
order, not the wiring: change it in the WLED panel under `/settings/leds`
(GRB ↔ RGB), then run `./deploy.sh <address> sync`.

## The interface

`index.htm` is uploaded into the ESP32's own filesystem and shadows the stock
WLED panel. The lamp serves it itself, so it needs no internet and loads nothing
from anywhere else — 40 KB, no libraries.

It gives you a master switch, master brightness with an estimated current draw,
one fader per strip lit in that strip's colour, a colour picker with white
presets from 2200 K to 6500 K, effects, palettes, speed, intensity, six scenes,
and the measuring mode below.

The stock WLED panel doesn't go away — it stays at `/settings`, and the file
manager at `/edit`. To go back to it permanently, delete `index.htm` there.

You can also open `index.htm` straight from disk; it asks for the lamp's address
and remembers it. Convenient while changing the design.

## Measuring a strip whose length you don't know

Near the bottom of the interface there's **Measure strip lengths**. Every strip
lights warm white with its **last LED in red**, and from there it's hot-and-cold:

1. **Raise** the number until the red LED disappears — it has run past the
   physical end of the strip.
2. **Step back down by one** until it lights again.
3. That number is the strip's length.

All strips are measured at once, each on its own row. **Save lengths** writes
the outputs, the segments and the boot preset in one go.

Underneath, the outputs are temporarily stretched to 300 LEDs so that an LED
past the real end can be addressed at all — which is also why this mode can't
measure a strip longer than 300.

## Knowing which strip is which

The strips sit in a row, in whatever order you put them in, so the row on
screen can be made to match the order they physically sit in. Three things help
you set that up:

- **Arrange** (above the strips) turns on swap mode. Tap two strips and they
  trade places; tap **Arrange** again to leave.
- **Blink** (in a strip's colour panel) flashes that one strip white three
  times, so you can see which physical strip you're looking at.
- **Rename** (same panel) gives it a name of your own — "front left", "spine",
  whatever fits your build.

Names and the order live in `/favs.json` on the lamp, alongside the saved
colours. Names are also pushed to WLED itself, so the stock panel and the phone
app show them too.

## When an effect ignores your colour

Most WLED effects take their colours from the **palette**, not from the colour
you set on a strip. With any palette other than *Default* selected, picking a
colour changes the stored value but nothing you can see — the effect keeps
drawing from the palette.

*Default* is the palette that means "use this segment's own colours". The
colour panel says so when a palette is in the way, with a button to switch
back.

Tapping a chip that is already on turns it off again: an effect goes back to
*Solid*, a palette back to *Default*. Both mean "nothing on top of my colours".

## Turning off by itself

The *Sleep timer* row sets a delay — 15 to 90 minutes. The light stays exactly
as it is for the whole delay and then switches off; a readout shows how long is
left, and **Cancel** calls it off. Brightness is remembered, so switching the
lamp back on brings back the same light.

The countdown runs on the lamp, not in the page, so it still happens after you
close the browser or leave the house. It is WLED's nightlight underneath, so
the phone app shows and controls the same timer.

## Saving a look

**+** at the end of the *Scenes* row saves everything on screen right now —
every strip's colour, the effect, palette, speed, intensity and master
brightness — under a name you choose. **Remove** deletes your own saved looks;
the six built-in scenes stay.

These are WLED's own presets, in slots 2 and up, so the phone app and any
physical buttons can reach them too. Slot 1 is reserved for the boot preset
that holds the strip layout.

They are saved **without segment bounds**. A look therefore carries colours and
effects but can never redefine how long the strips are — applying one from six
months ago won't undo a strip you have since rewired.

## Saving what you like

Colours, effects and palettes can be kept as favourites. In the colour picker,
**+** saves the colour you're looking at; the chip rows under *Effect* and
*Palette* have the same **+** for whatever is running right now. **Remove**
turns a row into delete mode; tapping it again leaves.

These live in `/favs.json` **on the lamp**, not in your browser. That matters
more than it sounds: browser storage would give you one set of favourites on
your phone and a different set on a laptop, and clearing site data would wipe
them. On the lamp they're the same for everyone who opens the page. If the page
is opened from disk instead of from the lamp, it falls back to browser storage.

Effects and palettes are stored **by name**, not by number. WLED renumbers
effects between versions, so a saved number would silently point at something
else after an update. A saved name that a later build doesn't have shows up
struck through rather than disappearing.

## When effects cut off at the end of a strip

Effects run from one end of a segment to the other and then start over, which
shows up as a hard seam. Two segment options fix it, both in the WLED panel
under the segment, or over the API:

- **Mirror** plays the effect across half the strip and reflects it onto the
  other half, so both ends behave like the middle. The seam disappears. Costs
  you half the effective resolution.
- **Reverse** flips a strip's direction. Useful when strips are arranged so that
  one's end sits next to the next one's start — reversing every other strip
  makes the light run continuously along the zigzag instead of jumping back.

```sh
curl -X POST -H 'Content-Type: application/json' \
  -d '{"seg":[{"id":0,"mi":true},{"id":1,"mi":true}]}' \
  http://<address>/json/state
```

Both are preserved by `sync` and saved into the boot preset.

## Why these scripts exist

WLED keeps three things separately and never reconciles them:

1. **outputs (buses)** — how many LEDs hang off which GPIO,
2. **segments** — what actually lights up and what you control,
3. **the boot preset** — the only place segments survive a restart, because
   `cfg.json` doesn't store them.

Change a strip's length in the WLED panel and only the outputs move. The segment
bounds stay frozen in the preset and start overlapping: one strip's segment runs
into the next, and the last strip gets clipped. The symptom is misleading — it
looks as though the change did nothing at all.

So change lengths here instead, with one command that does all three:

```sh
./deploy.sh <address> leds 102 102 93 97 101   # one number per strip
```

And if something has already drifted — after a panel change, or a firmware
update:

```sh
./deploy.sh <address> sync
```

## All the commands

```sh
./install.sh                          # put WLED on a fresh board
./install.sh --port /dev/cu.usbserial-10   # if it picks the wrong port

./deploy.sh <address>                 # interface + sync
./deploy.sh <address> ui              # interface only
./deploy.sh <address> leds 102 102 93 # set strip lengths
./deploy.sh <address> sync            # repair drift
./deploy.sh <address> check           # report only, changes nothing
```

`configure.py` does the real work and is what keeps outputs, segments and the
boot preset saying the same thing. `tools/make_partitions.py` builds the ESP32
partition table; the WLED web installer publishes ready-made ones for 8 MB and
16 MB boards only, so 4 MB boards need it generated.

## Updating WLED later

Use `/update` in the browser and upload a `WLED_*_ESP32.bin` release — that path
replaces only the application and keeps your settings.

Afterwards, **check the boot preset**: a version change can shift WLED's effect
numbering, so a scene may land on a different effect than it did before.

## Notes for the curious

The `WLED_*_ESP32.bin` file published on GitHub is the **application alone**, not
a full flash image. Written to `0x0` — the obvious guess — the board boot-loops
with `invalid header`. It belongs at `0x10000`, with the bootloader at `0x1000`,
the partition table at `0x8000` and the boot selector at `0xe000`. `install.sh`
does this correctly.

The partition table is WLED's `WLED_ESP32_4MB_1MB_FS` layout: app0 at `0x10000`
with 1.5 MB, a second OTA slot after it, and a 960 KB filesystem at `0x310000`,
which is where the interface lives.

## License

MIT — see [LICENSE](LICENSE). WLED itself is a separate project under EUPL-1.2;
this repository downloads its released binaries rather than redistributing them.
