# Sanyo MBC-550 plasma

<img src="plasma.gif" width="400" height="250" alt="Plasma-effect op de Sanyo MBC-550" width="640">

Dit is het resultaat van `app.asm`: een bewegend plasma-effect voor de
Sanyo MBC-550/MBC-55x. Het effect wordt rechtstreeks in de RGB-video-RAM
getekend en combineert drie ideeën die op deze hardware goed samenwerken:

- een **3-bit RGB-gradient**: de drie bitplanes leveren de acht RGB-kleuren;
  patronen met `00h`, `55h`, `AAh` en `FFh` ditheren tussen die kleuren en
  maken een vloeiender gradient met een kleine tabel van 32 cellen;
- drie onafhankelijk verschuivende sinusgolven, aangevuld met een diagonale
  component, zodat het beeld niet in een eenvoudig rij- of kolompatroon valt;
- **interleaved/strided rendering**: elke 8×4-pixelcel wordt in een
  diagonaal strided patroon bezocht. Daardoor is een complete fase zichtbaar
  voordat de volgende fase het beeld merkbaar verandert.

De code rendert één cel door vier bytes naar elk van de rode, groene en blauwe
bitplanes te kopiëren. De inhoud van die cel komt uit `img`, geselecteerd door
de gecombineerde sinuswaarde. De renderlus in `app.asm` is daarmee het
belangrijkste onderdeel van dit project: de video-adressering wordt niet per
pixel opnieuw berekend en de plane-wissel gebeurt buiten de kleine kopieerlus.

## Techniek

Het scherm is 640×200 pixels. De video-RAM bestaat uit drie onafhankelijke
bitplanes:

```asm
RED_SEG   equ 0f000h
GREEN_SEG equ 0800h
BLUE_SEG  equ 0f400h
```

Een cel is 8 pixels breed en 4 scanlines hoog, dus vier bytes per plane. De
fysieke layout is geïnterleaved per groep van vier scanlines. Voor pixel `(x,y)`
is de byte-offset:

```text
(y & 3) + 320 * (y >> 2) + 4 * (x >> 3)
```

Het bijbehorende bitmasker is `80h >> (x & 7)`. `video.asm` bouwt hiervoor
eenmalig LUT's in conventioneel RAM; die route is bedoeld voor vrije vormen en
afzonderlijke pixels. `app.asm` gebruikt voor het plasma de snellere, op 8×4
uitgelijnde celroute.

## Projectstructuur

| Bestand | Rol |
| --- | --- |
| `app.asm` | Plasma-effect, sinusfasen, dither-cellen en strided renderlus. |
| `video.asm` | CRTC-initialisatie, scherm wissen en pixel-LUT's. |
| `bootloader.asm` | Leest stage 2 vanaf de floppy. |
| `build.sh` | Assembleert het image en start MAME. |
| `plasma.gif` | Opname van het resultaat. |

```bash
ffmpeg -i snap/plasma.avi -y -an \
-vf "fps=10,scale=640:400:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=8:reserve_transparent=0[p];[s1][p]paletteuse=dither=none" \
plasma.gif
```

`app.asm` is zelf stage 2 (`org 0`, `cpu 8086`) en include't `video.asm` aan
het einde. `setup` initialiseert de stack en video, bouwt de sinus-tabel en
start de renderlus.

## Bouwen en uitvoeren

Start in deze map:

```sh
sh build.sh
```

Het script assembleert `app.asm`, berekent automatisch hoeveel sectoren stage
2 nodig heeft, bouwt een 180 KiB floppy-image en start `mame mbc55x` met 256 KiB
RAM. Gegenereerde `*.img`, `*.bin` en `*.lst`-bestanden zijn tijdelijke
build-output.

Voor een variant kun je `app.asm` kopiëren en de basisnaam meegeven:

```sh
sh build.sh app-my-effect
```

De belangrijkste hardwaredetails zijn afgeleid en getest in de MAME
`mbc55x`-driver. De bootloader gebruikt tijdens het laden de groene plane als
indicator; daarom wist `setup_video` bij de start alle drie planes.
