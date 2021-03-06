globals 
[
  finalizo-encaminamiento?                    ;bandera que indica si se establecieron los parametros de encaminamiento
  nodos-muertos
  ;TOTAL de paquetes enviados y perdidos
  total-paquetes-enviados                    
  total-paquetes-recibidos                    
  total-perdidas-por-congestion
  total-perdidas-por-encaminamiento
  total-perdidas-por-inalambricas
  ;paquetes enviados y perdidos POR TICK
  goodput
  paquetes-enviados-por-tick                    
  paquetes-recibidos-por-tick                    
  perdidas-por-congestion-por-tick
  perdidas-por-encaminamiento-por-tick
  perdidas-por-inalambricas-por-tick
  perdidas-por-goodput-por-tick
  ;efectos inalambricos
  k       ;constante de boltzaman
  c       ;velocidad de la luz
  N0      ;densidad espectral del ruido
  lambda  ;longitud de onda
  B       ;ancho de banda
  ;requerimientos de la aplicacion
  paquetes-por-segundo
]

turtles-own 
[
  ;variables del protocolo de encaminamiento
  mensaje
  nivel
  ;variables de control
  tipo
  estado
  energia
  ;variables de buffer
  tamanio-buffer
  buffer
  ;variables de transmision
  cobertura
  interferencia
]

links-own
[
  ber   ;probabilidad de error por bit
  per   ;probabilidad de error por paquete
]

to setup
  clear-all
  setup-globals         
  setup-patches
  setup-nodes           ;despliegue de nodos, establece fuentes iniciales, sink y los demas nodos
  setup-topologia       ;establece la topologia de la red
  if efectos-inalambricos
  [
    setup-enlaces         ;establece la probabilidad de error de cada enlace
  ]
  reset-ticks
end

to go
  ;resetea los contadores de paquetes POR TICK
  set paquetes-enviados-por-tick 0
  set paquetes-recibidos-por-tick 0               
  set perdidas-por-congestion-por-tick 0
  set perdidas-por-encaminamiento-por-tick 0
  set perdidas-por-inalambricas-por-tick 0
  set goodput 0
  set perdidas-por-goodput-por-tick 0
  go-patches
  go-encaminamiento
  go-fuentes
  go-nodos
  tick
end

to setup-globals
  set finalizo-encaminamiento? False
  set total-paquetes-enviados 0
  set total-paquetes-recibidos 0
  set nodos-muertos numero-de-nodos
  set total-perdidas-por-congestion 0
  set total-perdidas-por-encaminamiento 0
  set total-perdidas-por-inalambricas 0
  set paquetes-por-segundo ceiling (velocidad-de-transmision / talla-del-paquete)
  if efectos-inalambricos
  [
    set k 1.38 * (10 ^ -23)                       ;constante de boltzman [J/K]
    set c 3 * (10 ^ 8)                            ;velocidad de la luz [m/s]
    set B 4000                                    ;ancho de banda
    set N0 k * (temperatura + 273)                ;densidad espectral del ruido [W/Hz]
    set lambda c / (frecuencia-de-transmision * (10 ^ 6))
  ]
end


to setup-patches
  ask patches 
  [
    set pcolor gray
  ]
end

to setup-nodes
  set-default-shape turtles "circle"
  crt numero-de-nodos
  [
    ;se multiplca por 0.95 para que ningun nodo quede cerca de los ejes
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    set color 3 
    set size 0.5
    set mensaje -1
    set tipo "nodo"
    set estado "dormido"
    set energia 100
    set total-paquetes-recibidos 0
    set buffer []
    set interferencia 0
    ifelse talla-del-buffer = "infinito"
    [
      set tamanio-buffer 1000000000000000
    ]
    [
      let tamanio round random-normal talla-del-buffer 2
      ifelse tamanio > 0
      [
        set tamanio-buffer tamanio
      ]
      [
        set tamanio-buffer 1
      ]
    ]
  ]    
  ;establece el numero de fuentes
  ask n-of numero-de-fuentes turtles
  [
    setup-fuentes
  ]
  ;establece el sink
  ask one-of (turtles with [shape = "circle"])
  [
    setup-sink 
  ]
end

to setup-topologia
  ask turtles
  [
    ;let tortuga-vecina - a la variable tortuga-vecina le asigna
    ;one-of (...) - un elemento de (...)
    ;other turtles - el conjunto de tortugas, excepto la que ejecuta al procedimeinto
    ;with [not link-neighbor? myself] - que no estan conectadas con la tortuga que ejecuta al procedimiento
    repeat grado-promedio
    [
      set cobertura random-normal cobertura-promedio (cobertura-promedio * 0.05)
      set cobertura cobertura * 0.34
      let tortuga-vecina one-of (other turtles in-radius cobertura with [not link-neighbor? myself])
      ;si la tortuga obtenida no tiene enlace con la tortuga que ejecuta el procedimiento
      if tortuga-vecina != nobody 
      [
        ;crea un enlace con la tortuga elegida
        create-link-with tortuga-vecina
      ]
    ]
  ]
  ask links [set color white]
end

to setup-fuentes
  set shape "circle 2"
  set size 0.5
  set tipo "fuente"
  set energia 300
end

to setup-sink
    set shape "target"
    set size 1
    set mensaje 0
    set nivel 0
    set tipo "sink"
    set estado "despierto"
end

to setup-enlaces
  ask links
  [
    let fin2 end2
    let  distancia 0
    ask end1 
    [
      set distancia (distance fin2) / 0.34
    ]
    let potencia-recibida potencia-de-transmision + (20 * log lambda 10) - 21.98419728 - (20 * log distancia 10);20log 4pi=21.98419728, en dBw
    let s/n potencia-recibida - (10 * log N0 10) - (10 * log B 10) ;en dBw
    let snW 10 ^ (s/n / 10)
    ;igualamos la velocidad de transmision r con la capacidad el canal c
    let r B * log (snW + 1) 2
    let ebno s/n + (10 * log B 10) - (10 * log r 10)
    if ebno >= 0 and ebno < 3
    [set ber 0.1]
    if ebno >= 3 and ebno < 5
    [set ber 0.01]
    if ebno >= 5 and ebno < 7.5
    [set ber 0.001]
    if ebno >= 7.5 and ebno < 9
    [set ber 0.0001]
    if ebno >= 9 and ebno < 10
    [set ber 0.00001]
    ;las ber < 0.00001 se dicriminan (ber = 0)
    if ebno >= 10
    [set ber 0]
    ;calculo de la probabilidad de error por paquete
    set per 0
    ;;;;;
    set ber .2
    
    ;;;;;
    if ber != 0
    [
      let bits-incorrectos 1
      let prob-configuracion 0
      repeat tolerancia-a-fallas - 1
      [
        ;probabilidad de obtener una configuracion de cierto numero de bits incorrectos
        set prob-configuracion (ber ^ bits-incorrectos) * ((1 - ber) ^ (talla-del-paquete - bits-incorrectos))
        show prob-configuracion
        ;calculo del numero de combinaciones de una permutacion
        let combinaciones talla-del-paquete
        if bits-incorrectos - 1 > 0
        [
          let multiplicador tolerancia-a-fallas
          repeat bits-incorrectos - 1
          [
            set combinaciones combinaciones * (multiplicador - 1)
            set multiplicador multiplicador - 1
          ]
        ]
        set combinaciones combinaciones / factorial bits-incorrectos
        show combinaciones
        set per per + (combinaciones * prob-configuracion)
        show per
        set bits-incorrectos bits-incorrectos + 1
      ]
       
       ;probabilidad de obtener una configuracion sin ningun error (solo hay una configuracion)
       set prob-configuracion (1 - ber) ^ talla-del-paquete
       set per 1 - (per + prob-configuracion)
    ]
    ;;;;
    show per
  ]
end

to go-patches
  ask patches with [pcolor = 4]
  [
    set pcolor gray
  ]
end

to go-encaminamiento
  if not finalizo-encaminamiento?
  [
    print "Se estan estableciendo parametros de encaminamiento..."
    ask turtles
    [
      if mensaje >= 0
      [
        set-parametros-encaminamiento
        envia-mensaje-encaminamiento
      ]
    ]
    if all? turtles [mensaje = -1]
    [
      set finalizo-encaminamiento? True
      print "Los parametros de encaminamiento se han establecido con exito."
      reset-ticks
    ]
  ]
end

to go-fuentes
  if activar-fuentes and finalizo-encaminamiento? 
  [
    let num-paquetes media
    if generacion-de-paquetes = "pdf-poisson"
    [
      set num-paquetes random-poisson media
    ]
    if generacion-de-paquetes = "en-aumento"
    [
      set num-paquetes random-poisson (media + ticks)
    ]
    repeat num-paquetes
    [
      generar-paquete
    ]
    if generacion-de-paquetes = "rafaga"
    [
      set activar-fuentes False
    ]
  ]
end

to go-nodos
  ;los nodos que tienen paquetes en buffer 
  print "TICK"
  ask-concurrent turtles
  [
    let envios 0
    foreach buffer
    [
      ;reenvia el mensaje si es de datos y esta de acuerdo a la velocidad de transmision        
      if envios < velocidad-de-transmision / talla-del-paquete and item 0 ? = -2
      [
        let nodo-destino protocolo-encaminamiento
        if is-turtle? nodo-destino 
        [
          set envios envios + 1
          ; y si no hay perdidas inalambricas y el control de congestion lo permite
          ifelse not efectos-inalambricos and control-de-congestion
          [
            let paquete saca-paquete-del-buffer
            envia-mensaje paquete nodo-destino
          ]
          [
            ;perdidas por efectos inalambricos
          ]
        ]
      ]
    ]
  ]
  ask turtles
  [
    ifelse length buffer > 0
    [
      set label length buffer
    ]
    [
      set label ""
    ]
  ]
end


to generar-paquete
  ask-concurrent turtles with [tipo = "fuente" and estado = "despierto"]
  [
    set total-paquetes-enviados total-paquetes-enviados + 1
    set paquetes-enviados-por-tick paquetes-enviados-por-tick + 1
    ;paquete [tipo tiempo_de_salida saltos], tipo = -2 Mensaje de datos
    let paquete [-2 0 0]
    set paquete replace-item 1 paquete ticks
    let nodo-destino protocolo-encaminamiento
    if is-turtle? nodo-destino 
    [
      envia-mensaje paquete nodo-destino
    ]
  ]
end

to envia-mensaje-encaminamiento
  ;envia mensaje para establecer parametros del protocolo de encaminamiento a sus vecinos que no han sido visitados
  let emisor who
  let emisor-nivel nivel
  ask link-neighbors with [estado = "dormido"]
  [
    set mensaje emisor-nivel
    set estado "despierto"
   ]
   set mensaje -1   
end

to envia-mensaje [paquete nodo-destino]
  ;envia mensaje de datos
  print "soy"
  show who
  ;genera interferencia
  genera-interferencia nodo-destino
  ask link-with nodo-destino 
  [
    set color red
  ]
  ask nodo-destino
  [
    ifelse tipo = "sink"
    [
      set total-paquetes-recibidos total-paquetes-recibidos + 1
      set paquetes-recibidos-por-tick paquetes-recibidos-por-tick + 1
      ifelse ticks - item 1 paquete > retardo-permitido
      [
        set perdidas-por-goodput-por-tick perdidas-por-goodput-por-tick + 1
      ]
      [
        set goodput goodput + 1
      ]
    ]
    [
      consume-energia
      mete-paquete-al-buffer paquete
    ]
  ]
end

;establece un "protocolo de encaminamiento", crea un arbol por medio del algoritmo de propagacion de la informacion
to set-parametros-encaminamiento 
  set nivel mensaje + 1
  set color lime
  set nodos-muertos nodos-muertos - 1
end

;indica el nodo a que se enviara el mensaje
to-report protocolo-encaminamiento
  let mi_nivel nivel
  let nodo-destino one-of link-neighbors with [nivel < mi_nivel and estado != "muerto"]
  if not is-turtle? nodo-destino 
  [
    set total-perdidas-por-encaminamiento total-perdidas-por-encaminamiento + length buffer
    set perdidas-por-encaminamiento-por-tick perdidas-por-encaminamiento-por-tick + length buffer
    set buffer []
    set size 0.5
    ;EL NODO YA NO TIENE A QUIEN REENVIAR
    ;RESTAURAR LA TALLA DEL NODO 
    ;REINICIAR SU BUFFER A 0 YA QUE SUS PAQUETES SE HAN SUMADO A LA PERDIDAS
  ]  
  report nodo-destino
end

to-report control-de-congestion
  report true
end

to-report saca-paquete-del-buffer
   let paquete first buffer
   set buffer but-first buffer
   let tam size
   set size (tam - 0.15)
   report paquete
end

to mete-paquete-al-buffer [paquete]
  ifelse length buffer <= tamanio-buffer
  [
    set paquete replace-item 2 paquete (item 2 paquete + 1)
    set buffer lput paquete buffer
    let tam size
    set size (tam + 0.15)
  ]
  [
    set total-perdidas-por-congestion total-perdidas-por-congestion + 1
    set perdidas-por-congestion-por-tick perdidas-por-congestion-por-tick + 1
  ]
end

to consume-energia
  set energia energia - energia-por-transmision
  if energia > 35 and energia < 70
  [
    set color yellow
  ]
  if energia > 0 and energia <= 35
  [
    set color red
  ]
  if energia < 0
  [
    set color 2
    set size 0.5
    set estado "muerto"
    ask my-links
    [
      set color 3
    ]
    set nodos-muertos nodos-muertos + 1
    set total-perdidas-por-encaminamiento total-perdidas-por-encaminamiento + length buffer ;contador-de-paquetes-recibidos
    set perdidas-por-encaminamiento-por-tick perdidas-por-encaminamiento-por-tick + length buffer ;contador-de-paquetes-recibidos
  ]
end

to genera-interferencia [nodo-destino]
  ask patches in-radius cobertura
  [
    set pcolor 4
  ]
  let tortugas-afectadas turtles in-radius cobertura
  set tortugas-afectadas tortugas-afectadas with [who != [who] of nodo-destino]
  let mi_id who
  set tortugas-afectadas tortugas-afectadas with [who != mi_id]
  ask-concurrent tortugas-afectadas
  [
    calcula-potencia-recibida
  ]
end

to calcula-potencia-recibida
end

to-report perdidas-inalambricas? [enlace]
  let perdida false
  ask enlace
  [
    if (ber * 10000000) > random 10000000
    [
      set total-perdidas-por-inalambricas total-perdidas-por-inalambricas + 1
      set perdidas-por-inalambricas-por-tick perdidas-por-inalambricas-por-tick + 1
      set perdida true
    ]
  ]
  report perdida 
end

to-report factorial [n]
  let n! 1
  if n = 2
  [ set n! 2]
  if n = 3
  [ set n! 6]
  if n = 4
  [ set n! 24]
  if n = 5
  [ set n! 120]
  if n = 6
  [ set n! 720]
  if n = 7
  [ set n! 5040]
  if n = 8
  [ set n! 40320]
  if n = 9
  [ set n! 362880]
  if n = 10
  [ set n! 3628800]
  if n = 11
  [ set n! 39916800]
  if n = 12
  [ set n! 479001600]
  report n!  
end
@#$#@#$#@
GRAPHICS-WINDOW
5
10
518
515
17
16
14.37143
1
10
1
1
1
0
0
0
1
-17
17
-16
16
1
1
1
ticks
30.0

SLIDER
0
550
163
583
numero-de-nodos
numero-de-nodos
0
1000
163
1
1
NIL
HORIZONTAL

SLIDER
533
552
722
585
numero-de-fuentes
numero-de-fuentes
1
20
1
1
1
NIL
HORIZONTAL

SLIDER
172
550
340
583
grado-promedio
grado-promedio
1
6
4
1
1
NIL
HORIZONTAL

BUTTON
648
87
721
120
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
798
89
861
122
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
147
594
340
627
cobertura-promedio
cobertura-promedio
1
30
10.9
0.1
1
m.
HORIZONTAL

SWITCH
370
551
519
584
activar-fuentes
activar-fuentes
1
1
-1000

PLOT
891
10
1333
246
Paquetes Recibidos
Tiempo [s]
Paquetes
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"útiles" 1.0 0 -13840069 true "" "plot goodput"
"inservibles" 1.0 0 -2674135 true "" "plot perdidas-por-goodput-por-tick"

CHOOSER
369
594
544
639
generacion-de-paquetes
generacion-de-paquetes
"rafaga" "continua" "pdf-poisson" "pdf-normal" "en-aumento"
0

SLIDER
0
645
276
678
energia-por-transmision
energia-por-transmision
0
5
0.61
.01
1
%
HORIZONTAL

MONITOR
519
85
635
130
nodos inactivos
nodos-muertos
17
1
11

TEXTBOX
521
10
890
78
Modelo de Transmisión: Pérdidas en el Espacio Libre\nTipo de Ruido: Blanco\nEsquema de Modulación: BPSK\nAncho de Banda: 4khz
14
2.0
0

PLOT
892
250
1335
516
Paquetes Pérdidos
Tiempo [s]
Paquetes
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Congestión" 1.0 0 -5825686 true "" "plot perdidas-por-congestion-por-tick"
"Efectos inlámbricos" 1.0 0 -2674135 true "" "plot perdidas-por-inalambricas-por-tick"
"Encaminamiento" 1.0 0 -955883 true "" "plot perdidas-por-encaminamiento-por-tick"

CHOOSER
0
592
138
637
talla-del-buffer
talla-del-buffer
1 2 4 8 16 32 "infinito"
3

BUTTON
729
89
793
122
tick
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
941
547
1106
580
Temperatura
Temperatura
10
30
30
.1
1
°C
HORIZONTAL

SLIDER
755
597
1035
630
potencia-de-transmision
potencia-de-transmision
-30
-5
-30
1
1
dBw
HORIZONTAL

SLIDER
755
638
1031
671
frecuencia-de-transmision
frecuencia-de-transmision
2400
2480
2480
5
1
Mhz
HORIZONTAL

SWITCH
755
550
932
583
efectos-inalambricos
efectos-inalambricos
1
1
-1000

MONITOR
795
202
893
247
por congestion
total-perdidas-por-congestion
17
1
11

MONITOR
517
202
669
247
por efectos inalambricos
total-perdidas-por-inalambricas
17
1
11

MONITOR
667
203
794
248
por encaminamiento
total-perdidas-por-encaminamiento
17
1
11

SLIDER
557
598
723
631
media
media
1
32
1
1
1
paquetes
HORIZONTAL

SLIDER
1143
594
1339
627
talla-del-paquete
talla-del-paquete
256
1024
512
256
1
bits
HORIZONTAL

SLIDER
755
681
933
714
tolerancia-a-fallas
tolerancia-a-fallas
0
64
24
2
1
bits
HORIZONTAL

MONITOR
648
133
720
178
enviados
total-paquetes-enviados
17
1
11

MONITOR
727
133
800
178
recibidos
total-paquetes-recibidos
17
1
11

PLOT
518
248
893
516
Paquetes Enviados y Recibidos
Tiempo [s]
Paquetes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"recibidos" 1.0 0 -13840069 true "" "plot paquetes-recibidos-por-tick"
"enviados" 1.0 0 -13791810 true "" "plot paquetes-enviados-por-tick"

TEXTBOX
520
181
670
199
Pérdidas\n
12
0.0
1

TEXTBOX
521
145
671
163
Total de Paquetes
12
0.0
1

SLIDER
1142
549
1338
582
retardo-permitido
retardo-permitido
5
180
5
5
1
s
HORIZONTAL

TEXTBOX
83
527
263
557
Configuracion de los Nodos
12
0.0
1

TEXTBOX
435
529
661
559
Configuracion de los Nodos Fuente
12
0.0
1

TEXTBOX
864
526
1014
544
Efectos Inalámbricos
12
0.0
1

TEXTBOX
1141
525
1345
543
Requerimientos de la Aplicación
12
0.0
1

SLIDER
1097
637
1342
670
velocidad-de-transmision
velocidad-de-transmision
1024
2096
1024
512
1
bps
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="efectos-inalambricos">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="generacion-de-paquetes">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="velocidad-de-transmision">
      <value value="2400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energia-por-transmision">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numero-de-fuentes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grado-promedio">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cobertura-promedio">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="numero-de-nodos">
      <value value="27"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frecuencia-de-transmision">
      <value value="2480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Potencia-de-transmision">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activar-fuentes">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="talla-del-buffer">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Temperatura">
      <value value="23"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
