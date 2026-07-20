# Foodia — Próximos wins (backlog post-MVP de la Fase 2)

> Backlog priorizado por valor/esfuerzo según la investigación de competencia
> del 2026-07-18. Referenciado desde `PHASE-2.md` (§E5). Ningún ítem entra al
> MVP; se revisita tras validar M1–M3 con nutricionistas partner reales.

1. **Comentarios del profesional sobre entradas de la bitácora** — el feature de
   engagement n.º 1 del mercado (Healthie lo hace estilo feed con "visto" y
   notificación). Tabla `meal_comments`, endpoint bidireccional, burbuja en
   `MealDetailView`. Es la versión asíncrona (y suficiente) del chat.
2. **Push notifications (APNs)** — habilita el valor real de 1 y de HU-4.2
   ("tu nutricionista comentó/ajustó"). Infra nueva en backend (tokens de
   dispositivo, envío), entitlement ya disponible.
3. **Digest diario por email al profesional** (patrón FatSecret): resumen de
   qué pacientes registraron ayer y señales de alerta (0 registros en 3 días).
   Cloud Scheduler → endpoint + proveedor de email (Resend/SES). Barato y muy
   valorado; requiere decidir proveedor de email.
4. **Adherencia como KPI en el portal**: % de días con registro, racha, semáforo
   en la lista de pacientes (los datos ya están; es cálculo + UI).
5. **Permisos granulares del paciente** (patrón MyNetDiary/Healthie): elegir
   rango de fechas compartido, ocultar peso (modo sensible tipo TCA de Healthie).
6. **Planes de comida asignables** — el feature por el que las plataformas pro
   cobran (NutriAdmin/Avena). Dominio nuevo completo (plan, comidas, vista en
   iOS). Grande: solo tras validar el MVP con partners reales.
7. **Chat 1:1** (Supabase Realtime) — solo si los comentarios (1) se quedan
   cortos con partners reales.
8. **Directorio de profesionales + verificación de credenciales** — cuando haya
   más de un puñado de partners.
9. **Cobros al profesional** (suscripción por volumen, patrón dominante) —
   decisión de negocio + Stripe; recién cuando el valor esté probado.
10. **Compliance formal Ley 21.719**: EIPD documentada, export de datos del
    paciente incluyendo accesos de profesionales, retención de auditoría.
    Deadline duro: **1-dic-2026**.
11. **MFA (TOTP) y endurecimiento de cuentas profesionales** — una cuenta pro
    comprometida expone a toda su cartera de pacientes; Supabase soporta TOTP
    nativo. Incluye activar la protección contra contraseñas filtradas (chequeo
    HaveIBeenPwned, toggle de Supabase Auth). Esfuerzo bajo: puede adelantarse
    en cuanto haya más de un puñado de pros. Decisión 2026-07-18: fuera del MVP.
12. **Rotar la password del rol `foodia_backend`** — deuda de la Fase 1: quedó
    visible en un transcript local, se considera quemada. La exposición real es
    baja (archivo en la máquina del usuario), pero la password es la única
    barrera del pooler público (Supavisor 6543): **ejecutar antes de tener
    usuarios reales**. Runbook (~15 min, corte de ~2 min; pasos 1-3 fuera de
    cualquier chat para no re-exponerla): (1) generar password ~32 caracteres
    solo alfanuméricos; (2) actualizar el secret `DATABASE_URL` en GitHub
    Actions del backend; (3) `alter role foodia_backend with password '…'` en
    el SQL Editor de Supabase; (4) redeploy por pipeline con "Run workflow"
    (`workflow_dispatch`); (5) actualizar el `.env` local; (6) smoke test
    contra el servicio. Decisión 2026-07-18: no bloquea M1.
