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
;  ;efectos inalambricos
;  k       ;constante de boltzaman
;  c       ;velocidad de la luz
;  N0      ;densidad espectral del ruido
;  lambda  ;longitud de onda
;  B       ;ancho de banda
  ;agenda
  agenda
  ;requerimientos de la aplicacion
  paquetes-por-segundo
  ;desempeño
  satisfaccion-promedio-de-paquete
  satisfaccion-del-sistema
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
  ;sed
  libre
  ultimo-arribo-agendado
  ultima-velocidad-arribos
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
  setup-encaminamiento
  set active-sources true
  reset-ticks
  agendar-actualizacion-graficas
end

to go
    go-fuentes
    ifelse length agenda > 0
    [
      ;obtener el siguiente evento de la agenda
      let evento-actual siguiente-evento
      ;actualizar el reloj
      let tiempo-evento-actual first evento-actual
      tick-advance tiempo-evento-actual - ticks
      ;si el evento es de actualizar graficas
      ifelse item 1 evento-actual = "update-plots"
      [
        actualizar-graficas
      ]
      [
        go-nodo evento-actual
      ]
    ]
    [
      finaliza-simulacion
      stop
    ]
end

to setup-globals
  set finalizo-encaminamiento? False
  set total-paquetes-enviados 0
  set total-paquetes-recibidos 0
  set nodos-muertos number-of-nodes
  set total-perdidas-por-congestion 0
  set total-perdidas-por-encaminamiento 0
  set total-perdidas-por-inalambricas 0
  set agenda []
  set satisfaccion-promedio-de-paquete 0
  set satisfaccion-del-sistema 0
;  if efectos-inalambricos
;  [
;    set k 1.38 * (10 ^ -23)                       ;constante de boltzman [J/K]
;    set c 3 * (10 ^ 8)                            ;velocidad de la luz [m/s]
;    set B 4000                                    ;ancho de banda
;    set N0 k * (temperatura + 273)                ;densidad espectral del ruido [W/Hz]
;    set lambda c / (frecuencia-de-transmision * (10 ^ 6))
;  ]
end


to setup-patches
  ask patches 
  [
    set pcolor white
  ]
end

to setup-nodes
  set-default-shape turtles "circle"
  crt number-of-nodes
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
    set libre true
    ifelse buffer-length = "infinito"
    [
      set tamanio-buffer 1000000000000000
    ]
    [
      let tamanio round random-normal buffer-length 2
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
  ask n-of Number-of-sources turtles
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
    repeat average-degree-of-connectivity
    [
      set cobertura random-normal average-coverage (average-coverage * 0.05)
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
  ask links [set color black]
end

to setup-fuentes
  set shape "triangle"
  set size 1.5
  set tipo "fuente"
  set energia 300
  set ultimo-arribo-agendado 0
end

to setup-sink
    set color gray
    set shape "target"
    set size 1.5
    set mensaje 0
    set nivel 0
    set tipo "sink"
    set estado "despierto"
end

;to setup-enlaces
;  ask links
;  [
;    let fin2 end2
;    let  distancia 0
;    ask end1 
;    [
;      set distancia (distance fin2) / 0.34
;    ]
;    let potencia-recibida potencia-de-transmision + (20 * log lambda 10) - 21.98419728 - (20 * log distancia 10);20log 4pi=21.98419728, en dBw
;    let s/n potencia-recibida - (10 * log N0 10) - (10 * log B 10) ;en dBw
;    let snW 10 ^ (s/n / 10)
;    ;igualamos la velocidad de transmision r con la capacidad el canal c
;    let r B * log (snW + 1) 2
;    let ebno s/n + (10 * log B 10) - (10 * log r 10)
;    if ebno >= 0 and ebno < 3
;    [set ber 0.1]
;    if ebno >= 3 and ebno < 5
;    [set ber 0.01]
;    if ebno >= 5 and ebno < 7.5
;    [set ber 0.001]
;    if ebno >= 7.5 and ebno < 9
;    [set ber 0.0001]
;    if ebno >= 9 and ebno < 10
;    [set ber 0.00001]
;    ;las ber < 0.00001 se dicriminan (ber = 0)
;    if ebno >= 10
;    [set ber 0]
;    ;calculo de la probabilidad de error por paquete
;    set per 0
;    ;;;;;
;    set ber .2
;    
;    ;;;;;
;    if ber != 0
;    [
;      let bits-incorrectos 1
;      let prob-configuracion 0
;      repeat tolerancia-a-fallas - 1
;      [
;        ;probabilidad de obtener una configuracion de cierto numero de bits incorrectos
;        set prob-configuracion (ber ^ bits-incorrectos) * ((1 - ber) ^ (talla-del-paquete - bits-incorrectos))
;        show prob-configuracion
;        ;calculo del numero de combinaciones de una permutacion
;        let combinaciones talla-del-paquete
;        if bits-incorrectos - 1 > 0
;        [
;          let multiplicador tolerancia-a-fallas
;          repeat bits-incorrectos - 1
;          [
;            set combinaciones combinaciones * (multiplicador - 1)
;            set multiplicador multiplicador - 1
;          ]
;        ]
;        set combinaciones combinaciones / factorial bits-incorrectos
;        show combinaciones
;        set per per + (combinaciones * prob-configuracion)
;        show per
;        set bits-incorrectos bits-incorrectos + 1
;      ]
;       
;       ;probabilidad de obtener una configuracion sin ningun error (solo hay una configuracion)
;       set prob-configuracion (1 - ber) ^ talla-del-paquete
;       set per 1 - (per + prob-configuracion)
;    ]
;    ;;;;
;    show per
;  ]
;end

to setup-encaminamiento
  while [not finalizo-encaminamiento?]
  [
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
    ]
  ]
end

to go-fuentes
  ifelse active-sources
  [
    ask turtles with [tipo =  "fuente" and estado = "despierto"]
    [
      if ultima-velocidad-arribos = 0
      [
        set ultima-velocidad-arribos arraival-rate
      ]
      let paquete generar-paquete-de-datos
      let tiempo-de-arribo tiempo-entre-paquetes
      agendar-envio paquete tiempo-de-arribo
      set ultimo-arribo-agendado tiempo-de-arribo
    ]
  ]
  [
    ask turtles with [tipo =  "fuente" and estado = "despierto"]
    [
      set ultima-velocidad-arribos 0
    ]
  ]
end

to agendar [evento]
  set agenda lput evento agenda
end

to go-nodo [evento-actual]
  ;el nodo en turno ejecuta su actividad
  let nodo-en-turno item 2 evento-actual
  let actividad item 1 evento-actual
  ask nodo-en-turno
  [
    let paquete item 3 evento-actual
    if actividad = "arribo"
    [
      arribo paquete
    ]
    if actividad = "envio"
    [
      envio paquete
    ]
  ]
  ask turtles
  [
    ifelse length buffer > 0
    [
      set label length buffer
      set label-color gray
    ]
    [
      set label ""
    ]
  ]
end

to arribo [paquete]
  if tipo != "fuente"
  [
    pintar-trayectoria item 3 paquete
  ]
  if tipo = "sink"
  [
      set total-paquetes-recibidos total-paquetes-recibidos + 1
      set paquetes-recibidos-por-tick paquetes-recibidos-por-tick + 1
      let retardo ticks - item 1 paquete
      ifelse ticks - item 1 paquete > tolerated-delay
      [
        set perdidas-por-goodput-por-tick perdidas-por-goodput-por-tick + 1
      ]
      [
        set goodput goodput + 1
      ]
      calcula-satisfaccion-del-sistema retardo
  ]
  if libre and tipo != "sink"
  [
    set libre false
    agendar-envio paquete tiempo-envio
  ]
  if not libre and tipo != "sink"
  [
    mete-paquete-al-buffer paquete
  ]
end

to pintar-trayectoria [nodo-origen]
  ask link-with nodo-origen 
  [
    set shape "continua"
    
  ]
end

to actualizar-graficas
  update-plots
  ;resetea los contadores de paquetes POR TICK
  set paquetes-enviados-por-tick 0
  set paquetes-recibidos-por-tick 0               
  set perdidas-por-congestion-por-tick 0
  set perdidas-por-encaminamiento-por-tick 0
  set perdidas-por-inalambricas-por-tick 0
  set goodput 0
  set perdidas-por-goodput-por-tick 0
  ;agenda la proxima actualizacion
  if length agenda != 0
  [
    agendar-actualizacion-graficas
  ]
end

to envio [paquete]
  ;si hay paquetes en buffer - saca paquetes del buffer
  if length buffer > 0
  [
    set paquete saca-paquete-del-buffer
  ]
  ;procesa paquete
  set paquete procesa-paquete paquete
  ;aumenta si no ha dado ningun salto aumenta el contador de paquetes enviados
  if item 2 paquete = 1
  [
    set total-paquetes-enviados total-paquetes-enviados + 1
  ]
  ;incrementa el contador de paquetes enviados por tick
  set paquetes-enviados-por-tick paquetes-enviados-por-tick + 1
  consume-energia
  ;agenda arribo en nodo destino
  let nodo-destino protocolo-encaminamiento
  if is-turtle? nodo-destino ;and not wireless
  [
    agendar-arribo paquete nodo-destino ticks
  ]
  ;si hay paquetes en buffer agenda envio de paquete
  if length buffer > 0
  [
    agendar-envio 0 ticks
  ]
  ;si el buffer esta vacio cambia estado del nodo a libre
  if length buffer <= 0 and control-de-congestion
  [
    set libre true
  ]
end

to agendar-envio [paquete tiempo]
  let evento-envio ["tiempo-envio" "envio" "nodo-en-turno" "paquete"]
  set evento-envio replace-item 0 evento-envio tiempo
  set evento-envio replace-item 2 evento-envio self
  set evento-envio replace-item 3 evento-envio paquete
  agendar evento-envio
end

to agendar-arribo [paquete destino tiempo]
  let evento-arribo ["tiempo-arribo" "arribo" "nodo-en-turno" "paquete"]
  set evento-arribo replace-item 0 evento-arribo tiempo
  set evento-arribo replace-item 2 evento-arribo destino
  set evento-arribo replace-item 3 evento-arribo paquete
  agendar evento-arribo
end

to agendar-actualizacion-graficas
  let evento-actualizacion [0 "update-plots"]
  set evento-actualizacion replace-item 0 evento-actualizacion (ticks + 1)
  agendar evento-actualizacion
end

to-report tiempo-entre-paquetes
  let tiempo-de-envio 0
  if Packet-generator = "pdf-poisson"
  [
    set tiempo-de-envio ultimo-arribo-agendado + random-exponential (1 / arraival-rate)
  ]
  if Packet-generator = "pdf-normal"
  [
    set tiempo-de-envio ultimo-arribo-agendado + random-normal (1 / arraival-rate) 1
  ]
  if Packet-generator = "continua"
  [
    set tiempo-de-envio ultimo-arribo-agendado + ( 1 / arraival-rate )
  ]
  if Packet-generator = "en-aumento"
  [
    set tiempo-de-envio ultimo-arribo-agendado + ( 1 / arraival-rate )
    set ultima-velocidad-arribos ultima-velocidad-arribos + .01
  ]
  report tiempo-de-envio
end

to-report tiempo-envio
  report ticks + random-exponential (packet-length / transmission-rate)
end

to-report siguiente-evento
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

to-report generar-paquete-de-datos
  ;paquete [tipo tiempo_de_salida saltos], tipo = -2 Mensaje de datos
  let paquete [-2 0 0 0]
  set paquete replace-item 1 paquete ticks
  report paquete
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

;establece un "protocolo de encaminamiento", crea un arbol por medio del algoritmo de propagacion de la informacion
to set-parametros-encaminamiento 
  set nivel mensaje + 1
  if tipo != "sink"
  [
    set color black
  ]
  set nodos-muertos nodos-muertos - 1
end

to-report procesa-paquete [paquete]
  set paquete replace-item 2 paquete (item 2 paquete + 1)
  set paquete replace-item 3 paquete self
  report paquete
end

;indica el nodo a que se enviara el mensaje
to-report protocolo-encaminamiento
  let mi_nivel nivel
  let nodo-destino one-of link-neighbors with [nivel < mi_nivel and estado != "muerto"]
  if not is-turtle? nodo-destino 
  [
    set total-perdidas-por-encaminamiento total-perdidas-por-encaminamiento + length buffer + 1
    set perdidas-por-encaminamiento-por-tick perdidas-por-encaminamiento-por-tick + length buffer + 1
    set buffer []
    elimina-eventos-de-agenda
    set size 0.5
    ;EL NODO YA NO TIENE A QUIEN REENVIAR
    ;RESTAURAR LA TALLA DEL NODO 
    ;REINICIAR SU BUFFER A 0 YA QUE SUS PAQUETES SE HAN SUMADO A LA PERDIDAS
  ]  
  report nodo-destino
end

;SIMULA efectos inalambricos
to-report wireless
  ifelse random 10 >= 8
  [
    set total-perdidas-por-inalambricas total-perdidas-por-inalambricas + 1
    set perdidas-por-inalambricas-por-tick perdidas-por-inalambricas-por-tick + 1
    report true
  ]
  [  
    report false
  ]
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
    set color 3
  ]
  if energia > 0 and energia <= 35
  [
    set color 5
  ]
  if energia < 0
  [
    set color 2
    set size 1
    set shape "x"
    set estado "muerto"
    set nodos-muertos nodos-muertos + 1
    set total-perdidas-por-encaminamiento total-perdidas-por-encaminamiento + length buffer ;contador-de-paquetes-recibidos
    set perdidas-por-encaminamiento-por-tick perdidas-por-encaminamiento-por-tick + length buffer ;contador-de-paquetes-recibidos
    set buffer []
    elimina-eventos-de-agenda
  ]
end

to elimina-eventos-de-agenda
  foreach agenda 
  [
    if item 1 ? != "update-plots" and item 2 ? = self 
    [
      set agenda remove ? agenda
    ]
  ]   
end

to finaliza-simulacion
   print "termina simulacion"
  ;set satisfaccion-del-sistema (satisfaccion-promedio-de-paquete * (total-paquetes-recibidos)) / total-paquetes-enviados
end

to calcula-satisfaccion-del-sistema [retardo]
;  let satisfaccion-del-paquete 0
;  if retardo <= retardo-permitido
;  [
;    set satisfaccion-del-paquete 1 - (retardo / retardo-permitido)
;  ] 
;  set satisfaccion-del-paquete ((satisfaccion-promedio-de-paquete * (total-paquetes-recibidos - 1)) + satisfaccion-del-paquete) / total-paquetes-recibidos
end

;to genera-interferencia [nodo-destino]
;  ask patches in-radius cobertura
;  [
;    set pcolor 4
;  ]
;  let tortugas-afectadas turtles in-radius cobertura
;  set tortugas-afectadas tortugas-afectadas with [who != [who] of nodo-destino]
;  let mi_id who
;  set tortugas-afectadas tortugas-afectadas with [who != mi_id]
;  ask-concurrent tortugas-afectadas
;  [
;    calcula-potencia-recibida
;  ]
;end

;to calcula-potencia-recibida
;end

;to-report perdidas-inalambricas? [enlace]
;  let perdida false
;  ask enlace
;  [
;    if (ber * 10000000) > random 10000000
;    [
;      set total-perdidas-por-inalambricas total-perdidas-por-inalambricas + 1
;      set perdidas-por-inalambricas-por-tick perdidas-por-inalambricas-por-tick + 1
;      set perdida true
;    ]
;  ]
;  report perdida 
;end

;to-report factorial [n]
;  let n! 1
;  if n = 2
;  [ set n! 2]
;  if n = 3
;  [ set n! 6]
;  if n = 4
;  [ set n! 24]
;  if n = 5
;  [ set n! 120]
;  if n = 6
;  [ set n! 720]
;  if n = 7
;  [ set n! 5040]
;  if n = 8
;  [ set n! 40320]
;  if n = 9
;  [ set n! 362880]
;  if n = 10
;  [ set n! 3628800]
;  if n = 11
;  [ set n! 39916800]
;  if n = 12
;  [ set n! 479001600]
;  report n!  
;end
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
0
0
1
Time [s]
30.0

SLIDER
3
549
142
582
number-of-nodes
number-of-nodes
0
1000
200
1
1
NIL
HORIZONTAL

SLIDER
232
598
433
631
Number-of-sources
Number-of-sources
1
20
10
1
1
NIL
HORIZONTAL

SLIDER
3
645
205
678
average-degree-of-connectivity
average-degree-of-connectivity
1
6
4
1
1
NIL
HORIZONTAL

BUTTON
891
38
964
71
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
1038
38
1101
71
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
5
690
204
723
average-coverage
average-coverage
1
30
11.7
0.1
1
m.
HORIZONTAL

SWITCH
234
554
383
587
active-sources
active-sources
0
1
-1000

PLOT
973
247
1415
513
Received packets
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
"a tiempo" 1.0 0 -16777216 true "" "plotxy ticks goodput"
"fuera de tiempo" 1.0 0 -9276814 true "" "plotxy ticks perdidas-por-goodput-por-tick"
"sent" 1.0 0 -4539718 true "" "plotxy ticks paquetes-enviados-por-tick"

CHOOSER
233
643
387
688
Packet-generator
Packet-generator
"rafaga" "continua" "pdf-poisson" "pdf-normal" "en-aumento"
2

SLIDER
909
703
1185
736
energia-por-transmision
energia-por-transmision
0
5
5
.01
1
%
HORIZONTAL

MONITOR
610
11
683
56
died nodes
nodos-muertos
17
1
11

PLOT
520
248
963
514
Lost packets
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
"due to congestion" 1.0 0 -16777216 true "" "plot perdidas-por-congestion-por-tick"
"due to wireless effects" 1.0 0 -11053225 true "" "plot perdidas-por-inalambricas-por-tick"
"due to routing" 1.0 0 -5987164 true "" "plot perdidas-por-encaminamiento-por-tick"

CHOOSER
3
590
143
635
buffer-length
buffer-length
1 2 4 8 16 32 "infinito"
3

BUTTON
970
38
1034
71
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
1096
567
1261
600
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
910
617
1190
650
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
910
658
1186
691
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
910
570
1087
603
efectos-inalambricos
efectos-inalambricos
1
1
-1000

MONITOR
741
201
842
246
due to congestion
total-perdidas-por-congestion
17
1
11

MONITOR
517
202
640
247
due to wireless effects
total-perdidas-por-inalambricas
17
1
11

MONITOR
649
201
732
246
due to routing
total-perdidas-por-encaminamiento
17
1
11

SLIDER
234
699
435
732
arraival-rate
arraival-rate
1
32
8
1
1
packets / s
HORIZONTAL

SLIDER
471
600
636
633
packet-length
packet-length
256
1024
768
256
1
bits
HORIZONTAL

SLIDER
471
686
638
719
tolerated-error-bit
tolerated-error-bit
0
64
24
2
1
bits
HORIZONTAL

MONITOR
973
200
1039
245
sent
total-paquetes-enviados
17
1
11

MONITOR
1050
200
1112
245
received
total-paquetes-recibidos
17
1
11

TEXTBOX
520
181
670
199
Monitors of lost packets\n
12
0.0
1

TEXTBOX
975
181
1108
199
Monitors of packets:
12
0.0
1

SLIDER
470
555
637
588
tolerated-delay
tolerated-delay
5
180
15
5
1
s
HORIZONTAL

TEXTBOX
71
528
151
546
Node Settings
12
0.0
1

TEXTBOX
299
532
525
562
Source Settings
12
0.0
1

TEXTBOX
1019
546
1169
564
Efectos Inalámbricos
12
0.0
1

TEXTBOX
487
534
629
552
Application requirements
12
0.0
1

SLIDER
472
643
636
676
transmission-rate
transmission-rate
512
2096
1024
512
1
bps
HORIZONTAL

MONITOR
523
10
598
55
clock (s)
ticks
5
1
11

MONITOR
517
123
723
168
satisfaccion promedio de paquete
satisfaccion-promedio-de-paquete
17
1
11

MONITOR
724
123
890
168
satisfaccion del sistema
satisfaccion-del-sistema
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
-0.2 0 0.0 1.0
0.0 1 2.0 2.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

continua
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
