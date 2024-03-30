globals [
  expressway-ycor
  street-ycor
  speed-min
  global-emissions
  cars-remaining
  car-spawnpoints
  cumulative-expressway-traffic
  cumulative-street-traffic
  last-average-speed-expressway
  last-average-speed-street
  cumulative-weighted-average-speed-expressway-history
  cumulative-weighted-average-speed-street-history
  historical-distn
]

breed [cars car]
cars-own [myspeed emissions go-expressway? cartype exit-early? distance-travelled]
breed [traffic-lights traffic-light]
traffic-lights-own [red-light-duration green-light-duration]

to setup
  clear-all
  reset-ticks

  set speed-min 0

  resize-world 0 50 -10 10
  set-patch-size 12

  set expressway-ycor n-values 3 [i -> i + 3]
  set street-ycor n-values 3 [i -> i - 5]
  set cars-remaining num-cars
  set cumulative-weighted-average-speed-expressway-history []
  set cumulative-weighted-average-speed-street-history []

  setup-expressway
  setup-street
  setup-traffic-lights
  setup-points
  price-sensitive-spawning
end

to setup-expressway
  ask patches with [member? pycor expressway-ycor and pxcor <= min-pxcor + expressway-distance] [
    set pcolor blue
  ]
end

to setup-street
  let street-patches patches with [member? pycor street-ycor and pxcor <= min-pxcor + street-distance]
  ask street-patches [
    set pcolor gray
  ]
end

to setup-traffic-lights
  let placement-history []
  repeat num-traffic-lights [
    let traffic-light-location (random (street-distance - 1)) + 1
    while [member? traffic-light-location placement-history] [
      set traffic-light-location random (street-distance - 1) + 1
    ]
    set placement-history lput traffic-light-location placement-history
    let target-patches patches with [pxcor = traffic-light-location and pcolor = gray]
    if any? target-patches with [ not any? traffic-lights-here ] [
      let col-color ifelse-value (random-float 1 < 0.5) [red] [green]
      ask target-patches [
        sprout-traffic-lights 1 [
          set color col-color
          set shape "circle"
          set red-light-duration light-duration
          set green-light-duration light-duration * green-light-duration-multiplier
        ]
      ]
    ]
  ]
end

to setup-points
  ask patches with [pcolor != black and (pxcor = min-pxcor or ((pxcor = expressway-distance and member? pycor expressway-ycor) or (pxcor = street-distance and member? pycor  street-ycor)))] [
    set pcolor red
  ]
end

to price-sensitive-spawning
  let expressway-spawnpoint patches with [pcolor = red and pxcor = min-pxcor and pycor > 0]
  let street-spawnpoint patches with [pcolor = red and pxcor = min-pxcor and pycor < 0]

  ; Default Strategy: fictitious
  let decision true
  if ticks != 0 [
    set decision run-fictitious-play
  ]

  if decision-strategy = "proportional probability" [
    let probability random-float 1
    let adjusted-probability (erp-price / 6) * 0.90 + 0.05
    set decision random-float 1 > adjusted-probability
  ]

  ifelse decision [
    while [cars-remaining > 0 and (count patches with [pcolor = red and pxcor = min-pxcor and pycor > 0 and not any? cars-here] > 0)] [
      ifelse cars-remaining < count patches with [pcolor = red and pxcor = min-pxcor and pycor > 0] [
        ask one-of expressway-spawnpoint [
          spawn-car self
        ]
        set cars-remaining (cars-remaining - 1)
        set cumulative-expressway-traffic cumulative-expressway-traffic + 1
      ] [
        ask expressway-spawnpoint [
          spawn-car self
        ]
        set cars-remaining (cars-remaining - 3)
        set cumulative-expressway-traffic cumulative-expressway-traffic + 3
      ]
    ]
  ] [
    while [cars-remaining > 0 and (count patches with [pcolor = red and pxcor = min-pxcor and pycor < 0 and not any? cars-here] > 0)] [
      ifelse cars-remaining < count patches with [pcolor = red and pxcor = min-pxcor and pycor < 0] [
        ask one-of street-spawnpoint [
          spawn-car self
        ]
        set cars-remaining (cars-remaining - 1)
        set cumulative-street-traffic cumulative-street-traffic + 1
      ] [
        ask street-spawnpoint [
          spawn-car self
        ]
        set cars-remaining (cars-remaining - 3)
        set cumulative-street-traffic cumulative-street-traffic + 3
      ]
    ]
  ]
end

to spawn-car [target-patch]
  ask target-patch [
    sprout-cars 1 [
      set color violet
      set shape "car"
      set heading 90
      set exit-early? false
    ]
  ]
end

to go

  ask traffic-lights [
    ifelse color = red [
      set red-light-duration red-light-duration - 1
      if red-light-duration = 0 [
        set color green
        set red-light-duration light-duration
      ]
    ] [
      set green-light-duration green-light-duration - 1
      if green-light-duration = 0 [
        set color red
        set green-light-duration light-duration * green-light-duration-multiplier
      ]
    ]
  ]

  ask cars [
    set distance-travelled 0
    ifelse any? traffic-lights-on patch-ahead 1 [
      let ahead-light one-of traffic-lights-on patch-ahead 1
      ifelse [color] of ahead-light = red [
        set myspeed 0
        stop
      ] [
        ; Allow cars to proceed if no red light
        ifelse [pcolor] of patch-here = blue or [pcolor] of patch-ahead 1 = blue [
          ifelse exit-early? [
            die
          ] [
            if random-float 1 < 0.01 [
              set exit-early? true
            ]
          ]
          let car-ahead one-of cars-on patch-ahead 1
          ifelse car-ahead != nobody
          [ slow-down-car car-ahead ]
          [ speed-up-car ] ;; otherwise, speed up
          ;; don't slow down below speed minimum or speed up beyond speed limit
          if myspeed < speed-min [ set myspeed speed-min ]
          if myspeed > expressway-speedlimit [ set myspeed expressway-speedlimit ]

          if pxcor >= expressway-distance [
            die
            stop
          ]
        ] [
          ifelse [pcolor] of patch-here = gray or [pcolor] of patch-ahead 1 = gray [
            ifelse exit-early? [
              die
            ] [
              if random-float 1 < 0.05 [
                set exit-early? true
              ]
            ]
            let car-ahead one-of cars-on patch-ahead 1
            ifelse car-ahead != nobody
            [ slow-down-car car-ahead ]
            [ speed-up-car ] ;; otherwise, speed up
                             ;; don't slow down below speed minimum or speed up beyond speed limit
            if myspeed < speed-min [ set myspeed speed-min ]
            if myspeed > street-speedlimit [
              let max-cruising-random-factor myspeed * (0.10 * (random-float 2 - 1))
              set myspeed street-speedlimit + max-cruising-random-factor
            ]
            if pxcor >= street-distance [
              die
              stop
            ]
          ] [
            die
            stop
          ]
        ]
        let distance-to-move myspeed / 60
        fd distance-to-move
        set distance-travelled distance-travelled + distance-to-move
      ]
      let adjusted-consumption (8.42 / 100) * distance-travelled
      set emissions adjusted-consumption * 2.3 * (1 / 1000)
      set emissions emissions * (1 + (acceleration / 60 * acceleration-factor))
      if myspeed = 0 [
        set emissions emissions + 0.0001843142857
      ]
      set global-emissions global-emissions + emissions
    ] [
      ; Allow cars to proceed if no traffic light
      ifelse [pcolor] of patch-here = blue or [pcolor] of patch-ahead 1 = blue [
        let car-ahead one-of cars-on patch-ahead 1
          ifelse car-ahead != nobody
          [ slow-down-car car-ahead ]
          [ speed-up-car ] ;; otherwise, speed up
          ;; don't slow down below speed minimum or speed up beyond speed limit
          if myspeed < speed-min [ set myspeed speed-min ]
          if myspeed > expressway-speedlimit [ set myspeed expressway-speedlimit ]

          if pxcor >= expressway-distance [
            die
            stop
          ]
      ] [
        ifelse [pcolor] of patch-here = gray or [pcolor] of patch-ahead 1 = gray [
          let car-ahead one-of cars-on patch-ahead 1
            ifelse car-ahead != nobody
            [ slow-down-car car-ahead ]
            [ speed-up-car ] ;; otherwise, speed up
                             ;; don't slow down below speed minimum or speed up beyond speed limit
            if myspeed < speed-min [ set myspeed speed-min ]
            if myspeed > street-speedlimit [ set myspeed street-speedlimit ]
            if pxcor >= street-distance [
              die
              stop
            ]
        ] [
          die
          stop
        ]
      ]
      let distance-to-move myspeed / 60
      fd distance-to-move
      set distance-travelled distance-travelled + distance-to-move
    ]
    let adjusted-consumption (8.42 / 100) * distance-travelled
    set emissions adjusted-consumption * 2.3 * (1 / 1000)
    set emissions emissions * (1 + (acceleration / 60 * acceleration-factor))
    if myspeed = 0 [
      set emissions emissions + 0.0001843142857
    ]
    set global-emissions global-emissions + emissions
  ]

  price-sensitive-spawning

  if remaining-spawns = 0 and count cars = 0 [stop]

  set cumulative-weighted-average-speed-expressway-history lput average-speed-expressway cumulative-weighted-average-speed-expressway-history
  set cumulative-weighted-average-speed-street-history lput average-speed-street cumulative-weighted-average-speed-street-history
  tick
end

to slow-down-car [ car-ahead ] ;; turtle procedure
  ;; slow down so you are driving more slowly than the car ahead of you, allow speed to vary up to -20%
  let percentage 0.2
  let variation percentage * deceleration
  let random-varying-deceleration (random-float 1) * variation
  set myspeed [ myspeed ] of car-ahead - random-varying-deceleration
end

to speed-up-car ;; turtle procedure
  ;; allow speed to increase with variation of 20%
  if pcolor = red and pycor > 0 [
    set myspeed expressway-speedlimit
  ]
  if pcolor = red and pycor < 0 [
    set myspeed street-speedlimit
  ]
  let percentage 0.2
  let variation percentage * acceleration
  let random-factor (random-float 1) * variation
  set myspeed myspeed + random-factor
end

to-report run-fictitious-play
  let old-historical-distn historical-distn
  let history-list cumulative-weighted-average-speed-expressway-history
  let cumulative-weight 0
  if length cumulative-weighted-average-speed-expressway-history > 10 [
    set history-list (sublist cumulative-weighted-average-speed-expressway-history (length cumulative-weighted-average-speed-expressway-history - 10) (length cumulative-weighted-average-speed-expressway-history))
  ]
  foreach history-list [observation ->
    let utility-street ifelse-value average-speed-street = 0 [50] [average-speed-street]
    ; based on data provided by government, each dollar increases speed by 7%
    let formula fp-price-sensitivity * 1.07 * erp-price
    if erp-price = 0 [set formula 1]
    if observation > (utility-street * formula) [
      set cumulative-weight (cumulative-weight + 1)
    ]
  ]
  set historical-distn cumulative-weight / (length history-list)
  ifelse random-float 1 < historical-distn [
    report true
  ] [
    report false
  ]
end

to-report remaining-spawns
  report cars-remaining
end

to-report cars-on-expressway
  report cumulative-expressway-traffic
end

to-report cars-on-street
  report cumulative-street-traffic
end

to-report average-speed-expressway
  let total-cars 0
  let total-speed 0

  ask patches with [pcolor = blue] [
    if any? cars-here [
      set total-speed total-speed + sum [myspeed] of cars-here
      set total-cars total-cars + count cars-here
    ]
  ]
  ifelse total-cars > 0 [
    set last-average-speed-expressway total-speed / total-cars
    report total-speed / total-cars
  ] [
    report last-average-speed-expressway
  ]
end

to-report average-speed-street
  let total-cars 0
  let total-speed 0

  ask patches with [pcolor = gray] [
    if any? cars-here [
      set total-speed total-speed + sum [myspeed] of cars-here
      set total-cars total-cars + count cars-here
    ]
  ]
  ifelse total-cars > 0 [
    set last-average-speed-street total-speed / total-cars
    report total-speed / total-cars
  ] [
    report last-average-speed-street
  ]
end

to-report cumulative-weighted-average-speed-expressway
  if cumulative-weighted-average-speed-expressway-history = 0 [
    report 0
  ]
  let rolling-average mean cumulative-weighted-average-speed-expressway-history
  report rolling-average
end

to-report cumulative-weighted-average-speed-street
  if cumulative-weighted-average-speed-street-history = 0 [
    report 0
  ]
  let rolling-average mean cumulative-weighted-average-speed-street-history
  report rolling-average
end
@#$#@#$#@
GRAPHICS-WINDOW
267
128
887
389
-1
-1
12.0
1
10
1
1
1
0
1
1
1
0
50
-10
10
0
0
1
ticks
30.0

BUTTON
267
72
419
112
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
498
71
649
111
Advance 1 Min
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

BUTTON
720
72
883
110
Run Entire Simulation
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
11
131
217
164
expressway-distance
expressway-distance
1
50
37.0
1
1
km
HORIZONTAL

SLIDER
11
171
218
204
street-distance
street-distance
1
50
37.0
1
1
km
HORIZONTAL

SLIDER
921
128
1093
161
num-cars
num-cars
1
1000
1000.0
1
1
NIL
HORIZONTAL

SLIDER
11
213
218
246
expressway-speedlimit
expressway-speedlimit
0
140
80.0
1
1
km/h
HORIZONTAL

SLIDER
12
254
217
287
street-speedlimit
street-speedlimit
0
100
50.0
1
1
km/h
HORIZONTAL

SLIDER
13
297
217
330
light-duration
light-duration
1
3
1.0
1
1
min
HORIZONTAL

SLIDER
922
255
1095
288
acceleration-factor
acceleration-factor
0
0.1
0.04
0.01
1
NIL
HORIZONTAL

SLIDER
921
168
1093
201
acceleration
acceleration
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
922
210
1094
243
deceleration
deceleration
0
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
608
420
758
465
CO2 Emissions (Tons)
global-emissions
2
1
11

MONITOR
767
420
894
465
Remaining Spawns
remaining-spawns
17
1
11

MONITOR
608
527
770
572
No. of Cars: Expressway
cars-on-expressway
17
1
11

MONITOR
608
473
733
518
No. of Cars: Street
cars-on-street
17
1
11

SLIDER
12
419
218
452
erp-price
erp-price
0
6
6.0
1
1
$
HORIZONTAL

MONITOR
910
605
1145
650
Current Average Speed: Expressway
average-speed-expressway
2
1
11

MONITOR
910
658
1146
703
Current Average Speed: Street
average-speed-street
2
1
11

PLOT
272
606
599
769
Average Speed
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Expressway" 1.0 0 -13345367 true "" "plot average-speed-expressway"
"Street" 1.0 0 -7500403 true "" "plot average-speed-street"

MONITOR
611
607
840
652
Rolling Average Speed: Expressway
cumulative-weighted-average-speed-expressway
2
1
11

MONITOR
611
659
840
704
Rolling Average Speed: Street
cumulative-weighted-average-speed-street
2
1
11

TEXTBOX
10
99
214
118
Environmental Factors
16
0.0
1

PLOT
272
420
599
593
Traffic Flow
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"expressway" 1.0 0 -13345367 true "" "plot cars-on-expressway"
"street" 1.0 0 -7500403 true "" "plot cars-on-street"

TEXTBOX
315
10
851
38
Environmental Effects of ERP Congestion Charges
21
0.0
1

TEXTBOX
922
95
1072
115
Vehicle Settings
16
0.0
1

SLIDER
13
338
217
371
num-traffic-lights
num-traffic-lights
1
20
8.0
1
1
NIL
HORIZONTAL

CHOOSER
922
302
1099
347
decision-strategy
decision-strategy
"fictitious play" "proportional probability"
1

SLIDER
12
378
217
411
green-light-duration-multiplier
green-light-duration-multiplier
0
5
3.0
1
1
x
HORIZONTAL

SLIDER
920
378
1105
411
fp-price-sensitivity
fp-price-sensitivity
0
4
2.1
0.1
1
x
HORIZONTAL

TEXTBOX
920
356
1070
374
Fictitious Play Only
12
0.0
1

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
NetLogo 6.4.0
@#$#@#$#@
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
