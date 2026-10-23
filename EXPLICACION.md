# Cómo funciona el código del mockup

Guía para principiantes. Cada término se explica la primera vez que aparece.

---

## 1. Lo básico: con qué está hecho

- **Swift**: el lenguaje de programación de Apple para iPhone, Mac, Apple Watch, etc.
- **SwiftUI**: una herramienta (framework) de Apple para dibujar pantallas con Swift. En lugar de arrastrar botones, **describes con código cómo se ve la pantalla** y SwiftUI la dibuja.
  - *Framework* = un paquete de código ya hecho que te da herramientas listas para usar.
- **Xcode**: el programa donde escribes el código y corres la app.
- **Simulador**: un iPhone falso dentro de la Mac para probar la app.
- **Mockup**: una maqueta. Se ve y se navega como la app real, pero **los datos son de ejemplo** (no hay servidor, ni base de datos, ni inteligencia artificial real).

> Frase para la expo: *"Es un prototipo navegable hecho en SwiftUI con datos de ejemplo. La lógica real (servidor, IA, envío a Cruz Roja) sería la siguiente etapa."*

---

## 2. Los archivos del proyecto

Todo el código está en la carpeta `CruzRoja/`. Cada archivo `.swift` es una parte de la app:

| Archivo | Qué hace |
|---|---|
| `CruzRojaApp.swift` | El punto de arranque de la app. Es lo primero que se ejecuta. |
| `ContentView.swift` | La barra de abajo con las 5 pestañas. |
| `Datos.swift` | Los datos de ejemplo, el color rojo y los "moldes" (structs/clases). |
| `EmergenciaView.swift` | Pantalla de inicio con el mapa y el botón rojo + la cuenta regresiva. |
| `ReporteView.swift` | El formulario del reporte. |
| `ResumenView.swift` | El resumen y el seguimiento de la ambulancia. |
| `PrimerosAuxiliosView.swift` | Instrucciones paso a paso con voz. |
| `AprendeView.swift` | Lista de videos y la pantalla del video. |
| `PerfilView.swift` | Perfil médico con código QR. |
| `LoginView.swift` | La pantalla para iniciar sesión. |
| `FamiliaView.swift` | Alerta de mamá, lista de familia y mapa. |
| `AlertasView.swift` | Alertas de Protección Civil y reportes de vecinos. |

En SwiftUI se acostumbra que cada pantalla termine en **`View`** (vista = pantalla o pedazo de pantalla).

---

## 3. Conceptos de Swift que usamos

### Variables y constantes: `var` y `let`
- `let` = **constante**, un valor que no cambia. Ej: `let direccion = "Av. Eugenio Garza Sada..."`
- `var` = **variable**, un valor que sí puede cambiar. Ej: `var lesionados = 1`

### Tipos de datos
Swift necesita saber qué tipo de dato es cada cosa:
- `String` = texto (`"Caída en casa"`)
- `Int` = número entero (`1`, `6`)
- `Double` = número con decimales (`25.6516`)
- `Bool` = verdadero o falso (`true` / `false`). Ej: `var enviado = false`
- **Arreglo** (`[ ]`) = una lista. Ej: `["Alerta", "Confundido", "Inconsciente"]`

### Opcionales: el signo `?`
Un **opcional** es un valor que **puede existir o no** (estar vacío = `nil`).
En `Reporte` tenemos `var nombre: String? = nil` → si el reporte es "para mí", no hay nombre; si es "por mamá", el nombre es `"Mamá"`.

### Funciones: `func`
Un bloque de código con nombre que haces correr cuando quieras.
Ej: `func dictar()` llena el reporte con el texto de ejemplo cuando presionas "Dictar".

### Closures
Una **función sin nombre** que se pasa como si fuera un dato. La ves en los botones:
```swift
Button("Confirmar") {
    r.confirmado = true   // ← esto es un closure: lo que pasa al tocar el botón
}
```

### `struct` vs `class` (pregunta muy probable)

Las dos son **moldes** para crear cosas (como un molde de galletas). Cada "galleta" que sale del molde es una **instancia**.

| | `struct` (estructura) | `class` (clase) |
|---|---|---|
| Cómo se copia | Al pasarla a otro lado se hace **una copia**. Cambiar la copia no cambia la original. | Al pasarla a otro lado se pasa **la misma**. Todos ven los cambios. |
| Analogía | Fotocopia de un documento | Documento compartido de Google Docs |
| Tipo técnico | Tipo **por valor** | Tipo **por referencia** |
| En SwiftUI | Todas las pantallas (`View`) son struct | Datos que comparten varias pantallas |

**Dónde usamos cada una:**
- **struct**: todas las pantallas (`EmergenciaView`, `ReporteView`...) y los datos simples: `Familiar`, `Leccion`, `ReporteVecinal`.
- **class**: solo `Reporte` (en `Datos.swift`). ¿Por qué? Porque **el mismo reporte** lo llenas en una pantalla (Reporte) y se muestra en otra (Resumen). Si fuera struct, cada pantalla tendría su propia copia y el resumen saldría vacío.

> Respuesta corta: *"Las pantallas y datos simples son struct porque son ligeros y seguros. El reporte es class porque varias pantallas necesitan compartir y modificar el mismo objeto."*

### `enum` (enumeración)
Una lista cerrada de opciones posibles.
```swift
enum Tab { case emergencia, familia, alertas, aprende, perfil }
enum Pantalla { case reporte, resumen, auxilios }
```
Sirve para no equivocarse escribiendo texto: solo existen esas opciones.

### Protocolos
Un **protocolo** es como un contrato: "si dices que eres X, debes cumplir estas reglas".
- `View`: "soy algo que se puede dibujar" → obliga a tener un `body`.
- `Identifiable`: "tengo un `id` único" → para que las listas sepan distinguir cada fila.
- `Hashable`: "me puedo comparar y guardar en listas de navegación".

Ej: `struct Familiar: Identifiable` = "Familiar es un molde que cumple el contrato Identifiable".

### `extension`
Le agrega cosas a algo que ya existe. Ej: en `Datos.swift` agregamos `Color.rojo` al tipo `Color` de Apple, y `Font.marca()` para la tipografía Helvetica Bold. Así en cualquier archivo escribes `Color.rojo` en vez del código del color cada vez.

---

## 4. Conceptos de SwiftUI

### Cómo se ve una pantalla
```swift
struct AlertasView: View {      // un struct que cumple el protocolo View
    var body: some View {       // body = "lo que se dibuja"
        Text("Hola")            // un texto en pantalla
    }
}
```
Toda pantalla tiene un **`body`**. Ahí describes qué se ve.

### Modificadores
Son los `.algo()` que van después de un elemento y le cambian el estilo:
```swift
Text("Reportar emergencia")
    .font(.marca(24))          // tamaño y tipo de letra
    .foregroundStyle(.white)   // color del texto
```

### Contenedores (cómo se acomodan las cosas)
- `VStack` = uno **debajo** del otro (vertical).
- `HStack` = uno **al lado** del otro (horizontal).
- `ZStack` = uno **encima** del otro (capas).
- `Spacer()` = un espacio flexible que empuja las cosas.
- `ScrollView` = permite deslizar si no cabe.
- `List` / `Form` / `Section` = las listas con tarjetas blancas típicas de iPhone (como en Ajustes).

### Navegación
- `TabView` = la barra de pestañas de abajo (`ContentView.swift`).
- `NavigationStack` = una "pila" de pantallas: entras a una y aparece la flecha para regresar.
- `NavigationLink` = el botón que te lleva a la siguiente pantalla.
- `.sheet` = una ventana que sale desde abajo (el login, "Reportar algo en mi zona").
- `.fullScreenCover` = ventana a pantalla completa (la cuenta regresiva).
- `.alert` = el aviso de confirmación "¿Reportar una emergencia?".

### Estado (lo más importante de SwiftUI)
**Estado** = datos que pueden cambiar mientras usas la app. Cuando el estado cambia, **SwiftUI redibuja la pantalla sola**. Se marcan con palabras que empiezan con `@`, llamadas **property wrappers** (envoltorios que le dan superpoderes a una variable):

| Wrapper | Para qué | Ejemplo en la app |
|---|---|---|
| `@State` | Un dato que pertenece a una sola pantalla | `@State var segundos = 5` en la cuenta regresiva |
| `@Observable` | Se pone sobre una **clase** para que las pantallas se enteren cuando cambia | `@Observable class Reporte` |
| `@Bindable` | Permite que un campo de texto **escriba directo** en esa clase | `TextField(..., text: $reporte.motivo)` |
| `@AppStorage` | Un dato que **se guarda en el teléfono** aunque cierres la app | `@AppStorage("sesion")` → si iniciaste sesión |
| `@Environment` | Toma algo que da el sistema | `@Environment(\.dismiss)` → la acción de cerrar una ventana |
| `@FocusState` | Qué campo de texto tiene el cursor | En el login, pasar de correo a contraseña |

**El signo `$`**: `$reporte.motivo` significa "conexión de ida y vuelta" (**binding**). El campo de texto muestra el valor **y** lo cambia cuando escribes.

### `#Preview`
Al final de cada archivo hay un `#Preview { ... }`. Sirve para ver la pantalla en Xcode (panel derecho, el *Canvas*) **sin correr toda la app**.

---

## 5. Pantalla por pantalla

### Arranque (`CruzRojaApp.swift` y `ContentView.swift`)
- `@main` marca el punto de entrada: aquí empieza la app.
- En `init()` cambiamos la letra de los títulos a **Helvetica Bold** (la del manual de identidad).
- `ContentView` crea el `TabView` con 5 pestañas. Cada pestaña tiene un ícono de **SF Symbols** (la biblioteca de íconos gratis de Apple, ej. `"bell"`, `"person.2"`).
- `.tint(Color.rojo)` pinta de rojo lo que está seleccionado.

### Emergencia (`EmergenciaView.swift`)
- **Mapa**: usamos **MapKit** (el framework de mapas de Apple) con una coordenada fija en el Tec. `Marker` es el pin "Tú".
- **Botón rojo**: no es un botón normal, usa `.onLongPressGesture(minimumDuration: 3)` = **"mantener presionado 3 segundos"**. Mientras lo presionas, una capa oscura crece de izquierda a derecha (animación).
- Al terminar los 3 s → sale un `.alert` para confirmar → luego la **cuenta regresiva**.
- **Cuenta regresiva** (`CuentaRegresivaView`): un ciclo `while` que espera 1 segundo (`Task.sleep`) y resta 1 hasta llegar a 0. Si presionas Cancelar, se cierra.
  - `Task` = un trabajo que corre "en segundo plano" sin congelar la pantalla.
- Al llegar a 0, la app navega al reporte.

### Reporte (`ReporteView.swift`)
- Es un `Form` (formulario) con secciones.
- `Picker` con estilo `.segmented` = los botones de opciones juntos (Alerta / Confundido / Inconsciente).
- `Stepper` = el control de **– / +** para el número de lesionados.
- **"Dictar"**: es falso. Espera 1.5 segundos (para simular que escucha) y llama a `reporte.dictar()`, que llena los campos con el ejemplo del brief.
- Escribe directo en el objeto `Reporte` (la clase compartida).

### Resumen y seguimiento (`ResumenView.swift`)
- Lee el **mismo** `Reporte` y muestra cada dato con `LabeledContent` (etiqueta a la izquierda, valor a la derecha).
- Botón "Enviar a Cruz Roja": cambia `reporte.enviado = true`. Como el estado cambió, la pantalla se redibuja y aparece el seguimiento (Recibido → Unidad asignada → En camino). Todo es texto fijo.
- `if reporte.enviado { ... }` = **condición**: solo muestra eso si ya se envió.

### Primeros auxilios (`PrimerosAuxiliosView.swift`)
- Un arreglo con 4 textos (los pasos) y una variable `paso` que dice en cuál vas.
- Anterior / Siguiente suman o restan 1 a `paso`.
- `ProgressView` = la barra roja de progreso.
- **Voz**: usamos **AVFoundation** (framework de audio de Apple) con `AVSpeechSynthesizer`, que **lee texto en voz alta** con acento de México (`"es-MX"`).

### Aprende (`AprendeView.swift`)
- `List` recorre el arreglo `lecciones` y dibuja una fila por cada una.
- Las miniaturas son rectángulos grises con un ícono de "play" (placeholder = relleno temporal).
- El "reproductor" es falso: un rectángulo gris + un `Slider` (barra deslizable).

### Perfil y login (`PerfilView.swift`, `LoginView.swift`)
- Siempre muestra el perfil médico. Arriba hay una fila "Inicia sesión o regístrate".
- `@AppStorage("sesion")` guarda si iniciaste sesión (true/false). Con eso decidimos qué mostrar (`if sesion { ... } else { ... }`).
- El login se abre como `.sheet`. Es falso: cualquier correo entra después de 1 segundo.
- **Código QR**: usamos **CoreImage** (framework de Apple para procesar imágenes), que tiene un generador de QR incluido (`CIFilter.qrCodeGenerator()`). Le das un texto y te devuelve la imagen.

### Familia (`FamiliaView.swift`)
- Tarjeta de alerta de mamá con dos botones.
- "Reportar por ella" abre el **mismo** formulario de reporte, pero con un `Reporte` que ya tiene el nombre "Mamá" y el motivo "Ritmo cardiaco anormal". Así **reusamos** la pantalla en lugar de hacer otra.
- `ForEach(familia)` recorre la lista de familiares y dibuja una fila por cada uno (rojo si tiene alerta, gris si no).
- Mapa con un pin por familiar.

### Alertas (`AlertasView.swift`)
- Una tarjeta fija de Protección Civil.
- Reportes de vecinos guardados en un `@State` (lista). Al tocar "Confirmar", el contador sube +1 y el botón cambia a "Confirmado".
- "Reportar algo en mi zona" abre un pequeño formulario en `.sheet`.

---

## 6. Cosas extra que te pueden preguntar

**¿Cómo pasan los datos de una pantalla a otra?**
El `Reporte` se crea una vez en `EmergenciaView` y se le pasa a `ReporteView` y `ResumenView`. Como es una **clase** con `@Observable`, las dos pantallas ven el mismo objeto y se actualizan solas.

**¿Por qué los datos son falsos?**
Porque es un mockup. Los datos están **hardcodeados** (escritos directo en el código) en `Datos.swift` y en cada pantalla.

**¿Qué faltaría para que fuera real?**
- Un **servidor/backend** (computadora en internet) que reciba los reportes y los mande a la central de Cruz Roja.
- **Ubicación real** con CoreLocation (el GPS del teléfono) en lugar de una coordenada fija.
- **Reconocimiento de voz real** (framework Speech) para "Dictar".
- **Login real** (por ejemplo con número de teléfono verificado por SMS).
- Notificaciones y conexión con el Apple Watch.

**¿Qué es `-demo`?**
Un truco que pusimos para las capturas: si abres la app con `-demo familia`, arranca directo en esa pantalla. Normalmente no se usa; la app abre en Emergencia.

**¿Por qué no aparece la cruz de Cruz Roja?**
El manual de identidad prohíbe imitar el emblema. Usamos su **color oficial** (rojo PMS 485 = RGB 238, 20, 10), el negro y la **tipografía Helvetica Bold**, que vienen del manual.

**¿Funciona en Android?**
No. SwiftUI es solo para dispositivos Apple. Para Android se tendría que hacer otra versión (o usar una herramienta multiplataforma como Flutter).

---

## 7. Mini glosario

| Término | Significado sencillo |
|---|---|
| Framework | Paquete de código ya hecho (MapKit, CoreImage, AVFoundation) |
| View | Una pantalla o un pedazo de pantalla |
| body | Lo que se dibuja de una View |
| Modificador | `.algo()` que cambia el estilo de un elemento |
| struct | Molde que se **copia** al pasarlo |
| class | Molde que se **comparte** al pasarlo |
| Instancia | Un objeto hecho a partir de un molde |
| enum | Lista cerrada de opciones |
| Protocolo | Contrato de reglas que un tipo promete cumplir |
| Estado | Datos que cambian y hacen que la pantalla se redibuje |
| Binding (`$`) | Conexión de ida y vuelta entre un dato y un control |
| Opcional (`?`) | Valor que puede estar vacío (`nil`) |
| Closure | Función sin nombre, como lo que pasa al tocar un botón |
| Hardcodeado | Dato escrito fijo en el código |
| Placeholder | Relleno temporal (las miniaturas grises) |
| SF Symbols | Biblioteca de íconos de Apple |
