#!/bin/bash
# codificar.sh PASTA_QUADROS SAIDA_SEM_EXT [CRF] : mp4 1280x720 a 60 fps (H.264, reduzido de 1080p) e gif de até 4 MB
Q=$1; O=$2; CRF=${3:-21}
ffmpeg -y -loglevel error -framerate 60 -start_number 0 -i $Q/q%08d.png -vf "scale=1280:720:flags=lanczos" -c:v libx264 -preset slow -crf $CRF -pix_fmt yuv420p -movflags +faststart -an $O.mp4
# gif: 480 px, 12 fps, 48 cores; se passar de 4 MB, cai para 400 px e 10 fps
gif() { ffmpeg -y -loglevel error -framerate 60 -start_number 0 -i $Q/q%08d.png -vf "fps=$2,scale=$1:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=$3:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" $O.gif; }
gif 480 12 48
[ $(stat -c %s $O.gif) -gt 4000000 ] && gif 400 10 40
[ $(stat -c %s $O.gif) -gt 4000000 ] && gif 360 8 32
ls -la $O.mp4 $O.gif
ffprobe -v error -show_entries stream=width,height,r_frame_rate -show_entries format=duration -of csv=p=0 $O.mp4
