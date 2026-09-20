# Sponsors Hub CT — Documentación del Proyecto

Portal de gestión de patrocinadores (sponsors) para eventos de **Colombia Tech Week**. Es una aplicación **Next.js 16** que embebe **Payload CMS 3** como backend/admin, con un panel de administración para el equipo interno (Customer Success) y un dashboard de cliente para cada sponsor.

## 1. Qué problema resuelve

Cada sponsor de un evento paga por un **Plan** (tier) que define beneficios (ítems a ejecutar por el equipo) y entregables (contenido que el sponsor debe subir: logos, textos, formularios, links, etc.). El sistema:

- Da de alta sponsors con acceso propio (login) a un dashboard donde ven su progreso.
- Clona automáticamente beneficios/entregables/reuniones desde el Plan y el Evento asignado hacia cada Sponsor.
- Mantiene sincronizados esos datos si el Plan o el Evento cambian después.
- Sube evidencias de cumplimiento (imágenes, documentos, texto, links) y sube entregables del propio sponsor.
- Envía notificaciones por correo (bienvenida, nueva evidencia, nuevo recurso/pieza) y dispara webhooks hacia **n8n** para sincronizar con Notion/Google Drive.

## 2. Stack técnico

| Capa | Tecnología |
|---|---|
| Framework | Next.js 16 (App Router, React 19) |
| CMS / Backend | Payload CMS 3.82 (`buildConfig`, colecciones, hooks, API REST + GraphQL) |
| Base de datos | PostgreSQL (`@payloadcms/db-postgres`), alojada en **Supabase** |
| Almacenamiento de archivos | S3-compatible (`@payloadcms/storage-s3`), apuntando al **Storage de Supabase** (`forcePathStyle: true`) |
| Editor de texto enriquecido | Lexical (`@payloadcms/richtext-lexical`) |
| Envío de correo | **Resend** (`resend` + plantillas en `@react-email/components`) |
| Automatización externa | **n8n** vía webhooks (sync Notion, reuniones, Google Drive) |
| UI | Tailwind CSS 4, shadcn/ui (Radix UI), lucide-react |
| Imágenes | `sharp` (procesamiento de uploads) |
| Testing | Vitest (integración) + Playwright (e2e) |
| Despliegue | Vercel (`vercel.json`, `.vercel/`) — también soporta Docker/`docker-compose` para desarrollo local |
| Lenguaje | TypeScript |

## 3. Servicios externos conectados

Definidos por variables de entorno (ver `.env`, no versionado; plantilla en `.env.example`):

| Variable | Servicio | Uso |
|---|---|---|
| `DATABASE_URL` | Supabase Postgres | Conexión principal de Payload (`db-postgres`) |
| `PAYLOAD_SECRET` | — | Secreto de firma de sesiones/JWT de Payload |
| `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION`, `S3_ENDPOINT` | Supabase Storage (S3-compatible) | Almacenamiento de la colección `media` (logos, PDFs, evidencias, entregables) |
| `RESEND_API_KEY` | Resend | Envío de emails transaccionales (bienvenida, evidencia, nuevo contenido) desde `hola@sponsor.colombiatechweek.co` |
| `N8N_WEBHOOK_URL` | n8n | Sincroniza datos del Sponsor (estrategia, contacto, eventos, planes, logo) hacia Notion al actualizar un Sponsor |
| `N8N_WEBHOOK_REUNIONES_URL` | n8n | Notifica actualización de reuniones de un Sponsor (solo envía `sponsorId`) |
| `N8N_WEBHOOK_DRIVE_URL` | n8n → Google Drive | Cuando se sube un entregable cuyo nombre contiene "logo", envía la URL del archivo para subirlo a Drive |

Notas de infraestructura:
- El despliegue productivo corre en **Vercel** bajo el dominio `sponsors-hub-ct.vercel.app` (usado como base para construir URLs absolutas de archivos en los webhooks).
- `docker-compose.yml` está pensado para desarrollo local con Mongo (plantilla original de Payload), aunque el proyecto real usa Postgres — ese archivo no refleja el estado actual del adaptador de base de datos.
- `Dockerfile` sigue el patrón estándar de despliegue standalone de Next.js.

## 4. Estructura del repositorio

```
sponsors-hub-ct/
├── src/
│   ├── payload.config.ts        # Configuración central de Payload (colecciones, DB, S3, admin UI)
│   ├── payload-types.ts         # Tipos TS autogenerados (payload generate:types)
│   ├── collections/             # Definición de colecciones (ver sección 5)
│   ├── emails/                  # Plantillas React Email (Welcome, EvidenceUploaded, NuevoContenido)
│   ├── hooks/                   # Hooks de React del frontend (use-mobile)
│   ├── lib/                     # Utilidades (cn/clsx helper)
│   ├── components/
│   │   ├── ui/                  # Componentes shadcn/ui (button, dialog, sidebar, etc.)
│   │   ├── admin/                # Componentes custom inyectados en el admin de Payload
│   │   └── *.tsx                 # Vistas y widgets del dashboard del sponsor
│   └── app/
│       ├── (frontend)/           # Rutas públicas: login (`/`) y dashboard del sponsor
│       │   └── dashboard/        # planes, entregables, reuniones, calendario, redes-sociales, documentos
│       ├── (payload)/            # Admin de Payload + API REST/GraphQL montada por Payload
│       │   └── api/duplicate-plan/  # Endpoint custom: duplica un Plan completo
│       └── api/recursos-globales/notify/  # Endpoint custom: notifica por email sobre un Recurso Global
├── tests/
│   ├── int/                     # Tests de integración (Vitest)
│   ├── e2e/                     # Tests end-to-end (Playwright): admin y frontend
│   └── helpers/                 # Helpers de login/seed de usuarios para tests
├── .cursor/rules/               # Guías de buenas prácticas de Payload CMS (para asistentes de código)
├── media/                       # Carpeta local de medios (posiblemente uploads antes de mover a S3)
├── middleware.ts                # Protección de rutas /dashboard vía cookie `payload-token`
├── next.config.ts               # withPayload + config de imágenes/webpack/turbopack
├── docker-compose.yml / Dockerfile
├── playwright.config.ts / vitest.config.mts
└── vercel.json                  # Config de funciones serverless (maxDuration, memory)
```

## 5. Colecciones de Payload (modelo de datos)

| Colección (slug) | Rol | Puntos clave |
|---|---|---|
| **users** | Usuarios internos del admin | `auth: { useAPIKey: true }`, sin campos extra (solo email por defecto) |
| **sponsors** | Cuenta de cada patrocinador | `auth: true` (login propio). Contiene datos de contacto, documentos/recursos, y `eventParticipations[]` (array con: evento, plan, estrategia, reuniones, entregables, ejecución de beneficios/evidencias, piezas de redes sociales). Es el corazón del sistema — ver sección 6 |
| **events** | Eventos (ediciones de Colombia Tech Week) | Fechas, identidad visual, ubicación, "journey" (momentos/ítems del calendario) y plantillas de reuniones que se clonan a cada sponsor asignado |
| **plans** | Planes/tiers de patrocinio | `benefits[]` con ítems y entregables exigidos (tipo, fecha límite, formulario vinculado, ítems relacionados). Botón custom "Duplicar Plan" en el admin |
| **forms** | Formularios dinámicos configurables | Campos con tipo (texto, número, fecha, selector, checkbox, imagen, link, email); genera `fieldKey` automáticamente desde el label |
| **piezas-redes-sociales** | Plantillas de piezas gráficas para RRSS | Formato (imagen/PDF/link), fecha/hora sugerida de publicación, copy sugerido |
| **recursos-globales** | Recursos compartidos asignables a varios sponsors a la vez | Al asignar/desasignar sponsors, sincroniza automáticamente el array `documents` de cada Sponsor. Incluye botón UI para notificar por email |
| **media** | Almacén de archivos (uploads) | Guardado en S3/Supabase Storage. Sanitiza nombres de archivo (sin tildes/ñ/espacios) y autocompleta el campo `alt` |

## 6. Automatizaciones clave (hooks de Payload)

- **`Sponsors.beforeChange`**: recalcula `eventsSummary`/`currentPlanName`, determina el evento "actual" (próximo o más reciente), clona `meetings` desde las plantillas del Evento y `deliverables`/`benefitItems` desde los `benefits` del Plan la primera vez que se asigna.
- **`processNotionEvidences`** (hook `beforeChange` de Sponsors): detecta evidencias tipo `link` que apuntan a URLs temporales de AWS/Notion, las descarga y las convierte en un documento `media` real (para que no expiren), conservando el link original.
- **`Sponsors.afterChange`**: dispara en cadena, salvo que `req.context.skipNotifications` esté activo:
  1. Email de bienvenida (Resend) al crear un sponsor, con la contraseña temporal capturada en el hook `beforeChange`.
  2. Email de "nueva evidencia" cuando se detecta un incremento de evidencias en algún `benefitItem`.
  3. Email de "nuevo recurso" o "nueva pieza de redes sociales" cuando crecen esos arrays.
  4. Webhook a `N8N_WEBHOOK_URL` con el perfil completo del sponsor (para sincronizar Notion).
  5. Webhook a `N8N_WEBHOOK_REUNIONES_URL` (solo `sponsorId`).
  6. Webhook a `N8N_WEBHOOK_DRIVE_URL` cuando se sube un entregable de "logo" (envía la URL pública del archivo).
- **`Plans.afterChange`**: al editar un plan, recorre todos los sponsors que lo tienen asignado y sincroniza (agrega/actualiza, sin pisar personalizaciones marcadas como `source: 'custom'`) sus `deliverables` y `benefitItems`.
- **`Events.afterChange`**: al editar un evento, "toca" (re-guarda) a todos los sponsors participantes para propagar cambios relacionados.
- **`RecursosGlobales.afterChange`**: sincroniza (de forma asíncrona, `setImmediate`) el array `documents` de los sponsors añadidos/removidos/actualizados en el recurso, usando `context.skipNotifications` para no disparar emails/webhooks de Sponsors en cascada.
- **`Media.beforeOperation` / `beforeChange`**: sanitiza el nombre del archivo subido (requisito de Supabase S3) y autocompleta `alt`.
- **`Forms.beforeChange`**: autogenera `fieldKey` (slug) desde el `label` de cada campo.

## 7. Endpoints custom (fuera del CRUD autogenerado de Payload)

- `POST /api/duplicate-plan` — duplica un Plan completo (limpia IDs internos) y le agrega el sufijo "(Copia)".
- `POST /api/recursos-globales/notify` — envía un email personalizado (Resend) a todos los sponsors asignados a un Recurso Global.
- `/(payload)/api/graphql` y `/api/graphql-playground` — API GraphQL de Payload.
- `/(payload)/api/[...slug]` — API REST autogenerada de Payload para todas las colecciones.

## 8. Frontend (dashboard del sponsor)

Rutas bajo `src/app/(frontend)/`:

- `/` — login del sponsor (`login-form.tsx`), redirige a `/dashboard` si ya hay cookie `payload-token`.
- `/dashboard` — resumen general (saludo, próximos hitos, estado del plan).
- `/dashboard/planes` — plan contratado y beneficios.
- `/dashboard/entregables` — roadmap de entregables a subir (con lógica de desbloqueo por fecha/secuencia).
- `/dashboard/reuniones` — reuniones agendadas/pendientes (Calendly).
- `/dashboard/calendario` — journey/calendario general del evento.
- `/dashboard/redes-sociales` — piezas de redes sociales asignadas.
- `/dashboard/documentos` — recursos y documentos asignados al sponsor.

Todas las páginas del dashboard son Server Components que leen la cookie `payload-token`, autentican contra Payload (`payload.auth`) y redirigen a `/` si no hay sesión válida. `middleware.ts` añade una capa extra de protección a nivel de ruta.

## 9. Panel de administración (Payload Admin)

Personalizado en `payload.config.ts`:
- Branding propio ("Colombia Tech"), logo/ícono custom (`payload-logo.tsx`).
- Vista `beforeDashboard`: saludo personalizado (`dashboard-greeting.tsx`).
- Vistas custom añadidas vía `admin.components.views`:
  - `/admin/entregables` (`EntregablesView`) — vista agregada de entregables de todos los sponsors.
  - `/admin/cs-dashboard` (`CSDashboardView`) — dashboard de Customer Success.
- Componentes de campo custom: `RelatedItemsPicker`, `SponsorRelatedItemsPicker`, `FormResponseViewer`, `DuplicatePlanButton`, `RecursosGlobalesNotify`, `ScrollToBottomButton`.
- Límite de subida de archivos: 25 MB por archivo (`upload.limits.fileSize`).

## 10. Testing

- **Integración** (`tests/int/api.int.spec.ts`, Vitest): contra la API local de Payload.
- **E2E** (`tests/e2e/*.spec.ts`, Playwright): flujos de admin y frontend.
- Helpers en `tests/helpers/` para login y seed de usuarios de prueba.
- Comandos: `pnpm test:int`, `pnpm test:e2e`, `pnpm test` (ambos).

## 11. Scripts principales (`package.json`)

| Script | Qué hace |
|---|---|
| `pnpm dev` | Levanta Next.js + Payload en desarrollo |
| `pnpm build` / `pnpm start` | Build y arranque de producción |
| `pnpm payload` | CLI de Payload |
| `pnpm generate:types` | Regenera `src/payload-types.ts` desde las colecciones |
| `pnpm generate:importmap` | Regenera el import map de componentes custom del admin |
| `pnpm lint` | ESLint |

## 12. Notas relevantes / puntos de atención

- El correo remitente de todas las notificaciones está *hardcodeado*: `Colombia Tech <hola@sponsor.colombiatechweek.co>` (requiere dominio verificado en Resend).
- La URL base usada para construir enlaces absolutos hacia n8n/Drive está *hardcodeada* como `https://sponsors-hub-ct.vercel.app` en `Sponsors.ts` — si cambia el dominio de producción, hay que actualizarla ahí.
- El campo `data.password` capturado en texto plano (`req.context.rawPassword`) solo vive en memoria durante el ciclo del hook, para poder incluir la contraseña temporal en el email de bienvenida; Payload la hashea antes de persistir.
- `docker-compose.yml` referencia Mongo, pero el adaptador real de base de datos configurado en `payload.config.ts` es Postgres — ese archivo quedó desactualizado respecto al stack real.
