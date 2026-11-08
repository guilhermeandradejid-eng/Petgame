class_name TrackData
## As 26 pistas (6 mundos x 4 + 2 extras) e os temas de ambientação.
##
## Cada pista é um polígono fechado de pontos [x, z, altura]. "feat" põe elementos especiais:
##   no ponto i:          ["helix", voltas(+esq/-dir), raio, desnível]   espiral que sobe/desce
##   no trecho i -> i+1:  ["loop", raio]                                   looping (sai deslocado para a direita)
##                        ["jump", vão, altura_rampa]                      rampa + vão sem pista (cair = voltar)
##                        ["cork", sentido]                                saca-rolhas (a pista gira 360°)
##                        ["cork", sentido]   = torção (a pista deita 75° para um lado e para o outro)
## Referências: Rock n' Roll Racing (armas e nitro por volta, dinheiro e upgrades),
## Hot Wheels Unleashed / Trackmania (loops, espirais, saca-rolhas, rampas), Burnout (tráfego, takedowns).

const THEMES := {
	"park": {
		"label": "Parque", "sky_top": "#6fa6f2", "sky_hor": "#dde8f7", "bg": "#bcd6f2", "sun": "#fff0d4", "sun_e": 1.7, "sun_rot": [-52, -35],
		"amb": 1.0, "fog": "", "ground": 0, "ga": "#3f8f2a", "gb": "#64ad3a", "gy": 0.0, "road": 0, "tint": "#ffffff",
		"curb": ["#e8432f", "#f7f2e8"], "rail": ["#f5f1ea", "#2e6fe0"], "shoulder": "#8f8a84",
		"props": [["prop_tree", 4], ["prop_pine", 3], ["prop_rock", 1]], "density": 240, "bldg": 20, "night": false,
		"grav": 1.0, "grip": 1.0, "pillars": true,
	},
	"city": {
		"label": "Cidade Neon", "sky_top": "#141446", "sky_hor": "#5a2f86", "bg": "#22184a", "sun": "#a8b4ff", "sun_e": 1.0, "sun_rot": [-60, 20],
		"amb": 0.95, "fog": "#2a1846", "ground": 6, "ga": "#3a3646", "gb": "#4a4558", "gy": 0.0, "road": 0, "tint": "#e6e2f5",
		"curb": ["#ff2d95", "#2ee6ff"], "rail": ["#2a2735", "#ff2d95"], "shoulder": "#3b3846",
		"props": [["prop_billboard", 1], ["prop_lamp", 1]], "density": 30, "bldg": 70, "night": true,
		"grav": 1.0, "grip": 1.0, "pillars": true,
	},
	"desert": {
		"label": "Deserto", "sky_top": "#4f86d8", "sky_hor": "#ffc58a", "bg": "#f2b989", "sun": "#ffd29a", "sun_e": 1.9, "sun_rot": [-28, -60],
		"amb": 0.9, "fog": "#f0c397", "ground": 1, "ga": "#d58c4e", "gb": "#e8b070", "gy": 0.0, "road": 0, "tint": "#f2dcc4",
		"curb": ["#c43d1f", "#f4e3c8"], "rail": ["#e8cfa8", "#b8562a"], "shoulder": "#b98a60",
		"props": [["prop_cactus", 4], ["prop_rock", 3]], "density": 160, "bldg": 0, "night": false,
		"grav": 1.0, "grip": 1.0, "pillars": true,
	},
	"snow": {
		"label": "Neve", "sky_top": "#8fb4e8", "sky_hor": "#eef4ff", "bg": "#dfe9f7", "sun": "#f4f7ff", "sun_e": 1.5, "sun_rot": [-40, 30],
		"amb": 1.1, "fog": "#e6eefa", "ground": 2, "ga": "#e9eff8", "gb": "#ffffff", "gy": 0.0, "road": 2, "tint": "#ffffff",
		"curb": ["#2f6fd6", "#ffffff"], "rail": ["#ffffff", "#2f6fd6"], "shoulder": "#c8d4e4",
		"props": [["prop_snowpine", 6], ["prop_rock", 1]], "density": 260, "bldg": 0, "night": false,
		"grav": 1.0, "grip": 0.85, "pillars": true,
	},
	"port": {
		"label": "Porto", "sky_top": "#5f95dd", "sky_hor": "#d6e6f5", "bg": "#b8d0ea", "sun": "#fff4e0", "sun_e": 1.7, "sun_rot": [-45, 60],
		"amb": 1.0, "fog": "#c3d8ee", "ground": 3, "ga": "#1f5f8f", "gb": "#3a8fbf", "gy": -3.0, "road": 0, "tint": "#e6e6e6",
		"curb": ["#ffcc1f", "#26272d"], "rail": ["#ffcc1f", "#26272d"], "shoulder": "#7d8088",
		"props": [["container", 1]], "density": 40, "bldg": 0, "night": false,
		"grav": 1.0, "grip": 1.0, "pillars": true,
	},

	"toy": {
		"label": "Loop Mania", "sky_top": "#58a6ff", "sky_hor": "#e9f4ff", "bg": "#cfe6ff", "sun": "#ffffff", "sun_e": 1.6, "sun_rot": [-55, -10],
		"amb": 1.1, "fog": "", "ground": 7, "ga": "#e4e7f2", "gb": "#c9cfe4", "gy": 0.0, "road": 1, "tint": "#ffffff",
		"curb": ["#ff7a1a", "#ff7a1a"], "rail": ["#ff6a00", "#ff8c1a"], "shoulder": "#ff7a1a",
		"props": [["prop_crate", 2], ["prop_barrel", 1], ["prop_cone", 1]], "density": 50, "bldg": 0, "night": false,
		"grav": 1.0, "grip": 1.05, "pillars": true, "prop_scale": 4.0,
	},
	"sky": {
		"label": "Céu", "sky_top": "#3f7fe0", "sky_hor": "#ffe1f0", "bg": "#cfe0ff", "sun": "#fff6e8", "sun_e": 1.7, "sun_rot": [-40, 45],
		"amb": 1.15, "fog": "#e4ecff", "ground": 8, "ga": "#ffffff", "gb": "#d6e2ff", "gy": -12.0, "road": 0, "tint": "#d8dcf0",
		"curb": ["#7d5cff", "#ffffff"], "rail": ["#ffffff", "#7d5cff"], "shoulder": "#a8acc8",
		"props": [], "density": 0, "bldg": 0, "night": false,
		"grav": 1.0, "grip": 1.0, "pillars": false,
	},
	"swamp": {
		"label": "Pântano", "sky_top": "#5d7d6a", "sky_hor": "#b9c9a8", "bg": "#a4b693", "sun": "#f2f0c8", "sun_e": 1.2, "sun_rot": [-50, 10],
		"amb": 0.9, "fog": "#9fb090", "fog_d": 0.0018, "ground": 9, "ga": "#2b3a22", "gb": "#4c5e30", "gy": -1.5, "road": 0, "tint": "#c8c0a8",
		"curb": ["#6b8f2a", "#e8e0c0"], "rail": ["#7a5a3a", "#a8c050"], "shoulder": "#6a5a40",
		"props": [["prop_deadtree", 4], ["prop_reeds", 6], ["prop_stump", 2], ["prop_tree", 2], ["prop_palm", 1]], "density": 260, "bldg": 0, "night": false, "dusk": true,
		"grav": 1.0, "grip": 0.95, "pillars": true,
	},
	"moon": {
		"label": "Estação Lunar", "sky_top": "#04040e", "sky_hor": "#1d1c3a", "bg": "#07071a", "sun": "#e8ecff", "sun_e": 1.8, "sun_rot": [-30, 70],
		"amb": 0.85, "fog": "", "ground": 5, "ga": "#6f6f78", "gb": "#9a9aa4", "gy": 0.0, "road": 3, "tint": "#c8c8d8",
		"curb": ["#2ee6ff", "#3a3a48"], "rail": ["#4a4a58", "#2ee6ff"], "shoulder": "#55555f",
		"props": [["prop_crystal", 2], ["prop_rock", 3]], "density": 120, "bldg": 0, "night": true,
		"grav": 0.6, "grip": 0.95, "pillars": true,
	},
}

const TRACKS := [
	{
		"name": "Lago Azul", "theme": "park", "w": 22.0, "traffic": 0,
		"desc": "Volta larga em torno do lago com uma chicane. A pista para aprender.",
		"pts": [[-150, -20, 0.6], [-120, -75, 0.6], [-50, -95, 1], [30, -80, 2], [90, -95, 2.5], [150, -60, 2], [165, 0, 1], [140, 55, 1], [80, 70, 0.6], [40, 40, 0.6], [0, 60, 0.6], [-40, 90, 1], [-100, 85, 1], [-150, 40, 0.6]],
		"feat": {},
	},
	{
		"name": "Circuito do Parque", "theme": "park", "w": 22.0, "traffic": 0,
		"desc": "Morros, chicane e grampo. Tráfego nos dois sentidos.",
		"pts": [[-91, 68, 0.6], [-26, 78, 0.6], [39, 75, 1.5], [101, 65, 4], [135, 31, 7], [135, -16, 7], [109, -52, 3], [73, -60, 0.6],
			[42, -36, 0.6], [8, -23, 0.6], [-23, -47, 0.6], [-47, -81, 1], [-96, -86, 1.5], [-135, -52, 1], [-140, 3, 0.6], [-127, 44, 0.6]],
		"feat": {},
	},
	{
		"name": "Trilha do Bosque", "theme": "park", "w": 22.0, "traffic": 0,
		"desc": "Curvas em S entre as árvores e um salto no riacho.",
		"pts": [[-160, -30, 1], [-110, -85, 1], [-40, -70, 2], [0, -100, 3], [60, -85, 4], [120, -100, 4], [170, -50, 3], [150, 10, 2], [95, 0, 1.5], [70, 45, 1], [120, 85, 2], [60, 110, 3], [-10, 90, 3], [-60, 50, 2], [-110, 70, 1.5], [-165, 35, 1]],
		"feat": {4: ["jump", 10.0, 1.2]},
	},
	{
		"name": "Colina dos Ventos", "theme": "park", "w": 22.0, "traffic": 0,
		"desc": "Sobe e desce pelos morros, com salto no topo.",
		"pts": [[-150, -50, 1], [-80, -95, 3], [0, -80, 7], [70, -100, 10], [150, -70, 8], [175, 0, 5], [140, 60, 3], [70, 50, 4], [20, 90, 7], [-50, 100, 8], [-120, 80, 8], [-170, 20, 3]],
		"feat": {9: ["jump", 12.0, 1.3]},
	},
	{
		"name": "Brejo das Garças", "theme": "swamp", "w": 20.0, "traffic": 0,
		"desc": "Rente à água, com dois saltos sobre o brejo.",
		"pts": [[-160, -40, 1], [-100, -90, 1], [-20, -85, 1.5], [50, -100, 1.5], [130, -80, 2], [175, -20, 2], [160, 50, 1.5], [100, 80, 1], [30, 60, 1], [-30, 90, 1], [-100, 85, 1.5], [-165, 35, 1]],
		"feat": {2: ["jump", 12.0, 1.6], 8: ["jump", 11.0, 1.4]},
	},
	{
		"name": "Raízes Retorcidas", "theme": "swamp", "w": 20.0, "traffic": 0,
		"desc": "Grampos fechados entre raízes e um salto no final.",
		"pts": [[-170, -60, 1], [-90, -95, 1], [-30, -60, 2], [-60, -15, 2], [0, 10, 2.5], [60, -40, 3], [110, -90, 3], [170, -60, 2.5], [175, 10, 2], [120, 50, 2], [150, 95, 2], [70, 110, 1.5], [20, 70, 1.5], [-50, 90, 1], [-120, 60, 1], [-175, 0, 1]],
		"feat": {13: ["jump", 11.0, 1.4]},
	},
	{
		"name": "Pântano Sombrio", "theme": "swamp", "w": 20.0, "traffic": 0,
		"desc": "Oito com ponte alta e saltos sobre o brejo.",
		"pts": [[-150, -40, 1], [-80, -80, 1], [0, -60, 2], [60, 0, 3], [110, 60, 4], [170, 50, 6], [190, -10, 8], [150, -65, 10], [95, -50, 11],
			[60, 0, 11], [10, 55, 9], [-60, 75, 6], [-130, 60, 3], [-175, 10, 1]],
		"feat": {1: ["jump", 11.0, 2.0], 11: ["jump", 12.0, 1.5]},
	},
	{
		"name": "Ponte Podre", "theme": "swamp", "w": 20.0, "traffic": 0,
		"desc": "Oito com ponte alta de madeira sobre o cruzamento.",
		"pts": [[-50, -50, 1], [0, 0, 1], [50, 50, 1], [90, 100, 2], [150, 95, 4], [185, 40, 6], [170, -30, 8], [120, -70, 10], [60, -60, 11], [30, -30, 11], [0, 0, 11], [-30, 30, 11], [-60, 60, 10], [-110, 90, 8], [-165, 70, 5], [-190, 10, 3], [-160, -55, 1.5], [-100, -80, 1]],
		"feat": {16: ["jump", 11.0, 1.5]},
	},
	{
		"name": "Dunas Altas", "theme": "desert", "w": 22.0, "traffic": 0,
		"desc": "Dunas enormes e dois saltos longos.",
		"pts": [[-170, -40, 1], [-110, -100, 4], [-30, -90, 8], [40, -110, 8], [120, -90, 5], [175, -30, 3], [170, 40, 6], [110, 90, 10], [30, 80, 10], [-40, 105, 7], [-110, 90, 4], [-175, 40, 2]],
		"feat": {2: ["jump", 14.0, 1.5], 7: ["jump", 13.0, 1.4]},
	},
	{
		"name": "Cânion do Deserto", "theme": "desert", "w": 22.0, "traffic": 0,
		"desc": "Subidas fortes e dois saltos sobre o vale.",
		"pts": [[-160, -20, 1], [-120, -80, 1], [-40, -100, 3], [40, -90, 8], [120, -100, 8], [170, -60, 6], [175, 10, 3], [140, 60, 1], [70, 70, 1],
			[30, 48, 4], [-5, 62, 7], [-20, 90, 10], [-80, 110, 12], [-140, 90, 8], [-175, 40, 4]],
		"feat": {3: ["jump", 14.0, 1.5], 12: ["jump", 13.0, 1.4]},
	},
	{
		"name": "Mesa Vermelha", "theme": "desert", "w": 22.0, "traffic": 0,
		"desc": "Espiral de subida até o topo da mesa e salto na descida.",
		"pts": [[-150, -50, 2], [-70, -90, 2], [20, -80, 3], [90, -100, 3], [150, -40, 23], [160, 40, 22], [110, 90, 16], [40, 80, 13], [-50, 100, 13], [-120, 80, 7], [-170, 20, 3]],
		"feat": {3: ["helix", 2.0, 24.0, 20.0], 7: ["jump", 11.0, 1.2]},
	},
	{
		"name": "Desfiladeiro", "theme": "desert", "w": 22.0, "traffic": 0,
		"desc": "Looping no fundo do cânion e salto entre as rochas.",
		"pts": [[-160, -30, 2], [-120, -95, 2], [-20, -100, 2], [80, -100, 2], [150, -60, 4], [165, 10, 6], [120, 60, 8], [60, 40, 8], [20, 85, 6], [-60, 100, 4], [-130, 80, 3], [-175, 30, 2]],
		"feat": {2: ["loop", 11.0], 6: ["jump", 11.0, 1.3]},
	},
	{
		"name": "Lago Congelado", "theme": "snow", "w": 20.0, "traffic": 0,
		"desc": "Volta larga sobre o lago de gelo: o carro escorrega.",
		"pts": [[-160, 0, 1], [-130, -70, 2], [-50, -95, 3], [50, -95, 3], [130, -70, 2], [165, 0, 1], [130, 70, 2], [60, 60, 2], [0, 90, 3], [-60, 60, 2], [-130, 70, 1]],
		"feat": {},
	},
	{
		"name": "Pico Nevado", "theme": "snow", "w": 20.0, "traffic": 0,
		"desc": "Espiral de descida com 2 voltas e asfalto escorregadio.",
		"pts": [[-130, -40, 12], [-60, -80, 15], [20, -70, 18], [80, -90, 21], [140, -50, 1], [150, 20, 1], [110, 70, 2], [40, 90, 4], [-30, 80, 7],
			[-90, 95, 10], [-150, 60, 12], [-165, 10, 12]],
		"feat": {3: ["helix", 2.0, 24.0, -20.0]},
	},
	{
		"name": "Trilha do Yeti", "theme": "snow", "w": 20.0, "traffic": 0,
		"desc": "Descida longa pela montanha, salto e espiral de volta ao topo.",
		"pts": [[90, -95, 16], [150, -40, 14], [165, 30, 12], [120, 80, 10], [40, 70, 7], [-20, 95, 7], [-90, 85, 4], [-150, 60, 2], [-180, 0, 2], [-140, -40, 22], [-60, -90, 20], [20, -75, 18]],
		"feat": {4: ["jump", 12.0, 1.4], 8: ["helix", 2.0, 22.0, 20.0]},
	},
	{
		"name": "Avalanche", "theme": "snow", "w": 20.0, "traffic": 0,
		"desc": "Saca-rolhas no vale gelado e salto na crista.",
		"pts": [[-150, -40, 6], [-80, -90, 6], [10, -95, 6], [100, -95, 6], [160, -50, 8], [170, 20, 10], [120, 75, 12], [40, 80, 11], [-30, 95, 11], [-100, 85, 8], [-165, 40, 6]],
		"feat": {2: ["cork", 1.0], 7: ["jump", 12.0, 1.4]},
	},
	{
		"name": "Cidade Neon", "theme": "city", "w": 20.0, "traffic": 0,
		"desc": "Oito à noite com viaduto por cima do cruzamento.",
		"pts": [[-60, -40, 0.6], [0, 0, 0.6], [60, 40, 0.6], [100, 70, 1], [150, 60, 2], [175, 20, 4], [165, -30, 6], [130, -60, 8], [90, -55, 9],
			[60, -40, 9], [0, 0, 9], [-60, 40, 9], [-100, 65, 8], [-150, 60, 6], [-178, 20, 4], [-165, -30, 2], [-130, -60, 1], [-90, -55, 0.6]],
		"feat": {},
	},
	{
		"name": "Viaduto", "theme": "city", "w": 20.0, "traffic": 0,
		"desc": "Oito comprido com viaduto sobre a avenida.",
		"pts": [[-80, -30, 0.6], [0, 0, 0.6], [80, 30, 0.6], [140, 70, 1], [190, 40, 3], [195, -30, 6], [150, -75, 9], [90, -60, 10], [40, -20, 10], [0, 0, 10], [-40, 20, 10], [-90, 60, 9], [-150, 75, 6], [-195, 30, 3], [-190, -40, 1], [-140, -65, 0.6]],
		"feat": {},
	},
	{
		"name": "Centro Financeiro", "theme": "city", "w": 20.0, "traffic": 0,
		"desc": "Quarteirões em ângulo reto e salto na avenida larga.",
		"pts": [[-160, -80, 0.6], [-40, -80, 0.6], [-40, -20, 0.6], [60, -20, 0.6], [60, -90, 0.6], [160, -90, 1], [160, 20, 2], [80, 20, 2], [80, 90, 3], [-60, 90, 3], [-60, 30, 2], [-160, 30, 1]],
		"feat": {8: ["jump", 13.0, 1.4]},
	},
	{
		"name": "Túnel de Neon", "theme": "city", "w": 20.0, "traffic": 0,
		"desc": "Dois loopings iluminados nas avenidas principais.",
		"pts": [[-160, -40, 1], [-100, -90, 1], [0, -95, 1], [100, -95, 1], [160, -50, 2], [170, 20, 3], [110, 70, 3], [10, 75, 3], [-90, 80, 2], [-160, 40, 1]],
		"feat": {2: ["loop", 11.0], 7: ["loop", 10.0]},
	},
	{
		"name": "Estratosfera", "theme": "sky", "w": 18.0, "traffic": 0,
		"desc": "O topo do mundo: rampas entre ilhas flutuantes.",
		"pts": [[-150, -50, 25], [-70, -95, 25], [20, -85, 26.5], [100, -100, 26.5], [160, -50, 28], [170, 30, 30], [110, 85, 31], [30, 75, 31], [-40, 100, 31], [-110, 90, 28], [-170, 30, 26]],
		"feat": {2: ["jump", 12.0, 1.4], 7: ["jump", 13.0, 1.4]},
	},
	{
		"name": "Nuvem Nove", "theme": "sky", "w": 18.0, "traffic": 0,
		"desc": "Dois loopings flutuando acima das nuvens.",
		"pts": [[-150, -40, 25], [-90, -90, 25], [10, -95, 25], [110, -95, 26], [160, -40, 27], [165, 30, 28], [100, 80, 28], [0, 80, 28], [-90, 85, 27], [-160, 40, 26]],
		"feat": {2: ["loop", 11.0], 7: ["loop", 10.0]},
	},
	{
		"name": "Arco-íris", "theme": "sky", "w": 18.0, "traffic": 0,
		"desc": "Saca-rolhas, espiral até o arco e salto entre as ilhas.",
		"pts": [[-130, -50, 24], [-50, -90, 24], [40, -90, 24], [120, -70, 25], [160, 0, 26], [130, 70, 27], [50, 85, 44], [-30, 80, 41], [-100, 90, 41], [-160, 40, 30], [-170, -20, 24]],
		"feat": {1: ["cork", 1.0], 5: ["helix", 1.0, 24.0, 17.0], 7: ["jump", 14.0, 1.5]},
	},
	{
		"name": "Espiral do Céu", "theme": "sky", "w": 18.0, "traffic": 0,
		"desc": "Nas nuvens: espirais de subida e descida, torção e salto.",
		"pts": [[-110, -55, 25], [-40, -75, 25], [40, -70, 26], [110, -40, 27], [130, 30, 28], [70, 80, 47], [-10, 75, 43], [-80, 85, 40],
			[-150, 50, 39], [-182, -5, 18], [-162, -48, 22]],
		"feat": {2: ["jump", 15.0, 1.5], 4: ["helix", 2.0, 26.0, 20.0], 6: ["cork", -1.0], 8: ["helix", 2.0, 24.0, -22.0]},
	},
	{
		"name": "Docas do Porto", "theme": "port", "w": 20.0, "traffic": 0,
		"desc": "Píeres sobre o mar e saltos entre as docas.",
		"pts": [[-150, -60, 1.5], [-60, -70, 1.5], [20, -60, 1.5], [100, -70, 1.5], [160, -40, 1.5], [170, 30, 2], [120, 80, 4], [40, 60, 5], [-40, 85, 3],
			[-110, 70, 1.5], [-165, 20, 1.5]],
		"feat": {2: ["jump", 12.0, 2.0], 7: ["jump", 12.0, 1.6]},
	},
	{
		"name": "Loop Mania", "theme": "toy", "w": 18.0, "traffic": 0,
		"desc": "Pista de brinquedo: 2 loopings, espiral, torção e salto.",
		"pts": [[-140, -40, 4], [-50, -60, 4], [60, -55, 5], [140, -20, 8], [150, 50, 10], [90, 95, 21], [0, 90, 18], [-60, 80, 15], [-130, 60, 9],
			[-170, 10, 6]],
		"feat": {1: ["loop", 11.0], 2: ["loop", 10.0], 4: ["helix", 1.0, 22.0, 11.0], 5: ["cork", 1.0], 7: ["jump", 12.0, 1.2]},
	},
]
