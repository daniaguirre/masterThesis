breed [nodes node]
breed [packets packet]

nodes-own 
[
  ;variables del protocolo de encaminamiento
  mensaje
  nivel
  ;variables de control
  kind
  state
  energy
  idle
  ;variables de buffer
  max-buffer-length
  buffer
  ;variables de transmision
  coverage
  ;variables de satisfaccion
  packet-count
  sigma_x ;satisfaccion promedio de los paquetes que ha transportado
]

packets-own
[
  creation-time
  source-node
  sender
  next-node
  packet-type
  data
  ttl
  ;campos de control
  sigma ;satisfaccion del paquete
]

globals 
[
  is-set-routing-finished?                    
  died-nodes
  ;TOTAL de paquetes enviados y perdidos
  packets-send-total                    
  total-received-packets                  
  total-congestion-losses
  total-routing-losses
  total-wireless-losses
  lost-generated-packets
  ;paquetes enviados y perdidos POR TICK
  goodput
  sent-packets-per-tick
  received-packets-per-tick                    
  congestion-losses-per-tick
  routing-losses-per-tick
  goodput-losses-per-tick
  wireless-losses-per-tick
  per
  ;simulation of discrete events
  agenda
  current-event
]

to setup
  clear-all
  setup-globals         
  setup-patches
  setup-nodes           ;despliegue de nodos, establece fuentes iniciales, sink y los demas nodos
  setup-topologia       ;establece la topologia de la red
  setup-encaminamiento
  set active-sources true
  reset-ticks
  setup-schedule
end

to go
    ifelse length agenda > 0
    [
      ;obtener el siguiente evento de la agenda
      set current-event next-event
    ;  show current-event
      ;actualizar el reloj
      let tiempo-evento-actual first current-event
      tick-advance tiempo-evento-actual - ticks
      ;si el evento es de actualizar graficas
      ifelse item 1 current-event = "update-plots"
      [
        update-charts
      ]
      [
        go-node
      ]
    ]
    [
;      ifelse active-sources
 ;     [
 ;       setup-schedule
  ;    ]
  ;    [
        finish-simulation
        stop
   ;   ]
    ]    
end

to arrive [pack]
  ;el paquete se hace visible y marca su trayectoria
  ask pack
  [
    pen-down
    set pen-size 4
    move-to [next-node] of self
  ]
  ;si el nodo es de tipo sink, registra paquetes recibidos (entregados)
  ifelse kind = "sink"
  [
      set total-received-packets total-received-packets + 1
      set received-packets-per-tick received-packets-per-tick + 1
     ; print "recibi"
      ;show pack
      let retardo ticks - [creation-time] of pack
      ifelse retardo > tolerated-delay
      [
        set goodput-losses-per-tick goodput-losses-per-tick + 1
      ]
      [
        set goodput goodput + 1
      ]
      ask pack
      [
        die
      ]
  ]
  ;si es un nodo intermedio...
  [
    ;hace el control de congestion
    congestion-control pack
    ;si esta libre cambia a ocupado y agenda un envio de paquete
    ifelse idle
    [
      set idle false
      schedule-sent pack ticks "envio"
    ]
    ;si esta ocupado coloca el paquete en el buffer
    [
      place-packet-into-buffer pack
    ]
  ]
end

to calculate-satisfaction [pack]
  let delay (ticks - [creation-time] of pack) - ( [ttl] of pack * transmission-time )
end

to congestion-control [pack]
  calculate-satisfaction pack
end

to consume-energy
  set energy energy - battery-consumed-by-transmission
  if energy > 35 and energy < 70
  [
    set color yellow
  ]
  if energy > 0 and energy <= 35
  [
    set color red
  ]
  if energy <= 0
  [
    set color 2
    set shape "x"
    set size 0.5
    set state "muerto"
    ask my-links
    [
      set color 3
    ]
    set died-nodes died-nodes + 1
    empty-buffer
    set size 0.5
  ]
end

to finish-simulation
 ; print "termina simulacion"
end

to-report generate-packet
  let source self
  let pack nobody
  hatch-packets 1
  [
    set creation-time ticks
    set source-node source
    set sender source
    set next-node source
    set packet-type "data"
    set ttl 0
    set data ""
    set size 0.4
    set shape "box"
    set color sky
    set pack self
    ;set label ""
  ]
 report pack
end

to go-node
  let pack item 3 current-event
  let node-in-turn item 2 current-event
  let event-type item 1 current-event
  ask node-in-turn
  [
    ifelse state != "muerto"
    [
      if event-type = "packet-arrive"
      [
        ifelse random 1000 < 2 and [ttl] of pack > 0
        [
          ask pack
          [
            set total-wireless-losses total-wireless-losses + 1
            set wireless-losses-per-tick wireless-losses-per-tick + 1          
           ; print "perdida inalambrica"
           ; show self
            die
          ]
        ]
        [
          arrive pack
        ]
      ]
      if event-type = "envio"
      [
        sent pack
      ]
      if event-type = "monitoring"
      [
        monitoring
      ]
    ]
    [ 
      ifelse is-packet? pack and [ttl] of pack > 0
      [
        set total-routing-losses total-routing-losses + 1
        set routing-losses-per-tick routing-losses-per-tick + 1
     ;   print "perdida encaminameinto (nodo muerto)"
      ;  show pack
      ]
      [
       ; print "pack sin enviar (nodo muerto)"
       ; show pack
      ]
      if is-packet? pack
      [
        ask pack
        [
          die
        ]
      ]
    ]
  ]
  ask nodes
  [
    ifelse length buffer > 0
    [
     ; set label length buffer
    ]
    [
    ;  set label ""
    ]
  ]
end

to initialize-stats
  set goodput 0
  set sent-packets-per-tick 0
  set received-packets-per-tick 0                    
  set congestion-losses-per-tick 0
  set routing-losses-per-tick 0
  set goodput-losses-per-tick 0
  set wireless-losses-per-tick 0
end


to-report next-event
  set agenda (sort-by [first ?1 < first ?2] agenda)
  let prox-evento []
  ifelse length agenda >= 2 and item 0 first agenda = item 0 item 1 agenda and item 1 first agenda = "update-plots" 
  [
    set prox-evento item 1 agenda
  ]
  [
    set prox-evento first agenda
  ]
  set agenda remove prox-evento agenda
  report prox-evento
end

to place-packet-into-buffer [paquete]
  ifelse length buffer <= max-buffer-length
  [
    set buffer lput paquete buffer
    let tam size
    set size (tam + 0.1)
  ]
  [
    ask paquete
    [
      ifelse ttl > 0
      [
        set total-congestion-losses total-congestion-losses + 1
        set congestion-losses-per-tick congestion-losses-per-tick + 1
      ;  print "perdida cong buffer lleno"
       ; show self
      ]
      [
        set lost-generated-packets lost-generated-packets + 1
    ;    print "paq sin enviar buffer lleno"
     ;   show self
      ]
      die
    ]
  ]
end

to-report process-packet [paquete]
  let current-node self
  ask paquete 
  [
    set sender current-node
    set ttl ttl + 1
  ]
  report paquete
end

to schedule-arrival [paquete destino tiempo]
  let evento-arribo ["tiempo-arribo" "packet-arrive" "nodo-en-turno" "paquete"]
  set evento-arribo replace-item 0 evento-arribo tiempo
  set evento-arribo replace-item 2 evento-arribo destino
  set evento-arribo replace-item 3 evento-arribo paquete
  set agenda lput evento-arribo agenda
end

to schedule-sent [paquete tiempo evento]
  let evento-envio ["tiempo-envio" "envio" "nodo-en-turno" "paquete"]
  set evento-envio replace-item 0 evento-envio tiempo
  set evento-envio replace-item 1 evento-envio evento
  set evento-envio replace-item 2 evento-envio self
  set evento-envio replace-item 3 evento-envio paquete
  set agenda lput evento-envio agenda
end

to schedule-update-charts
  let evento-actualizacion [0 "update-plots"]
  set evento-actualizacion replace-item 0 evento-actualizacion (ticks + 1)
  set agenda lput evento-actualizacion agenda
end

to monitoring
  ;genera un paquete
  let pack generate-packet
  let time [creation-time] of pack
  ;agenda un arrivo de paquete de paquetes
  schedule-arrival pack self ticks
  ;agenda un evento monitoreo
  if active-sources
  [
    schedule-sent "X" time-of-packet-generation "monitoring"
  ]
end

to sent [pack]
  ;si el evento no tiene un paquete, entonces saca el paquete del buffer
  ifelse not is-packet? pack
  [
    set pack take-packet-out-of-buffer
  ]
  [
   ;si el nodo que envia es fuente aumenta el contador de paquetes enviados
   if [ttl] of pack = 0
   [
     set packets-send-total packets-send-total + 1
     set sent-packets-per-tick sent-packets-per-tick + 1
   ;  print "envie"
    ; show pack
   ]
  ]
  ;procesa paquete
  set pack process-packet pack
  consume-energy
  ifelse state != "muerto"
  [
    ;agenda arribo en nodo destino
    let next-hub routing-protocol
    ask pack
    [
      set next-node next-hub
    ]
    schedule-arrival pack [next-node] of pack ticks + transmission-time
    ;si hay paquetes en buffer agenda envio de paquete
    ifelse length buffer > 0
    [
      schedule-sent "buffer" ticks + transmission-time "envio"
    ]
    ;si no hay paquetes en el buffer cambia a estado libre
    [
      set idle true
    ]
  ]
  [
    ;registra perdidas por encaminamiento
    ifelse [ttl] of pack > 1
    [
      set total-routing-losses total-routing-losses + 1
      set routing-losses-per-tick routing-losses-per-tick + 1
    ;  print "perdida encaminameinto (acabo pila)"
     ; show pack
    ]
    [
    ;  print "paq sin enviar (acabo pila)"
     ; show pack
    ]
    ask pack
    [
      die
    ]
  ]
end

to-report transmission-time
  report packet-lenght / (transmission-rate * 1000)
end

to setup-globals
  set is-set-routing-finished? False
  set packets-send-total 0
  set total-received-packets 0
  set died-nodes number-of-nodes
  set total-congestion-losses 0
  set total-routing-losses 0
  set total-wireless-losses 0
  set lost-generated-packets 0
  set per 0.2
  set agenda []
  random-seed 2
end

to setup-nodes
  set-default-shape nodes "circle"
  create-nodes number-of-nodes
  [
    ;se multiplca por 0.95 para que ningun nodo quede cerca de los ejes
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    set color 3 
    set size 0.5
    set mensaje -1
    set kind "nodo"
    set state "dormido"
    set energy 100
    set buffer []
    set idle true
    ifelse buffer-length = "infinito"
    [
      set max-buffer-length 1000000000000000
    ]
    [
      let tamanio round random-normal buffer-length 2
      ifelse tamanio > 0
      [
        set max-buffer-length tamanio
      ]
      [
        set max-buffer-length 1
      ]
    ]
  ]    
  ;establece el numero de fuentes
  ask n-of number-of-sources nodes
  [
    setup-sources
  ]
  ;establece el sink
  ask one-of (nodes with [shape = "circle"])
  [
    setup-sink 
  ]
end

to setup-patches
  ask patches 
  [
    set pcolor gray
  ]
end

to setup-schedule
  ;agenda arribos en la agenda para las fuentes
  ask nodes with [kind = "fuente" and state = "despierto"]
  [
    schedule-sent 0 time-of-packet-generation "monitoring"
  ]
  schedule-update-charts ;agenda 1a actualizacion de graficas
end

to setup-sink
    set shape "target"
    set mensaje 0
    set nivel 0
    set kind "sink"
    set state "despierto"
    set size 1
    set label-color red
    set label "SINK"
end

to setup-sources
  set shape "circle 2"
  set kind "fuente"
  set energy 300
end

to setup-topologia
  ask nodes
  [
    ;let tortuga-vecina - a la variable tortuga-vecina le asigna
    ;one-of (...) - un elemento de (...)
    ;other nodes - el conjunto de tortugas, excepto la que ejecuta al procedimeinto
    ;with [not link-neighbor? myself] - que no estan conectadas con la tortuga que ejecuta al procedimiento
    repeat average-degree-of-connectivity
    [
      set coverage random-normal (average-coverage / 10) ((average-coverage * 0.01) / 10)
      set coverage coverage * 0.34
      let tortuga-vecina one-of (other nodes in-radius coverage with [not link-neighbor? myself])
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

to-report take-packet-out-of-buffer
   let paquete first buffer
   set buffer but-first buffer
   let tam size
   set size (tam - 0.1)
   report paquete
end

;REFINA EL CASO "en-aumento"
to-report time-of-packet-generation
  let  generation-time 0
  if generator-mode = "pdf-poisson"
  [
    set generation-time ticks + random-exponential (1 / generation-packets-rate)
  ]
  if generator-mode = "pdf-normal"
  [
    set generation-time ticks + random-normal (1 / generation-packets-rate) 1
  ]
  if generator-mode = "continuous"
  [
    set generation-time ticks + ( 1 / generation-packets-rate )
  ]
  ;el tiempo de generacion de paquetes debe ser mayor o igual al tiempo de transmision
  if (generation-time - ticks) < transmission-time
  [
    set generation-time ticks + transmission-time
  ]
  report generation-time
end

to update-charts
  update-plots
  initialize-stats
  ;agenda la proxima actualizacion
  if length agenda != 0
  [
    schedule-update-charts
  ]
end

to setup-encaminamiento
  while [not is-set-routing-finished?]
  [
    ask nodes
    [
      if mensaje >= 0
      [
        set-parametros-encaminamiento
        envia-mensaje-encaminamiento
      ]
    ]
    if all? nodes [mensaje = -1]
    [
      set is-set-routing-finished? True
    ]
  ]
end

to empty-buffer
  foreach buffer 
  [
    set buffer remove ? buffer
    ask ?
    [
      ifelse ttl > 0
      [
        set total-routing-losses total-routing-losses + 1
        set routing-losses-per-tick routing-losses-per-tick + 1
      ;  print "perdida encaminameinto (vaciando buffer)"
       ; show self
      ]
      [
      ;  print "paq sin enviar (vaciando buffer)"
       ; show self
      ]
      die
    ]
  ]
end

to envia-mensaje-encaminamiento
  ;envia mensaje para establecer parametros del protocolo de encaminamiento a sus vecinos que no han sido visitados
  let emisor who
  let emisor-nivel nivel
  ask link-neighbors with [state = "dormido"]
  [
    set mensaje emisor-nivel
    set state "despierto"
   ]
   set mensaje -1   
end

;establece un "protocolo de encaminamiento", crea un arbol por medio del algoritmo de propagacion de la informacion
to set-parametros-encaminamiento 
  set nivel mensaje + 1
  set color lime
  set died-nodes died-nodes - 1
end

;indica el nodo al que se enviara el mensaje
to-report routing-protocol
  let mi_nivel nivel
  let nodo-destino one-of link-neighbors with [nivel < mi_nivel]
  report nodo-destino
end
@#$#@#$#@
GRAPHICS-WINDOW
7
14
520
519
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
0
0
1
seconds
30.0

SLIDER
126
627
296
660
number-of-nodes
number-of-nodes
10
1000
250
1
1
NIL
HORIZONTAL

SLIDER
127
666
294
699
number-of-sources
number-of-sources
1
20
10
1
1
NIL
HORIZONTAL

SLIDER
541
681
780
714
average-degree-of-connectivity
average-degree-of-connectivity
1
15
6
1
1
NIL
HORIZONTAL

BUTTON
728
16
801
49
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
869
16
932
49
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
542
722
781
755
average-coverage
average-coverage
70
120
110
5
1
m.
HORIZONTAL

SWITCH
1058
669
1218
702
active-sources
active-sources
0
1
-1000

PLOT
969
11
1414
247
Received Packets
Time [s]
Packets
0.0
4.0
0.0
10.0
true
true
"" ""
PENS
"on time" 1.0 0 -13840069 true "" "plotxy ticks goodput"
"out time" 1.0 0 -2674135 true "" "plotxy ticks goodput-losses-per-tick"

CHOOSER
1059
752
1277
797
generator-mode
generator-mode
"continuous" "pdf-poisson" "pdf-normal" "increse"
1

SLIDER
542
761
781
794
battery-consumed-by-transmission
battery-consumed-by-transmission
0
5
0.01
.01
1
%
HORIZONTAL

MONITOR
651
16
725
61
died nodes
died-nodes
17
1
11

TEXTBOX
881
895
1250
963
Modelo de Transmisión: Pérdidas en el Espacio Libre\nTipo de Ruido: Blanco\nEsquema de Modulación: BPSK\nAncho de Banda: 4khz
14
2.0
0

PLOT
571
249
1027
519
Lost Packets
Time [s]
Packets
0.0
4.0
0.0
10.0
true
true
"" ""
PENS
"due to link level congestion" 1.0 0 -13840069 true "" "plot wireless-losses-per-tick"
"due to node level congestion" 1.0 0 -13791810 true "" "plot routing-losses-per-tick + congestion-losses-per-tick"

CHOOSER
541
631
779
676
buffer-length
buffer-length
0 2 4 8 16 32 "infinito"
3

BUTTON
803
16
867
49
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
1058
629
1218
662
temperature
temperature
10
30
30
.1
1
°C
HORIZONTAL

SLIDER
788
682
991
715
power-transmission
power-transmission
-30
-5
-30
1
1
dBw
HORIZONTAL

SLIDER
789
725
992
758
transmission-frequency
transmission-frequency
2400
2480
2480
5
1
Mhz
HORIZONTAL

SWITCH
787
641
990
674
wireless-effects
wireless-effects
1
1
-1000

MONITOR
575
182
737
227
due to link level congestion
total-wireless-losses
17
1
11

MONITOR
741
182
913
227
due to node level congestion
total-routing-losses + total-congestion-losses
17
1
11

SLIDER
1058
711
1277
744
generation-packets-rate
generation-packets-rate
1
50
30
1
1
packets / s
HORIZONTAL

SLIDER
126
708
293
741
packet-lenght
packet-lenght
256
2048
2048
256
1
bits
HORIZONTAL

SLIDER
306
670
472
703
tolerated-error-bit
tolerated-error-bit
0
64
50
2
1
bits
HORIZONTAL

MONITOR
575
102
640
147
sent
packets-send-total
17
1
11

MONITOR
648
101
713
146
received
total-received-packets
17
1
11

PLOT
1031
250
1415
520
Sent and Received Packets
Time[s]
Packets
0.0
4.0
0.0
10.0
true
true
"" ""
PENS
"received" 1.0 0 -13840069 true "" "plotxy ticks received-packets-per-tick"
"sent" 1.0 0 -13791810 true "" "plotxy ticks sent-packets-per-tick"

TEXTBOX
578
161
768
201
Monitors of lost packets
16
0.0
1

TEXTBOX
580
80
730
100
Monitors of packets
16
0.0
1

SLIDER
306
710
480
743
tolerated-delay
tolerated-delay
5
180
20
5
1
s
HORIZONTAL

TEXTBOX
741
596
921
626
Node Settings
18
0.0
1

TEXTBOX
1075
593
1286
637
Source Node Settings\n
18
0.0
1

SLIDER
307
631
479
664
transmission-rate
transmission-rate
120
300
120
10
1
kbps
HORIZONTAL

MONITOR
573
16
647
61
clock (s)
ticks
5
1
11

TEXTBOX
226
590
400
634
Application Settings\n
18
0.0
1

MONITOR
720
102
819
147
unsent packets 
lost-generated-packets
17
1
11

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
  <experiment name="experiment-arraivail-buffer" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300"/>
    <metric>total-wireless-losses + total-routing-losses + total-congestion-losses</metric>
    <enumeratedValueSet variable="buffer-length">
      <value value="0"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="16"/>
      <value value="32"/>
      <value value="&quot;infinito&quot;"/>
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
