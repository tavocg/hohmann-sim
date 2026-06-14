# hohmann-sim

A continuación se presenta bosquejo de lo que debería producir finalmente este
proyecto.

## Título tentativo

Robustez de una transferencia orbital de Hohmann bajo incertidumbre en los
impulsos: simulación numérica y análisis Monte Carlo.

## Idea central

La transferencia de Hohmann es una maniobra orbital idealizada que permite mover
una nave o satélite entre dos órbitas circulares coplanares usando dos impulsos.
En el modelo ideal, se conocen exactamente el radio inicial, el radio final, la
velocidad inicial, la dirección del impulso y la magnitud de cada \(\Delta v\).

En una situación realista, esas cantidades pueden tener errores pequeños por
medición, navegación o ejecución del motor. La idea del proyecto es estudiar
qué tan sensible es la transferencia de Hohmann a esos errores y estimar, por
Monte Carlo, la probabilidad de llegar cerca de la órbita objetivo.

## Aplicación real

La transferencia de Hohmann se usa como modelo base en astronáutica para:

- Subir satélites desde una órbita baja terrestre a una órbita más alta.
- Llevar satélites hacia órbitas geoestacionarias.
- Estimar combustible necesario para cambios orbitales.
- Diseñar maniobras preliminares de misiones interplanetarias, por ejemplo
  Tierra-Marte.
- Comparar la eficiencia energética de diferentes estrategias orbitales.

El proyecto serviría para estudiar una pregunta práctica: si la maniobra ideal
es eficiente, ¿qué tan precisa debe ser su ejecución para que siga siendo útil?

## Problema de investigación

Se quiere simular una transferencia orbital entre una órbita circular inicial
de radio \(r_1\) y una órbita circular final de radio \(r_2\). Primero se
calcula la transferencia ideal de Hohmann. Después se repite la maniobra muchas
veces introduciendo errores aleatorios pequeños en la magnitud o dirección de
los impulsos.

La pregunta principal es:

¿Cuál es la probabilidad de que la nave termine suficientemente cerca de la
órbita objetivo cuando los impulsos tienen incertidumbre?

Preguntas secundarias:

- ¿Qué afecta más el resultado: error en magnitud o error angular?
- ¿Cómo cambia la probabilidad de éxito al aumentar la desviación estándar del
  error?
- ¿Qué tan bien se conserva la energía y el momento angular en la simulación?
- ¿Cuánto se aleja la órbita final de la órbita circular deseada?

## Marco teórico mínimo

### Movimiento gravitatorio

El movimiento se modela con el problema de dos cuerpos reducido a una partícula
de prueba en el campo gravitatorio de un cuerpo central:

\[
\ddot{\mathbf r}=-\frac{GM}{r^3}\mathbf r
\]

donde \(G\) es la constante gravitacional, \(M\) es la masa del cuerpo central y
\(r=|\mathbf r|\).

### Energía y momento angular

En el problema ideal sin perturbaciones, la energía mecánica específica y el
momento angular específico se conservan:

\[
E=\frac{1}{2}v^2-\frac{GM}{r}
\]

\[
\ell=|\mathbf r\times \mathbf v|
\]

Estas cantidades permiten verificar que la integración numérica está
funcionando correctamente.

### Transferencia de Hohmann

Para transferir una nave entre dos órbitas circulares de radios \(r_1\) y
\(r_2\), la órbita de transferencia es una elipse con semieje mayor:

\[
a_t=\frac{r_1+r_2}{2}
\]

La velocidad circular en un radio \(r\) es:

\[
v_c=\sqrt{\frac{GM}{r}}
\]

La velocidad en la elipse de transferencia se obtiene con:

\[
v_t^2=GM\left(\frac{2}{r}-\frac{1}{a_t}\right)
\]

De ahí salen los impulsos ideales:

\[
\Delta v_1=v_{t,p}-v_{c1}
\]

\[
\Delta v_2=v_{c2}-v_{t,a}
\]

El tiempo de vuelo de la transferencia es la mitad del período de la elipse:

\[
T_t=\pi\sqrt{\frac{a_t^3}{GM}}
\]

### Incertidumbre y Monte Carlo

Un error simple en la magnitud del impulso puede modelarse como:

\[
\Delta v_{\text{real}}=\Delta v_{\text{ideal}}+\epsilon
\]

con:

\[
\epsilon\sim \mathcal N(0,\sigma^2)
\]

Después de muchas simulaciones, la probabilidad de éxito se puede estimar como:

\[
P(\text{éxito})\approx
\frac{N_{\text{exitosas}}}{N_{\text{total}}}
\]

## Metodología

### 1. Definir el sistema físico

- Escoger un cuerpo central, por ejemplo la Tierra.
- Definir \(GM\), \(r_1\) y \(r_2\).
- Construir la órbita circular inicial.
- Definir el criterio de éxito, por ejemplo terminar con radio promedio cercano
  a \(r_2\) y excentricidad pequeña.

### 2. Implementar la dinámica orbital

- Resolver numéricamente:

\[
\ddot{\mathbf r}=-\frac{GM}{r^3}\mathbf r
\]

- Usar un integrador como `solve_ivp` o velocity-Verlet.
- Guardar posición, velocidad, energía y momento angular.

### 3. Validar el código

- Simular una órbita circular sin impulsos.
- Verificar que el radio permanezca aproximadamente constante.
- Verificar conservación de energía y momento angular.
- Comparar el período numérico con la ley de Kepler.

### 4. Simular la transferencia ideal

- Calcular \(\Delta v_1\), \(\Delta v_2\) y \(T_t\).
- Aplicar el primer impulso para entrar en la elipse de transferencia.
- Integrar hasta el apoapsis o periapsis final.
- Aplicar el segundo impulso para circularizar.
- Verificar que la órbita final se acerque a \(r_2\).

### 5. Agregar incertidumbre

Repetir la transferencia muchas veces, pero perturbando los impulsos:

- Error en magnitud de \(\Delta v_1\).
- Error en magnitud de \(\Delta v_2\).
- Error angular pequeño en la dirección del impulso.
- Opcionalmente, error en la posición o velocidad inicial.

### 6. Analizar resultados

- Calcular radio final, energía final, excentricidad y error respecto a la
  órbita objetivo.
- Estimar la probabilidad de éxito.
- Hacer histogramas de errores finales.
- Comparar sensibilidad ante distintos valores de \(\sigma\).
- Identificar cuál fuente de error afecta más la transferencia.

## Resultados esperados

### Resultados numéricos

- Trayectoria de la órbita inicial, elipse de transferencia y órbita final.
- Comparación entre transferencia ideal y transferencias perturbadas.
- Conservación aproximada de energía y momento angular durante tramos sin
  impulsos.
- Histogramas del radio final y la excentricidad final.
- Curva de probabilidad de éxito contra tamaño del error.

### Discusión esperada

El análisis debería mostrar que la transferencia de Hohmann es eficiente en el
caso ideal, pero que su éxito depende de la precisión con que se ejecutan los
impulsos. Un error pequeño puede producir una órbita final elíptica, un radio
incorrecto o la necesidad de maniobras de corrección.

## Estructura base del trabajo escrito

### 1. Introducción

Presentar la motivación aeroespacial del problema, explicar qué es una
transferencia orbital y por qué la transferencia de Hohmann es importante como
aproximación inicial.

### 2. Marco teórico

Incluir el problema de dos cuerpos, movimiento bajo fuerza central, energía,
momento angular, órbitas circulares, órbitas elípticas, transferencia de
Hohmann e incertidumbre modelada con variables aleatorias.

### 3. Descripción del problema

Definir claramente \(r_1\), \(r_2\), el cuerpo central, las condiciones
iniciales, los impulsos ideales y el tipo de errores que se van a estudiar.

### 4. Descripción de la solución numérica

Explicar el integrador usado, las variables de estado, cómo se aplican los
impulsos, cómo se valida el código y cómo se ejecutan las simulaciones Monte
Carlo.

### 5. Código

Organizar el código en funciones:

- `aceleracion_gravitatoria`
- `energia`
- `momento_angular`
- `calcular_hohmann`
- `integrar_orbita`
- `aplicar_impulso`
- `simular_transferencia`
- `simular_monte_carlo`

### 6. Resultados

Presentar gráficas de órbitas, errores de conservación, histogramas,
probabilidad de éxito y comparación entre diferentes niveles de incertidumbre.

### 7. Discusión y alcances

Discutir qué tan robusta es la transferencia, cuáles errores dominan, qué
limitaciones tiene el modelo y qué efectos reales quedaron fuera.

Posibles limitaciones:

- No se incluye atmósfera.
- No se incluyen perturbaciones de otros cuerpos.
- Se usan impulsos instantáneos.
- Se asumen órbitas coplanares.
- Se desprecia el consumo continuo de combustible.

### 8. Conclusiones

Resumir qué se aprendió sobre la transferencia ideal y sobre la sensibilidad a
errores pequeños. Concluir si Monte Carlo fue útil para estimar la confiabilidad
de la maniobra.

## Posibles extensiones

- Agregar arrastre atmosférico en órbitas bajas.
- Comparar Hohmann con otra estrategia de transferencia.
- Estimar combustible extra necesario para correcciones.
- Incluir errores simultáneos en posición, velocidad y dirección.
- Estudiar una transferencia tipo Tierra-Marte con unidades astronómicas.
