-- Vista de estado de onboarding por sponsor.
-- "Completo" = logo + los 4 datos de contacto + los 3 campos de estrategia
-- de la participación marcada como actual (is_current = true).
--
-- Este archivo NO lo gestiona Payload (no es una colección/campo), así que
-- no interfiere con el push de schema de `npm run dev`. Es un objeto aparte
-- creado directamente en Postgres.
--
-- Uso:
--   psql "$DATABASE_URL" -f sql/onboarding-status-view.sql

CREATE OR REPLACE VIEW sponsors_onboarding_status AS
SELECT
  s.id,
  s.company_name,
  s.contact_info_corporate_email,

  (s.logo_id IS NOT NULL)                                        AS has_logo,
  (NULLIF(TRIM(s.contact_info_full_name), '') IS NOT NULL)        AS has_full_name,
  (NULLIF(TRIM(s.contact_info_whatsapp), '') IS NOT NULL)         AS has_whatsapp,
  (NULLIF(TRIM(s.contact_info_corporate_email), '') IS NOT NULL)  AS has_corporate_email,
  (NULLIF(TRIM(s.contact_info_linkedin), '') IS NOT NULL)         AS has_linkedin,
  (NULLIF(TRIM(ep.strategy_description), '') IS NOT NULL)         AS has_strategy_description,
  (NULLIF(TRIM(ep.strategy_event_objectives), '') IS NOT NULL)    AS has_strategy_objectives,
  (NULLIF(TRIM(ep.strategy_brand_differentiator), '') IS NOT NULL) AS has_strategy_differentiator,

  (
    s.logo_id IS NOT NULL
    AND NULLIF(TRIM(s.contact_info_full_name), '') IS NOT NULL
    AND NULLIF(TRIM(s.contact_info_whatsapp), '') IS NOT NULL
    AND NULLIF(TRIM(s.contact_info_corporate_email), '') IS NOT NULL
    AND NULLIF(TRIM(s.contact_info_linkedin), '') IS NOT NULL
    AND NULLIF(TRIM(ep.strategy_description), '') IS NOT NULL
    AND NULLIF(TRIM(ep.strategy_event_objectives), '') IS NOT NULL
    AND NULLIF(TRIM(ep.strategy_brand_differentiator), '') IS NOT NULL
  ) AS onboarding_completed

FROM sponsors s
LEFT JOIN sponsors_event_participations ep
  ON ep._parent_id = s.id AND ep.is_current = true;

-- Ejemplos de uso:

-- Resumen total:
-- SELECT
--   count(*) FILTER (WHERE onboarding_completed) AS completados,
--   count(*) FILTER (WHERE NOT onboarding_completed) AS incompletos
-- FROM sponsors_onboarding_status;

-- Listado de quiénes faltan y qué les falta:
-- SELECT company_name, has_logo, has_full_name, has_whatsapp,
--        has_corporate_email, has_linkedin, has_strategy_description,
--        has_strategy_objectives, has_strategy_differentiator
-- FROM sponsors_onboarding_status
-- WHERE NOT onboarding_completed
-- ORDER BY company_name;
