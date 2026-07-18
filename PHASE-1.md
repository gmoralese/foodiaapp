# Foodia — Estado de la Fase 1 (referencia para la Fase 2)

> Documento de traspaso. Describe TODO lo construido hasta 2026‑07‑18: features,
> arquitectura, contratos, datos, infraestructura, tests, convenciones y deuda.
> Pensado para retomar en otro contexto y planear la Fase 2.

---

## 0. El ecosistema (3 repos)

| Repo | Ruta local | Qué es | Estado |
|---|---|---|---|
| **foodia** (iOS) | `~/projects/foodia` | App iOS SwiftUI que estima macros desde una foto | MVP funcional, en el iPhone del usuario |
| **foodia-backend** (NestJS) | `~/projects/foodia-backend` | API de análisis IA + auth + sync + telemetría + backoffice | Deployado en Cloud Run |
| **foodia-nutritionist-app** (Angular) | `~/projects/foodia-nutritionist-app` | Backoffice/panel admin interno | **Scaffold** (Angular 21, sin features) |

**Cuentas / infraestructura clave**
- GitHub personal: cuenta `gmoralese`. Remotos SSH vía alias `gmoralese.github.com` (llave `~/.ssh/id_ed25519_gmoralese`). Repos: `gmoralese/foodiaapp` (iOS) y `gmoralese/foodia-backend`. Ambos **privados**, deploy/commits directos a `main` (autorizado por el usuario; la regla general es rama+PR).
- GCP: proyecto `developer-unknown`, región `us-central1`, cuenta `gus.morales@me.com`. Cloud Run: servicio `foodia-backend` (`https://foodia-backend-2rm6w36ggq-uc.a.run.app`). Vertex AI (Gemini).
  - OJO gcloud: la cuenta activa por defecto es `g.morales@ecopass.cl` → usar `CLOUDSDK_CORE_ACCOUNT=gus.morales@me.com` en comandos.
- Supabase: proyecto `foodia`, ref `titegcedxvdgqshsicay`, región **us-east-2 (Ohio)**. Auth (Sign in with Apple nativo), Postgres, Storage.
- Deploy: **push a `main` de foodia-backend → GitHub Actions → Cloud Run** (no hay deploys manuales). El workflow NO corre tests (solo build+deploy). Las migraciones se aplican con `supabase db push` (CLI linkeado, token en Keychain).

---

## 1. App iOS (`foodia`)

### 1.1 Stack y config
- **SwiftUI, Swift 6**, target de deployment **iOS 18.0**, solo iPhone.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: TODO es MainActor salvo lo marcado `nonisolated` (modelos de datos puros y servicios sin UI).
- Bundle id `me.gusmorales.foodia` (widget: `me.gusmorales.foodia.FoodiaWidget`). Team `S23GC6A3K6`. `MARKETING_VERSION 0.1.0`.
- **Fuente de verdad del proyecto: `project.yml` (XcodeGen).** El `.xcodeproj` es artefacto y está gitignoreado — regenerar con `xcodegen generate` tras agregar/mover/renombrar archivos.
- **Capabilities/entitlements** (`Foodia/Support/Foodia.entitlements`): `com.apple.developer.applesignin`, `com.apple.developer.healthkit`, `com.apple.security.application-groups` = `group.me.gusmorales.foodia`. Requieren **cuenta Apple Developer de pago**.
- **Info.plist** (declarado en project.yml): `BackendURL`, `BackendAPIKey` (⚠️ en texto plano en el bundle — trade-off del MVP), `SupabaseURL`, `SupabasePublishableKey`, y usage descriptions de cámara/micrófono/salud/voz.
- **Paquetes SPM**: `mlx-swift-lm` (VLM local), `swift-huggingface` + `swift-transformers` (descarga/tokenizer del modelo), `lucide-icons-swift` (iconografía), `supabase-swift` (auth + storage).
- **Localización**: bilingüe **español neutro (tuteo, SIN voseo) + inglés** vía `Foodia/Resources/Localizable.xcstrings` (String Catalog, ~321 claves; `developmentLanguage: es`). **Deuda**: las claves nuevas de las últimas features (Perfil, Peso y medidas, detalle de comida) están en es pero **faltan traducir al `en`**.

### 1.2 Estructura de carpetas
```
Foodia/
  App/            FoodiaApp (entry + ModelContainer), RootView (gating + tabs)
  DesignSystem/   DSColor, DSButtonStyles, Components/ (Avatar, KcalRing, MacroBar, MealRow, DSIcon, FoodiaTabBar, ...)
  Domain/         PlanCalculator (Mifflin-St Jeor), Streak, GoalsStore, UserProfile, MealType, FoodCategory
  Features/       Auth, Onboarding, Today, History, Goals, Profile, Measurements, Capture, Settings(MetasSheet)
  Persistence/    MealEntry, WaterEntry, BodyMeasurement (SwiftData), PhotoStore, AvatarStore, MealGrouping, DemoSeeder
  Services/       Recognition (3 motores), API (BackendClient), Auth, Sync, Health, Intelligence, Notifications, Nutrition, Speech
  Shared/         WidgetSnapshot (app ↔ widget)
FoodiaWidget/     FoodiaWidget (WidgetKit extension)
FoodiaTests/      Swift Testing (dominio + AvatarStore)
```

### 1.3 Navegación y gating
- `RootView` decide: `if hasOnboarded && AuthService.shared.isAuthenticated { mainApp } else { FirstRunFlow() }`.
  - `hasOnboarded` es un flag **local** (`@AppStorage`). `isAuthenticated` = hay sesión de Supabase.
- **Tab bar custom** (`FoodiaTabBar`, `AppTab`): 4 destinos + botón central de cámara (acción, no tab): **Hoy** · **Historial** · 📷 · **Metas** · **Perfil**. Íconos SF Symbols (a diferencia de las secciones internas que usan Lucide).
- Args de debug (DEBUG only): `-seedDemo`, `-hasOnboarded YES`, `-initialTab history|goals|profile`, `-skipAuth`, `-testLogin correo:pass`, `-AppleLanguages "(en)"`.

### 1.4 Autenticación (Sign in with Apple)
- `AuthService` (@Observable singleton) envuelve `SupabaseClient`. Login obligatorio.
- Flujo: `FirstRunFlow` → Splash → `LoginView` (botón nativo `SignInWithAppleButton`) → `prepareAppleRequest` (nonce SHA‑256, scopes **`[.fullName, .email]`**) → `signInWithApple` → `client.auth.signInWithIdToken(provider: .apple, ...)`.
- **Nombre**: Apple entrega `credential.fullName` **solo en la PRIMERA autorización** de un Apple ID. Se captura y se hace `PATCH /v1/profile` best‑effort. Usuarios ya registrados NO lo reciben → lo editan a mano.
- Sesión persistida en Keychain (via supabase-swift). `userID` = `session.user.id` = el `user_id` de todas las tablas. `accessToken()` refresca contra Supabase.
- OJO simulador: build con `CODE_SIGNING_ALLOWED=NO` rompe el Keychain → para correr con auth usar `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES` (o `-testLogin`).

### 1.5 Onboarding (`OnboardingFlow.swift`)
- 7 pasos (0‑indexados): Valor, Privacidad, Sobre ti (sexo/edad/peso/altura/país), Actividad (nivel + deportes), Objetivo, Plan sugerido, Permiso de cámara.
- **Server‑side resume**: tras login, `.preparing` consulta `GET /v1/profile`. Si `onboardingCompletedAt != nil` → salta el onboarding y baja metas/país (`applyToLocalStores`). Si no → retoma en `onboardingStep`.
- Cada `next()` hace `PATCH /v1/profile` con los campos del paso (`pushProgress`). El último paso manda `onboardingCompleted = true`.
- Metas se calculan con `PlanCalculator` (Mifflin‑St Jeor: BMR + factor de actividad + objetivo; reparto de macros: proteína 1,8–2,0 g/kg, grasa 0,8 g/kg, resto carbos; redondeos).

### 1.6 Los 3 motores de análisis (`Services/Recognition/`)
- **Nube** (`RemoteFoodRecognizer`): multipart a `POST /v1/analyze` del backend (foto opcional + `context` + `locale`); manda JWT best‑effort. Devuelve componentes con macros por porción → la app los pasa a **per‑100g** para re‑escalar por gramos.
- **VLM local** (`VLMFoodRecognizer` + `VLMModelManager`, MLX): modelo por defecto **LFM2.5‑VL‑1.6B‑4bit**, descarga on‑demand desde HuggingFace (~1 GB). Parser JSON tolerante (`parse`, testeado). Soporta foto y texto‑only. Cambiar de VLM = tocar las 4 constantes de `VLMModelManager` + validar con `tools/vlm-harness/`. Licencias: LFM comercial hasta USD 10M; fallback Apache 2.0 = Qwen2‑VL‑2B.
- **Apple Vision** (`VisionFoodRecognizer` vía `ClassifyImageRequest`, ~1300 clases): clasifica y matchea contra la base local (`nutrition.json`, ~89 alimentos, aliases snake_case).
- **Orquestación** (`AnalysisModel.analyze()`): preferencia `EnginePreference` (local/cloud/**auto** default). `auto` usa Nube con conexión, cae a Local si no hay; `cloud` estricto muestra error sin fallback silencioso.
- Nombres de comida según el **país** del usuario (`FoodLocale`, key `foodCountry`, ej. "es‑CL" palta / "es‑MX" aguacate); la base local usa `FoodItem.localizedName` (name/nameEn).
- **Categoría** (`MealType`: breakfast/lunch/dinner/snack) la elige el usuario en el Resumen (sugerida por hora), nunca se infiere sola al guardar.

### 1.7 Pantallas principales
- **Hoy** (`TodayView`): anillo de kcal (`KcalRing`), barras de macros (P verde, C ámbar, G azul), card de hidratación, racha 🔥, resumen del día con IA, semana. Publica `WidgetSnapshot`.
- **Historial** (`HistoryView` → `DayDetailView` → `MealDetailView`):
  - Lista de días + gráfico semanal (Swift Charts). `navigationDestination(for: Date.self)`.
  - **DayDetailView**: totales del día + lista de comidas (agrupadas por `mealGroupID`). Cada fila (`MealRow`) muestra ingredientes completos (sin truncar) y navega a…
  - **MealDetailView**: foto (si hay), total kcal + macros, y **cada alimento con sus gramos y P/C/G**. Permite eliminar la comida.
- **Metas** (`GoalsView`): edita metas/agua EN VIVO + card de plan.
- **Perfil** (`ProfileView`, ex‑Ajustes): ver §1.8.
- **Captura** (`Features/Capture/`): cámara AVFoundation full‑screen (`CameraScreen`/`CameraService`), `AnalysisView` con estados, `CaptureFlowView`. Registro sin foto: `DescribeMealSheet` (+ dictado de voz `SpeechDictation` on‑device) → `AnalysisModel(description:)`. Búsqueda manual: `FoodSearchView`.

### 1.8 Perfil (última feature, `Features/Profile/`)
- Card superior "PERFIL": **AvatarView** (foto / iniciales / ícono persona) + **nombre** + email; toca para **EditProfileSheet**. Dentro del card agrupa: **Metas diarias**, **Peso y medidas**, **País**.
- Debajo, ajustes de la app: Motor de análisis (local/nube/auto), Modelo Foodia Vision (descarga/borrado), Salud, Recordatorios, Datos y privacidad (exportar JSON, cerrar sesión, eliminar todo).
- **EditProfileSheet**: editar **nombre** (TextField) y **avatar** (`PhotosPicker` → comprime → sube al bucket privado → cachea local).
- `name` y `avatarPath` viven en `UserProfile` y viajan por `RemoteProfile`/`ProfilePatch`/sync.

### 1.9 Peso y medidas (`Features/Measurements/BodyMeasurementsSheet.swift`)
- Histórico de **peso + cintura, cadera, pecho, brazo, muslo, cuello, % grasa** (todas opcionales por registro).
- Peso actual + delta, **gráfico de tendencia por métrica** (Swift Charts, selector), historial (borrar con context menu), formulario con validación de rangos.
- Al guardar un peso: actualiza el peso del perfil (`GoalsStore.updateWeight`) y **ofrece recalcular las metas** (`recalcGoalsFromProfile`, plan recomendado Mifflin‑St Jeor) sin pisar metas personalizadas.

### 1.10 Extras
- **Hidratación** (`WaterEntry`, `HydrationCard`, meta en Metas, export a Salud).
- **Racha** (`Streak.days`: días consecutivos, tolera "hoy sin registrar").
- **Recordatorio diario** (`ReminderService`, 20:30, toggle en Perfil).
- **Widget** (`FoodiaWidget`, systemSmall+medium, App Group, snapshot desde TodayView, reset a medianoche).
- **HealthKit** (`HealthKitExporter`, write‑only kcal/macros/agua, toggle).
- **Apple Intelligence** (`IntelligenceService`, resumen del día): tras `#if canImport(FoundationModels)` + `#available(iOS 26)` + chequeo de disponibilidad. **Solo iPhone 15 Pro+ con iOS 26**; en iOS 18 no aparece (degradación intencional).

### 1.11 Almacenamiento en disco (`Persistence/`)
- **SwiftData**: `MealEntry` (con `mealGroupID`, `remoteMealID`, `needsSync`, `engine`, `icon`, `mealType`), `WaterEntry`, `BodyMeasurement`. Schema en `FoodiaApp.container`.
- Fotos/avatares a **disco** (Application Support), no a SwiftData. `PhotoStore` (fotos de comida, downscale 900 px + jpeg 0.8) y `AvatarStore` (avatar, downscale 512 px + jpeg 0.7).
- ⚠️ **GOTCHA resuelto (crítico)**: `URL.path()` devuelve el path **percent‑encoded** (`Application%20Support`), así que `UIImage(contentsOfFile: url.path())` NUNCA encontraba el archivo. **Regla: leer archivos con `Data(contentsOf: URL)`**, no con `contentsOfFile: url.path()`. (Rompía avatar y fotos de comida.)
- ⚠️ `UIGraphicsImageRenderer` usa la escala del device (2‑3×) por defecto → forzar `format.scale = 1` para que el downscale reduzca píxeles de verdad.

---

## 2. Backend (`foodia-backend`)

### 2.1 Stack
NestJS 11, Node 22, TypeScript 5.7, yarn. Arquitectura **hexagonal** (domain/application/infrastructure/http por contexto). Sin ORM: `pg` (Pool) contra Supavisor (transaction mode, puerto 6543, rol `foodia_backend`). `@google/genai` (Vertex, ADC — sin credenciales en runtime). `jsonwebtoken` + JWKS para validar JWT de Supabase. `helmet`, `@nestjs/throttler` (30 req/60s global), `class-validator`.

### 2.2 Endpoints

| Método | Ruta | Auth | Función |
|---|---|---|---|
| POST | `/v1/analyze` | `x-api-key` + JWT opcional | Análisis (multipart, foto opcional; `context`≤300, `locale`) → `{components[], model}` |
| GET | `/health` | — | Probe Cloud Run → `{status:"ok"}`. **OJO: NO usar `/healthz`** (el GFE de Google lo intercepta) |
| GET / PATCH | `/v1/profile` | JWT | Perfil: metas, onboarding, `food_country`, **`name`, `avatar_path`** |
| POST / GET / DELETE | `/v1/meals` (+`/:id`) | JWT | Comida+componentes (tx), listar (keyset), borrar |
| POST / GET / DELETE | `/v1/water` (+`/:id`) | JWT | Hidratación |
| POST / GET / DELETE | `/v1/measurements` (+`/:id`) | JWT | Peso y medidas corporales |
| GET | `/admin/overview`, `/cost/daily`, `/top-spenders`, `/users/:id/events`, `/review` | JWT + `AdminGuard` | **Backoffice**: analytics de costo/abuso/moderación |

- **Paginación keyset** (`common/keyset.ts`): cursor opaco base64url `"<ISO>|<uuid>"`, orden `(<ts>, id) desc`.
- **Auth**: `SupabaseJwtGuard` (estricto, ES256 vs JWKS con `JwksCache`, issuer/audience validados) para las rutas de usuario; `ApiKeyGuard` (comparación en tiempo constante) + `OptionalUserGuard` (identidad best‑effort) para `/v1/analyze`. `AdminGuard` coteja el claim `email` del JWT contra `FOODIA_ADMIN_EMAILS`.
- **SIWA** no vive en el backend: la app hace el login contra Supabase Auth; el backend solo consume el JWT.

### 2.3 Análisis (Vertex Gemini)
- `VertexGeminiAnalyzer`: `@google/genai` (`vertexai:true`), modelo default `gemini-3.5-flash`, `responseMimeType: application/json` + `responseSchema` tipado, temp 0.2. Prompts con foto y **text‑only**.
- Traduce el nombre por país (`displayNameInstruction`). **Anti prompt‑injection** (nota como dato no confiable, `sanitizeUserNote`, heurística `looksLikeInjection` que marca sin bloquear). **Clamps de plausibilidad física** (macros ≤ peso, ≤~9.5 kcal/g).
- **Telemetría**: cada análisis registra en `analysis_events` (tokens, latencia, outcome, `user_id` opcional). (Deuda menor: `clamp_hit` nunca se setea → siempre `false`.)

### 2.4 Backoffice (`src/admin/`) — inicio de la Fase 2
- Módulo `admin`: endpoints de analytics sobre `analysis_events` (costo diario, top spenders, eventos por usuario, cola de `review`/`flagged`), lógica de pricing (`domain/pricing.ts`), `AdminGuard` por email.
- **Estado**: el backend admin ya existe (con trabajo en paralelo, puede estar **sin commitear** en el working tree — al commitear cambios propios stagear SOLO los archivos propios). El **frontend Angular (`foodia-nutritionist-app`) sigue siendo scaffold**.

### 2.5 Config / env
Requeridas: `FOODIA_API_KEY`, `GCP_PROJECT_ID`, `SUPABASE_URL`, `DATABASE_URL`. Opcionales: `PORT` (3000), `VERTEX_LOCATION` (global), `GEMINI_MODEL` (gemini-3.5-flash), `FOODIA_ADMIN_EMAILS`. El workflow de deploy inyecta las env vía `--env-vars-file` (**REEMPLAZA todas** → agregar cualquier env nueva también al yaml). ⚠️ `DATABASE_URL` con la password del rol `foodia_backend` **quedó expuesta en un transcript** → **rotar** (Supabase → nueva password → `gh secret set DATABASE_URL` → push para redeploy).

---

## 3. Supabase (base de datos + storage + auth)

Ref `titegcedxvdgqshsicay`, us‑east‑2. Migraciones en `foodia-backend/supabase/migrations/` (5): initial_schema, backend_role, analysis_events, body_measurements, profile_name_avatar.

### 3.1 Tablas (`public`)
- **profiles** (1:1 con `auth.users`, PK `user_id`): `onboarding_step` (0‑7), `onboarding_completed_at`, `sex/age/weight_kg/height_cm/activity/sports[]/objective`, plan (`plan_name`, `goal_kcal/protein_g/carbs_g/fat_g/water_ml`), `food_country`, **`name` (≤80), `avatar_path`**, `created_at/updated_at`. Trigger `handle_new_user` crea la fila al signup (solo `user_id`); `moddatetime` para `updated_at`. CHECKs que espejan los tipos Swift.
- **meals**: `id, user_id, eaten_at, meal_type, photo_path, note(≤300), engine(vision/vlm/cloud), model, created_at`. Índice keyset `(user_id, eaten_at desc, id desc)`.
- **meal_components**: `id, meal_id, user_id(desnorm), name(1‑120), icon, emoji, grams, kcal, protein_g, carbs_g, fat_g, category(8 cat.)`. Macros ya escaladas a la porción.
- **water_entries**: `id, user_id, logged_at, milliliters(1‑5000)`. Keyset.
- **body_measurements**: `id, user_id, measured_at, weight_kg, waist/hip/chest/arm/thigh/neck_cm, body_fat_pct` (todas opcionales, CHECK "al menos una"). Keyset.
- **analysis_events** (append‑only, telemetría): tokens/latencia/outcome/user_id/clamp_hit.

### 3.2 RLS + rol backend
- RLS habilitado en todas con políticas `own` (ownership por `auth.uid()`) — defensa en profundidad / futuro acceso directo.
- Hoy el backend usa el rol **`foodia_backend`** (mínimo privilegio: DML sobre las tablas de la app) con políticas `using(true)`; el scoping por usuario lo hace el backend en cada `WHERE user_id = $jwt.sub`. Ese rol **no** puede leer los schemas `auth`/`storage` (por eso para verificar objetos de storage se usa el CLI de Supabase, no un `select`).

### 3.3 Storage (buckets privados, folder por usuario)
- **meal-photos**: `<user_id>/<uuid>.jpg` (fotos de comida). La app sube directo con su sesión.
- **avatars**: `<user_id>/avatar.jpg` (avatar). 4 policies RLS por folder (`(storage.foldername(name))[1] = auth.uid()`). Upload/download vía `AuthService.uploadAvatar/downloadAvatar`; comprimido antes de subir.

### 3.4 Auth
- Provider **Apple** habilitado (flujo nativo: `external_apple_client_id` = bundle `me.gusmorales.foodia`, sin secret). Token del CLI de Supabase en Keychain de macOS.

---

## 4. Sincronización iOS ↔ backend (`SyncService`)

Best‑effort, la app siempre funciona offline. Disparadores: `scenePhase == .active` y tras cada save.
- **Push de pendientes**: entradas con `needsSync == true` (comidas por grupo, agua, medidas) → POST al backend, marca `needsSync = false` + guarda `remoteID`.
- **Backfill** (primer login en un dispositivo, flag `didBackfill-<uid>`): baja TODO el historial paginado (meals, water, measurements) hacia SwiftData; dedup por `remoteID`.
- **Borrados**: tombstones en UserDefaults (`pendingMealDeletions`, `pendingMeasurementDeletions`), drenados en cada sync (borrado idempotente: 404 = éxito).
- **Perfil/metas**: `pushProfileSnapshot` con debounce 1.5 s (incluye sexo/edad/peso/altura/actividad/objetivo/metas/país/**name/avatarPath**).
- **Fotos**: subida directa a Storage (`uploadMealPhoto`); el backfill NO baja fotos. **Avatar**: se baja en `ProfileView.task`/`EditProfileSheet.task` si hay `avatar_path` y no está cacheado (porque un usuario ya logueado no pasa por el resume del onboarding).
- **Wipe** (`wipeRemote`): borra meals/water/measurements remotos + limpia caches locales.
- `BackendClient`: DTOs camelCase, fechas ISO‑8601 con y sin fracción (decoder custom), `Authorization: Bearer <jwt>` en cada request.

---

## 5. CI/CD e infraestructura

- **Backend**: `.github/workflows/deploy-foodia-backend.yaml` → push a `main` → build Docker (multi‑stage, `node:22-alpine`, puerto 8080) → push a GCR → `gcloud run deploy` (`--cpu 1 --memory 512Mi --min 0 --max 2 --allow-unauthenticated`). SA `foodia-deployer` (roles run.admin/storage.admin/iam.serviceAccountUser/**artifactregistry.writer**). El workflow **no** corre tests.
- **App iOS**: sin CI. Build de verificación local:
  `xcodebuild -project Foodia.xcodeproj -scheme Foodia -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation` (los skip‑flags son obligatorios por el plugin CudaBuild de mlx‑swift y los macros de MLXHuggingFace). Tests: reemplazar `build` por `test` con `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- **Migraciones**: `supabase db push` (dry‑run primero). El Warning de `pg-delta` sobre el cert cache es benigno (la migración se aplica igual; verificar con un `select`).

---

## 6. Testing

- **App iOS**: **Swift Testing** (`import Testing`), target `FoodiaTests` (`bundle.unit-test`). **~50 tests / 9 suites**: `PlanCalculator`, `Streak`, `VLMFoodRecognizer.parse`, `MealGroup`, `MealType.inferred`, `Macros`, `BodyMetric`/`measurementText`, `AvatarStore` (round‑trip en disco). Sin cobertura de la capa de servicios con efectos (sync/auth/red).
- **Backend**: **Jest** (ts‑jest). **~111 tests / 19 suites**: unit + e2e (puerto mockeado, sin Vertex/DB). Cubre analysis, meals/profile/water/measurements (controllers + repos), auth (guards, JWKS, verificador ES256 real vs JWKS mockeado), keyset, y el módulo admin.

---

## 7. Convenciones y comandos

- **Regenerar proyecto Xcode**: `xcodegen generate` (tras agregar/mover/renombrar archivos Swift).
- **Íconos**: **Lucide** (`DSIcon(id:)`) para toda la iconografía de features; SF Symbols solo para chrome (tab bar, chevrons). Emojis eliminados (campo `emoji` es legacy).
- **Microcopy**: español neutro **tuteo** (nunca voseo), tono cálido; términos técnicos (VLM/inference) solo en detalles de config.
- **Foundation Models** siempre tras `#if canImport(FoundationModels)` + `#available(iOS 26.0, *)` + chequeo de disponibilidad (target iOS 18).
- **Nota**: `docs/design-guidelines.md` y el `README.md` raíz están **DESACTUALIZADOS** (mencionan emoji/voseo/"sin servidor"). Manda el `CLAUDE.md` + este documento.

---

## 8. Deuda técnica y pendientes (input para la Fase 2)

**App iOS**
- [ ] Traducir al **`en`** las claves nuevas del catálogo (Perfil, Editar perfil, Peso y medidas, detalle de comida, etc.).
- [ ] Cobertura de tests de la capa de servicios con efectos (SyncService, BackendClient con URLProtocol mock, AuthService).
- [ ] `RemoteFoodRecognizer.mapping` y el keyset del lado iOS no son testeables sin un pequeño refactor (extraer función pura).
- [ ] README raíz y `design-guidelines.md` desactualizados.

**Backend**
- [ ] **Rotar la password de `foodia_backend`** (expuesta) + actualizar secret + redeploy.
- [ ] `.env.example`/`docs/gcp-setup.md` deben incluir `SUPABASE_URL`/`DATABASE_URL`/`FOODIA_ADMIN_EMAILS`.
- [ ] Telemetría `clamp_hit` muerta (siempre false).
- [ ] El pipeline no corre tests antes de deployar (agregar gate).

**Backoffice / Fase 2 (el foco declarado)**
- [ ] **`foodia-nutritionist-app` (Angular 21) es scaffold** — hay que construir el dashboard admin (observabilidad de costo de IA por usuario, detección de abuso, moderación de `flagged`, KPIs). La skill de diseño `kpi-dashboard-design` está instalada.
- [ ] Decidir **acceso a datos del SPA**: la opción recomendada es un **BFF `/admin/*` en el backend NestJS** (ya iniciado, ver §2.4) con secretos server‑side — el SPA nunca lleva `service_role` ni `DATABASE_URL`.
- [ ] Rate limit / cuota por `user_id` en `/v1/analyze`.
- [ ] Vistas SQL de costo/top‑spenders/error‑rate/flagged (parte ya en el módulo admin).

**Producto / validación**
- [ ] Probar en device: dictado por voz, HealthKit real, resumen IA (iPhone 15 Pro+ iOS 26), widget.
- [ ] El nombre de SIWA solo se captura en el primer login de un Apple ID nuevo (limitación de Apple).

---

## 9. Roadmap de features (checklist de lo HECHO)

- [x] 3 motores de análisis (Nube/Gemini, VLM local MLX, Apple Vision) + fallback
- [x] Onboarding 7 pasos + Sign in with Apple + resume server‑side
- [x] Tab bar (Hoy/Historial/📷/Metas/Perfil)
- [x] Dashboard Hoy (anillo, macros, hidratación, racha, resumen IA)
- [x] Historial → detalle de día → **detalle de comida** (alimento + gramos + macros)
- [x] Metas (Mifflin‑St Jeor) editables
- [x] **Perfil**: nombre (desde SIWA + editable), **avatar** (bucket privado, comprimido)
- [x] **Peso y medidas corporales** con histórico y gráficos
- [x] Hidratación, racha, recordatorio diario
- [x] Registro sin foto (voz/texto)
- [x] Widget, HealthKit export, resumen con Apple Intelligence
- [x] Bilingüe es/en (en parcial — faltan traducciones nuevas)
- [x] Backend NestJS + Vertex Gemini + telemetría, deployado en Cloud Run
- [x] Auth JWT (Supabase/JWKS), sync bidireccional (push/backfill/tombstones/keyset)
- [x] Storage privado (fotos de comida + avatares)
- [x] Backoffice **backend** (analytics/pricing/admin guard) — falta el frontend Angular
