#!/bin/bash
# Renderiza as faixas da folha de modelo em out/folha/ e monta entrega/modelo.png
cd $(dirname $0)/..
R=tools/run.sh; O=out/folha
$R fplus 2400x720 $O/a.png cy=0.62 cena=folha who=escorador yaws=0,40,90 dx=1.85 size=1.7 &
$R fplus 2400x720 $O/b.png cena=folha who=cristaleira,coveira yaws=0,40,90 dx=0.85 size=1.85 cy=0.68 &
$R fplus 2400x720 $O/c.png cena=folha who=gancheiro yaws=0,40,90 dx=1.4 size=1.7 &
wait
$R fplus 2400x620 $O/d.png cena=folha who=ouvidor yaws=0,40,90 dx=1.3 size=1.2 bg=#6b6f7a cy=0.42 &
$R fplus 2400x560 $O/g.png cena=poses who=ouvidor anim=folha q=0,1,2,3,4 dx=0.95 size=1.2 bg=#6b6f7a cy=0.42 &
$R fplus 2400x620 $O/e.png cena=folha who=bocalume yaws=0,40,90 dx=2.1 size=1.9 bg=#6b6f7a cy=0.5 &
wait
$R fplus 2400x560 $O/f.png cena=poses who=gancheiro anim=folha q=0,1,2,3,4,5,6,7 dx=0.66 size=1.3 &
$R fplus 2400x720 $O/h.png cena=folha who=escorador,cristaleira,coveira,gancheiro yaws=0,40 dx=1.0 size=2.6 cy=0.9 jogo=1 &
wait
cp entrega/silhuetas.png $O/s.png
python3 tools/folha_modelo.py $O entrega/modelo.png
