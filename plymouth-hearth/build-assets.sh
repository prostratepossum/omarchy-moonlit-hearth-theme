#!/bin/bash
# Regenerates the Moonlit Hearth plymouth assets from the theme's art.
set -euo pipefail
cd "$(dirname "$0")"

# The built PNGs ship with the theme; this is only needed after changing art.
PLATE=${PLATE:-../backgrounds/0-moonlithearth-hearth.jpg}
BADGE=${BADGE:-../plugins/io.github.prostratepossum.moonlit-hearth-lock/hearth-badge.png}
FONT=${FONT:-$HOME/.local/share/fonts/Cinzel.ttf}   # Cinzel (OFL), for the title

# Moonlit plate, dimmed and softened so the badge and prompt read clearly,
# with a darker pool behind the centre column.
magick "$PLATE" -resize 1920x1080 -blur 0x2.5 -evaluate multiply 0.58 -channel R -evaluate multiply 0.9 +channel \
  \( -size 1920x1080 radial-gradient:'rgba(4,10,19,0.62)-rgba(4,10,19,0)' \) -composite \
  -define png:compression-level=9 background.png
magick "$BADGE" -resize 360x360 badge.png

# Warm glow that pulses over the cabin's lit window in the badge.
magick -size 64x64 radial-gradient:'rgba(255,196,110,1)-rgba(240,160,80,0)' -channel A -evaluate pow 1.6 +channel window.png

# Snowflakes: soft round flakes at three sizes (sharpness differs per layer).
magick -size 32x32 radial-gradient:'rgba(240,247,255,1)-rgba(212,227,240,0)' -channel A -evaluate pow 1.2 +channel flake_near.png
magick -size 20x20 radial-gradient:'rgba(236,244,252,1)-rgba(212,227,240,0)' -channel A -evaluate pow 1.6 +channel flake_mid.png
magick -size 12x12 radial-gradient:'rgba(226,238,250,1)-rgba(190,215,240,0)' -channel A -evaluate pow 2.0 +channel flake_far.png

# Six-point snowflake bullet for the password pill.
magick -size 56x56 xc:none -stroke 'rgba(232,243,252,1)' -strokewidth 4 -fill none \
  -draw "line 28,4 28,52" -draw "line 7,16 49,40" -draw "line 7,40 49,16" \
  -draw "line 28,12 22,6" -draw "line 28,12 34,6" -draw "line 28,44 22,50" -draw "line 28,44 34,50" \
  \( +clone -background 'rgba(143,187,224,1)' -shadow 90x3+0+0 \) +swap -background none -layers merge +repage \
  -gravity center -extent 64x64 -resize 28x28 bullet.png

# Breathing moonlight halo behind the badge.
magick -size 400x400 xc:none -fill none -stroke 'rgba(188,215,240,0.85)' -strokewidth 12 \
  -draw "circle 200,200 200,82" -blur 0x16 halo.png

# Title in Cinzel.
magick -background none -fill '#e4eef7' -font "$FONT" -pointsize 34 -kerning 14 label:'MOONLIT HEARTH' \
  -trim +repage \( +clone -background '#8fbbe0' -shadow 70x8+0+0 \) +swap -background none -layers merge +repage title.png
magick -background none -fill 'rgba(212,227,240,0.8)' -font "$FONT" -pointsize 17 -kerning 6 label:'come in from the cold' -trim +repage motto.png

# Password pill and progress bar.
magick -size 440x62 xc:none -fill 'rgba(10,20,36,0.84)' -stroke '#8fbbe0' -strokewidth 2 \
  -draw "roundrectangle 1,1 438,60 30,30" entry.png
magick -size 440x4 xc:none -fill 'rgba(26,44,69,0.9)' -draw "roundrectangle 0,0 439,3 2,2" progress_box.png
magick -size 440x4 gradient:'#8fbbe0-#f0c47a' -rotate 90 -resize 440x4\! \
  \( -size 440x4 xc:none -fill white -draw "roundrectangle 0,0 439,3 2,2" \) \
  -compose CopyOpacity -composite progress_bar.png

ls -la *.png
