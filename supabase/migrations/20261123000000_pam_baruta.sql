-- =====================================================================
-- PAM Baruta · Base de datos en Supabase (alternativa a Google Sheets)
-- ---------------------------------------------------------------------
-- Replica en Postgres lo mismo que hace google-sheets/Code.gs:
-- mismas acciones, mismas reglas de Signo y las mismas respuestas.
-- El sitio habla con una sola función, pam_api(req), igual que hablaba con /exec.
--
-- Seguridad:
--   * Todas las tablas tienen RLS activo y NINGUNA política: con la clave pública
--     (anon / publishable) nadie puede leer ni escribir las tablas directamente.
--   * La única puerta es pam_api(), que valida la sesión del admin en cada acción
--     privada y nunca devuelve datos completos de una persona a una consulta pública.
--   * La clave del admin se guarda solo como huella SHA-256 en la tabla config.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- Tablas ----------
create table if not exists public.config (
  clave text primary key,
  valor text not null default '',
  nota  text not null default ''
);

create table if not exists public.afiliados (
  token_afiliado text primary key,
  rol text not null,                               -- TITULAR | DEPENDIENTE
  tipo_documento text not null,
  nro_documento text not null,
  nombres text not null default '',
  apellidos text not null default '',
  genero text not null default '',
  fecha_nacimiento text not null default '',       -- DD/MM/AAAA, igual que en la hoja
  telefono text not null default '',
  parentesco text not null default '',
  parentesco_texto text not null default '',
  tipo_documento_titular text not null default '',
  nro_documento_titular text not null default '',
  token_registro text not null default '',
  creado text not null,
  actualizado text not null,
  unique (tipo_documento, nro_documento)
);

create table if not exists public.registros (
  n bigserial,
  token_registro text primary key,
  fecha_registro text not null,
  token_afiliado text not null,
  lo_llena text not null default '',
  tipo_documento text not null,
  nro_documento text not null,
  nombres text not null default '',
  apellidos text not null default '',
  fecha_nacimiento text not null default '',
  genero text not null default '',
  telefono text not null default '',
  correo text not null default '',
  direccion text not null default '',
  urbanizacion_sector text not null default '',
  nro_familiares int not null default 0,
  estado_signo text not null default 'Pendiente',
  datos jsonb not null default '{}'::jsonb         -- el formulario completo (salud, emergencia, familiares…)
);

-- Columnas 1 a 15 = plantilla de carga masiva de Signo (pestaña DATOS), en el mismo orden.
create table if not exists public.signo (
  n bigserial,
  tipo_documento text not null,
  nro_documento text not null,
  nombres text not null default '',
  apellidos text not null default '',
  genero text not null default '',
  fecha_nacimiento text not null default '',
  nro_afiliacion text not null default '',
  rif_company text not null default '',
  nombre_company text not null default '',
  fecha_inicio text not null default '',
  fecha_fin text not null default '',
  nro_documento_titular text not null default '',
  tipo_documento_titular text not null default '',
  parentesco text not null default '',
  tlf text not null default '',
  estado_carga text not null default 'Pendiente',  -- control interno: no va a Signo
  token_afiliado text not null default '',
  actualizado text not null default '',
  primary key (tipo_documento, nro_documento)
);

create table if not exists public.eventos (
  n bigserial,
  id text primary key,
  titulo text not null default '',
  categoria text not null default '',
  fecha text not null default '',                  -- AAAA-MM-DD
  hora text not null default '',                   -- HH:MM
  fin text not null default '',
  lugar text not null default '',
  sector text not null default '',
  cupos int,
  estado text not null default 'borrador',
  instagram text not null default '',
  imagen text not null default '',
  descripcion text not null default '',
  creado text not null default ''
);

create table if not exists public.inscripciones (
  n bigserial,
  token_inscripcion text primary key,
  evento_id text not null,
  evento_titulo text not null default '',
  evento_fecha text not null default '',
  fecha_inscripcion text not null,
  token_afiliado text not null,
  tipo_documento text not null,
  nro_documento text not null,
  nombre text not null default '',
  telefono text not null default ''
);
create index if not exists inscripciones_evento_idx on public.inscripciones (evento_id);

create table if not exists public.tips (
  n bigserial,
  id text primary key,
  titulo text not null default '',
  categoria text not null default '',
  resumen text not null default '',
  contenido text not null default '',
  publicado boolean not null default false,
  fecha text not null default '',
  instagram text not null default '',
  imagen text not null default ''
);

create table if not exists public.avisos (
  n bigserial,
  id text primary key,
  tipo text not null default 'aviso',
  titulo text not null default '',
  mensaje text not null default '',
  link text not null default '',
  fecha text not null
);

create table if not exists public.sesiones (
  token text primary key,
  vence timestamptz not null
);

-- RLS sin políticas: solo pam_api() (security definer) toca las tablas.
alter table public.config        enable row level security;
alter table public.afiliados     enable row level security;
alter table public.registros     enable row level security;
alter table public.signo         enable row level security;
alter table public.eventos       enable row level security;
alter table public.inscripciones enable row level security;
alter table public.tips          enable row level security;
alter table public.avisos        enable row level security;
alter table public.sesiones      enable row level security;

insert into public.config (clave, valor, nota) values
  ('rif_company', '', 'RIF de la póliza PAM Baruta en Signo (POR CONFIRMAR). Va en la columna rif_company.'),
  ('nombre_company', 'PAM BARUTA', 'Nombre de la empresa como lo pide Signo (POR CONFIRMAR).'),
  ('vigencia_meses', '12', 'Signo acepta máximo 1 año: fecha_fin = fecha_inicio + 12 meses − 1 día.'),
  ('admin_usuario', 'admin', 'Usuario del panel admin.'),
  ('admin_clave_sha256', '', 'Huella SHA-256 de la clave. Se define con: select pam_cambiar_clave(''la clave'');')
on conflict (clave) do nothing;

-- ---------- Utilidades ----------
create or replace function public.pam_cfg(k text) returns text
language sql stable security definer set search_path = public as
$$ select coalesce((select valor from public.config where clave = k), '') $$;

create or replace function public.pam_ahora() returns text
language sql stable as
$$ select to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') $$;

create or replace function public.pam_hoy() returns text
language sql stable as
$$ select to_char(now() at time zone 'America/Caracas', 'YYYY-MM-DD') $$;

create or replace function public.pam_norm_doc(tipo text, nro text) returns text
language sql immutable as
$$ select case when tipo = 'PASSPORT' then upper(regexp_replace(coalesce(nro, ''), '\s', '', 'g'))
               else regexp_replace(coalesce(nro, ''), '\D', '', 'g') end $$;

create or replace function public.pam_solo_num(t text) returns text
language sql immutable as $$ select regexp_replace(coalesce(t, ''), '\D', '', 'g') $$;

create or replace function public.pam_mayus(t text) returns text
language sql immutable as $$ select upper(btrim(coalesce(t, ''))) $$;

create or replace function public.pam_ddmmaaaa(iso text) returns text
language sql immutable as
$$ select case when coalesce(iso, '') ~ '^\d{4}-\d{2}-\d{2}$'
               then substr(iso, 9, 2) || '/' || substr(iso, 6, 2) || '/' || substr(iso, 1, 4) else coalesce(iso, '') end $$;

create or replace function public.pam_genero(sx text) returns text
language sql immutable as
$$ select case sx when 'Femenino' then 'F' when 'Masculino' then 'M' else '' end $$;

create or replace function public.pam_parentesco_texto(p text) returns text
language sql immutable as
$$ select case p when 'SPOUSE' then 'Cónyuge' when 'CHILD' then 'Hijo/a' when 'PARENTS' then 'Padre o madre'
                 when 'IN_LAW' then 'Suegro/a' else 'Otro familiar' end $$;

create or replace function public.pam_primer_nombre(s text) returns text
language sql immutable as
$$ select initcap(lower(split_part(btrim(coalesce(s, '')), ' ', 1))) $$;

create or replace function public.pam_fecha_larga(iso text) returns text
language sql immutable as
$$ select (array['domingo','lunes','martes','miércoles','jueves','viernes','sábado'])[extract(dow from iso::date)::int + 1]
          || ' ' || extract(day from iso::date)::int || ' de '
          || (array['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'])[extract(month from iso::date)::int] $$;

create or replace function public.pam_hora12(h text) returns text
language sql immutable as
$$ select case when coalesce(h, '') = '' then '' else
     (case when split_part(h, ':', 1)::int % 12 = 0 then 12 else split_part(h, ':', 1)::int % 12 end)::text
     || ':' || lpad(split_part(h, ':', 2), 2, '0') || case when split_part(h, ':', 1)::int >= 12 then ' pm' else ' am' end end $$;

-- Códigos: alfabeto sin 0/O/1/I para dictarlos por teléfono
create or replace function public.pam_rand(n int) returns text
language plpgsql volatile as $$
declare abc text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; b bytea := extensions.gen_random_bytes(n); s text := '';
begin
  for i in 0 .. n - 1 loop s := s || substr(abc, (get_byte(b, i) % 32) + 1, 1); end loop;
  return s;
end $$;

create or replace function public.pam_token(tipo text) returns text
language plpgsql volatile security definer set search_path = public as $$
declare t text;
begin
  loop
    if tipo = 'U' then t := 'PAM-U-' || pam_rand(4) || '-' || pam_rand(4);
    else t := 'PAM-' || tipo || '-' || to_char(now() at time zone 'America/Caracas', 'YYMMDD') || '-' || pam_rand(6); end if;
    exit when not exists (select 1 from afiliados where token_afiliado = t)
          and not exists (select 1 from registros where token_registro = t)
          and not exists (select 1 from inscripciones where token_inscripcion = t);
  end loop;
  return t;
end $$;

create or replace function public.pam_id(prefijo text) returns text
language sql volatile as
$$ select prefijo || lower(to_hex((extract(epoch from clock_timestamp()) * 1000)::bigint)) || substr(md5(random()::text), 1, 3) $$;

create or replace function public.pam_sesion_valida(t text) returns boolean
language sql stable security definer set search_path = public as
$$ select coalesce(t, '') <> '' and exists (select 1 from sesiones where token = t and vence > now()) $$;

create or replace function public.pam_aviso(a jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare r avisos;
begin
  insert into avisos (id, tipo, titulo, mensaje, link, fecha)
  values (coalesce(nullif(a->>'id', ''), pam_id('av')), coalesce(nullif(a->>'tipo', ''), 'aviso'), coalesce(a->>'titulo', ''),
          coalesce(a->>'mensaje', ''), coalesce(a->>'link', ''), pam_ahora())
  returning * into r;
  return to_jsonb(r) - 'n';
end $$;

-- ---------- Registro de afiliados ----------
create or replace function public.pam_upsert_afiliado(p jsonb, rol text, titular jsonb, tok_reg text, ahora text) returns text
language plpgsql volatile security definer set search_path = public as $$
declare ex afiliados; tel text := pam_solo_num(p->>'telefono'); par text := coalesce(nullif(p->>'parentesco', ''), 'OTHERS');
begin
  select * into ex from afiliados where tipo_documento = p->>'tipo_documento' and nro_documento = p->>'nro_documento';
  if found then
    -- Un titular que luego aparece como familiar de otro sigue siendo titular
    if ex.rol = 'TITULAR' and rol = 'DEPENDIENTE' then return ex.token_afiliado; end if;
    update afiliados set rol = pam_upsert_afiliado.rol, nombres = p->>'nombre', apellidos = p->>'apellidos',
      genero = pam_genero(p->>'sexo'), fecha_nacimiento = pam_ddmmaaaa(p->>'nacimiento'),
      telefono = case when tel = '' then ex.telefono else tel end,
      parentesco = case when titular is null then '' else par end,
      parentesco_texto = case when titular is null then '' else pam_parentesco_texto(par) end,
      tipo_documento_titular = coalesce(titular->>'tipo_documento', ''), nro_documento_titular = coalesce(titular->>'nro_documento', ''),
      token_registro = tok_reg, actualizado = ahora
    where token_afiliado = ex.token_afiliado;
    return ex.token_afiliado;
  end if;
  insert into afiliados values (pam_token('U'), rol, p->>'tipo_documento', p->>'nro_documento', p->>'nombre', p->>'apellidos',
    pam_genero(p->>'sexo'), pam_ddmmaaaa(p->>'nacimiento'), tel,
    case when titular is null then '' else par end, case when titular is null then '' else pam_parentesco_texto(par) end,
    coalesce(titular->>'tipo_documento', ''), coalesce(titular->>'nro_documento', ''), tok_reg, ahora, ahora);
  return (select token_afiliado from afiliados where tipo_documento = p->>'tipo_documento' and nro_documento = p->>'nro_documento');
end $$;

create or replace function public.pam_upsert_signo(o jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  insert into signo (tipo_documento, nro_documento, nombres, apellidos, genero, fecha_nacimiento, nro_afiliacion, rif_company, nombre_company,
                     fecha_inicio, fecha_fin, nro_documento_titular, tipo_documento_titular, parentesco, tlf, estado_carga, token_afiliado, actualizado)
  values (o->>'tipo_documento', o->>'nro_documento', o->>'nombres', o->>'apellidos', o->>'genero', o->>'fecha_nacimiento', '',
          o->>'rif_company', o->>'nombre_company', o->>'fecha_inicio', o->>'fecha_fin', o->>'nro_documento_titular',
          o->>'tipo_documento_titular', o->>'parentesco', o->>'tlf', 'Pendiente', o->>'token_afiliado', o->>'actualizado')
  on conflict (tipo_documento, nro_documento) do update set
    nombres = excluded.nombres, apellidos = excluded.apellidos, genero = excluded.genero, fecha_nacimiento = excluded.fecha_nacimiento,
    rif_company = excluded.rif_company, nombre_company = excluded.nombre_company, fecha_inicio = excluded.fecha_inicio, fecha_fin = excluded.fecha_fin,
    nro_documento_titular = excluded.nro_documento_titular, tipo_documento_titular = excluded.tipo_documento_titular,
    parentesco = excluded.parentesco, tlf = excluded.tlf, estado_carga = 'Pendiente', token_afiliado = excluded.token_afiliado,
    actualizado = excluded.actualizado;
end $$;

create or replace function public.pam_registrar(d jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  ahora text := pam_ahora(); tok_reg text; tok_tit text; deps jsonb := '[]'::jsonb; p jsonb; out_deps jsonb := '[]'::jsonb;
  ini date := (now() at time zone 'America/Caracas')::date; fin date; base jsonb; tdoc text; tok text;
begin
  if d is null or coalesce(d->>'nro_documento', '') = '' then raise exception 'Faltan datos del registro.'; end if;
  perform pg_advisory_xact_lock(911);
  tdoc := coalesce(nullif(d->>'tipo_documento', ''), 'NATIONAL_ID');
  d := d || jsonb_build_object('tipo_documento', tdoc, 'nro_documento', pam_norm_doc(tdoc, d->>'nro_documento'),
                               'nombre', pam_mayus(d->>'nombre'), 'apellidos', pam_mayus(d->>'apellidos'));
  for p in select * from jsonb_array_elements(coalesce(d->'dependientes', '[]'::jsonb)) loop
    tdoc := coalesce(nullif(p->>'tipo_documento', ''), 'NATIONAL_ID');
    p := p || jsonb_build_object('tipo_documento', tdoc, 'nro_documento', pam_norm_doc(tdoc, p->>'nro_documento'),
                                 'nombre', pam_mayus(p->>'nombre'), 'apellidos', pam_mayus(p->>'apellidos'),
                                 'parentesco', case when p->>'parentesco' in ('SPOUSE','CHILD','PARENTS','IN_LAW','OTHERS') then p->>'parentesco'
                                                    when coalesce(p->>'parentesco', '') = '' then '' else 'OTHERS' end);
    deps := deps || jsonb_build_array(p);
  end loop;

  tok_reg := pam_token('R');
  tok_tit := pam_upsert_afiliado(d, 'TITULAR', null, tok_reg, ahora);
  for p in select * from jsonb_array_elements(deps) loop
    tok := pam_upsert_afiliado(p, 'DEPENDIENTE', d, tok_reg, ahora);
    out_deps := out_deps || jsonb_build_array(p || jsonb_build_object('token', tok));
  end loop;
  d := d || jsonb_build_object('dependientes', out_deps);

  insert into registros (token_registro, fecha_registro, token_afiliado, lo_llena, tipo_documento, nro_documento, nombres, apellidos,
    fecha_nacimiento, genero, telefono, correo, direccion, urbanizacion_sector, nro_familiares, estado_signo, datos)
  values (tok_reg, ahora, tok_tit, coalesce(d->>'para', ''), d->>'tipo_documento', d->>'nro_documento', d->>'nombre', d->>'apellidos',
    pam_ddmmaaaa(d->>'nacimiento'), pam_genero(d->>'sexo'), pam_solo_num(d->>'telefono'), coalesce(d->>'correo', ''),
    coalesce(d->>'direccion', ''), coalesce(d->>'sector', ''), jsonb_array_length(out_deps), 'Pendiente', d);

  -- Signo: una fila por persona, vigencia de 1 año menos 1 día
  fin := (ini + make_interval(months => coalesce(nullif(pam_cfg('vigencia_meses'), '')::int, 12)) - interval '1 day')::date;
  base := jsonb_build_object('rif_company', pam_cfg('rif_company'), 'nombre_company', pam_cfg('nombre_company'),
    'fecha_inicio', to_char(ini, 'DD/MM/YYYY'), 'fecha_fin', to_char(fin, 'DD/MM/YYYY'), 'actualizado', ahora);
  perform pam_upsert_signo(base || jsonb_build_object('tipo_documento', d->>'tipo_documento', 'nro_documento', d->>'nro_documento',
    'nombres', d->>'nombre', 'apellidos', d->>'apellidos', 'genero', pam_genero(d->>'sexo'), 'fecha_nacimiento', pam_ddmmaaaa(d->>'nacimiento'),
    'nro_documento_titular', '', 'tipo_documento_titular', '', 'parentesco', '', 'tlf', pam_solo_num(d->>'telefono'), 'token_afiliado', tok_tit));
  for p in select * from jsonb_array_elements(out_deps) loop
    -- Si el familiar ya es titular por su cuenta, conserva su fila de titular
    if exists (select 1 from afiliados where token_afiliado = p->>'token' and rol = 'TITULAR') then continue; end if;
    perform pam_upsert_signo(base || jsonb_build_object('tipo_documento', p->>'tipo_documento', 'nro_documento', p->>'nro_documento',
      'nombres', p->>'nombre', 'apellidos', p->>'apellidos', 'genero', pam_genero(p->>'sexo'), 'fecha_nacimiento', pam_ddmmaaaa(p->>'nacimiento'),
      'nro_documento_titular', d->>'nro_documento', 'tipo_documento_titular', d->>'tipo_documento',
      'parentesco', coalesce(nullif(p->>'parentesco', ''), 'OTHERS'), 'tlf', pam_solo_num(p->>'telefono'), 'token_afiliado', p->>'token'));
  end loop;

  return jsonb_build_object('userToken', tok_tit, 'regToken', tok_reg,
    'deps', coalesce((select jsonb_agg(jsonb_build_object('nombre', x->>'nombre', 'token', x->>'token')) from jsonb_array_elements(out_deps) x), '[]'::jsonb));
end $$;

-- ---------- Eventos, inscripciones y tips ----------
create or replace function public.pam_inscribir(ev_id text, r jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare ev eventos; a afiliados; ya inscripciones; n int; t text; tdoc text := coalesce(nullif(r->>'tipo_documento', ''), 'NATIONAL_ID');
begin
  perform pg_advisory_xact_lock(911);
  select * into ev from eventos where id = ev_id;
  if not found then raise exception 'El evento ya no está disponible.'; end if;
  select * into a from afiliados where tipo_documento = tdoc and nro_documento = pam_norm_doc(tdoc, r->>'nro_documento');
  if not found then return jsonb_build_object('estado', 'no_registrado'); end if;
  select * into ya from inscripciones where evento_id = ev_id and token_afiliado = a.token_afiliado;
  if found then return jsonb_build_object('estado', 'ya_inscrito', 'token', ya.token_inscripcion, 'nombre', a.nombres); end if;
  select count(*) into n from inscripciones where evento_id = ev_id;
  if ev.cupos is not null and ev.cupos > 0 and n >= ev.cupos then return jsonb_build_object('estado', 'sin_cupos'); end if;
  t := pam_token('E');
  insert into inscripciones values (default, t, ev_id, ev.titulo, ev.fecha, pam_ahora(), a.token_afiliado, a.tipo_documento, a.nro_documento,
    a.nombres || ' ' || a.apellidos, coalesce(nullif(pam_solo_num(r->>'telefono'), ''), a.telefono));
  return jsonb_build_object('estado', 'ok', 'token', t, 'nombre', a.nombres);
end $$;

create or replace function public.pam_evento_json(e eventos) returns jsonb
language sql stable security definer set search_path = public as
$$ select (to_jsonb(e) - 'n') || jsonb_build_object('cupos', coalesce(to_jsonb(e.cupos), '""'::jsonb),
          'inscritos', (select count(*) from inscripciones i where i.evento_id = e.id)) $$;

create or replace function public.pam_guardar_evento(ev jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare old eventos; nu eventos; cambios text[] := '{}'; m text; cup int := nullif(regexp_replace(coalesce(ev->>'cupos', ''), '\D', '', 'g'), '')::int;
begin
  if coalesce(ev->>'id', '') = '' then
    insert into eventos (id, titulo, categoria, fecha, hora, fin, lugar, sector, cupos, estado, instagram, imagen, descripcion, creado)
    values (pam_id('ev'), coalesce(ev->>'titulo', ''), coalesce(ev->>'categoria', ''), coalesce(ev->>'fecha', ''), coalesce(ev->>'hora', ''),
            coalesce(ev->>'fin', ''), coalesce(ev->>'lugar', ''), coalesce(ev->>'sector', ''), cup, coalesce(nullif(ev->>'estado', ''), 'borrador'),
            coalesce(ev->>'instagram', ''), coalesce(ev->>'imagen', ''), coalesce(ev->>'descripcion', ''), pam_ahora())
    returning * into nu;
    if nu.estado = 'publicado' then
      perform pam_aviso(jsonb_build_object('tipo', 'evento', 'titulo', 'Nueva jornada: ' || nu.titulo,
        'mensaje', pam_fecha_larga(nu.fecha) || ' · ' || pam_hora12(nu.hora) || ' · ' || nu.lugar || '. ¡Inscríbete!', 'link', 'eventos.html#' || nu.id));
    end if;
    return pam_evento_json(nu);
  end if;
  select * into old from eventos where id = ev->>'id';
  if not found then raise exception 'El evento ya no existe.'; end if;
  update eventos set
    titulo = coalesce(ev->>'titulo', titulo), categoria = coalesce(ev->>'categoria', categoria), fecha = coalesce(ev->>'fecha', fecha),
    hora = coalesce(ev->>'hora', hora), fin = coalesce(ev->>'fin', fin), lugar = coalesce(ev->>'lugar', lugar), sector = coalesce(ev->>'sector', sector),
    cupos = case when ev ? 'cupos' then cup else cupos end, estado = coalesce(nullif(ev->>'estado', ''), estado),
    instagram = coalesce(ev->>'instagram', instagram), imagen = coalesce(ev->>'imagen', imagen), descripcion = coalesce(ev->>'descripcion', descripcion)
  where id = old.id returning * into nu;
  if old.fecha <> nu.fecha then cambios := cambios || ('nueva fecha: ' || pam_fecha_larga(nu.fecha)); end if;
  if old.hora <> nu.hora then cambios := cambios || ('nueva hora: ' || pam_hora12(nu.hora)); end if;
  if old.lugar <> nu.lugar then cambios := cambios || ('nuevo lugar: ' || nu.lugar); end if;
  if nu.estado = 'publicado' and old.estado <> 'publicado' then
    perform pam_aviso(jsonb_build_object('tipo', 'evento', 'titulo', 'Nueva jornada: ' || nu.titulo,
      'mensaje', pam_fecha_larga(nu.fecha) || ' · ' || pam_hora12(nu.hora) || ' · ' || nu.lugar || '. ¡Inscríbete!', 'link', 'eventos.html#' || nu.id));
  elsif nu.estado = 'publicado' and array_length(cambios, 1) > 0 then
    m := array_to_string(cambios, ' · ');
    perform pam_aviso(jsonb_build_object('tipo', 'cambio', 'titulo', 'Cambio en: ' || nu.titulo,
      'mensaje', upper(left(m, 1)) || substr(m, 2) || '.', 'link', 'eventos.html#' || nu.id));
  end if;
  return pam_evento_json(nu);
end $$;

create or replace function public.pam_borrar_evento(ev_id text) returns boolean
language plpgsql volatile security definer set search_path = public as $$
declare ev eventos;
begin
  delete from eventos where id = ev_id returning * into ev;
  if found and ev.estado = 'publicado' and ev.fecha >= pam_hoy() then
    perform pam_aviso(jsonb_build_object('tipo', 'cancelado', 'titulo', 'Evento cancelado: ' || ev.titulo,
      'mensaje', 'La actividad del ' || pam_fecha_larga(ev.fecha) || ' no se realizará. Disculpa las molestias.', 'link', 'eventos.html'));
  end if;
  return true;
end $$;

create or replace function public.pam_guardar_tip(t jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare pub boolean := coalesce((t->>'publicado')::boolean, false); old tips; nu tips;
begin
  if coalesce(t->>'id', '') = '' then
    insert into tips (id, titulo, categoria, resumen, contenido, publicado, fecha, instagram, imagen)
    values (pam_id('tp'), coalesce(t->>'titulo', ''), coalesce(t->>'categoria', ''), coalesce(t->>'resumen', ''), coalesce(t->>'contenido', ''),
            pub, coalesce(nullif(t->>'fecha', ''), pam_hoy()), coalesce(t->>'instagram', ''), coalesce(t->>'imagen', ''))
    returning * into nu;
    if pub then perform pam_aviso(jsonb_build_object('tipo', 'tip', 'titulo', 'Nuevo consejo: ' || nu.titulo, 'mensaje', nu.resumen, 'link', 'tips.html#' || nu.id)); end if;
    return to_jsonb(nu) - 'n';
  end if;
  select * into old from tips where id = t->>'id';
  if not found then raise exception 'El tip ya no existe.'; end if;
  update tips set titulo = coalesce(t->>'titulo', titulo), categoria = coalesce(t->>'categoria', categoria), resumen = coalesce(t->>'resumen', resumen),
    contenido = coalesce(t->>'contenido', contenido), publicado = pub, fecha = coalesce(nullif(t->>'fecha', ''), fecha),
    instagram = coalesce(t->>'instagram', instagram), imagen = coalesce(t->>'imagen', imagen)
  where id = old.id returning * into nu;
  if pub and not old.publicado then
    perform pam_aviso(jsonb_build_object('tipo', 'tip', 'titulo', 'Nuevo consejo: ' || nu.titulo, 'mensaje', nu.resumen, 'link', 'tips.html#' || nu.id));
  end if;
  return to_jsonb(nu) - 'n';
end $$;

-- ---------- La API que usa el sitio ----------
-- Recibe { action, auth, ...datos } y responde { ok, data } o { ok: false, error, code }, igual que Code.gs.
create or replace function public.pam_api(req jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  act text := coalesce(req->>'action', ''); auth text := req->>'auth'; adm boolean; data jsonb; a afiliados; t text;
  privadas text[] := array['resumen','registros','inscritos','guardarEvento','borrarEvento','guardarTip','borrarTip','crearAviso','borrarAviso','signo','marcarSignoCargado'];
begin
  adm := pam_sesion_valida(auth);
  if act = any(privadas) and not adm then
    return jsonb_build_object('ok', false, 'error', 'Sesión vencida', 'code', 'auth');
  end if;

  case act
    when 'ping' then data := jsonb_build_object('version', 'supabase-1.0', 'hora', pam_ahora());

    when 'buscar' then   -- nunca devuelve datos personales completos
      select * into a from afiliados where tipo_documento = coalesce(nullif(req->>'tipo_documento', ''), 'NATIONAL_ID')
        and nro_documento = pam_norm_doc(coalesce(nullif(req->>'tipo_documento', ''), 'NATIONAL_ID'), req->>'nro_documento');
      data := case when found then jsonb_build_object('rol', a.rol, 'nombre', pam_primer_nombre(a.nombres)) else 'null'::jsonb end;

    when 'registrar' then data := pam_registrar(req->'datos');

    when 'eventos' then
      select coalesce(jsonb_agg(pam_evento_json(e) order by e.fecha, e.hora), '[]'::jsonb) into data
      from eventos e where (coalesce((req->>'todos')::boolean, false) and adm) or e.estado = 'publicado';

    when 'inscribir' then data := pam_inscribir(req->>'eventoId', req);

    when 'tips' then
      select coalesce(jsonb_agg(to_jsonb(x) - 'n' order by x.fecha desc), '[]'::jsonb) into data
      from tips x where (coalesce((req->>'todos')::boolean, false) and adm) or x.publicado;

    when 'avisos' then
      select coalesce(jsonb_agg(to_jsonb(x) - 'n' order by x.fecha desc), '[]'::jsonb) into data from avisos x;

    when 'login' then
      if lower(btrim(coalesce(req->>'usuario', ''))) = lower(pam_cfg('admin_usuario')) and pam_cfg('admin_clave_sha256') <> ''
         and encode(extensions.digest(convert_to(coalesce(req->>'clave', ''), 'UTF8'), 'sha256'), 'hex') = pam_cfg('admin_clave_sha256') then
        t := gen_random_uuid()::text;
        delete from sesiones where vence < now();
        insert into sesiones values (t, now() + interval '6 hours');
        data := jsonb_build_object('sesion', t);
      else data := 'null'::jsonb; end if;

    when 'resumen' then
      data := jsonb_build_object(
        'titulares', (select count(*) from afiliados where rol = 'TITULAR'),
        'familiares', (select count(*) from afiliados where rol = 'DEPENDIENTE'),
        'registros', (select count(*) from registros),
        'inscripciones', (select count(*) from inscripciones),
        'tipsPublicados', (select count(*) from tips where publicado),
        'hoy', pam_hoy());

    when 'registros' then
      select coalesce(jsonb_agg(jsonb_build_object('token', r.token_registro, 'userToken', r.token_afiliado, 'fecha', r.fecha_registro,
        'estadoSigno', r.estado_signo, 'datos', r.datos) order by r.n desc), '[]'::jsonb) into data from registros r;

    when 'inscritos' then
      select coalesce(jsonb_agg(jsonb_build_object('token', i.token_inscripcion, 'eventoId', i.evento_id, 'userToken', i.token_afiliado,
        'tipo_documento', i.tipo_documento, 'nro_documento', i.nro_documento, 'nombre', i.nombre, 'telefono', i.telefono,
        'fecha', i.fecha_inscripcion) order by i.n), '[]'::jsonb) into data from inscripciones i where i.evento_id = req->>'eventoId';

    when 'guardarEvento' then data := pam_guardar_evento(req->'evento');
    when 'borrarEvento' then data := to_jsonb(pam_borrar_evento(req->>'id'));
    when 'guardarTip' then data := pam_guardar_tip(req->'tip');
    when 'borrarTip' then delete from tips where id = req->>'id'; data := 'true'::jsonb;
    when 'crearAviso' then data := pam_aviso(jsonb_build_object('tipo', 'aviso') || coalesce(req->'aviso', '{}'::jsonb));
    when 'borrarAviso' then delete from avisos where id = req->>'id'; data := 'true'::jsonb;

    when 'signo' then   -- columnas A–O de la plantilla de Signo
      select jsonb_build_array(jsonb_build_array('tipo_documento','nro_documento','nombres','apellidos','genero','fecha_nacimiento','nro_afiliacion',
               'rif_company','nombre_company','fecha_inicio','fecha_fin','nro_documento_titular','tipo_documento_titular','parentesco','tlf'))
             || coalesce(jsonb_agg(jsonb_build_array(s.tipo_documento, s.nro_documento, s.nombres, s.apellidos, s.genero, s.fecha_nacimiento,
               s.nro_afiliacion, s.rif_company, s.nombre_company, s.fecha_inicio, s.fecha_fin, s.nro_documento_titular, s.tipo_documento_titular,
               s.parentesco, s.tlf) order by s.n), '[]'::jsonb)
      into data from signo s;

    when 'marcarSignoCargado' then
      with u as (update signo set estado_carga = 'Cargado' where estado_carga <> 'Cargado' returning 1) select to_jsonb(count(*)) into data from u;
      update registros set estado_signo = 'Cargado' where estado_signo <> 'Cargado';

    else raise exception 'Acción desconocida: %', act;
  end case;

  return jsonb_build_object('ok', true, 'data', data);
exception when others then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

-- Cambiar la clave del admin (solo desde el SQL Editor de Supabase, nunca desde el sitio):
--   select pam_cambiar_clave('la clave nueva');
create or replace function public.pam_cambiar_clave(nueva text) returns text
language plpgsql volatile security definer set search_path = public as $$
begin
  if length(coalesce(nueva, '')) < 8 then raise exception 'La clave debe tener al menos 8 caracteres.'; end if;
  update config set valor = encode(extensions.digest(convert_to(nueva, 'UTF8'), 'sha256'), 'hex') where clave = 'admin_clave_sha256';
  delete from sesiones;
  return 'Clave cambiada. Las sesiones abiertas se cerraron.';
end $$;

-- ---------- Permisos ----------
-- Nadie ejecuta funciones por defecto; el sitio (anon) solo puede llamar a pam_api.
revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function public.pam_api(jsonb) to anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
