base=${1:-app}
case "$base" in
  base=*) base=${base#base=} ;;
esac
flashfloppy_image_folder=/Volumes/FLASHFLOPPY/diskimages/
stage2=$base
bootloader=bootloader

set -e

nasm -w-label-orphan "$stage2.asm" -o "$stage2.bin" -l "$stage2.lst"
stage2_size=$(wc -c < "$stage2.bin" | tr -d ' ')
stage2_sectors=$(( (stage2_size + 511) / 512 ))

nasm -w-label-orphan -DSECTORS=$stage2_sectors "$bootloader.asm" -o "$bootloader.bin" -l "$bootloader.lst"

cp "$bootloader.bin" "$base.img"
cat "$stage2.bin" >> "$base.img"
pad=$(( stage2_sectors * 512 - stage2_size ))
if [ "$pad" -gt 0 ]; then
  dd if=/dev/zero bs=1 count="$pad" >> "$base.img" 2>/dev/null
fi
img_size=$(wc -c < "$base.img" | tr -d ' ')
disk_size=$((180 * 1024))
disk_pad=$(( disk_size - img_size ))
if [ "$disk_pad" -gt 0 ]; then
  dd if=/dev/zero bs=1 count="$disk_pad" >> "$base.img" 2>/dev/null
fi

nasm -w-label-orphan "$base.asm" -o "$base-standalone.img" -l "$base-standalone.lst"

if pgrep -x "mame" > /dev/null; then
	killall -9 mame
fi

img=`pwd`/$base.img

mame mbc55x \
-flop1 "$img" \
-ramsize 256K -skip_gameinfo -window -ui_active \
-nomaximize -resolution0 800x600 -prescale 2 -gamma 3 -contrast 1.5 \
-aviwrite plasma-material-palette.gif

rm -rf cfg
rm app.img
rm app-standalone.img
rm app-standalone.lst
rm bootloader.bin
rm bootloader.lst
rm app.bin
rm app.lst
