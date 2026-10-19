#!/bin/bash
# Static mockup of one Moonlit Hearth splash frame.
#   ./mockup.sh [W H out.png [boot|password]]   (default: password, 8 bullets)
# Mirrors the layout math in hearth.script. Never run plymouthd live.
set -euo pipefail
cd "$(dirname "$0")"
W=${1:-2560}; H=${2:-1440}; out=${3:-mockup.png}; state=${4:-password}
U() { echo $(( $1 * H / 1080 )); }   # scale a 1080p length

badge=$(( H * 21 / 100 )); (( badge < 150 )) && badge=150
halo=$(( badge * 16 / 10 ))
bx=$(( W / 2 - badge / 2 )); by=$(( H * 36 / 100 - badge / 2 ))
hx=$(( W / 2 - halo / 2 )); hy=$(( by + badge / 2 - halo / 2 ))
ws=$(( badge * 20 / 100 )); wx=$(( bx + badge * 545 / 1000 - ws / 2 )); wy=$(( by + badge * 87 / 100 - ws / 2 ))
tw=$(U $(magick identify -format %w title.png)); th=$(U $(magick identify -format %h title.png))
ty=$(( by + badge + $(U 34) ))
ey=$(( ty + th + $(U 44) )); ex=$(( W / 2 - 220 ))
mw=$(U $(magick identify -format %w motto.png)); mh=$(U $(magick identify -format %h motto.png))

args=(background.png -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" -gravity northwest)
add_flakes() {   # $1 layer image, $2 count, $3 base size, $4 size spread, $5 alpha tenths
  for i in $(seq "$2"); do
    s=$(( $(U $3) + RANDOM % ($(U $4) + 1) )); (( s < 3 )) && s=3
    args+=( \( "$1" -resize "${s}x${s}" -channel A -evaluate multiply 0.$5 +channel \) -geometry "+$(( RANDOM % W ))+$(( RANDOM % H ))" -composite )
  done
}
RANDOM=11
add_flakes flake_far.png 20 4 2 4
add_flakes flake_mid.png 18 8 5 6
args+=( \( halo.png -resize "${halo}x${halo}" -channel A -evaluate multiply 0.55 +channel \) -geometry "+$hx+$hy" -composite )
args+=( \( badge.png -resize "${badge}x${badge}" \) -geometry "+$bx+$by" -composite )
args+=( \( window.png -resize "${ws}x${ws}" -channel A -evaluate multiply 0.6 +channel \) -geometry "+$wx+$wy" -composite )
add_flakes flake_near.png 10 12 8 7
args+=( \( title.png -resize "${tw}x${th}!" \) -geometry "+$(( W / 2 - tw / 2 ))+$ty" -composite )
if [[ $state == password ]]; then
  args+=( entry.png -geometry "+$ex+$ey" -composite )
  n=8; row=$(( n * 14 + (n - 1) * 8 )); sx=$(( W / 2 - row / 2 )); sy=$(( ey + 31 - 7 ))
  for i in $(seq 0 $(( n - 1 ))); do
    args+=( \( bullet.png -resize 14x14 \) -geometry "+$(( sx + i * 22 ))+$sy" -composite )
  done
else
  pb=$(( ey + 31 - 2 ))
  args+=( progress_box.png -geometry "+$ex+$pb" -composite )
  args+=( \( progress_bar.png -crop 264x4+0+0 +repage \) -geometry "+$ex+$pb" -composite )
fi
args+=( \( motto.png -resize "${mw}x${mh}!" \) -geometry "+$(( W / 2 - mw / 2 ))+$(( ey + 62 + $(U 30) ))" -composite )
magick "${args[@]}" "$out"
echo "$out"
