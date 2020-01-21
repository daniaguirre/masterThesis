;-------------------------------------------------------------------------------
; Copyright 2010, Nick Bennett, Grass Roots Consulting 
; (http://www.g-r-c.com ). All rights reserved.
;
; Permission to use, modify or redistribute this model is hereby granted, 
; provided that both of the following requirements are followed: a) this 
; copyright notice is included. b) this model will not be redistributed for 
; profit without permission from Nick Bennett. Contact Nick Bennett 
; (nickbenn@g-r-c.com) for appropriate licenses for redistribution for profit.
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; Version History
; 2010-02-21 - v1.0: M/M/n queueing simulation; up to 10 servers; standard 
;                    aggregate statistics & corresponding expected values.
;-------------------------------------------------------------------------------


; The model has two types of agents: customers, who enter and wait in a queue 
; until a server is available; and servers, who serve each customer in 
; first-come, first-served order.

breed [customers customer]
breed [servers server]


; Each customer records the time entering the system, and the time entering
; service, so that average time-in-queue/time-in-system statistics can be 
; computed.

customers-own [
  time-entered-queue
  time-entered-service
]


; Each server records the customer agent being served, and the scheduled 
; completion of that service. Since servers are homogenous, individual 
; utilization statistics aren't kept.

servers-own [
  customer-being-served
  next-completion-time
]


globals [
  ; Waiting line
  queue
  ; Arrival process
  arrival-count
  next-arrival-time  
  ; Statistics for average load/usage of queue and servers
  stats-start-time
  total-customer-queue-time 
  total-customer-service-time
  ; Statistics for average time-in-queue and time-in-service
  total-time-in-queue
  total-time-in-system
  total-queue-throughput
  total-system-throughput
  ; Physical layout parameters
  server-ycor
  queue-server-offset
  customer-xinterval
  customer-yinterval
  customers-per-row
  ; Saved slider values to allow detection of changes during a simulation run
  save-mean-arrival-rate
  save-mean-service-time
  ; Theoretical measures, computed analytically using classic queueing theory
  expected-utilization
  expected-queue-length
  expected-queue-time
]


to startup
  setup
end

; Initializes global variables and server agents.

to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  setup-globals
  setup-servers
  compute-theoretical-measures
end


; Resets statistics, initializes queue list, and sets agent shapes and other 
; display properties.

to setup-globals
  reset-stats
  set queue []
  set next-arrival-time 0
  set arrival-count 0
  set-default-shape servers "server"
  set-default-shape customers "person"
  set server-ycor (min-pycor + 1)
  set queue-server-offset 1.5
  set customer-xinterval 0.5
  set customer-yinterval 1
  set customers-per-row (1 + (world-width - 1) / customer-xinterval)
  set save-mean-arrival-rate mean-arrival-rate
  set save-mean-service-time mean-service-time
end


; Creates server agents and arranges them horizontally, evenly spaced along the 
; bottom of the NetLogo world. This layout is purely cosmetic, and has no 
; functional purpose or impact.

to setup-servers
  let horizontal-interval (world-width / number-of-servers)
  create-servers number-of-servers [
    set color green
    setxy (min-pxcor - 0.5 + horizontal-interval * (0.5 + who)) server-ycor 
    set size 2.75
    set label ""
    set customer-being-served nobody
    set next-completion-time 0
  ]
end


; Updates statistics (which also advances the clock) and dispatches the end-run, 
; reset-stats, complete-service, or arrive procedure, based on the next event 
; scheduled.

to go
  ifelse (ticks < max-run-time) [
    let next-event []
    let event-queue (list (list max-run-time "end-run"))                        ;event-queue = [[<tiempo en que se acaba la simulacion> "end-run"]]
    let next-server-to-complete next-server-complete                            ;siguiente servidor que complera el servicio
    if (next-arrival-time <= 0) [                       
      schedule-arrival                                                          ;establece el tiempo del siguiente arrivo <next-arrival-time> de acuerdo a una distribucion exponencial
    ]
    if (next-arrival-time > ticks) [                                            ;si aun no esta en el siguiente tiempo de arrivo
      set event-queue (fput (list next-arrival-time "arrive") event-queue)      ;agrega a event-queue [<tiempo del siguiente arrivo> "arrive"]
    ]
    if (is-turtle? next-server-to-complete) [                                   ;si hay un servidor proximo a completar su servicio
      set event-queue (fput                                                     ;agrega a event-queue [<tiempo-en que se completa el proximo servicio> "complete-service" <quien completa el proximo servicio>]
        (list 
          ([next-completion-time] of next-server-to-complete) 
          "complete-service" 
          ([who] of next-server-to-complete)) 
        event-queue)
    ]
    if (stats-reset-time > ticks) [                                             ;si aun no es momento de reiniciar las estadisticas
      set event-queue (fput (list stats-reset-time "reset-stats") event-queue)  ;agrega a event-queue [<tiempo-de reiniciar-las-estadisticas> "reset-stats"]
    ]
    set event-queue (sort-by [first ?1 < first ?2] event-queue)                 ;ordena la cola de eventos
    set next-event first event-queue                                            ;obtiene el <next-event> siguiente evento
    update-usage-stats first next-event                                         ;actualiza las estadisticas
    run (reduce [(word ?1 " " ?2)] (but-first next-event))                      ;ejecuta el procedimiento que corresponde al siguiente evento ("end-run" "arrive" "complete-service" "reset-stats")
  ]
  [
    stop
  ]
end


; Ends the execution of the simulation. In fact, this procedure does nothing, 
; but is still necessary. When the associated event is the first in the event
; queue, the clock will be updated to the simulation end time prior to this 
; procedure being invoked; this causes the go procedure to stop on the next 
; iteration.

to end-run
  ; Do nothing
end


; Creates a new customer agent, adds it to the queue, and attempts to start 
; service.

to arrive
  let color-index (arrival-count mod 70)
  let main-color (floor (color-index / 5))
  let shade-offset (color-index mod 5)
  create-customers 1 [
    set color (3 + shade-offset + main-color * 10)
    set time-entered-queue ticks
    move-forward length queue
    set queue (lput self queue)
    set time-entered-queue ticks
  ]
  set arrival-count (arrival-count + 1)
  schedule-arrival
  begin-service
end


; Samples from the exponential distribution to schedule the time of the next
; customer arrival in the system.

to schedule-arrival
  set next-arrival-time (ticks + random-exponential (1 / mean-arrival-rate))
end


; If there are customers in the queue, and at least one server is idle, starts 
; service on the first customer in the queue, using a randomly selected 
; idle server, and generating a complete-service event with a time sampled from
; the exponential distribution. Updates the queue display, moving each customer 
; forward.

to begin-service
  let available-servers (servers with [not is-agent? customer-being-served])
  if (not empty? queue and any? available-servers) [
    let next-customer (first queue)
    let next-server one-of available-servers
    set queue (but-first queue)
    ask next-customer [
      set time-entered-service ticks
      set total-time-in-queue 
        (total-time-in-queue + time-entered-service - time-entered-queue)
      set total-queue-throughput (total-queue-throughput + 1)
      move-to next-server
    ]
    ask next-server [
      set customer-being-served next-customer
      set next-completion-time (ticks + random-exponential mean-service-time)
      set label precision next-completion-time 3
      set color red
    ]
    (foreach queue (n-values length queue [?]) [
      ask ?1 [
        move-forward ?2
      ]
    ])
  ]
end


; Updates time-in-system statistics, removes current customer agent, returns the
; server to the idle state, and attempts to start service on another customer.

to complete-service [server-id]
  ask (server server-id) [
    set total-time-in-system (total-time-in-system + ticks 
      - [time-entered-queue] of customer-being-served)
    set total-system-throughput (total-system-throughput + 1)
    ask customer-being-served [
      die
    ]
    set customer-being-served nobody
    set next-completion-time 0
    set color green
    set label ""
  ]
  begin-service
end


; Reports the busy server with the earliest scheduled completion.

to-report next-server-complete
  report (min-one-of 
    (servers with [is-agent? customer-being-served]) [next-completion-time])
end


; Sets all aggregate statistics back to 0 - except for the simulation start
; time (used for computing average queue length and average server utilization),
; which is set to the current time (which is generally not 0, for a reset-stats
; event).

to reset-stats
  set total-customer-queue-time 0
  set total-customer-service-time 0
  set total-time-in-queue 0
  set total-time-in-system 0
  set total-queue-throughput 0
  set total-system-throughput 0
  set stats-start-time ticks
end


; Updates the usage/utilization statistics and advances the clock to the 
; specified event time.

to update-usage-stats [event-time]
  let delta-time (event-time - ticks)
  let busy-servers (servers with [is-agent? customer-being-served])
  let in-queue (length queue)
  let in-process (count busy-servers)
  let in-system (in-queue + in-process)
  set total-customer-queue-time 
    (total-customer-queue-time + delta-time * in-queue)
  set total-customer-service-time 
    (total-customer-service-time + delta-time * in-process)
  tick-advance (event-time - ticks)
end


; Move to the specified queue position, based on the global spacing parameters.
; This queue display is purely cosmetic, and has no functional purpose or 
; impact.

to move-forward [queue-position]
  let new-xcor 
    (max-pxcor - customer-xinterval * (queue-position mod customers-per-row))
  let new-ycor (server-ycor + queue-server-offset 
    + customer-yinterval * floor (queue-position / customers-per-row))
  ifelse (new-ycor > max-pycor) [
    hide-turtle
  ]
  [
    setxy new-xcor new-ycor
    if (hidden?) [
      show-turtle
    ]
  ]
end


; Checks to see if the values of the mean-arrival-rate and mean-service-time
; sliders have changed since the last time that the theoretical system measures
; were calculated; if so, the theoretical measures are recalculated.

to-report sliders-changed?
  let changed? false
  if ((save-mean-arrival-rate != mean-arrival-rate) 
      or (save-mean-service-time != mean-service-time)) [
    set changed? true
    set save-mean-arrival-rate mean-arrival-rate
    set save-mean-service-time mean-service-time
    compute-theoretical-measures
  ]
  report changed?
end


; Compute the expected utilization, queue length, and time in queue for an M/M/n
; queueing system.

to compute-theoretical-measures
  let balance-factor (mean-arrival-rate * mean-service-time)
  let n (count servers)
  ifelse ((balance-factor / n) < 1) [
    let k 0
    let k-sum 1
    let power-product 1
    let factorial-product 1
    let busy-probability 0
    foreach (n-values (n - 1) [? + 1]) [
      set power-product (power-product * balance-factor)
      set factorial-product (factorial-product * ?)
      set k-sum (k-sum + power-product / factorial-product)
    ]
    set power-product (power-product * balance-factor)
    set factorial-product (factorial-product * n)
    set k (k-sum / (k-sum + power-product / factorial-product))
    set busy-probability ((1 - k) / (1 - balance-factor * k / n))
    set expected-utilization (balance-factor / n)
    set expected-queue-length 
      (busy-probability * expected-utilization / (1 - expected-utilization))
    set expected-queue-time 
      (busy-probability * mean-service-time / (n * (1 - expected-utilization)))
  ]
  [
    set expected-utilization 1
    set expected-queue-length "N/A"
    set expected-queue-time "N/A"
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
195
60
733
203
16
3
16.0
1
9
1
1
1
0
1
1
1
-16
16
-3
3
1
1
0
ticks
30.0

SLIDER
10
10
185
43
number-of-servers
number-of-servers
1
10
5
1
1
NIL
HORIZONTAL

SLIDER
10
100
185
133
mean-arrival-rate
mean-arrival-rate
0
5
1.75
0.05
1
per tick
HORIZONTAL

SLIDER
10
140
185
173
mean-service-time
mean-service-time
0.05
10
2.75
0.05
1
ticks
HORIZONTAL

SLIDER
10
230
185
263
stats-reset-time
stats-reset-time
0
max-run-time / 2
5000
100
1
ticks
HORIZONTAL

SLIDER
10
190
185
223
max-run-time
max-run-time
1000
100000
100000
1000
1
ticks
HORIZONTAL

BUTTON
60
50
135
83
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
110
270
185
303
Go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

MONITOR
195
10
305
55
Current Time
ticks
3
1
11

MONITOR
425
10
535
55
Queue Length
length queue
0
1
11

MONITOR
540
210
650
255
Server Utilization %
100 * total-customer-service-time / (ticks - stats-start-time) / count servers
3
1
11

MONITOR
195
210
305
255
Avg. Queue Length
total-customer-queue-time / (ticks - stats-start-time)
3
1
11

MONITOR
425
210
535
255
Avg. Time in System
total-time-in-system / total-system-throughput
3
1
11

BUTTON
10
270
85
303
Next
go
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
1

MONITOR
310
210
420
255
Avg. Time in Queue
total-time-in-queue / total-queue-throughput
3
1
11

MONITOR
310
10
420
55
Next Arrival Time
next-arrival-time
3
1
11

MONITOR
540
260
650
305
Exp. Utilization %
100 * expected-utilization
3
1
11

MONITOR
195
260
305
305
Exp. Queue Length
ifelse-value sliders-changed? [\n  expected-queue-length\n]\n[\n  expected-queue-length\n]\n
3
1
11

MONITOR
310
260
420
305
Exp. Time in Queue
expected-queue-time
3
1
11

MONITOR
425
260
535
305
Exp. Time in System
expected-queue-time + mean-service-time
3
1
11

BUTTON
655
210
730
243
Reset Stats
reset-stats
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This is a simple queueing system model, with a single, unlimited queue and 1-10 homogeneous servers. Arrivals follow a Poisson process, and service times are exponentially distributed.

## HOW IT WORKS

This is a discrete-event simulation, which is a type of simulation that advances the clock in discrete, often irregularly sized steps, rather than by very small, regular time slices (which are generally used to produce quasi-continuous simulation). At each step, the clock is advanced to the next scheduled event in an event queue, and that event is processed. In this model, the different events are: customer arrival and entry into the queue (followed, if possible, by start of service); service completion, with the customer leaving the system (followed, if possible, by start of service for a new customer); statistics reset; and simulation end. Since these are the only events that can result in a change of the state of the simulation, there is no point in advancing the clock in smaller time steps than the intervals between the events.

## HOW TO USE IT

Use the number-of-servers slider to set the number of servers; then press the Setup button to create the servers and reset the simulation clock. 

The mean-arrival-rate and mean-service-time sliders control the arrival and service processes, respectively. These values can be changed before starting the simulation, or  at anytime during the simulation run; any changes are reflected immediately in a running model.

The max-run-time and stats-reset-time control the length of the simulation and the time at which all the aggregate statistics are reset, respectively. The latter allows for minimizing the effects of system startup on the aggregate statistics.

The simulation can be run one step at a time with the Next button, or by repeatedly processing events with the Go button.

The aggregate statistics can be reset at any time - without emptying the queue or placing servers in the idle state - with the Reset Stats button.

## THINGS TO NOTICE

After the simulation has started, the next scheduled arrival time is always shown in the Next Arrival Time monitor. When any of the servers are busy, the scheduled time of service completion is shown in the label below the server.

In queueing theory notation, the type of system being simulated in this model is referred to as M/M/n - i.e. Poisson arrivals, exponential service times, infinite queue capacity and source population, FIFO queue discipline. When there is a single server, or when all the servers have the same mean service time, the steady state characteristics (if the system is capable of reaching a steady state) can be determined analytically. In this model, these theoretical values are shown in the bottom row of monitors. If the theoretical server utilization - determined by multiplying the arrival rate by the service time, dividing by the number of servers, and taking the lesser the result of the calculation and 1 - is less than 1, then the queueing equations have a defined solution; otherwise, the expected queue length and expected time in the queue are unbounded. In this model, these unbounded values are denoted by "N/A" in the associated monitors.

This model displays servers in a row along the bottom of the NetLogo world; customers are shown in a queue which "snakes" from near the bottom of the NetLogo world to the top. However, these display features are purely for visualization purposes; the positions of the servers and customers, and the colors of the customers, have no functional purpose or impact. The colors of the servers, on the other hand, does have a meaning: an idle server is shown in green, while a busy server is red.

## THINGS TO TRY

Run the simulation several times, to get a sense of the effects of the different parameters on the average queue length and average time in the queue. How do these observed statistics compare with the theoretical values? Do the input parameters seem to affect not only the average queue length, but also the variability of the queue length?

## EXTENDING THE MODEL

This model could easily be extended to support non-identical mean service times for different servers (possibly through an Add Server button that creates servers one at a time, each with a specified mean service time value); additional service time distributions besides exponential; a capacitated queue; and alternative queue disciplines (random priority and LIFO would be the easiest to add). However, when simulating a system with these complicating factors, the computations for expected queue length and expected time in the queue can become difficult, or even practically impossible. Note, however, that there is a general relationship - known as Little's formula - between expected queue length and expected time in the queue (or, more generally, between expected number of customers/transactions in the entire system, and the expected time a customer/transaction spends in the system), which holds for even very complicated queueing systems.

## NETLOGO FEATURES

This model uses the tick-advance primitive to advance the NetLogo ticks value by non-integral amounts. This allows the NetLogo clock to be used as a discrete-event simulation clock. However, the standard ticks display (normally seen in the bar above the NetLogo world) is unable to display non-integral values, so this model uses a separate ticks monitor.

## CREDITS AND REFERENCES

Copyright 2010, Nick Bennett, Grass Roots Consulting (http://www.g-r-c.com ). All rights reserved.

Permission to use, modify or redistribute this model is hereby granted, provided that both of the following requirements are followed: a) this copyright notice is included. b) this model will not be redistributed for profit without permission from Nick Bennett. Contact Nick Bennett (nickbenn@g-r-c.com) for appropriate licenses for redistribution for profit.
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

server
false
0
Rectangle -7500403 true true 75 75 225 90
Rectangle -7500403 true true 75 90 90 210
Rectangle -7500403 true true 210 90 225 210
Rectangle -7500403 true true 75 210 225 225

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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
1
@#$#@#$#@
