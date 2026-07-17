# Foodia — Lineamientos de diseño

Referencia para toda pantalla nueva o rediseño. La app es SwiftUI nativa, iOS 18+, solo iPhone.

## Principios

1. **Nativo primero**: si Apple ya resolvió el patrón, se usa el de Apple. Componentes de
   SwiftUI (TabView, NavigationStack, sheets, List, `.searchable`), materiales del sistema
   (Liquid Glass en iOS 26 con `#available` + fallback), SF Symbols para TODA la iconografía,
   SF Pro vía estilos semánticos (`.title2`, `.headline`, `.caption`) — nunca tamaños fijos.
2. **La privacidad es la marca**: cada pantalla que toque datos debe poder decir dónde se
   procesan ("en tu iPhone" / "en tu servidor"). El modo Local es el default y eso se comunica
   con orgullo, no como limitación.
3. **Cero fricción en el flujo core**: de abrir la app a foto tomada, máximo 2 taps.
   El análisis (3-8 s) siempre muestra progreso con la foto visible; nunca spinner en pantalla vacía.
4. **El usuario siempre corrige**: la IA propone, el usuario confirma. Toda estimación es
   editable con un tap; el costo de un error del modelo debe ser un gesto, no una frustración.
5. **Emoji-forward**: los alimentos se representan con su emoji (🍚🍳🥑) — es el lenguaje
   visual de la app, gratis, localizado y accesible.

## Tokens

- **Acento**: verde `#2E9E5A` (ya definido en `AccentColor.colorset`). Usos: acciones
  primarias, progreso, selección. Nunca para texto largo.
- **Macros**: proteínas azul, carbohidratos naranja, grasas rosa (ya en uso en `MacroTile`) —
  consistente en toda la app, siempre acompañado de etiqueta de texto (no solo color).
- **Grilla de 8 pt**; esquinas `16` para cards, `12` para filas, siempre `.rect(cornerRadius:)`
  (esquinas continuas).
- **Dark mode obligatorio**: solo colores semánticos del sistema (`.primary`, `.secondary`,
  `.quinary`, materiales) — jamás hex hardcodeado fuera del asset catalog.

## Patrones

- **Navegación**: tab bar (Registrar / Diario, y lo que venga) — nunca hamburger. Flujos
  modales (captura → análisis) en sheet o fullScreenCover con Cancelar/Guardar en toolbar.
- **Targets táctiles ≥ 44 pt**; botones primarios `.borderedProminent` + `.controlSize(.large)`.
- **Estados**: toda pantalla define vacío (`ContentUnavailableView`), cargando y error con
  mensaje accionable en tono humano. Errores de red siempre ofrecen el fallback local.
- **Feedback háptico** con `sensoryFeedback` en confirmaciones (guardar comida) y selecciones.
- **Accesibilidad**: Dynamic Type sin truncar, contraste AA, `accessibilityLabel` en botones
  de solo ícono, nada comunicado únicamente por color.

## Tono y microcopy

- Español latinoamericano con voseo: "Sacale una foto", "¿Algo que aclarar?".
- Directo y cálido, sin tecnicismos en la UI (nunca "VLM" o "inference" — sí "en tu iPhone",
  "modo Nube"). Los términos técnicos viven solo en Configuración → detalles.
- Los errores hablan de soluciones: "No pude conectarme — analicé con el motor de tu iPhone".

## Reglas de App Store a tener presentes

- Si se ofrece login de terceros, **Sign in with Apple es obligatorio** — y siempre con
  "Continuar sin cuenta" porque la app funciona offline.
- Los permisos (cámara, micrófono, voz) se piden en contexto, justo antes del primer uso,
  con las descripciones ya definidas en `project.yml`.
