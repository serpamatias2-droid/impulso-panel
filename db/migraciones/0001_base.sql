-- Esquema base del panel de Impulso: lo mínimo que reemplaza al Libro de eventos.
-- Las tres decisiones del libro viven acá, no en la pantalla:
--   1. Vacío significa «no se puede saber»: los importes aceptan nulo y no tienen valor por defecto.
--   2. El id del trabajo nace en la consulta y no cambia nunca.
--   3. Todo peso lleva el índice de su mes: a_constante() devuelve nulo si falta.
-- Permisos (RLS) y Accesos van en una migración aparte, con los roles de Supabase.

create type linea as enum ('acreditacion', 'web', 'contenido', 'otro');
create type tipo_trabajo as enum ('servicio', 'propio');
create type estado_trabajo as enum ('consulta', 'presupuestado', 'perdido', 'firmado', 'caido', 'cerrado');
create type moneda as enum ('ARS', 'USD');

create table personas (
  codigo text primary key,
  nombre text not null,
  activo boolean not null default true
);

create table clientes (
  id bigint generated always as identity primary key,
  nombre text not null check (btrim(nombre) <> ''),
  cuit text,
  notas text,
  creado_en timestamptz not null default now()
);

-- Numeración por año de la consulta. Nadie la toca salvo las funciones de esta migración.
create table contadores (
  anio int primary key,
  ultimo int not null check (ultimo >= 0)
);

create table trabajos (
  id text primary key check (id ~ '^IMP-[0-9]{4}-[0-9]{3,}$'),
  linea linea not null,
  tipo tipo_trabajo not null default 'servicio',
  cliente_id bigint references clientes,
  nombre text not null check (btrim(nombre) <> ''),
  estado estado_trabajo not null default 'consulta',
  motivo text,
  origen text,
  personas_declaradas int check (personas_declaradas >= 0),
  sede text,
  fecha_consulta date not null,
  fecha_evento date,
  le_dijimos_no_a text references trabajos (id),
  responsable text references personas,
  notas text,
  creado_en timestamptz not null default now(),
  constraint motivo_al_perder check (
    estado not in ('perdido', 'caido') or (motivo is not null and btrim(motivo) <> '')
  ),
  constraint id_del_anio_de_la_consulta check (
    substr(id, 5, 4)::int = extract(year from fecha_consulta)::int
  )
);

-- Cada cambio de estado, con su fecha y su motivo. De acá salen fecha_presupuesto, fecha_firma, etc.
create table trabajo_estados (
  id bigint generated always as identity primary key,
  trabajo_id text not null references trabajos (id),
  de estado_trabajo,
  a estado_trabajo not null,
  fecha date not null,
  motivo text,
  registrado_en timestamptz not null default now()
);

create table transiciones (
  de estado_trabajo not null,
  a estado_trabajo not null,
  primary key (de, a)
);

insert into transiciones (de, a) values
  ('consulta', 'presupuestado'), ('consulta', 'firmado'), ('consulta', 'perdido'),
  ('presupuestado', 'firmado'), ('presupuestado', 'perdido'),
  ('perdido', 'presupuestado'),
  ('firmado', 'cerrado'), ('firmado', 'caido');

-- Índice del mes: dólar MEP, promedio de cierres del mes (DECISIONES.md, 1).
create table indices (
  mes date primary key check (mes = date_trunc('month', mes)::date),
  valor numeric not null check (valor > 0),
  fuente text not null
);

create table decisiones (
  clave text primary key,
  valor text,
  nota text
);

create table gastos (
  id bigint generated always as identity primary key,
  trabajo_id text references trabajos (id),
  es_estructura boolean not null default false,
  rubro text not null,
  detalle text,
  monto numeric check (monto >= 0),
  moneda moneda not null default 'ARS',
  fecha date not null,
  pagado_por text references personas,
  con_factura boolean,
  proveedor text,
  es_equipo boolean not null default false,
  comprobante text,
  id_local text unique,
  creado_en timestamptz not null default now(),
  constraint trabajo_o_estructura check ((trabajo_id is not null) <> es_estructura)
);

create table cobros (
  id bigint generated always as identity primary key,
  trabajo_id text not null references trabajos (id),
  concepto text not null,
  monto numeric check (monto >= 0),
  moneda moneda not null default 'ARS',
  fecha_factura date,
  nro_factura text,
  fecha_cobro_esperada date,
  fecha_cobro_real date,
  medio text,
  facturo text references personas,
  id_local text unique,
  creado_en timestamptz not null default now()
);

create table horas (
  id bigint generated always as identity primary key,
  trabajo_id text references trabajos (id),
  es_estructura boolean not null default false,
  persona text not null references personas,
  fase text not null,
  horas numeric not null check (horas > 0),
  estimada boolean not null default true,
  semana date,
  nota text,
  id_local text unique,
  creado_en timestamptz not null default now(),
  constraint trabajo_o_estructura check ((trabajo_id is not null) <> es_estructura)
);

create table incidentes (
  id bigint generated always as identity primary key,
  trabajo_id text not null references trabajos (id),
  jornada text,
  fecha date not null,
  que_paso text not null check (btrim(que_paso) <> ''),
  impacto text,
  que_cambiamos text,
  operativo_degradado boolean,
  minuto_de_caida time,
  creado_en timestamptz not null default now()
);

-- ---------------------------------------------------------------- id: nace en la consulta, no cambia

-- Un id cargado a mano (el importador trae IMP-2026-001…) adelanta el contador, para que el
-- siguiente nuevo_trabajo() no lo repita.
create function trabajos_antes_de_insertar() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_anio int := substr(new.id, 5, 4)::int;
  v_n int := substr(new.id, 10)::int;
begin
  insert into contadores (anio, ultimo) values (v_anio, v_n)
  on conflict (anio) do update set ultimo = greatest(contadores.ultimo, excluded.ultimo);
  return new;
end $$;

create trigger trabajos_antes_de_insertar before insert on trabajos
  for each row execute function trabajos_antes_de_insertar();

create function trabajos_despues_de_insertar() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into trabajo_estados (trabajo_id, de, a, fecha, motivo)
  values (new.id, null, new.estado, new.fecha_consulta, new.motivo);
  return null;
end $$;

create trigger trabajos_despues_de_insertar after insert on trabajos
  for each row execute function trabajos_despues_de_insertar();

create function trabajos_antes_de_cambiar() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_fecha date := coalesce(nullif(current_setting('impulso.fecha_estado', true), '')::date, current_date);
begin
  if new.id is distinct from old.id then
    raise exception 'el id de un trabajo no cambia (%)', old.id using errcode = 'P0001';
  end if;
  if new.fecha_consulta is distinct from old.fecha_consulta then
    raise exception 'la fecha de consulta de % no cambia: es la de su nacimiento', old.id using errcode = 'P0001';
  end if;
  if new.estado is distinct from old.estado then
    if not exists (select 1 from transiciones t where t.de = old.estado and t.a = new.estado) then
      raise exception 'no se puede pasar % de % a %', old.id, old.estado, new.estado using errcode = 'P0001';
    end if;
    insert into trabajo_estados (trabajo_id, de, a, fecha, motivo)
    values (old.id, old.estado, new.estado, v_fecha, new.motivo);
  end if;
  return new;
end $$;

create trigger trabajos_antes_de_cambiar before update on trabajos
  for each row execute function trabajos_antes_de_cambiar();

create function trabajos_no_se_borran() returns trigger
language plpgsql as $$
begin
  raise exception 'un trabajo no se borra: pasalo a perdido o caido con su motivo (%)', old.id
    using errcode = 'P0001';
end $$;

create trigger trabajos_no_se_borran before delete on trabajos
  for each row execute function trabajos_no_se_borran();

create function nuevo_trabajo(
  p_linea linea,
  p_nombre text,
  p_fecha_consulta date default current_date,
  p_cliente bigint default null,
  p_origen text default null,
  p_personas int default null,
  p_tipo tipo_trabajo default 'servicio'
) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_anio int := extract(year from p_fecha_consulta)::int;
  v_n int;
  v_id text;
begin
  insert into contadores (anio, ultimo) values (v_anio, 1)
  on conflict (anio) do update set ultimo = contadores.ultimo + 1
  returning ultimo into v_n;
  v_id := format('IMP-%s-%s', v_anio, lpad(v_n::text, 3, '0'));
  insert into trabajos (id, linea, tipo, cliente_id, nombre, fecha_consulta, origen, personas_declaradas)
  values (v_id, p_linea, p_tipo, p_cliente, p_nombre, p_fecha_consulta, p_origen, p_personas);
  return v_id;
end $$;

-- Cambia el estado con la fecha en que pasó (no la de hoy, si se carga tarde).
create function cambiar_estado(p_id text, p_a estado_trabajo, p_motivo text default null,
                               p_fecha date default current_date) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('impulso.fecha_estado', p_fecha::text, true);
  update trabajos set estado = p_a, motivo = coalesce(p_motivo, motivo) where id = p_id;
  if not found then
    raise exception 'no existe el trabajo %', p_id using errcode = 'P0002';
  end if;
  perform set_config('impulso.fecha_estado', '', true);
end $$;

-- ---------------------------------------------------------------- índice: moneda constante

-- Lleva un importe a dólares MEP de su mes. Nulo si falta el monto o el índice de ese mes:
-- nunca devuelve pesos nominales como si fueran comparables.
create function a_constante(p_monto numeric, p_moneda moneda, p_fecha date) returns numeric
language sql stable as $$
  select case
    when p_monto is null then null
    when p_moneda = 'USD' then p_monto
    else p_monto / (select i.valor from indices i where i.mes = date_trunc('month', p_fecha)::date)
  end
$$;

-- ---------------------------------------------------------------- vacío: «no se puede saber»

-- Resultado de un trabajo en dólares MEP. Cada número viene con su motivo cuando falta:
--   «nada cargado»       no hay ninguna fila (un cero real se carga como 0);
--   «no se puede saber»  hay filas, pero alguna sin monto o sin índice de su mes.
create function resultado_trabajo(p_id text)
returns table (ingreso numeric, gastos numeric, margen numeric, motivo text)
language plpgsql stable as $$
declare
  n_cobros int; n_cobros_sin int; s_cobros numeric;
  n_gastos int; n_gastos_sin int; s_gastos numeric;
  motivos text[] := '{}';
begin
  select count(*), count(*) filter (where a_constante(c.monto, c.moneda, coalesce(c.fecha_cobro_real, c.fecha_factura, c.fecha_cobro_esperada)) is null),
         sum(a_constante(c.monto, c.moneda, coalesce(c.fecha_cobro_real, c.fecha_factura, c.fecha_cobro_esperada)))
    into n_cobros, n_cobros_sin, s_cobros
    from cobros c where c.trabajo_id = p_id;
  select count(*), count(*) filter (where a_constante(g.monto, g.moneda, g.fecha) is null),
         sum(a_constante(g.monto, g.moneda, g.fecha))
    into n_gastos, n_gastos_sin, s_gastos
    from gastos g where g.trabajo_id = p_id;

  if n_cobros = 0 then
    ingreso := null; motivos := array_append(motivos, 'ingreso: nada cargado');
  elsif n_cobros_sin > 0 then
    ingreso := null; motivos := array_append(motivos, format('ingreso: no se puede saber (%s cobro sin monto o sin índice)', n_cobros_sin));
  else
    ingreso := s_cobros;
  end if;

  if n_gastos = 0 then
    gastos := null; motivos := array_append(motivos, 'gastos: nada cargado');
  elsif n_gastos_sin > 0 then
    gastos := null; motivos := array_append(motivos, format('gastos: no se puede saber (%s gasto sin monto o sin índice)', n_gastos_sin));
  else
    gastos := s_gastos;
  end if;

  margen := ingreso - gastos;  -- nulo si cualquiera de los dos es nulo
  motivo := nullif(array_to_string(motivos, '; '), '');
  return next;
end $$;

-- Tasa de cierre del embudo: con menos de 5 trabajos decididos no se publica (regla del PANEL).
create function tasa_cierre() returns text
language sql stable as $$
  with n as (
    select count(*) filter (where estado in ('firmado', 'cerrado')) as ganados,
           count(*) filter (where estado in ('firmado', 'cerrado', 'perdido')) as decididos
      from trabajos
  )
  select case
    when decididos < 5 then format('n muy chico (%s), no se publica', decididos)
    else round(100.0 * ganados / decididos)::text || '%'
  end from n
$$;

revoke all on contadores from public;
