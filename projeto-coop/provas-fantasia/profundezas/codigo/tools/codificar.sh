#!/bin/bash
# codificar.sh PASTA_QUADROS SAIDA_SEM_EXT : mp4 1280x720 a 60 fps (H.264, direto dos quadros) e gif de 640 px a 15 fps
Q=$1; O=$2
ffmpeg -y -loglevel error -framerate 60 -start_number 0 -i $Q/q%08d.png -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart $O.mp4
ffmpeg -y -loglevel error -framerate 60 -start_number 0 -i $Q/q%08d.png -vf "fps=15,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" $O.gif
ls -la $O.mp4 $O.gif
ffprobe -v error -show_entries stream=width,height,r_frame_rate -show_entries format=duration -of csv=p=0 $O.mp4
