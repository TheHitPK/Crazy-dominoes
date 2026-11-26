-- Base de datos de Crazy Dominoes en Supabase.
-- Pégalo entero en Supabase → SQL Editor → New query → Run. Se puede volver a
-- ejecutar sin perder datos (solo crea lo que falte).
--
-- Solo el servidor del juego (Render) entra en esta tabla, con la clave
-- "service_role". Los teléfonos nunca hablan con Supabase: por eso RLS está
-- activado y sin políticas (con la clave pública "anon" no se ve nada).

create table if not exists public.players (
  id          uuid primary key default gen_random_uuid(),
  -- sha256 del token privado de cada instalación (ver scripts/cloud.gd).
  token_hash  text not null unique,
  name        text not null default 'Jugador',
  -- Ranked: temporada "AAAA-MM", puntos de clasificación y récord de la temporada.
  season      text not null default '',
  pr          integer not null default 0 check (pr >= 0),
  best        integer not null default 0,
  games       integer not null default 0,
  wins        integer not null default 0,
  streak      integer not null default 0,
  -- Monedas del premio de la temporada anterior, pendientes de recoger.
  reward      integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Tabla de clasificación: los mejores de cada temporada.
create index if not exists players_season_pr on public.players (season, pr desc);

alter table public.players enable row level security;
