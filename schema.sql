-- ═══════════════════════════════════════════════════════════════
-- CRONÓGRAFO @ale308win — Schema Supabase
-- ───────────────────────────────────────────────────────────────
-- Como usar:
--   1. Acesse supabase.com → seu projeto → SQL Editor
--   2. Clique em "New query"
--   3. Cole este arquivo inteiro e clique em "Run"
-- ═══════════════════════════════════════════════════════════════


-- ── PERFIS DE USUÁRIO ───────────────────────────────────────────
-- Complementa a tabela auth.users do Supabase
create table if not exists public.profiles (
  id                uuid references auth.users on delete cascade primary key,
  name              text not null default '',
  age               integer check (age between 14 and 99),
  email             text,
  experience        text,         -- tempo de prática no tiro
  how_found         text,         -- como conheceu a ferramenta
  follows_instagram boolean default false,
  consent_sharing   boolean not null default true,  -- LGPD: autoriza dados para base pública
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

comment on table  public.profiles                  is 'Perfil público dos usuários (complementa auth.users)';
comment on column public.profiles.consent_sharing  is 'Autorização LGPD para uso anônimo dos dados de recarga em base pública';
comment on column public.profiles.experience       is 'Tempo de prática: Menos de 1 ano | 1 a 3 anos | 3 a 5 anos | 5 a 10 anos | Mais de 10 anos | Instrutor / profissional';


-- ── SESSÕES DE CRONÓGRAFO ───────────────────────────────────────
create table if not exists public.sessions (
  id           uuid default gen_random_uuid() primary key,
  user_id      uuid references public.profiles(id) on delete cascade not null,

  -- Campos extraídos para busca e filtros rápidos (indexados)
  session_date date,
  caliber      text,
  city         text,
  state        text,    -- sigla: SP, MG, RJ, etc.
  club         text,
  weapon_type  text,
  shooter_name text,

  -- Todos os dados do formulário em JSON (flexível para versões futuras)
  session_data jsonb not null default '{}',

  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

comment on table  public.sessions              is 'Sessões de cronógrafo registradas pelos usuários';
comment on column public.sessions.session_data is 'JSON completo: identification, equipment, components, velocities, results, observations';


-- ── ÍNDICES PARA BUSCAS RÁPIDAS ─────────────────────────────────
create index if not exists idx_sessions_user   on public.sessions (user_id);
create index if not exists idx_sessions_date   on public.sessions (session_date desc);
create index if not exists idx_sessions_cal    on public.sessions (lower(caliber));
create index if not exists idx_sessions_state  on public.sessions (state);
create index if not exists idx_sessions_city   on public.sessions (lower(city));


-- ── ROW LEVEL SECURITY (RLS) ────────────────────────────────────
-- Cada usuário acessa APENAS os próprios dados
-- Alessandro usa o dashboard do Supabase (ou chave service_role) para ver tudo

alter table public.profiles enable row level security;
alter table public.sessions  enable row level security;

-- Perfis
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Sessões
create policy "sessions_select_own" on public.sessions
  for select using (auth.uid() = user_id);
create policy "sessions_insert_own" on public.sessions
  for insert with check (auth.uid() = user_id);
create policy "sessions_update_own" on public.sessions
  for update using (auth.uid() = user_id);
create policy "sessions_delete_own" on public.sessions
  for delete using (auth.uid() = user_id);


-- ── TRIGGER: atualiza updated_at automaticamente ─────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger trg_sessions_updated
  before update on public.sessions
  for each row execute function public.set_updated_at();


-- ── TRIGGER: cria perfil vazio após registro ─────────────────────
-- Garante que todo usuário novo já tenha uma linha em profiles
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_new_user
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ═══════════════════════════════════════════════════════════════
-- QUERIES PARA ALESSANDRO — EXTRAÇÃO DE DADOS
-- Execute no SQL Editor do Supabase com sua conta de admin
-- Ou use Table Editor → Export CSV
-- ═══════════════════════════════════════════════════════════════

-- Ver todos os dados de todos os usuários que consentiram:
/*
select
  p.name,
  p.age,
  p.experience,
  p.how_found,
  p.follows_instagram,
  s.session_date,
  s.caliber,
  s.city,
  s.state,
  s.club,
  s.weapon_type,
  s.shooter_name,
  s.session_data,
  s.created_at
from public.sessions s
join public.profiles p on p.id = s.user_id
where p.consent_sharing = true
order by s.session_date desc;
*/

-- Estatísticas gerais:
/*
select
  count(distinct p.id)  as total_usuarios,
  count(s.id)           as total_sessoes,
  count(distinct s.caliber) as calibres_distintos,
  min(s.session_date)   as primeira_sessao,
  max(s.session_date)   as ultima_sessao
from public.sessions s
join public.profiles p on p.id = s.user_id;
*/

-- Top calibres mais registrados:
/*
select caliber, count(*) as total
from public.sessions
group by caliber
order by total desc
limit 20;
*/

-- Usuários que seguem @ale308win no Instagram:
/*
select count(*) as seguidores_confirmados
from public.profiles
where follows_instagram = true;
*/
