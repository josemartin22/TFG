; GIS Reshaper online: https://mapshaper.org/

extensions [ gis rnd ]

globals [
  provinces-dataset
  provinces
  showing-labels
  node-diameter
  anthill
  ; Best visited route
  best-route
  best-route-cost
]

breed [province-labels province-label]
breed [nodes node]

; Each ant keep information about the visited route
; and its cost
breed [ants ant]
ants-own [
  route
  cost
]

; Edges are represented by links between nodes. Each one keep
; information about its lenght and level of pheromone deposited by ants
links-own [
  edge-cost
  pheromone-level
]


to setup
  clear-all
  random-seed 123456789

  setup-background
  setup-edges
  setup-anthill
  setup-ants

  ; Random initial best known solution
  set best-route generate-random-route
  set best-route-cost (calculate-cost-of-route best-route)

  update-display
  update-best-route
  reset-ticks
end


to setup-background

  ask patches [set pcolor white]
  ; Load coodinates system
  gis:load-coordinate-system "data/provincias-espanolas.prj"

  ; Load datasets
  set provinces-dataset gis:load-dataset "data/provincias-espanolas.shp"
  gis:set-world-envelope-ds (gis:envelope-of provinces-dataset)

  display-provinces
end


to display-provinces

  ; Clean previously labels
  ask province-labels [ die ]
  ; Set color and thickness of limits between provinces
  gis:set-drawing-color [0 0 0 100]
  gis:draw provinces-dataset 0.5

  ; Select a subset of all provinces
  set provinces (n-of num-provinces gis:feature-list-of provinces-dataset)

  foreach provinces [
    vector-feature ->
    let centroid gis:location-of gis:centroid-of vector-feature
    if not empty? centroid
    [
        ; To save the centroid location of each province
        let xcoor 0
        let ycoor 0

      create-province-labels 1 [
        set size 0
        ; Add 2 and 1 to avoid label overlapping with centroid
        set xcor 2 + item 0 centroid
        set ycor 1 + item 1 centroid
        set xcoor xcor - 2
        set ycoor ycor - 1

        ; Labeled provinces option
        if-else label-provinces [
          set label gis:property-value vector-feature "TEXTO"
          set label-color [0 0 100 150]
          set showing-labels true
        ]
        [set showing-labels false]
      ]
      create-city xcoor ycoor
    ]
  ]
end


to create-city [xcoor ycoor]
  ; Properties of each node
  set node-diameter 1
  set-default-shape nodes "circle"

  ask patch xcoor ycoor [
    sprout-nodes 1 [
      set color red
      set size node-diameter
    ]
  ]
end


to setup-edges
  ask nodes [
  ; Create links between nodes and set the cost and initial pheromone level
    create-links-with other nodes [
      set edge-cost link-length
      set pheromone-level random-float 0.05
      hide-link
    ]
  ]
  ; Normalize by the highest edge length
  ;let highest-cost (max [edge-cost] of links)
  ;ask links [set edge-cost (edge-cost / highest-cost)]
end


to setup-anthill
  ; Create the anthill (house) of the ants
  set anthill one-of nodes
  ask anthill [set shape "house" set size 3 set color brown]
end


to setup-ants
  ; Create ants at the anthill
  create-ants ants-population-size [
    setxy [xcor] of anthill [ycor] of anthill
    set shape "ant"
    set color brown
    set size 2
    ; empty route at the beginning
    set route []
    set cost 0
  ]
end


; Main procedure
to go
  ; ACO Algorithm
  ask ants [
    ; Each ant find a route and compair with the best known route
    set route find-route
    set cost calculate-cost-of-route route

    if cost < best-route-cost [
      set best-route-cost cost
      set best-route route
      update-best-route
    ]
  ]
  if show-ants [
    ask-concurrent ants [travel-route route]
  ]
  update-pheromone
  update-display
  tick
end


; Procedure to re-setup the present state of the model
to reset
  ask links [
    hide-link
    set pheromone-level random-float 0.05
  ]

  ask ants [die]
  setup-ants
  set best-route generate-random-route
  set best-route-cost (calculate-cost-of-route best-route)

  reset-ticks
  update-best-route
  update-display
  clear-all-plots
end


; Procedure to generate a random circuit (route)
to-report generate-random-route
  ; Reorganizate the rest of nodes randomly
  let list-nodes nodes with [self != anthill]
  set list-nodes [self] of list-nodes
  let random-route (shuffle list-nodes)

  ; Close the route through anthill (last one with first one)
  set random-route fput anthill random-route
  set random-route (lput anthill random-route)

  report random-route
end


; Procedure to find a circuit (route) that crosses every node
to-report find-route
  ; The anthill it's the first and last node to visit
  let new-route (list anthill)
  let remainder-nodes nodes with [self != anthill]
  let current anthill

  while [any? remainder-nodes]
  [
    ; https://ccl.northwestern.edu/netlogo/docs/rnd.html#rnd:weighted-one-of
    let next-node rnd:weighted-one-of remainder-nodes [weight-to-node current]
    set new-route (lput next-node new-route)

    ; We extract the next node to visit
    set remainder-nodes remainder-nodes with [self != next-node]
    set current next-node
  ]
  ; Close the route with the anthill to create a circuit
  set new-route (lput anthill new-route)

  report new-route
end


; Calculate the length of a route
to-report calculate-cost-of-route [given-route]
  let route-cost 0
  set route-cost (sum [edge-cost] of (get-edges given-route))
  report route-cost
end


; Node (turtle) procedure to calculate the edge cost between them
to-report weight-to-node [given-node]

  ; Localization of the edge
  let edge (link ([who] of self) ([who] of given-node))

  ; Calculate the nominator of the edge selection probability by the ant
  let p [pheromone-level] of edge
  let c [edge-cost] of edge
  ; Weight is the product of pheromone with visibility
  let weight (p ^ alpha) * ((1 / c) ^ beta)

  report weight
end


; Updates the world view
to update-display

  ; Show provinces labeled
  if (label-provinces and not showing-labels)[
    foreach provinces [
      vector-feature -> let centroid gis:location-of gis:centroid-of vector-feature

      create-province-labels 1 [
        set size 0
        ; Add 2 and 1 to avoid label overlapping with centroid
        set xcor 2 + item 0 centroid
        set ycor 1 + item 1 centroid
        set label gis:property-value vector-feature "TEXTO"
        set label-color [0 0 100 150]
      ]
    ]
    set showing-labels true
  ]
  if (not label-provinces and showing-labels)[
    ask province-labels [die]
    set showing-labels false
  ]

  ; Show pheromone level over edges
  if-else show-pheromone [
    let max-pheromone max [pheromone-level] of links
    ; Normalizate over the max value of pheromone
    ask links [
      show-link
      set thickness (pheromone-level / max-pheromone)
      set color lput (255 * pheromone-level / max-pheromone) [0 0 255]
    ]
  ]
  [update-best-route]

end

; Show best known route at the world view
to update-best-route
  ; Show best known route
  ask links [hide-link]

  let best-route-edges (get-edges best-route)
  ask best-route-edges [
    show-link
    set color red
    set thickness 0.2
  ]
end

; Procedure to update the level of pheromone at each edge
to update-pheromone
  ; Evaporate the pheromone of each edge and update the level of pheromone
  ; of the edges visited by ants
  ask links [set pheromone-level (pheromone-level * (1 - rho))]
  ask ants [
    let route-cost cost
    ask (get-edges route) [
      set pheromone-level (pheromone-level + (100 / route-cost))
    ]
  ]
end

; Procedure that reports all edges that composes a route
to-report get-edges [given-route]
  ; We conect each node with the next-one node of the given route
  let desplaced-route (lput (first given-route) (but-first given-route))
  report link-set (map [[n1 n2] -> (link ([who] of n1) ([who] of n2))] given-route desplaced-route)
end


; Procedure to visualizate ants travelling
to travel-route [city]
  ; We remove the first one (anthill)
  let to-visit (remove-item 0 city)
  let next item 0 to-visit

  ; Visit each city
  while [not empty? to-visit] [
    face next

    ; Walk till the next node
    while [distance next >= 0.05] [fd 0.015]
    set to-visit (remove-item 0 to-visit)
    if not empty? to-visit
      [set next item 0 to-visit]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
44
162
807
776
-1
-1
6.24
1
10
1
1
1
0
0
0
1
-60
60
-48
48
0
0
1
ticks
60.0

BUTTON
32
19
114
52
setup
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

SWITCH
122
20
287
53
label-provinces
label-provinces
0
1
-1000

SLIDER
403
23
576
56
ants-population-size
ants-population-size
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
300
21
392
54
alpha
alpha
0
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
300
58
393
91
beta
beta
0
20
3.0
1
1
NIL
HORIZONTAL

SLIDER
300
96
394
129
rho
rho
0
0.99
0.25
0.01
1
NIL
HORIZONTAL

BUTTON
34
97
115
145
go
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

SWITCH
122
58
288
91
show-pheromone
show-pheromone
1
1
-1000

SLIDER
404
61
577
94
num-provinces
num-provinces
2
47
32.0
1
1
NIL
HORIZONTAL

BUTTON
33
58
114
91
reset
reset
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
476
110
578
155
Best Route
best-route-cost
2
1
11

PLOT
586
16
817
157
Route Cost
Time
Cost
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"best" 1.0 0 -2674135 true "" "plot min [cost] of ants"
"avg" 1.0 0 -12087248 true "" "plot mean [cost] of ants"
"worst" 1.0 0 -13345367 true "" "plot max [cost] of ants"

SWITCH
122
97
288
130
show-ants
show-ants
0
1
-1000

@#$#@#$#@
## ¿ QUÉ ES ?

**Ant Colony Optimization** es una técnica o método en informática inspirada en el comportamiento de las hormigas en la búsqueda de comida. Esta técnica fue propuesta por M. Dorigo en 1992 [1]. Puede aplicarse para resolver cualquier problema de optimización que pueda ser reducido a encontrar rutas mínimas a través de grafos.

Hay una población de agentes llamados hormigas que construyen iterativamente una posible solución para nuestro problema combinatorio. Usan el entorno para intercambiar información entre sí depositando feromonas.
![aco-schema](images/ACO-schema.png)

Suelen comenzar con una solución vacía y luego van agregando componentes para nuestra solución hasta que la solución candidata es completada.

Una vez que se genera la solución, las hormigas dan su feedback sobre las soluciones que construyeron depositando una cantidad de feromona en cada una de las componentes (tramos del camino) que eligieron para construir su solución. Aquellas componentes que son comunes en buenas soluciones acumularán más feromonas y es más probable que las hormigas los utilicen en la próxima iteración

También incluye un mecanismo para simular la evaporación real de feromonas que evita elegir caminos más largos y atascarse en óptimos locales.

Muchos problemas reales, como problema de enrutamiento de vehículos o de redes de Internet, se resuelven utilizando estos algoritmos.
En este modelo, trato de ilustrar el uso de ACO resolviendo el conocido problema TSP: **Traveling Salesman Problem**:

![aco-tsp](images/ACO-TSP.png)

El problema TSP se puede representar mediante un grafo G = (N, A) con N nodos (en este caso, las capitales de provincia de España) y A. el conjunto de arcos que conectan cada nodo con el resto de ellos. El TSP se reduce a resolver el problema de encontrar el circuito hamiltoniano más corto que visite cada nodo exactamente una vez.

Casi todas las diferentes versiones de algoritmos ACO se prueban con TSP (veer [2]) porque es un problema bien conocido (fácil de entender para todos) y puede su complejidad aumenta a medida que crece el número de nodos (este es un problema NP-completo).


## COMO FUNCIONA

**Algorithm** (pseudocódigo general) [3]:

```
Inicializamos cada arco con una cantidad inicial de feromona
Creamos una población de hormigas
Repetimos hasta el criterio de parada:
	Para cada hormiga:
		Construimos una solución usando las feromonas y el coste de los arcos
	Para cada hormiga:
		Depositamos feromonas en aquellos arcos incluidos en la solución
	Esquema de evaporación global de la feromona
Devolvemos la mejor solución encontrada
```


**Selección de la arista** [4]:

Cada hormiga construye una solución candidata en cada iteración. La hormiga *k* hace una elección en cada nodo de acuerdo con la **probabilidad** asociada con cada nodo dependiendo de la cantidad de feromona y de la longitud o costo de ésta (es decir, la distancia desde el nodo actual *x* al siguiente *y*, donde el nodo *y* aún no se ha visitado).

![prob-selection](images/ACO-prob-selection.png)

Alfa es un parámetro para controlar la influencia de la cantidad de feromona depositada desde el nodo x al nodo y.
Beta es un parámetro para controlar la influencia de la visibilidad del nodo y desde x.
La ** visibilidad ** se calcula como la inversa de la distancia de x a y. 


**Actualizción de la feromona** [4]:

Las aristas se actualizan cuando todas las hormigas han construido su solución adecuada. Cada hormiga deposita una cantidad de feromona en aquellas aristas (componentes) que están incluidas en su solución. También se suele adoptar un mecanismo de evaporación para evitar trayectos más largos y permitir que esos trayectos más cortos acumulen más feromonas.

Un esquema flobal de actualización de feromona es:

![pheromone-1](images/ACO-pheromone-update1.png)

Rho es un parámetro que indica el coeficiente de evaporación de las feromonas.
El último término de la suma es la cantidad de feromona depositada por la k-ésima hormiga
para la componente que conecta los nodos x e y. Se calcula de la siguiente forma:

![pheromone-2](images/ACO-pheromone-update2.png)

donde Lk es el costo o la longitud de la ruta de la k-ésima hormiga y Q es una constante (en este modelo consideramos Q = 100). 


## COMO USARLO

Presione el botón SETUP para crear una solución aleatoria para los respectivos números de provincias (nodos).

Presione el botón RESET para restablecer toda la configuración inicial de las aristas (también destruye todas las hormigas y limpia los gráficos). Este botón permite al usuario ejecutar varias pruebas con la misma topología de grafo pero con diferente inicialización.

Presione el botón GO para iniciar la simulación del modelo.

=== Parámetros ===

El deslizador ANTS-POPULATION-SIZE controla el número de hormigas de nuestra población.

El deslizador NUM-PROVINCES controla el número de nodos (capitales de provincias) que vamos a considerar para construir la solución. Observe que la ubicación del nodo capital es el centro de la provincia y no la ubicación real.

El deslizador ALPHA controla la influencia de la feromona sobre las hormigas a la hora de seleccionar una nueva componente para la solución,.

El deslizador BETA controla la influencia de la heurística de visibilidad sobre las hormigas a la hora de seleccionar una nueva componente para la solución (como de greedys queremos que sean las hormigas).

El deslizador RHO controla el valor del parámetro de tasa de evaporación global de la feromona.

El interruptor LABEL-PROVINCES permite visualizar el nombre de cada capital (nodo).

El interruptor SHOW-PHEROMONE permite visualizar la cantidad / nivel de feromona que las hormigas depositan en cada arista. Habrá más feromonas en una arista que es más gruesa y menos feromona en una arista que sea más translúcida que otra.

El interruptor SHOW-ANTS permite visualizar las hormigas recorriendo las rutas encontradas por cada una de ellas. Cuando todas las hormigas llegan al hormiguero (todas han construido su solución) se aplica el esquema de actualización global de las feromonas.


## COSAS A TENER EN CUENTA

En el modelo, hay un gráfico para mostrar cómo se está desempeñando el rendimiento del algoritmo ACO. El gráfico "Costo de ruta" muestra el costo de las mejores y peores soluciones, así como un promedio de las mismas en cada iteración.

También hay un monitor que especifica el valor de la ruta mejor fundada.

## COSAS A PROBAR

Podemos intentar cambiar el valor de los parámetros alfa y beta, estableciendo un valor de cero a cada uno de estos para ver cómo influye en el rendimiento. Si el valor de alfa es 0, el algoritmo debería comportarse como un greedy porque no estamos tomando en cuenta la información de feromonas.

También podemos intentar cambiar el valor del parámetro rho y visualizar el nivel de feromonas sobre el mapa, para ver cómo puede ayudar a que la feromona permanezca más tiempo o se evapore más rápidamente.


## AMPLIACIÓN DEL MODELO

xisten muchas variantes para mejorar la eficiencia del algoritmo ACO inicial, las más populares son:

- **Versión elitista**: Únicamente la/s mejor/es solucion/es deposita/n una cantidad de feromonas en sus caminos en cada iteración.

- **Rank Ant System**: las soluciones se clasifican según su coste o longitud. Cada hormiga deposita una cantidad de feromona proporcional a la bondad de su solución.

- **Max-Min Ant System**: Controla el máximo y el mínimo de feromonas en cada arco. Solo la mejor solución global puede agregar feromonas.

- **Colony System**: La ejecución del algoritmo no está sincronizada. Las hormigas que ya han construido su solución pueden poner en marcha otra sin tener que esperar al resto de hormigas.

## CARACTERÍSTICAS DE NETLOGO

Usando la extensión rnd, agregamos la capacidad de hacer una selección de rueda de ruleta. Lo usamos en la siguiente línea de código:

```
extensions [ rnd ]

let next-node rnd:weighted-one-of remainder-nodes [weight-to-node current]
```

Un agente de 'remainder-nodes' será elegido proporcionalmente al peso (costo del nodo actual) que devuelve la función 'weight-to-node' desde el nodo actual 'current'.


## CREDITOS

Este modelo es una implementación de la optimización por colonia de hormigas (ACO) para el problema del vendedor ambulante (TSP) utilizando datos GIS de las provincias de España.

Forma parte del proyecto fin de grado (TFG) de Jose A. Martín Melguizo, dirigido por Rocio Romero Zaliz en la Universidad de Granada (UGR)

Granada, 15 de mayo de 2021



This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

![CC BY-NC-SA 4.0](https://licensebuttons.net/l/by-nc-sa/3.0/88x31.png)


## REFERENCIAS

- [1] Dorigo, M., Maniezzo, V., and Colorni, A., The Ant System: Optimization by a colony of cooperating agents. IEEE Transactions on Systems, Man, and Cybernetics Part B: Cybernetics, Vol. 26, No. 1. (1996), pp. 29-41.

- [2] Roach, Christopher (2007). NetLogo Ant System model. Computer Vision and Bio-inspired Computing Laboratory, Florida Institute of Technology, Melbourne, FL.

- [3] https://www.cs.us.es/~fsancho/?e=71

- [4] https://en.wikipedia.org/wiki/Ant_colony_optimization_algorithms
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

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
NetLogo 6.2.0
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
