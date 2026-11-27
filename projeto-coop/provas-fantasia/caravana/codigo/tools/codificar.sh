#!/bin/bash
# codificar.sh PASTA_QUADROS SAIDA_SEM_EXT : mp4 1280x720 a 60 fps (H.264, crf 24, yuv420p, faststart, sem áudio)
# e gif de 560 px a 15 fps com paleta própria (alvo: até 4 MB)
Q=$1; O=$2
ffmpeg -y -loglevel error -framerate 60 -start_number 0 -i $Q/q%08d.png -an -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p -movflags +faststart $O.mp4
ffmpeg -y -loglevel error -framerate 60 -start_number 0 -i $Q/q%08d.png -vf "fps=15,scale=${GIFW:-512}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=${GIFC:-80}:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" $O.gif
ls -la $O.mp4 $O.gif
ffprobe -v error -show_entries stream=width,height,r_frame_rate -show_entries format=duration -of csv=p=0 $O.mp4
