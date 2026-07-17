# Foodia

App iOS (SwiftUI, Swift 6) que estima macros de comida desde una foto. Tres motores:
Nube (backend NestJS + Vertex Gemini, repo hermano `../foodia-backend/foodia-backend`),
VLM local (MLX) y Apple Vision, con fallback en ese orden según preferencia del usuario
(`EnginePreference`: local/cloud/auto — default auto). El backend corre en Cloud Run
(proyecto GCP `developer-unknown`, us-central1, cuenta gus.morales@me.com).

UI: implementa el diseño de Claude Design (proyecto 2ad51a6d-…, spec completo con
tokens/microcopy). Design system en `Foodia/DesignSystem/` (colores `ds*` en Assets con
variante dark; macros: P verde, C ámbar, G azul). Estructura: FirstRunFlow (splash →
onboarding 7 pasos → login SIWA-local) → RootView con tab bar custom (Hoy/Historial/
cámara central/Ajustes). Metas en `Domain/` (Mifflin-St Jeor).

Bilingüe: español neutro (fuente, SIN voseo — usar tuteo en todo string nuevo) + inglés
vía `Resources/Localizable.xcstrings` e `InfoPlist.xcstrings`. Strings dinámicos con
`String(localized:)`; params de componentes UI son `LocalizedStringKey`. Los nombres de
comida de la IA siguen el PAÍS del usuario (`FoodLocale`, key `foodCountry`, elegido en
onboarding/Ajustes → campo `locale` del backend, ej. "es-CL"/"en"); los de la base local
usan `FoodItem.localizedName` (name/nameEn). La categoría de comida la elige el usuario
(`MealType` en el Resumen), nunca se infiere sola al guardar.
Args de debug: `-seedDemo`, `-hasOnboarded YES`, `-initialTab history|settings`,
`-AppleLanguages "(en)"` para probar inglés.

Extras: hidratación (`WaterEntry`, card en Hoy, meta en Metas), racha (`Streak`),
recordatorio diario (`ReminderService`), registro sin foto (cámara → "O descríbela
sin foto" → `AnalysisModel(description:)`; backend acepta multipart sin photo),
widget (`FoodiaWidget/`, App Group `group.me.gusmorales.foodia`, snapshot en
`Foodia/Shared/WidgetSnapshot.swift` publicado desde TodayView).

## Comandos

- Regenerar proyecto tras agregar/mover/renombrar archivos: `xcodegen generate`
  (el `.xcodeproj` es un artefacto; la fuente de verdad es `project.yml`)
- Build de verificación: `xcodebuild -project Foodia.xcodeproj -scheme Foodia -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation`
  (los skip-flags son obligatorios por el plugin CudaBuild de mlx-swift y los macros de MLXHuggingFace)
- Evaluar/comparar VLMs contra una foto: `tools/vlm-harness/` (compilar con
  xcodebuild, NO con `swift build` — el metallib de MLX solo se genera con el
  build system de Xcode; ver README)

## Convenciones

- Swift 6 con `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: todo es MainActor salvo
  lo marcado `nonisolated` (modelos de datos puros y servicios sin UI).
- Los alias de `Foodia/Resources/nutrition.json` deben corresponder a identificadores
  reales de Vision (`ClassifyImageRequest().supportedIdentifiers`, ~1300 clases,
  formato `snake_case` que la app normaliza a espacios). Verificar antes de agregar.
- Las fotos van a disco vía `PhotoStore`; SwiftData solo guarda el filename.
- Foundation Models (Apple Intelligence) siempre detrás de
  `#if canImport(FoundationModels)` + `#available(iOS 26.0, *)` + chequeo de
  disponibilidad, porque el target de deployment es iOS 18.
- El VLM local usa mlx-swift-lm 3.x: la descarga requiere `swift-huggingface`
  (HubClient) + `swift-transformers` (Tokenizers) + macros de `MLXHuggingFace`
  (`#hubDownloader`, `#huggingFaceTokenizerLoader`). `ModelContainer`/`ModelContext`
  chocan entre SwiftData y MLXLMCommon: calificar con el módulo.
- Cambiar de VLM = tocar las 4 constantes de `VLMModelManager` (modelID,
  configuration, approximateSize, displayName) y validar antes con el harness.
  Ojo con licencias: FastVLM es solo investigación; LFM = comercial hasta USD 10M;
  Qwen2-VL-2B = Apache 2.0.
