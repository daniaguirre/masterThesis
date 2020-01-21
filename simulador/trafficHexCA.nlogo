breed [cells]

globals
[
 
  grid-x-inc  ;; the amount of patches in between two streets in the x direction
  grid-y-inc  ;; the amount of patches in between two streets in the y direction
  grid-z-inc  ;; the amount of patches in between two streets in the z direction
  
  phase
  
  ;; patch agentsets
  streets
  traffic-lights
  upstreams
  intersections ;; all intersections
  Dintersections ;; intersections of 2 streets
  Tintersections ;; intersections of 3 streets
  xstreets ;;
  ystreets ;;
  zstreets ;; 
  upxstreets ;;
  upystreets ;;
  upzstreets ;; 
  dwxstreets ;;
  dwystreets ;;
  dwzstreets ;; 
  
  ;; string and list variables that hold data passed accumulated in the model run
  #cars
  #cars-old
  flow
  flow-data 
]



cells-own [
  hex-neighbors
  on? 
  was-on?
  rule
  green-x?;tells whether green light is for xstreets...
  green-y?;tells whether green light is for ystreets...
  green-z?;tells whether green light is for zstreets...
  all-stop? ;; tells whether all directions should have a red light (with SOLA only).
  was-all-stop? ;; tells whether intersection should turn back to one green
  switch-asap ; tells whether TL should switch...
  intersection?
  traffic-light?
  upstream?
  street?
  x?
  y?
  z?
  upx?
  dwx? 
  upy?
  dwy? 
  upz?
  dwz?
  #dirs ;; number of directions on patch (1 = street, 2 = intersection of 2 dirs, 3 = intersection of 3 dirs)
  lc ; left neighbor cell
  rc ; right neighbor cell
  var
  
  ;;SOLA intersection variables
  kappa-x ;; number of cars * number of time steps waiting
  kappa-y ;; number of cars * number of time steps waiting
  kappa-z ;; number of cars * number of time steps waiting
  greensteps ;; steps since last change of lights
  
  r1
  r2
  r3
  r4
  r5
  ooo
  ooi
  oio
  oii
  ioo
  ioi
  iio
  iii

]


;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;


to setup
  ca
  print ""
  doScenarios
  ifelse (not six-dirs?) or ((grid-size-x mod 2 = 0) and (grid-size-y mod 2 = 0))[  
    setup-streets
    init-lists
    ask streets  ;; randomly place cars on streets
    [
      set on? (random-float 100) < (density * 100)
      color-cells 
    ]
    ;;make real density close to probabilistic one...
    let density_OK? false
    while [not density_OK?][
      ifelse (100 * (count streets with [on?] - 0.5) > (density * (count streets))) [
        ask one-of streets with [on?][
          set on? false
        ]
      ][
        ifelse (100 * (count streets with [on?] + 0.5) < (density * (count streets)))[
          ask one-of streets with [not on?][
            set on? true
          ]
        ][
          set density_OK? true
        ]
      ]  
    ]
    
    
    ask intersections[
      init-lights
    ]
    ask streets 
    [
      color-cells 
    ]
    
    set #cars count streets with [on?]
    
    if any? intersections with [xcor = max-pxcor or xcor = min-pxcor] [
      print "WARNING: At least one intersection lies at the edge of the simulation. Vehicles might not be conserved!"
      beep
    ]
    if intersections-too-close[
      print "WARNING: One or more intersections are too close to each other. Vehicles might not be conserved!"
      beep
    ]
  ][
    print "UNABLE TO INITIALIZE: If six-dirs?, grid-size-x and grid-size-y must be even..."
  ]

end

to doScenarios
  if scenario != "custom"[
    ifelse scenario = "1 triple"[
      set grid-size-x 1 
      set grid-size-y 1 
      set grid-size-z 1 
      set six-dirs? false
      set x-offset-of-z 134
    ][
    ifelse scenario = "3 double"[
      set grid-size-x 1 
      set grid-size-y 1 
      set grid-size-z 1 
      set six-dirs? false
      set x-offset-of-z 123     
    ][
      set grid-size-x 6 
      set grid-size-y 6 
      set grid-size-z 6 
      set six-dirs? true
    ifelse scenario = "36 triple"[
      set x-offset-of-z 67
    ][
    ifelse scenario = "108 double"[
      set x-offset-of-z 56      
    ][
     if scenario = "12 triple, 48 double"[
       set grid-size-y 4 
       set x-offset-of-z 63 
     ]
    ]  
    ]  
    ]  
    ]

  ]
end

to-report intersections-too-close
  let close? false
  ask traffic-lights[
    ask lc[
      if traffic-light? or upstream? or intersection?[
        set close? true
      ]
    ]  
  ]
  ask upstreams[
    ask rc[
      if traffic-light? or upstream? or intersection?[
        set close? true
      ]
    ]  
  ]
  report close?
end

to setup-cell
  if pxcor mod 2 = 0 [
    set ycor ycor - 0.5
  ]
  set size 1.33
  set color background
  set street? true
  set traffic-light? false
  set green-x? false
  set green-y? false
  set green-z? false
  set all-stop? false
  set was-all-stop? false
  set intersection? false
  set rule 184
  set x? false
  set y? false
  set z? false
  set upstream? false
  set upx?  false
  set dwx?   false
  set upy? false
  set dwy? false
  set upz? false
  set dwz? false
  set #dirs 0
  set on? false
  set was-on? false
  set lc 0;
  set rc 0;
;  ask cells [
;    ifelse pxcor mod 2 = 0 [
;      set hex-neighbors cells-on patches at-points [[0  1] [ 1  0] [ 1 -1]
;                                                    [0 -1] [-1 -1] [-1  0]]
;    ][
;      set hex-neighbors cells-on patches at-points [[0  1] [ 1  1] [ 1  0]
;                                                    [0 -1] [-1  0] [-1  1]]
;    ]
;  ]
end


to setup-x-streets
  set x? true
  set #dirs (#dirs + 1)
  if xcor < max-pxcor[
    ask patch-at 1 -0.5 [
      ifelse any? cells-here[
        ask cells-here[
          setup-x-streets 
        ]
      ][
        sprout-cells 1 [ 
          setup-cell
          setup-x-streets
        ]
      ]
    ]
  ] 
end

to setup-y-streets
  set y? true
  set #dirs (#dirs + 1)
  if xcor > min-pxcor[
    ask patch-at -1 -0.5 [
      ifelse any? cells-here[
        ask cells-here[
          setup-y-streets 
        ]
      ][
        sprout-cells 1 [ 
          setup-cell
          setup-y-streets
        ]
      ]
    ]
  ] 
end

to setup-z-streets
  set z? true
  set #dirs (#dirs + 1)
  if ycor > min-pycor[
    ask patch-at 0 -1 [
      ifelse any? cells-here[
        ask cells-here[
          setup-z-streets 
        ]
      ][
        sprout-cells 1 [ 
          setup-cell
          setup-z-streets
        ]
      ]
    ]
  ] 
end

to chkr ;;; to check neighbourhoods... not used in runtime
  if color != orange [
    set color orange
    ask rc [chkr]
  ]
end
to chkl ;;; to check neighbourhoods... not used in runtime
  if color != violet [
    set color violet
    ask lc [chkl]
  ]
end

to setup-streets
  set-default-shape turtles "hex"

  set grid-z-inc world-height / grid-size-z
  ifelse grid-size-x > 0[;x intersections
    set grid-x-inc world-width / grid-size-x  
  ][;no intersections
    set grid-x-inc world-width * 3
  ]
  ifelse grid-size-y > 0[;y intersections
    set grid-y-inc world-width / grid-size-y 
  ][;no intersections
    set grid-y-inc world-width * 3
  ]
  
  ask patches with [(floor ((pycor + (pxcor / 2) + max-pycor  - floor (grid-x-inc / 2 ))  mod grid-x-inc) = 0) and      (pxcor <= min-pxcor)] [
    ifelse any? cells-here[
      ask cells-here[
        setup-x-streets 
      ]
    ][
      sprout-cells 1 [ 
        setup-cell
        setup-x-streets
      ]
    ]
  ]
  ask patches with [(floor ((pycor - (pxcor / 2) + max-pycor  - floor (grid-y-inc / 4 ))  mod grid-y-inc) = 0) and      (pxcor >= max-pxcor)] [
    ifelse any? cells-here[
      ask cells-here[
        setup-y-streets 
      ]
    ][
      sprout-cells 1 [ 
        setup-cell
        setup-y-streets
      ]
    ]
  ]
  ask patches with [ (floor ((pxcor - min-pxcor - x-offset-of-z ) mod grid-z-inc) = 0) and  (pycor >= (max-pycor - 0.5))] [
    ifelse any? cells-here[
      ask cells-here[
        setup-z-streets 
      ]
    ][
      sprout-cells 1 [ 
        setup-cell
        setup-z-streets
      ]
    ]
  ]
       
  set xstreets cells with [ x? ]
  set ystreets cells with [ y? ]
  set zstreets cells with [ z? ]

  set streets cells with [ x? or y? or z? ]

  ifelse (six-dirs?)[
    set dwxstreets xstreets with [(floor ((pycor + (pxcor / 2) + max-pxcor) / grid-x-inc ) mod 2) = 0]
    set upxstreets xstreets with [(floor ((pycor + (pxcor / 2) + max-pxcor) / grid-x-inc ) mod 2) = 1]
    set dwystreets ystreets with [(floor ((pycor - (pxcor / 2) + max-pycor) / grid-y-inc ) mod 2) = 0]
    set upystreets ystreets with [(floor ((pycor - (pxcor / 2) + max-pycor) / grid-y-inc ) mod 2) = 1]
    set dwzstreets zstreets with [(floor ((pxcor + max-pxcor) / grid-z-inc ) mod 2) = 0]
    set upzstreets zstreets with [(floor ((pxcor + max-pxcor) / grid-z-inc ) mod 2) = 1]
  ][
    set dwxstreets xstreets 
    set dwystreets ystreets 
    set dwzstreets zstreets 
  ]  
    
  if (six-dirs?)[
    ask upxstreets [
      set upx? true
      set-upx
    ]
    ask upystreets [
      set upy? true
      set-upy
    ]
    ask upzstreets [
      set upz? true
      set-upz
    ]
  ]
  ask dwxstreets [
    set dwx? true
    set-dwx
  ]
  ask dwystreets [
    set dwy? true
    set-dwy
  ]
  ask dwzstreets [
    set dwz? true
    set-dwz
  ]


  set intersections streets with [#dirs > 1]
  set Dintersections streets with [#dirs = 2]
  set Tintersections streets with [#dirs = 3]

  ask intersections[
    set hex-neighbors cells in-radius 1.5 with [myself != self]
    set intersection? true
    set switch-asap false
    if dwz?[
      ask cells-on patch-at  0  1 [ set traffic-light? true]
      ask cells-on patch-at 0 -1 [ set upstream? true]
    ]
    if dwx?[
      ask cells-on patch-at -1 0.5 [ set traffic-light? true]
      ask cells-on patch-at  1 -0.5 [ set upstream? true]
    ]
    if dwy?[
      ask cells-on patch-at -1 -0.5 [ set traffic-light? true]
      ask cells-on patch-at  1 0.5 [ set upstream? true]
    ]
    if upz?[
      ask cells-on patch-at 0 -1 [ set traffic-light? true]
      ask cells-on patch-at 0  1 [ set upstream? true]
    ]
    if upx?[
      ask cells-on patch-at  1 -0.5 [ set traffic-light? true]
      ask cells-on patch-at -1 0.5 [ set upstream? true]
    ]
    if upy?[
      ask cells-on patch-at  1 0.5 [ set traffic-light? true]
      ask cells-on patch-at -1 -0.5 [ set upstream? true]
    ]
       
  ]
  set traffic-lights streets with [traffic-light?]
  ask traffic-lights[
    set rule 252
  ]
  set upstreams streets with [upstream?]
  ask upstreams[
    set rule 136
  ]

  ask streets [extrapolate-rule]
end

to set-dwx
    set lc one-of cells-on patch-at -1 0.5
    set rc one-of cells-on patch-at 1 -0.5
    if xcor = min-pxcor[
      set lc one-of cells-on patch-at -1 min-pxcor 
    ]
    if xcor = max-pxcor[
      set rc one-of cells-on patch-at 1 min-pxcor 
    ]
end
to set-dwy
    set lc one-of cells-on patch-at -1 -0.5
    set rc one-of cells-on patch-at 1 0.5
    if xcor = min-pxcor[
      set lc one-of cells-on patch-at -1 max-pxcor 
    ]
    if xcor = max-pxcor[
      set rc one-of cells-on patch-at 1 (- max-pxcor) 
    ]
end
to set-dwz
    set lc one-of cells-on patch-at 0 1
    set rc one-of cells-on patch-at 0 -1
end
to set-upx
    set rc one-of cells-on patch-at -1 0.5
    set lc one-of cells-on patch-at 1 -0.5
    if xcor = min-pxcor[
      set rc one-of cells-on patch-at -1 min-pxcor 
    ]
    if xcor = max-pxcor[
      set lc one-of cells-on patch-at 1 min-pxcor 
    ]
end
to set-upy
    set rc one-of cells-on patch-at -1 -0.5
    set lc one-of cells-on patch-at 1 0.5
    if xcor = min-pxcor[
      set rc one-of cells-on patch-at -1 max-pxcor 
    ]
    if xcor = max-pxcor[
      set lc one-of cells-on patch-at 1 (- max-pxcor) 
    ]
end
to set-upz
    set rc one-of cells-on patch-at 0 1
    set lc one-of cells-on patch-at 0 -1
end


to init-lists
  set flow-data []
 
end

to init-lights
  set phase 0  
  if method = "marching" or method = "random"[
    ifelse z?[
      set green-z? true
    ][
      set green-x? true
    ]
    set switch-asap false
  ]
  if method = "random"[
    set var random p 
  ]
  if method = "green-wave"[
    set switch-asap false
    if #dirs = 2[;Dintersection
      ifelse not x?[
        set var round ((pxcor - pycor) mod (2 * p) )
        ifelse (p <= var)[
          GH 1
        ][
          GH 2
        ]
      ][
        ifelse not y?[
          set var round ((pxcor - pycor) mod (2 * p) )
          ifelse (p <= var)[
            GH 0
          ][
            GH 2
          ]        
        ][
          if not z?[
            set var round ((pxcor - pycor) mod (2 * p) )
            ifelse (p <= var)[
              GH 1
            ][
              GH 0
            ]          
          ]        
        ];y?      
      ];x?    
    ]
    if #dirs = 3[;Tintersection
        set var round ((pxcor - pycor) mod (3 * p) )
        ;set var pycor - min-pycor ; make it positive
        ifelse (2 * p <= var)[
          GH 2
        ][
          ifelse (p <= var)[
            GH 0
          ][  
            GH 1
          ]
        ]
    
    ]
  ]
  if method = "SOLA"[
    set switch-asap true
    set kappa-x 0
    set kappa-y 0
    set kappa-z 0
    set greensteps 0  
    ifelse z?[
      set green-z? true
    ][
      set green-x? true
    ]
  ]
  
;  init-TL
  set-all-red
  set-green
end

to GH [dir]
  if dir = 0[
    set green-x? true
    ask hex-neighbors [ set green-x? true]
  ]
  if dir = 1[
    set green-y? true
    ask hex-neighbors [ set green-y? true]
  ]
  if dir = 2[
    set green-z? true
    ask hex-neighbors [ set green-z? true]
  ]
end

;to init-TL
;  ask traffic-lights[
;    if x?[
;      ifelse green-x?[
;        set rule 184
;      ][    
;        set rule 252
;      ]
;    ]
;    if y?[
;      ifelse green-y?[
;        set rule 184
;      ][    
;        set rule 252
;      ]
;    ]
;    if z?[
;      ifelse green-z?[
;        set rule 184
;      ][    
;        set rule 252
;      ]
;    ]
;    extrapolate-rule
;  ]
;  
;  ask upstreams[
;    if x?[
;      ifelse green-x?[
;        set rule 184
;      ][    
;        set rule 136
;      ]
;    ]
;    if y?[
;      ifelse green-y?[
;        set rule 184
;      ][    
;        set rule 136
;      ]
;    ]
;    if z?[
;      ifelse green-z?[
;        set rule 184
;      ][    
;        set rule 136
;      ]
;    ]
;    extrapolate-rule
;  ]
;  set-green
;end ;;initTL

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GO Procedures      ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  do-method ;; traffic lights
  ask intersections with [switch-asap and not on? and not all-stop?][
    switch-traffic-lights
  ]
  ask intersections with [all-stop?][
    all-red
  ]
;  ask Dintersections with [not switch-asap and not all-stop? and was-all-stop?][
;    restore-green
;  ]

  ask streets[  ;; keep old states
    set was-on? on?
  ]
  ask streets  ;; apply rule
    [ do-rule ]
  ask streets [  ;; color in changed cells
    color-cells  
  ]
  do-lists
  update-plots
  do-clock
end

to do-clock
  tick
  ;; The phase cycles from 0 to p, then starts over.
  set phase phase + 1
  if phase mod p = 0
    [ set phase 0 ]
  ask intersections [
    set greensteps (greensteps + 1)
  ]
end

to do-rule  ;; patch procedure
  let left-on? false
  let right-on? false
  ;if dwx? and not (intersection? and not green-horizontal?)[
    set left-on? [was-on?] of lc  ;; set to true if the left cell was on
    set right-on? [was-on?] of rc  ;; set to true if the right cell was on
  ;]
  
  ;; each of these lines checks the local area and (possibly)
  ;; sets the lower cell according to the corresponding switch
  let new-value
    (iii and left-on?       and on?       and right-on?)          or
    (iio and left-on?       and on?       and (not right-on?))    or
    (ioi and left-on?       and (not on?) and right-on?)          or
    (ioo and left-on?       and (not on?) and (not right-on?))    or
    (oii and (not left-on?) and on?       and right-on?)          or
    (oio and (not left-on?) and on?       and (not right-on?))    or
    (ooi and (not left-on?) and (not on?) and right-on?)          or
    (ooo and (not left-on?) and (not on?) and (not right-on?))
  set on? new-value
end

to try-switch-traffic-lights [mode]; intersection procedure
  ifelse all-stop? [
    all-red
  ][
    ifelse on? [
      ifelse switch-asap[
        set switch-asap false
      ][
        set switch-asap true
      ]
    ][
      ;set switch-asap true
      if mode = ""[
        switch-traffic-lights
      ]
      if mode = "x"[
        switch-to-x
      ]
      if mode = "y"[
        switch-to-y
      ]
      if mode = "z"[
        switch-to-z
      ]
    ]
  ]
end

to switch-traffic-lights; intersection procedure
  if not on?[
    set all-stop? false
    ask hex-neighbors [ set all-stop? false ]
    set switch-asap false
    
    ifelse (green-x?)[
      set green-x? false
      ifelse y?[
        set green-y? true
      ][
        set green-z? true
      ]
    ][
      ifelse (green-y?)[
        set green-y? false
        ifelse z?[
          set green-z? true
        ][
          set green-x? true
        ]
      ][
        if (green-z?)[
          set green-z? false
          ifelse x?[
            set green-x? true
          ][
            set green-y? true
          ]
        ]
      ];;ifelse y
    ];;ifelse x
    set greensteps 0
    set rule 184
    extrapolate-rule
    
    
    set-all-red
    
    set-green    
  ]
end

to switch-to-x; 3-intersection procedure
  if not on?[
    set all-stop? false
    ask hex-neighbors [ set all-stop? false ]
    set switch-asap false
    set kappa-x 0 
    set green-x? true
    set green-y? false
    set green-z? false
    set greensteps 0
    set rule 184
    extrapolate-rule    
    set-all-red
    set-green    
  ]
end
to switch-to-y; 3-intersection procedure
  if not on?[
    set all-stop? false
    ask hex-neighbors [ set all-stop? false ]
    set switch-asap false
    set kappa-y 0 
    set green-x? false
    set green-y? true
    set green-z? false
    set greensteps 0
    set rule 184
    extrapolate-rule    
    set-all-red
    set-green    
  ]
end
to switch-to-z; 3-intersection procedure
  if not on?[
    set all-stop? false
    ask hex-neighbors [ set all-stop? false ]
    set switch-asap false
    set kappa-z 0 
    set green-x? false
    set green-y? false
    set green-z? true
    set greensteps 0
    set rule 184
    extrapolate-rule    
    set-all-red
    set-green    
  ]
end

to set-green
  set was-all-stop? false
    if (green-x?)[
      ifelse dwx?[
        set-dwx
      ][
        set-upx
      ]
    ]
    if (green-y?)[
      ifelse dwy?[
        set-dwy
      ][
        set-upy
      ]
    ]
    if (green-z?)[
      ifelse dwz?[
        set-dwz
      ][
        set-upz
      ]
    ]

    ask lc [
      set rule 184
      extrapolate-rule
    ]
    ask rc [
      set rule 184
      extrapolate-rule
    ]
end

to set-all-red
    ask hex-neighbors[
      ifelse traffic-light?[
        set rule 252;;red light rule 
      ][;; then upstream
        set rule 136;;red light rule
      ]      
      extrapolate-rule
    ]
end

to all-red ;intersection procedure, to set all lights red
  set was-all-stop? true
  ask hex-neighbors [ set all-stop? true ]    
  set rule 136
  extrapolate-rule
  ask lc [
    set rule 252
    extrapolate-rule
  ]
  ask rc [
    set rule 184
    extrapolate-rule
  ]
  set greensteps mingreen ; 0 ;*** to check...
  set green-x? false
  set green-y? false
  set green-z? false
;  set-all-red
end

;;;***not used???
to restore-green ;intersection procedure, to set a light back to green (without switching...)
  set was-all-stop? false
;  ask hex-neighbors [ 
;    set all-stop? false 
;    ifelse traffic-light?[
;      set rule 252;;red light rule 
;    ][;; then upstream
;      set rule 136;;red light rule
;    ]      
;    extrapolate-rule
;  ]    
  set rule 184
  extrapolate-rule
  set greensteps 0

;***to check...
    ask lc [
      set rule 184
      extrapolate-rule
    ]
;    ask rc [
;      set rule 184
;      extrapolate-rule
;    ]

end

to do-method
  if method = "SOLA" [SOLA]  
  if method = "green-wave" [gw]
  if method = "marching" [march]
  if method = "random" [rand]
end

to rand
  ask intersections[
    if ((ticks + var) mod p) = 0[
      try-switch-traffic-lights ""
    ]
  ]
end

to march
  if (ticks mod p) = 0[
    ask intersections[
      try-switch-traffic-lights ""
    ]
  ]
end

to gw
  ask intersections[
    if (phase = (round ( pxcor - pycor) mod p))[
      try-switch-traffic-lights ""
    ]
  ]
end

;;recursive function: cell tells which cell to evaluate, dir < 0 backwards, dir > 0 forward, stops when cells-to-go = 0
to-report count_cars [cell dir cells-to-go]
  ;print cells-to-go
  ifelse cells-to-go <= 0[
    ifelse on? [
      report 1 
    ][
      report 0
    ]  
  ][
    let cell-on? 0
    let c 0
    ask cell[
      ifelse dir < 0[
        set c lc;
      ][
        set c rc;
      ]
      ifelse on? [
        set cell-on? true
      ][
        set cell-on? false
      ]
    ]
    ifelse cell-on? [
      report 1 + (count_cars c dir (cells-to-go - 1))
    ][
      report count_cars c dir (cells-to-go - 1)
    ]
  ]
end

;;recursive function: returns true if there is a blockage at a certain distance, dir < 0 backwards, dir > 0 forward, stops when cells-to-go = 0
to-report blockage? [cell dir cells-to-go]
  let cell-on? 0
  let c 0
  ask cell[
    ifelse dir < 0[
      set c lc;
    ][
      set c rc;
    ]
    ifelse on? and was-on?[
      set cell-on? true
    ][
      set cell-on? false
    ]
  ]
  
  ifelse cell-on?[
    report true 
  ][
    ifelse cells-to-go <= 0[
        report false
    ][
      report blockage? c dir (cells-to-go - 1)
    ]
  ]  
  
;  ifelse cells-to-go <= 0[
;    ifelse cell-on?[
;      report true 
;    ][
;      report false
;    ]  
;  ][
;    report blockage? c dir (cells-to-go - 1)
;  ]
end

to SOLA
  ask intersections [
    let cars-near-x 0
    let cars-near-y 0
    let cars-near-z 0
    let cars-green-x 0
    let cars-green-y 0
    let cars-green-z 0
    let blockahead-x? false
    let blockahead-y? false
    let blockahead-z? false
    let i 0
    
    set r1 false
    set r2 false
    set r3 false
    set r4 false
    set r5 false    
        
    if (not green-x?) and (not green-y?) and (not green-z?)[
      set all-stop? true
    ]
           
    ifelse all-stop?[;;check all red directions...    
      if x?[
        ifelse (dwx?)[
          set kappa-x (kappa-x + count_cars (cells-on patch-at  -1 0.5) -1 (sensor-distance - 1));; kappas are for rule 1
          set blockahead-x? blockage? (cells-on patch-at  1 -0.5) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-x (kappa-x + count_cars (cells-on patch-at   1  -0.5) -1 (sensor-distance - 1))
          set blockahead-x? blockage? (cells-on patch-at  -1 0.5) 1 (cut-ahead - 1)
        ]
      ]
      if y?[
        ifelse (dwy?)[
          set kappa-y (kappa-y + count_cars (cells-on patch-at  -1 -0.5) -1 (sensor-distance - 1));; kappas are for rule 1
          set blockahead-y? blockage? (cells-on patch-at  1 0.5) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-y (kappa-y + count_cars (cells-on patch-at   1  0.5) -1 (sensor-distance - 1))
          set blockahead-y? blockage? (cells-on patch-at  -1 -0.5) 1 (cut-ahead - 1) ;; for rule 6
        ]
      ]
      if z?[
        ifelse (dwz?)[
          set kappa-z (kappa-z + count_cars (cells-on patch-at  0  1) -1 (sensor-distance - 1))
          set blockahead-z? blockage? (cells-on patch-at  0 -1) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-z (kappa-z + count_cars (cells-on patch-at  0 -1) -1 (sensor-distance - 1))
          set blockahead-z? blockage? (cells-on patch-at  0 1) 1 (cut-ahead - 1) ;; for rule 6
        ]
      ]
      ifelse  (#dirs = 3)[
        ifelse blockahead-x? and blockahead-y? and blockahead-z?[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ][
        ifelse (blockahead-x? and blockahead-y?) or (blockahead-x? and blockahead-z?) or (blockahead-y? and blockahead-z?)[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ]          
      
       if (kappa-x > tolerance) or (kappa-y > tolerance) or (kappa-z > tolerance) [;rule 1
         set r1 true
       ]
       if (greensteps > mingreen)[;rule 2
         set r2 true
       ]
       set r3 true  
    ][
    ifelse (green-x?) [;; then red light(s) in other directions... check those
      if y?[
        ifelse (dwy?)[
          set kappa-y (kappa-y + count_cars (cells-on patch-at  -1 -0.5) -1 (sensor-distance - 1));; kappas are for rule 1
          set blockahead-y? blockage? (cells-on patch-at  1 0.5) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-y (kappa-y + count_cars (cells-on patch-at   1  0.5) -1 (sensor-distance - 1))
          set blockahead-y? blockage? (cells-on patch-at  -1 -0.5) 1 (cut-ahead - 1) ;; for rule 6
        ]
      ]
      if z?[
        ifelse (dwz?)[
          set kappa-z (kappa-z + count_cars (cells-on patch-at  0  1) -1 (sensor-distance - 1))
          set blockahead-z? blockage? (cells-on patch-at  0 -1) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-z (kappa-z + count_cars (cells-on patch-at  0 -1) -1 (sensor-distance - 1))
          set blockahead-z? blockage? (cells-on patch-at  0 1) 1 (cut-ahead - 1) ;; for rule 6
        ]
      ]
      ifelse (dwx?)[
        set cars-near-x count_cars (cells-on patch-at   -1 0.5) -1 (keep-platoon - 1) ;; for rule 3
        set cars-green-x count_cars (cells-on patch-at  -1 0.5) -1 (sensor-distance - 1);; for rule 4
        set blockahead-x? blockage? (cells-on patch-at  1 -0.5) 1 (cut-ahead - 1) ;; for rule 5
      ][
        set cars-near-x count_cars (cells-on patch-at   1 -0.5) -1 (keep-platoon - 1) ;; for rule 3
        set cars-green-x count_cars (cells-on patch-at  1 -0.5) -1 (sensor-distance - 1)      
        set blockahead-x? blockage? (cells-on patch-at  -1 0.5) 1 (cut-ahead - 1)
      ]

      ifelse  (#dirs = 3)[
        ifelse blockahead-x? and blockahead-y? and blockahead-z?[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ][
        ifelse blockahead-x? and (blockahead-y? or blockahead-z?)[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ]          
      
       if (kappa-y > tolerance) or (kappa-z > tolerance) [;rule 1
         set r1 true
       ]
       if (greensteps > mingreen)[;rule 2
         set r2 true
       ]
       if ((0 = cars-near-x) or ((cars-near-x >= cut-platoon)))[; on street with green light ;rule 3
         set r3 true
       ]
       if ((cars-green-x = 0) and ((kappa-y >= 1) or (kappa-z >= 1))) [;rule 4
         set r4 true
       ]
       ifelse (blockahead-x?) [;rule 5
         set r5 true
       ][
         set all-stop? false ;; all stop only when all streets are blocked
       ]  
                 
    ][;;not green-x?
    ifelse green-y?[
      if x?[
        ifelse (dwx?)[
          set kappa-x (kappa-x + count_cars (cells-on patch-at  -1 0.5) -1 (sensor-distance - 1));; kappas are for rule 1
          set blockahead-x? blockage? (cells-on patch-at  1 -0.5) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-x (kappa-x + count_cars (cells-on patch-at   1  -0.5) -1 (sensor-distance - 1))
          set blockahead-x? blockage? (cells-on patch-at  -1 0.5) 1 (cut-ahead - 1)
        ]
      ]
      if z?[
        ifelse (dwz?)[
          set kappa-z (kappa-z + count_cars (cells-on patch-at  0  1) -1 (sensor-distance - 1))
          set blockahead-z? blockage? (cells-on patch-at  0 -1) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-z (kappa-z + count_cars (cells-on patch-at  0 -1) -1 (sensor-distance - 1))
          set blockahead-z? blockage? (cells-on patch-at  0 1) 1 (cut-ahead - 1) ;; for rule 6
        ]
      ]
      ifelse (dwy?)[
        set cars-near-y count_cars (cells-on patch-at   -1 -0.5) -1 (keep-platoon - 1) ;; for rule 3
        set cars-green-y count_cars (cells-on patch-at  -1 -0.5) -1 (sensor-distance - 1);; for rule 4
        set blockahead-y? blockage? (cells-on patch-at  1 0.5) 1 (cut-ahead - 1) ;; for rule 5
      ][
        set cars-near-y count_cars (cells-on patch-at   1 0.5) -1 (keep-platoon - 1) ;; for rule 3
        set cars-green-y count_cars (cells-on patch-at  1 0.5) -1 (sensor-distance - 1)      
        set blockahead-y? blockage? (cells-on patch-at  -1 -0.5) 1 (cut-ahead - 1) ;; for rule 5
      ]

      ifelse  (#dirs = 3)[
        ifelse blockahead-x? and blockahead-y? and blockahead-z?[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ][
        ifelse blockahead-y? and (blockahead-x? or blockahead-z?)[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ]          
      
       if (kappa-x > tolerance) or (kappa-z > tolerance) [;rule 1
         set r1 true
       ]
       if (greensteps > mingreen)[;rule 2
         set r2 true
       ]
       if ((0 = cars-near-y) or ((cars-near-y >= cut-platoon)))[; on street with green light ;rule 3
         set r3 true
       ]
       if ((cars-green-y = 0) and ((kappa-x >= 1) or (kappa-z >= 1))) [;rule 4
         set r4 true
       ]
       ifelse (blockahead-y?) [;rule 5
         set r5 true
       ][
         set all-stop? false ;; all stop only when all streets are blocked
       ]  
    
    ][;;not green-y?
    if green-z?[
      if x?[
        ifelse (dwx?)[
          set kappa-x (kappa-x + count_cars (cells-on patch-at  -1 0.5) -1 (sensor-distance - 1));; kappas are for rule 1
          set blockahead-x? blockage? (cells-on patch-at  1 -0.5) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-x (kappa-x + count_cars (cells-on patch-at   1  -0.5) -1 (sensor-distance - 1))
          set blockahead-x? blockage? (cells-on patch-at  -1 0.5) 1 (cut-ahead - 1)
        ]
      ]
      if y?[
        ifelse (dwy?)[
          set kappa-y (kappa-y + count_cars (cells-on patch-at  -1 -0.5) -1 (sensor-distance - 1));; kappas are for rule 1
          set blockahead-y? blockage? (cells-on patch-at  1 0.5) 1 (cut-ahead - 1) ;; for rule 6
        ][
          set kappa-y (kappa-y + count_cars (cells-on patch-at   1  0.5) -1 (sensor-distance - 1))
          set blockahead-y? blockage? (cells-on patch-at  -1 -0.5) 1 (cut-ahead - 1) ;; for rule 6
        ]
      ]
      ifelse (dwz?)[
        set cars-near-z count_cars (cells-on patch-at   0  1) -1 (keep-platoon - 1) ;; for rule 3
        set cars-green-z count_cars (cells-on patch-at  0  1) -1 (sensor-distance - 1);; for rule 4
        set blockahead-z? blockage? (cells-on patch-at  0 -1) 1 (cut-ahead - 1) ;; for rule 5
      ][
        set cars-near-z count_cars (cells-on patch-at   0 -1) -1 (keep-platoon - 1) ;; for rule 3
        set cars-green-z count_cars (cells-on patch-at  0 -1) -1 (sensor-distance - 1);; for rule 4
        set blockahead-z? blockage? (cells-on patch-at  0  1) 1 (cut-ahead - 1) ;; for rule 5
      ]

      ifelse  (#dirs = 3)[
        ifelse blockahead-x? and blockahead-y? and blockahead-z?[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ][
        ifelse blockahead-z? and (blockahead-x? or blockahead-y?)[
          set all-stop? true
        ][
          set all-stop? false
        ]       
      ]          
      
       if (kappa-x > tolerance) or (kappa-y > tolerance) [;rule 1
         set r1 true
       ]
       if (greensteps > mingreen)[;rule 2
         set r2 true
       ]
       if ((0 = cars-near-z) or ((cars-near-z >= cut-platoon)))[; on street with green light ;rule 3
         set r3 true
       ]
       if ((cars-green-z = 0) and ((kappa-x >= 1) or (kappa-y >= 1))) [;rule 4
         set r4 true
       ]
       ifelse (blockahead-z?) [;rule 5
         set r5 true
       ][
         set all-stop? false ;; all stop only when all streets are blocked
       ]      
    
    ];if green-z?
    ];else green-y?
    ];else green-x?
    ];else all-stop?

    if  ((r5) or
      (r4 and not all-stop?) or
      (r1 and r2 and r3 and not all-stop?)
      )
    [     ;; OK, switch... but which?
      ifelse #dirs = 2 [
;        set kappa-x 0 ;;reset kappas anyway...
;        set kappa-y 0
;        set kappa-z 0
        
        ifelse not z?[
          ifelse (not blockahead-x?) and (not blockahead-y?)[
            ifelse (kappa-y > kappa-x) [
              try-switch-traffic-lights "y"
            ][
              try-switch-traffic-lights "x"
            ] 
          ][
          ifelse (blockahead-x?) and (not blockahead-y?)[
            try-switch-traffic-lights "y"
          ][
          if (not blockahead-x?) and (blockahead-y?)[
            try-switch-traffic-lights "x"
          ]
          ]
          ]
        ][
        ifelse not y?[
          ifelse (not blockahead-x?) and (not blockahead-z?)[
            ifelse (kappa-z > kappa-x) [
              try-switch-traffic-lights "z"
            ][
              try-switch-traffic-lights "x"
            ] 
          ][
          ifelse (blockahead-x?) and (not blockahead-z?)[
            try-switch-traffic-lights "z"
          ][
          if (not blockahead-x?) and (blockahead-z?)[
            try-switch-traffic-lights "x"
          ]
          ]
          ]
        ][
        if not x?[
          ifelse (not blockahead-z?) and (not blockahead-y?)[
            ifelse (kappa-y > kappa-z) [
              try-switch-traffic-lights "y"
            ][
              try-switch-traffic-lights "z"
            ] 
          ][
          ifelse (blockahead-z?) and (not blockahead-y?)[
            try-switch-traffic-lights "y"
          ][
          if (not blockahead-z?) and (blockahead-y?)[
            try-switch-traffic-lights "z"
          ]
          ]
          ]
        ]
        ]        
        ]
;          try-switch-traffic-lights ""                                                                 
      ][;; 3-intersection, need to see which street will get green...
        ifelse (not blockahead-x?) and (not blockahead-y?) and (not blockahead-z?)[
          ifelse (kappa-x = max (list kappa-x kappa-y kappa-z)) [          
            try-switch-traffic-lights "x"
          ][
            ifelse (kappa-y > kappa-z) [
              try-switch-traffic-lights "y"
            ][
              try-switch-traffic-lights "z"
            ]
          ]
        ][;;then there is some blockage...
        ifelse (blockahead-x?) and (not blockahead-y?) and (not blockahead-z?)[;;only blockahead-x
          ifelse (kappa-y > kappa-z) [
            try-switch-traffic-lights "y"
          ][
            try-switch-traffic-lights "z"
          ]        
        ][
        ifelse (not blockahead-x?) and (blockahead-y?) and (not blockahead-z?)[;;only blockahead-y
          ifelse (kappa-x > kappa-z) [
            try-switch-traffic-lights "x"
          ][
            try-switch-traffic-lights "z"
          ]        
        ][
        ifelse (not blockahead-x?) and (not blockahead-y?) and (blockahead-z?)[;;only blockahead-z
          ifelse (kappa-y > kappa-x) [
            try-switch-traffic-lights "y"
          ][
            try-switch-traffic-lights "x"
          ]        
        ][
        ifelse (blockahead-x?) and (blockahead-y?) and (not blockahead-z?)[;;only z free
          try-switch-traffic-lights "z"
        ][
        ifelse (blockahead-x?) and (not blockahead-y?) and (blockahead-z?)[;;only y free
          try-switch-traffic-lights "y"
        ][
        ifelse (not blockahead-x?) and (blockahead-y?) and (blockahead-z?)[;;only x free
          try-switch-traffic-lights "x"
        ][;;then all blocked...
        
        ]                
        ]
        ]        
        ]        
        ]  
        ]
        ]
;        ifelse ((kappa-x = max (list kappa-x kappa-y kappa-z)) or (blockahead-y? and blockahead-z? )) and (not blockahead-x?)[          
;          try-switch-traffic-lights "x"
;        ][
;          ifelse ((kappa-y > kappa-z) or (blockahead-x? and blockahead-y? )) and (not blockahead-y?)[
;            try-switch-traffic-lights "y"
;          ][
;            if (not blockahead-z?)[
;              try-switch-traffic-lights "z"
;            ]
;          ]

      ] ;; dirs=3           
    ] ;; switch TL

  ] ;; ask intersections
end

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Utility Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

to color-cells 
  ifelse traffic-light?[
  ifelse rule = 184
     [ set color green ]
     [ set color red ] 
  ][;street
    ifelse on?
      [ 
        ifelse was-on?[
          set color foreground - 50 
        ][
          set color foreground 
        ]
      ]
      [ set color background ]   
  ]
end


to-report bindigit [number power-of-two]
  ifelse (power-of-two = 0)
    [ report floor number mod 2 ]
    [ report bindigit (floor number / 2) (power-of-two - 1) ]
end

to extrapolate-rule
  ;; set the switches based on the slider
  set ooo ((bindigit rule 0) = 1)
  set ooi ((bindigit rule 1) = 1)
  set oio ((bindigit rule 2) = 1)
  set oii ((bindigit rule 3) = 1)
  set ioo ((bindigit rule 4) = 1)
  set ioi ((bindigit rule 5) = 1)
  set iio ((bindigit rule 6) = 1)
  set iii ((bindigit rule 7) = 1)
end

to-report calculate-rule
  ;; set the slider based on the switches
  let result 0
  if ooo [ set result result +   1 ]
  if ooi [ set result result +   2 ]
  if oio [ set result result +   4 ]
  if oii [ set result result +   8 ]
  if ioo [ set result result +  16 ]
  if ioi [ set result result +  32 ]
  if iio [ set result result +  64 ]
  if iii [ set result result + 128 ]
  report result
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Plotting Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to do-lists
  set #cars-old #cars
  set #cars count streets with [on?]
  if #cars != #cars-old[
    print "WARNING: Vehicles were not conserved!"
  ]
  set flow (count streets with [on? and not was-on?]) / #cars ;;(count streets - #cars)
  set flow-data sentence flow-data flow
  
end

to update-plots
  if plots?[
    set-current-plot "Velocity"
    set-current-plot-pen "default"
    plotxy ticks  flow
    set-current-plot-pen "mean"
    plotxy ticks  mean flow-data

    set-current-plot "Flux"
    set-current-plot-pen "default"
    plotxy ticks  flow * density / 100
    set-current-plot-pen "mean"
    plotxy ticks  mean flow-data * density / 100
  ]
end

;Original model copyrights:

; *** NetLogo 4.0.4 Model Copyright Notice ***
;
; This model was created as part of the project: CONNECTED MATHEMATICS:
; MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL
; MODELS (OBPML).  The project gratefully acknowledges the support of the
; National Science Foundation (Applications of Advanced Technologies
; Program) -- grant numbers RED #9552950 and REC #9632612.
;
; Copyright 1998 by Uri Wilensky.  All rights reserved.
;
; Permission to use, modify or redistribute this model is hereby granted,
; provided that both of the following requirements are followed:
; a) this copyright notice is included.
; b) this model will not be redistributed for profit without permission
;    from Uri Wilensky.
; Contact Uri Wilensky for appropriate licenses for redistribution for
; profit.
;
; This model was converted to NetLogo as part of the projects:
; PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING
; IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT.
; The project gratefully acknowledges the support of the
; National Science Foundation (REPP & ROLE programs) --
; grant numbers REC #9814682 and REC-0126227.
; Converted from StarLogoT to NetLogo, 2001.
;
; To refer to this model in academic publications, please use:
; Wilensky, U. (1998).  NetLogo CA 1D Elementary model.
; http://ccl.northwestern.edu/netlogo/models/CA1DElementary.
; Center for Connected Learning and Computer-Based Modeling,
; Northwestern University, Evanston, IL.
;
; In other publications, please use:
; Copyright 1998 Uri Wilensky.  All rights reserved.
; See http://ccl.northwestern.edu/netlogo/models/CA1DElementary
; for terms of use.
;
; *** End of NetLogo 4.0.4 Model Copyright Notice ***


; *** NetLogo 4.0.4 Model Copyright Notice ***
;
; Copyright 2007 by Uri Wilensky.  All rights reserved.
;
; Permission to use, modify or redistribute this model is hereby granted,
; provided that both of the following requirements are followed:
; a) this copyright notice is included.
; b) this model will not be redistributed for profit without permission
;    from Uri Wilensky.
; Contact Uri Wilensky for appropriate licenses for redistribution for
; profit.
;
; To refer to this model in academic publications, please use:
; Wilensky, U. (2007).  NetLogo Hex Cell Aggregation model.
; http://ccl.northwestern.edu/netlogo/models/HexCellAggregation.
; Center for Connected Learning and Computer-Based Modeling,
; Northwestern University, Evanston, IL.
;
; In other publications, please use:
; Copyright 2007 Uri Wilensky.  All rights reserved.
; See http://ccl.northwestern.edu/netlogo/models/HexCellAggregation
; for terms of use.
;
; *** End of NetLogo 4.0.4 Model Copyright Notice ***

@#$#@#$#@
GRAPHICS-WINDOW
357
12
1267
943
-1
-1
5.0
1
10
1
1
1
0
1
1
1
-90
89
-90
89
1
1
1
ticks

BUTTON
131
149
204
183
setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL

TEXTBOX
113
764
203
782
Colors:
11
0.0
0

SLIDER
128
48
234
81
density
density
1
100.0
5
1
1
%
HORIZONTAL

BUTTON
209
151
280
184
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL

INPUTBOX
114
783
234
843
foreground
94
1
0
Color

INPUTBOX
239
783
355
843
background
1
1
0
Color

SLIDER
203
211
318
244
p
p
1
100
60
1
1
timesteps
HORIZONTAL

SLIDER
3
13
120
46
grid-size-x
grid-size-x
0
16
6
1
1
NIL
HORIZONTAL

SLIDER
121
13
238
46
grid-size-y
grid-size-y
0
16
6
1
1
NIL
HORIZONTAL

MONITOR
24
92
81
137
cars
#cars
17
1
11

PLOT
7
385
354
571
Velocity
timesteps
NIL
0.0
10.0
0.0
1.0
true
false
PENS
"default" 1.0 0 -2674135 true
"mean" 1.0 0 -16777216 true

CHOOSER
9
149
117
194
method
method
"random" "marching" "green-wave" "SOLA"
3

SWITCH
3
49
120
82
six-dirs?
six-dirs?
0
1
-1000

SLIDER
6
234
176
267
sensor-distance
sensor-distance
0
20
10
1
1
patches
HORIZONTAL

SLIDER
7
267
145
300
tolerance
tolerance
0
300
40
1
1
cars * ts
HORIZONTAL

SLIDER
4
302
152
335
keep-platoon
keep-platoon
0
10
5
1
1
patches
HORIZONTAL

SLIDER
151
302
273
335
cut-platoon
cut-platoon
0
10
2
1
1
cars
HORIZONTAL

SLIDER
4
337
152
370
cut-ahead
cut-ahead
0
10
2
1
1
patches
HORIZONTAL

SLIDER
146
266
254
299
mingreen
mingreen
0
60
10
1
1
ts
HORIZONTAL

TEXTBOX
9
221
159
239
SOLA\n
11
0.0
1

TEXTBOX
206
196
356
214
Green wave & marching\n
11
0.0
1

SWITCH
8
766
111
799
plots?
plots?
0
1
-1000

PLOT
7
572
354
758
Flux
NIL
NIL
0.0
10.0
0.0
0.5
true
false
PENS
"default" 1.0 0 -2674135 true
"mean" 1.0 0 -16777216 true

BUTTON
288
152
351
185
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
239
13
356
46
grid-size-z
grid-size-z
1
16
6
1
1
NIL
HORIZONTAL

SLIDER
240
48
355
81
x-offset-of-z
x-offset-of-z
1
134
56
1
1
NIL
HORIZONTAL

CHOOSER
171
95
341
140
scenario
scenario
"custom" "1 triple" "3 double" "36 triple" "108 double" "12 triple, 48 double"
4

@#$#@#$#@
CHANGELOG
-----------

0.12	2011/03/03	added random method
0.11	2010/06/24	added scenarios
0.10	2009/12/01	fixed marching init bug...
0.09	2009/11/25	increased world size...
0.08	2009/11/25	fixed minor bugs in SOLA, seems to work fine now, 2 and 3 dirs
0.06	2009/11/12	SOLA works! in 6 dirs!
0.05	2009/11/12	gw works, SOLA in process...
0.04	2009/11/04	TL, marching work; added warnings
0.03	2009/10/30	Intersections are inited OK, cars conserved...
0.02	2009/10/29	Got boudnaries, cars move, need intersections...
0.01	2009/10/29	Got streets more or less working
0.00	2009/10/29	Based on trafficCA0.22 and NetLogo Hex Cell Aggregation model

TODO
-----------


NOTES
-----------

* offsets to have 3-way intersections:
grid-size-z	x-offset-of-z
1		89
2		74
3		69
4		67
5		65
6		64
7		63
8		63
9		62
10		62
11		62
12		62

* Green-wave cannot work for 3 directions, even less 6... too many constraints... Still, it can work in z direction, and it does much better if there are 2-intersections (v~=0.75) than 3-intersections (v=0.66) in an 8x8x8 setup, since p can be 50% longer...


WHAT IS IT?
-----------

This is model of city traffic based on elementary cellular automata (ECA) on an hexagonal grid.
More info at http://turing.iimas.unam.mx/~cgg/

HOW TO USE IT
-------------

Click on "Setup" and then on "Go" or "Step". The controls above these buttons should be set before "Setup", the others can be changed anytime.

SCENARIO Loads default scenarios, choose "custom" for testing alternative scenarios.

GRID-SIZE-X and GRID-SIZE-Y determine how many streets will be with each orientation (vertical and horizontal). Use GRID-SIZE-X=0 for freeway model (Rule 184), i.e. no intersections.

SIX-DIRS? If true, streets flow in six directions (alternating). 
***Notice that if this is true, the nubmer of streets in x and y should be even, otherwise there are problems with boundary conditions...

DENSITY. Determines probabilistically how many cells are occupied by vehicles.

%VERTICAL Determines probabilistically the percentage of cars on vertical streets (complementary to horizontal ones)

METHOD. Choose between following methods:
"Marching": all lights march in step, either vertical or horizontal
"Green-wave": Lights are synchronized so that vehicels flowing eastbound or southbound would not need to stop (at a flow speed of 1)

The next parameter affects the marching or green wave methods

P Duration of a green light, i.e. half a period (T/2). To avoid stopping of vehicels, set this equal to half the length of the street or equal to a factor of half the length of the street.

The following parameters affect the self-organizing method. See paper for a description.

SENSOR-DISTANCE (d) 

TOLERANCE (n)

MINGREEN (t_min)

KEEP-PLATOON (m)

CUT-PLATOON (r)

CUT-AHEAD (e)



THINGS TO NOTICE
----------------

The Velocity plot shows the percentage of vehicles moving, i.e. if v=1, no vehicle stops, and if v=0, all vehicles are stopped.

The Flux plot shows the velocity multiplied by the density. In the rule 184 model of highway traffic (i.e. no intersections, grid-size-x = 0), the maximum possible flux is $J=0.5$, at a density $\rho=0.5$. This is because vehicles need at least one cell between them to move. If there are less vehicles, the flux will be lower, since there is no movement in free space. If there are more vehicles, then the flux will also be lower, since stopped vehicles do not move.


THINGS TO TRY
-------------

The green wave method works fine for only two directions (set FOUR-DIRS? to false). However, when vehicles flow in four directions (and there are more than two streets in any orientation), the performance is relatively bad, because vehicles going opposite to the green wave face anti-correlated lights.

The self-organizing mehtod can achieve free flow in four directions for low densities.

At which densities each method reaches a gridlock (flow=0)?

See how performance varies as more streets are added (for different methods).


CREDITS AND REFERENCES
-----------------------


Based on:  

* Wilensky, U. (1998).  NetLogo CA 1D Elementary model.  http://ccl.northwestern.edu/netlogo/models/CA1DElementary.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
*  Wilensky, U. (2007).  NetLogo Hex Cell Aggregation model. http://ccl.northwestern.edu/netlogo/models/HexCellAggregation. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.


About ECA:
http://mathworld.wolfram.com/ElementaryCellularAutomaton.html
http://en.wikipedia.org/wiki/Cellular_automata
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

hex
false
0
Polygon -7500403 true true 0 150 75 30 225 30 300 150 225 270 75 270

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
NetLogo 4.1.2
@#$#@#$#@
setup-random repeat world-height - 1 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
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
