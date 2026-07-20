# Foodia — Plan de la Fase 2: Nutricionistas (portal profesional)

> Plan de implementación. Alcance: vínculo nutricionista↔paciente con consentimiento,
> portal web del profesional (lectura), registro de mediciones y ajuste de metas por
> el profesional, más los próximos wins priorizados. Basado en la investigación de
> competencia del 2026-07-18 (Cronometer Pro, MyNetDiary, Healthie, Nutrium, Avena,
> FatSecret Professional) y en el estado descrito en `PHASE-1.md`.

---

## 0. Visión y principios

**Objetivo**: que un nutricionista partner pueda acompañar a su paciente dentro de
Foodia: ver su bitácora (comidas con foto y macros, agua, peso y medidas), registrar
mediciones en consulta y ajustar sus metas — con el paciente siempre en control del
acceso.

**Principios de diseño** (validados contra el mercado y la Ley 21.719):

1. **El paciente es dueño del vínculo**: nada se comparte sin aceptación explícita
   (acción afirmativa) y puede revocar en cualquier momento con efecto inmediato.
2. **Pro en web, paciente en móvil** (patrón Cronometer/Healthie/Nutrium): el portal
   del nutricionista es `foodia-nutritionist-app` (Angular); la app iOS no cambia de
   foco.
3. **Reutilizar antes que construir**: los datos y endpoints de meals/water/
   measurements/profile ya existen; la Fase 2 agrega **autorización por vínculo**,
   no un dominio nuevo de datos.
4. **Auditoría desde el día 1**: todo acceso del profesional a datos del paciente
   queda registrado (append-only), alineado con datos sensibles bajo Ley 21.719
   (fiscalización plena 1-dic-2026).
5. **Diferenciador intacto**: el análisis de macros por foto es del paciente; el
   portal lo muestra ya procesado (ninguna plataforma pro LatAm tiene esto).

**Modelo de negocio (referencia, fuera de alcance técnico del MVP)**: patrón
dominante = paga el profesional por volumen de pacientes (B2B2C: el paciente no
paga el vínculo). Para partners tempranos: gratis mientras validamos.

**Supuestos del MVP** (decisiones tomadas, revisables):
- Los nutricionistas **se registran solos en el portal**, pero la cuenta queda
  "en revisión" hasta aprobación manual nuestra (`approved_at`); sin
  verificación de credenciales todavía.
- El paciente puede tener **N nutricionistas** vinculados a la vez (como
  MyNetDiary); la app iOS lista todos los vínculos activos — nunca puede
  existir un vínculo invisible para el paciente.
- Portal **solo en español neutro** (mismo tono tuteo de la app) en el MVP,
  pero con i18n desde el día 1 (strings con `@angular/localize`): traducir
  después es agregar un archivo de traducciones, no refactorizar.
- Sin push notifications en el MVP (banners in-app); APNs va en próximos wins.
- Las fotos se sirven al portal **vía política RLS de Storage** con la sesión
  Supabase del profesional (sin `service_role` en ningún cliente).

---

## 1. Arquitectura de la solución

```
┌─────────────┐   JWT Supabase    ┌──────────────────┐    pg (rol foodia_backend)
│  App iOS    │ ────────────────► │  foodia-backend   │ ─────────────► Supabase
│  (paciente) │   /v1/me/*        │  (NestJS, hexag.) │                Postgres
└─────────────┘                   │                    │
┌─────────────┐   JWT Supabase    │  módulo nuevo:     │
│ Portal Ang. │ ────────────────► │  professional/     │
│ (nutricion.)│   /v1/pro/*       └──────────────────┘
└──────┬──────┘
       │ sesión Supabase (supabase-js): auth + lectura de fotos vía RLS de Storage
       ▼
   Supabase Auth + Storage (meal-photos / avatars)
```

- **Auth del profesional**: Supabase Auth email+password (mismo proyecto, mismo
  JWKS que ya valida `SupabaseJwtGuard`). Un usuario es "profesional" si existe en
  la tabla `professionals` con `approved_at` no nulo.
- **Autorización**: nuevo `ProfessionalGuard` (JWT válido + profesional aprobado) y
  verificación de vínculo `accepted` por request. La revocación surte efecto
  inmediato porque el vínculo se chequea en cada request (sin caché).
- **Scoping**: igual que hoy — el backend resuelve el `WHERE user_id = :patient`
  tras validar el vínculo; RLS queda como defensa en profundidad.

---

## 2. Modelo de datos (migraciones nuevas en `foodia-backend/supabase/migrations/`)

### 2.1 `professionals`
```sql
create table public.professionals (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null check (char_length(full_name) between 1 and 120),
  email       text not null,
  approved_at timestamptz,                 -- null = pendiente (MVP: se aprueba a mano)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- trigger moddatetime para updated_at (mismo patrón que profiles)
```

### 2.2 `professional_links` (el vínculo + su ciclo de vida)
```sql
create table public.professional_links (
  id              uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professionals(user_id),
  patient_id      uuid references auth.users(id),      -- null hasta que el paciente acepta
  invite_code     text not null unique,                -- código corto (8 chars, sin ambiguos)
  status          text not null default 'invited'
                    check (status in ('invited','accepted','revoked')),
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null,                -- invitación caduca (7 días)
  accepted_at     timestamptz,
  revoked_at      timestamptz,
  revoked_by      text check (revoked_by in ('patient','professional'))
);
-- un solo vínculo aceptado por par (pro, paciente):
create unique index professional_links_active_pair
  on public.professional_links (professional_id, patient_id)
  where status = 'accepted';
```
Ciclo: `invited` → (`accepted` | expira) → `revoked`. Nunca se borra (trazabilidad).

### 2.3 `professional_access_events` (auditoría, append-only)
```sql
create table public.professional_access_events (
  id              uuid primary key default gen_random_uuid(),
  professional_id uuid not null,
  patient_id      uuid not null,
  action          text not null,   -- 'viewed_meals' | 'viewed_measurements' | 'viewed_profile'
                                   -- | 'created_measurement' | 'updated_goals' | ...
  resource_id     uuid,            -- opcional (p.ej. id de la medición creada)
  created_at      timestamptz not null default now()
);
```
Mismo espíritu que `analysis_events`: insert-only, sin updates ni deletes.

### 2.4 Cambios a tablas existentes
```sql
alter table public.body_measurements
  add column recorded_by uuid references auth.users(id);  -- null = lo registró el paciente
```

### 2.5 RLS y Storage
- RLS `own` en `professionals` (cada pro ve su fila) y en `professional_links`
  (ve las filas donde es parte); grants DML al rol `foodia_backend` (mismo patrón
  de `backend_role`).
- **Política de Storage** en `meal-photos` (y `avatars`) para que el profesional
  con vínculo aceptado lea la carpeta del paciente con su propia sesión:
```sql
create policy "linked pro reads patient meal photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'meal-photos'
  and exists (
    select 1 from public.professional_links l
    where l.professional_id = auth.uid()
      and l.status = 'accepted'
      and l.patient_id::text = (storage.foldername(name))[1]
  )
);
```
La revocación corta también el acceso a fotos (la policy evalúa el estado actual).

> Proceso: `supabase db push` con dry-run primero, como siempre. Verificar la
> policy de storage con el CLI (el rol backend no lee el schema `storage`).

---

## 3. Contrato de API (backend, módulo `professional/`)

Estructura hexagonal como los módulos existentes:
`professional/{domain,application,http,infrastructure}` + tests Jest espejo de
`meals`/`measurements`.

### Lado profesional — prefijo `/v1/pro`, guard `ProfessionalGuard`

| Método | Ruta | Función |
|---|---|---|
| POST | `/v1/pro/invites` | Crea invitación → `{ code, expiresAt }` |
| GET | `/v1/pro/patients` | Pacientes vinculados (nombre, avatarPath, última comida registrada) |
| GET | `/v1/pro/patients/:id/profile` | Datos básicos + metas actuales + país |
| GET | `/v1/pro/patients/:id/meals?cursor=` | Bitácora paginada (keyset reutilizado, con componentes y `photoPath`) |
| GET | `/v1/pro/patients/:id/water?cursor=` | Hidratación |
| GET | `/v1/pro/patients/:id/measurements?cursor=` | Mediciones |
| POST | `/v1/pro/patients/:id/measurements` | Registra medición (setea `recorded_by = pro`) |
| PATCH | `/v1/pro/patients/:id/goals` | Ajusta metas (solo `goalKcal/proteinG/carbsG/fatG/waterMl/planName`) |
| DELETE | `/v1/pro/links/:id` | El profesional revoca el vínculo |
| POST | `/v1/pro/registration` | Registro: crea la fila `professionals` pendiente (`fullName`) — guard `SupabaseJwtGuard`, no `ProfessionalGuard` |
| GET | `/v1/pro/me` | Estado de la propia cuenta (pendiente/aprobada) — guard `SupabaseJwtGuard` |

- Toda ruta `patients/:id/*` pasa por un chequeo de vínculo (`LinkedPatientGuard` o
  use-case) que además **registra el evento de auditoría**.
- `PATCH goals` es un DTO propio y acotado — el pro **no** puede tocar
  `onboarding*`, `name`, `avatarPath` ni datos personales (segregación de
  interfaces: no se reutiliza `ProfilePatch` completo).

### Lado paciente — prefijo `/v1/me`, guard `SupabaseJwtGuard` (existente)

| Método | Ruta | Función |
|---|---|---|
| GET | `/v1/me/professional-invites/:code` | Preview de la invitación (nombre del pro) antes de aceptar |
| POST | `/v1/me/professional-links` | Acepta: `{ code }` → vincula `patient_id = jwt.sub` |
| GET | `/v1/me/professional-links` | Vínculos del paciente (para "Mis nutricionistas") |
| DELETE | `/v1/me/professional-links/:id` | El paciente revoca |

Reglas de dominio: código expirado o ya usado → 410/409; aceptar un código propio
(pro = paciente) → 422; revocar es idempotente (revocar algo ya revocado = 200).
Un paciente puede tener N vínculos activos con profesionales distintos; con el
mismo profesional solo uno (índice único por par) → re-aceptar = 409.

---

## 4. Épicas e historias de usuario

Formato: **HU** con criterios de aceptación (CA) + tareas técnicas por repo.
Prioridad en orden. DoD global en §6.

### E0 — Fundaciones (backend + datos) 🧱

> Habilita todo lo demás. Sin UI.

**HU-0.1** — Como *equipo Foodia*, quiero un registro de profesionales aprobados,
para que solo nutricionistas autorizados accedan a datos de pacientes.
- CA: existe `professionals`; un JWT válido sin fila aprobada recibe 403 en `/v1/pro/*`.
- CA: el registro del portal crea la fila con `approved_at` null (pendiente);
  la aprobación es manual (SQL/seed), sin verificación de credenciales.

**HU-0.2** — Como *paciente*, quiero que el acceso de un profesional exija mi
aceptación explícita y sea revocable, para mantener el control de mis datos de salud.
- CA: máquina de estados `invited → accepted → revoked` con expiración (7 días).
- CA: tras revocar (por cualquiera de las partes), el siguiente request del pro a
  ese paciente devuelve 403 (sin caché de autorización).
- CA: unicidad de vínculo aceptado por par pro–paciente.

**HU-0.3** — Como *responsable del tratamiento de datos*, quiero que cada acceso
del profesional quede auditado, para cumplir el estándar de datos sensibles
(Ley 21.719).
- CA: cada endpoint `/v1/pro/patients/:id/*` inserta un evento en
  `professional_access_events` (best-effort, no bloquea la respuesta).
- CA: la tabla es append-only (sin UPDATE/DELETE para el rol backend).

Tareas backend:
- [ ] Migraciones §2 (dry-run + push + verificación).
- [ ] Módulo `professional/`: entidades de dominio (`ProfessionalLink` con su
      máquina de estados como lógica pura testeable), repos `pg`, guards, DTOs
      con `class-validator`.
- [ ] `ProfessionalGuard` + verificación de vínculo con registro de auditoría.
- [ ] Tests Jest: máquina de estados, guards (aprobado/no aprobado/revocado),
      controllers con repos mockeados, expiración de códigos.

### E1 — Vínculo e invitaciones (e2e mínimo) 🔗

**HU-1.1** — Como *nutricionista*, quiero generar un código de invitación corto,
para dárselo a mi paciente en consulta (verbal, escrito o QR).
- CA: `POST /v1/pro/invites` devuelve código de 8 caracteres sin ambiguos
  (sin `0/O/1/I`), con expiración visible.
- CA: en el portal puedo ver mis invitaciones vigentes y su estado.

**HU-1.2** — Como *paciente*, quiero ingresar el código en la app y ver **quién**
me invita y **qué datos** va a ver, para aceptar con consentimiento informado.
- CA: en Perfil → "Mis nutricionistas" ingreso el código y veo una pantalla de
  consentimiento con: nombre del profesional y la lista explícita de lo que verá
  (comidas con fotos, agua, peso y medidas, metas) y lo que NO verá.
- CA: aceptar requiere acción afirmativa (botón primario); hay opción de rechazar.
- CA: código inválido/expirado muestra error claro y localizado (es/en).

**HU-1.3** — Como *paciente*, quiero ver **todos** mis vínculos activos y poder
revocar cada uno, para controlar exactamente quién ve mis datos.
- CA: "Mis nutricionistas" lista cada vínculo activo con nombre y fecha de
  vinculación — nunca puede existir un vínculo aceptado que no aparezca.
- CA: "Dejar de compartir" por vínculo, con confirmación (acción destructiva)
  y efecto inmediato.
- CA: sin vínculos, la sección muestra el estado vacío ("sin nutricionista")
  con la entrada para ingresar un código.

**HU-1.4** — Como *nutricionista*, quiero desvincular a un paciente que ya no
atiendo, para mantener mi lista limpia.
- CA: revocación desde el portal con confirmación; el paciente deja de aparecer.

Tareas iOS (`Features/Professional/`):
- [ ] Sección "Mis nutricionistas" en `ProfileView` (card, mismo patrón visual
      que Metas/Peso y medidas; ícono Lucide).
- [ ] `LinkNutritionistSheet`: campo de código + preview + pantalla de
      consentimiento; `MyNutritionistsView`: lista de vínculos activos +
      revocar por vínculo.
- [ ] `BackendClient`: DTOs y endpoints `/v1/me/professional-*`.
- [ ] Strings nuevos en `Localizable.xcstrings` (es tuteo + en desde el día 1 —
      no repetir la deuda de la Fase 1).
- [ ] Tests Swift Testing: validación/normalización del código (lógica pura),
      estados de la vista modelados como enum.
- [ ] `xcodegen generate` + build de verificación.

Tareas portal (mínimas en esta épica): registro + login + pantalla "Invitar
paciente".

### E2 — Portal del nutricionista, solo lectura 📊

> El grueso del valor. Diseñar con la skill `kpi-dashboard-design` ya instalada
> en el repo Angular.

**HU-2.1** — Como *nutricionista*, quiero iniciar sesión en un portal web, para
trabajar desde mi computador (patrón de mercado: pro en web).
- CA: registro con email+password (confirmación de email obligatoria) que deja
  la cuenta pendiente de aprobación; login; sesión persistida; guard de rutas;
  logout.
- CA: contraseña de 12 caracteres mínimo, validada en el formulario y en la
  config de Supabase Auth (misma regla en ambos lados).
- CA: un usuario no aprobado como profesional ve un estado "cuenta en revisión",
  no datos.

**HU-2.2** — Como *nutricionista*, quiero ver mi lista de pacientes con una señal
de actividad, para saber a quién priorizar.
- CA: lista con nombre, avatar y "última comida registrada hace X"; ordenada por
  actividad reciente; estados vacíos diseñados (sin pacientes / invitación
  pendiente).

**HU-2.3** — Como *nutricionista*, quiero ver la bitácora de un paciente con
fotos y macros por comida, para revisar su adherencia real entre consultas.
- CA: timeline agrupado por día (paginado keyset con "cargar más"); cada comida
  muestra foto (si hay), tipo (desayuno/almuerzo/…), alimentos con gramos y
  P/C/G, y totales del día vs. metas.
- CA: las fotos cargan con la sesión Supabase del profesional (política §2.5);
  si el vínculo se revoca, dejan de cargar.
- CA: incluye hidratación del día vs. meta.

**HU-2.4** — Como *nutricionista*, quiero ver la evolución de peso y medidas del
paciente, para evaluar el progreso.
- CA: gráfico de tendencia por métrica (peso, cintura, % grasa, …) con selector,
  y tabla histórica; distingue visualmente qué mediciones registró el
  profesional (`recordedBy`).

**HU-2.5** — Como *nutricionista*, quiero ver las metas vigentes del paciente
(kcal, macros, agua) y su perfil básico, para tener contexto en un vistazo.
- CA: card de metas + datos (sexo, edad, altura, peso actual, objetivo, país).

Tareas portal:
- [ ] Setup: `@supabase/supabase-js`, interceptor `Authorization: Bearer` hacia
      el backend, environments (URL backend), guard de rutas.
- [ ] i18n nativo (`@angular/localize`) desde el inicio: todos los strings
      marcados, locale fuente español neutro; el MVP compila solo el build es.
- [ ] Rutas: `/registro`, `/login`, `/pacientes`, `/pacientes/:id` (tabs Bitácora ·
      Mediciones · Metas), `/invitar`.
- [ ] Servicios API tipados (sin `any`) espejo de los DTOs del backend.
- [ ] Diseño con `kpi-dashboard-design`; colores de macros consistentes con la
      app (P verde, C ámbar, G azul).
- [ ] Tests de servicios y componentes clave (Karma/Jest según scaffold).
- [ ] CI simple del repo (lint + test + build) — este repo nace con gate.

### E3 — El profesional registra mediciones ✍️

**HU-3.1** — Como *nutricionista*, quiero registrar peso y medidas del paciente
durante la consulta, para que su histórico quede completo sin depender de él.
- CA: formulario con las mismas métricas y validaciones de rango que la app
  (peso, cintura, cadera, pecho, brazo, muslo, cuello, % grasa; al menos una).
- CA: la medición queda con `recordedBy = profesional` y aparece en el gráfico
  del portal de inmediato.
- CA: queda evento de auditoría `created_measurement`.

**HU-3.2** — Como *paciente*, quiero ver en mi app las mediciones que registró
mi nutricionista, para tener una sola fuente de verdad.
- CA: al volver a la app (scenePhase activo → sync), las mediciones remotas
  nuevas aparecen en "Peso y medidas" (dedup por `remoteID`, reutilizando la
  lógica de backfill extraída a función común).
- CA: una medición de peso del pro actualiza el peso del perfil igual que una
  propia (regla existente de `GoalsStore.updateWeight`).

Tareas:
- [ ] Backend: `POST /v1/pro/patients/:id/measurements` (+ `recorded_by` en el
      repo y DTOs de respuesta de ambos lados).
- [ ] iOS: **pull incremental de mediciones** en `SyncService` (hoy solo hay
      backfill inicial + push): en cada sync, traer la primera página y fusionar
      por `remoteID`. Extraer el merge a función pura testeable (de paso salda
      la deuda de testabilidad de la Fase 1).
- [ ] Portal: formulario en el tab Mediciones.
- [ ] Tests: merge de mediciones (Swift Testing), endpoint + repo (Jest).

### E4 — El profesional ajusta metas 🎯

**HU-4.1** — Como *nutricionista*, quiero ajustar las metas de kcal, macros y
agua del paciente, para alinear el plan a su tratamiento.
- CA: formulario con validaciones de rango espejo de la app; muestra el plan
  actual y el recomendado (Mifflin-St Jeor con los datos vigentes) como
  referencia.
- CA: guarda vía `PATCH /v1/pro/patients/:id/goals`; auditoría `updated_goals`.

**HU-4.2** — Como *paciente*, quiero enterarme cuando mi nutricionista cambió
mis metas, para no descubrirlo por sorpresa en el anillo de Hoy.
- CA: al sincronizar, si las metas remotas cambiaron desde fuera del dispositivo,
  se aplican localmente y aparece un aviso in-app ("Tu nutricionista actualizó
  tus metas") en Hoy/Metas.
- CA: sin ping-pong con el debounce de `pushProfileSnapshot`: una edición local
  posterior del paciente sigue mandando y ganando como hasta ahora (last write
  wins con `updated_at`; regla documentada en el código).

Tareas:
- [ ] Backend: DTO acotado de metas + use-case (cálculo recomendado se muestra
      client-side en el portal reutilizando la fórmula — puerto la lógica de
      `PlanCalculator` a TS o expongo los datos y calculo en Angular; decisión:
      **calcular en Angular**, es presentación, no dominio del backend).
- [ ] iOS: en el sync, comparar metas remotas vs. locales con `updatedAt`;
      aplicar + banner; test de la regla de merge (lógica pura).
- [ ] Portal: tab Metas editable.

### E5 — Próximos wins (backlog priorizado, post-MVP) 🚀

El backlog completo vive en **`NEXT-WINS.md`** (orden de valor/esfuerzo según
la investigación). Resumen: comentarios del pro en la bitácora, push (APNs),
digest por email, adherencia como KPI, permisos granulares del paciente,
planes de comida, chat, directorio + verificación de credenciales, cobros,
compliance Ley 21.719 y MFA para profesionales.

---

## 5. Orden de ejecución y hitos

| Hito | Contenido | Demo de salida |
|---|---|---|
| **M1** | E0 + E1 | Un pro (seed) genera código en el portal (pantalla mínima), el paciente lo acepta en la app iOS con consentimiento, el vínculo aparece en ambos lados, revocación funciona en ambos sentidos |
| **M2** | E2 | El nutricionista revisa bitácora con fotos, mediciones con gráfico y metas de un paciente real de prueba |
| **M3** | E3 + E4 | El pro registra una medición y ajusta metas; el iPhone las recibe en el siguiente sync con aviso |
| **M4** | Wins 1–4 de `NEXT-WINS.md` | Primer ciclo de feedback asíncrono pro→paciente |

Validar M1–M3 con **1–2 nutricionistas partner reales** antes de invertir en
los wins 6+ de `NEXT-WINS.md`.

Ramas y PRs por repo (regla del proyecto: nunca directo a `main`):
`feat/pro-links` (backend), `feat/mi-nutricionista` (iOS),
`feat/portal-mvp` (Angular). Commits atómicos, Conventional Commits.

---

## 6. Definition of Done (global, por PR)

- [ ] Tests nuevos/actualizados en verde (Jest backend, Swift Testing iOS,
      specs Angular) + linter.
- [ ] Migraciones aplicadas con dry-run previo y verificadas con `select`.
- [ ] iOS: `xcodegen generate` + build de verificación con los skip-flags.
- [ ] Sin secretos hardcodeados; env nuevas agregadas también al yaml de deploy
      (el `--env-vars-file` REEMPLAZA todo) y a `.env.example`.
- [ ] Strings de UI en es **y en** (String Catalog) — sin deuda de traducción.
- [ ] Endpoints `/v1/pro/*` con auditoría verificada en un e2e.
- [ ] Documentar decisiones no obvias en el código (el porqué, no el qué).

## 7. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| La policy de Storage por vínculo no funcione como se espera (RLS sobre `storage.objects`) | Probarla en M1 con el CLI de Supabase antes de construir la UI de fotos; plan B: signed URLs generadas por el backend (requiere key de storage server-side como env nueva) |
| Ping-pong de metas entre pro y debounce del paciente | Regla last-write-wins con `updated_at` + test dedicado del merge (HU-4.2) |
| Un pro con muchos pacientes vuelve pesadas las listas | Keyset ya resuelto; índice sobre `professional_links(professional_id, status)` |
| Datos sensibles expuestos a un pro tras revocación | Chequeo de vínculo por request (sin caché) + policy de Storage que evalúa estado actual + test e2e de revocación |
| Password de `foodia_backend` sigue expuesta (deuda Fase 1) | Rotación diferida a `NEXT-WINS.md` (win 12, con runbook) — decisión 2026-07-18; ejecutarla antes de tener usuarios reales |

