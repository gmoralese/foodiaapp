# Foodia 🥗

MVP de una app iOS que estima los macros de tu comida a partir de una foto.
**Todo corre on-device**: sin APIs externas, sin servidor, sin costo por request.

## Cómo funciona

Tres motores de reconocimiento detrás del mismo flujo (elegible en ⚙️ → Motor de análisis):

```
Foto (cámara o galería)
  ├─ Nube (opcional): backend NestJS en Cloud Run + Vertex AI Gemini Flash
  │    → máxima precisión; componentes con gramos Y macros estimados
  │    → repo: ../foodia-backend (contrato en su README)
  ├─ VLM local (LFM2.5-VL 1.6B vía MLX, descarga opcional de ~1 GB)
  │    → detecta TODOS los componentes del plato con gramos estimados
  └─ Apple Vision ClassifyImageRequest (fallback, sin descarga, ~1300 clases)
       → un alimento por foto, con chips de candidatos
  → Cruce con base nutricional local; para alimentos fuera de la base,
    se usan los macros estimados por Gemini
  → Se guarda en SwiftData → Diario con totales por día
  → (iOS 26 + Apple Intelligence) Foundation Models genera un resumen del día
```

Cadena de fallback: Nube → VLM local → Vision. La URL y API key del backend viven en
`project.yml` (Info.plist: `BackendURL`, `BackendAPIKey`).

El VLM se descarga desde la app (botón 🧠 en Registrar). Sin descarga, la app
funciona igual con Vision. El modelo corre 100% on-device vía MLX en cualquier
iPhone razonablemente moderno (no requiere Apple Intelligence).

**Licencias de modelos**: LFM2.5-VL usa la LFM Open License v1.0 (uso comercial
libre hasta USD 10M de facturación anual). FastVLM de Apple quedó descartado:
su licencia es solo para investigación. Alternativa Apache 2.0 pura:
`VLMRegistry.qwen2VL2BInstruct4Bit` (un cambio de constante en `VLMModelManager`).

## Arquitectura

- `App/` — entry point y TabView raíz.
- `Features/Capture/` — captura de foto, análisis, selección de porción y guardado.
- `Features/Diary/` — diario agrupado por día con totales de macros.
- `Services/Recognition/` — los dos motores: `VisionFoodRecognizer` (clasificador),
  `VLMFoodRecognizer` (VLM multi-componente vía MLX) y `VLMModelManager`
  (descarga/carga/borrado del modelo).
- `Services/Nutrition/` — base nutricional local de solo lectura (bundled).
- `Services/Intelligence/` — capa opcional de Apple Intelligence (Foundation Models).
  El modelo vive en el OS: 0 bytes de peso extra. Degrada sin romper nada.
- `Persistence/` — modelo SwiftData (`MealEntry`) y fotos en disco (`PhotoStore`).

Requisitos del proyecto: iOS 18+, Swift 6 (default actor isolation: MainActor).

## Desarrollo

El `.xcodeproj` se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`:

```sh
xcodegen generate   # regenerar tras agregar/mover archivos
open Foodia.xcodeproj
```

Build por línea de comandos:

```sh
xcodebuild -project Foodia.xcodeproj -scheme Foodia \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation -skipMacroValidation
```

Los flags `-skip*Validation` son para CLI; en Xcode, la primera vez que abras el
proyecto vas a tener que confiar en el plugin de mlx-swift y los macros
(botón "Trust & Enable"). También hace falta el Metal Toolchain
(`xcodebuild -downloadComponent MetalToolchain`, ya instalado en esta máquina).

### Harness de evaluación de modelos

`tools/vlm-harness/` corre el mismo prompt + parser de la app contra una foto
en macOS, para comparar VLMs antes de cambiar el default:

```sh
cd tools/vlm-harness
xcodebuild -scheme FoodVLMHarness -destination 'platform=macOS,arch=arm64' \
  -configuration Release -derivedDataPath ./dd build \
  -skipPackagePluginValidation -skipMacroValidation
./dd/Build/Products/Release/FoodVLMHarness foto.jpg [model-id-de-hugging-face]
```

(Con `swift build` no funciona: el metallib de MLX solo se compila con el build
system de Xcode.)

## Instalar en tu iPhone

1. `open Foodia.xcodeproj`
2. Target **Foodia → Signing & Capabilities → Team**: elegí tu Apple ID
   (si no aparece: Xcode → Settings → Accounts → “+”).
3. Conectá el iPhone por cable y activá **Developer Mode** en el teléfono
   (Ajustes → Privacidad y seguridad → Modo de desarrollador → reiniciar).
4. Elegí tu iPhone como destino en Xcode y **Run (⌘R)**.
5. La primera vez, confiá en el certificado: Ajustes → General →
   VPN y administración de dispositivos → tu Apple ID → Confiar.

Con cuenta gratuita (sin Apple Developer Program) la firma vence a los 7 días;
se reinstala con otro ⌘R.

## Limitaciones conocidas del MVP

- El VLM (1.6B parámetros) puede alucinar algún componente u omitir otros; la
  lista es editable justamente por eso. Las porciones estimadas son gruesas.
- Sin el VLM descargado, Vision reconoce platos "de libro" y un solo alimento
  por foto; comida casera mezclada requiere la búsqueda manual (botón "Otra…").
- Valores nutricionales aproximados por 100 g, curados a mano (~90 alimentos).
- El resumen con Apple Intelligence requiere iPhone 15 Pro+ con iOS 26.
- La primera inferencia tras abrir la app es más lenta (carga del modelo en RAM).
