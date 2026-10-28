// Las tres decisiones del Libro de eventos, controladas en la base. Todo con datos ficticios.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { baseNueva, conEjemplo, uno } from './base.mjs';

async function base() {
  return conEjemplo(await baseNueva());
}

async function rechaza(db, sql, params, patron) {
  await assert.rejects(db.query(sql, params), (e) => {
    assert.match(e.message, patron);
    return true;
  });
}

// ------------------------------------------------------------ 2. el id nace en la consulta

test('el id nace en la consulta, con el año de la consulta, y numera seguido', async () => {
  const db = await base();
  const a = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-28') as id`);
  const b = await uno(db, `select nuevo_trabajo('contenido', 'Redes de ejemplo', '2026-11-02') as id`);
  const c = await uno(db, `select nuevo_trabajo('otro', 'Consulta de ejemplo', '2027-01-05') as id`);
  assert.equal(a.id, 'IMP-2026-001');
  assert.equal(b.id, 'IMP-2026-002');
  assert.equal(c.id, 'IMP-2027-001');
  const t = await uno(db, `select estado from trabajos where id = $1`, [a.id]);
  assert.equal(t.estado, 'consulta');
});

test('el id no cambia, la fecha de consulta tampoco, y un trabajo no se borra', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-28') as id`);
  await rechaza(db, `update trabajos set id = 'IMP-2026-099' where id = $1`, [id], /no cambia/);
  await rechaza(db, `update trabajos set fecha_consulta = '2026-11-15' where id = $1`, [id], /no cambia/);
  await rechaza(db, `delete from trabajos where id = $1`, [id], /no se borra/);
});

test('un id importado adelanta la numeración, sin repetir', async () => {
  const db = await base();
  await db.query(`insert into trabajos (id, linea, nombre, fecha_consulta) values ('IMP-2026-007', 'web', 'Importado de ejemplo', '2026-10-20')`);
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Nuevo de ejemplo', '2026-10-28') as id`);
  assert.equal(id, 'IMP-2026-008');
});

test('un id con otro año que el de su consulta se rechaza', async () => {
  const db = await base();
  await rechaza(db, `insert into trabajos (id, linea, nombre, fecha_consulta) values ('IMP-2025-001', 'web', 'Mal fechado', '2026-10-20')`, [], /id_del_anio_de_la_consulta/);
});

test('los cambios de estado siguen las transiciones y piden motivo al perder', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('acreditacion', 'Evento de ejemplo', '2026-10-01') as id`);
  await rechaza(db, `select cambiar_estado($1, 'cerrado')`, [id], /no se puede pasar/);
  await rechaza(db, `select cambiar_estado($1, 'perdido')`, [id], /motivo_al_perder/);
  await db.query(`select cambiar_estado($1, 'presupuestado', null, '2026-10-05')`, [id]);
  await db.query(`select cambiar_estado($1, 'perdido', 'precio', '2026-10-20')`, [id]);
  const h = await db.query(`select de, a, fecha::text, motivo from trabajo_estados where trabajo_id = $1 order by id`, [id]);
  assert.deepEqual(h.rows, [
    { de: null, a: 'consulta', fecha: '2026-10-01', motivo: null },
    { de: 'consulta', a: 'presupuestado', fecha: '2026-10-05', motivo: null },
    { de: 'presupuestado', a: 'perdido', fecha: '2026-10-20', motivo: 'precio' },
  ]);
});

test('cerrado y caido son finales', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-01') as id`);
  await db.query(`select cambiar_estado($1, 'firmado')`, [id]);
  await db.query(`select cambiar_estado($1, 'caido', 'el cliente suspendió')`, [id]);
  await rechaza(db, `select cambiar_estado($1, 'firmado')`, [id], /no se puede pasar/);
});

// ------------------------------------------------------------ 3. todo peso con el índice de su mes

test('un importe en pesos sin índice de su mes es «no se puede saber»; en dólares no lo necesita', async () => {
  const db = await base();
  const sin = await uno(db, `select a_constante(155000, 'ARS', '2026-10-15') as v`);
  assert.equal(sin.v, null);
  const usd = await uno(db, `select a_constante(500, 'USD', '2026-10-15') as v`);
  assert.equal(Number(usd.v), 500);
  await db.query(`insert into indices (mes, valor, fuente) values ('2026-10-01', 1550, 'ejemplo')`);
  const con = await uno(db, `select a_constante(155000, 'ARS', '2026-10-15') as v`);
  assert.equal(Number(con.v), 100);
});

test('el índice es de un mes: solo se acepta el primer día', async () => {
  const db = await base();
  await rechaza(db, `insert into indices (mes, valor, fuente) values ('2026-10-15', 1550, 'ejemplo')`, [], /check/);
});

// ------------------------------------------------------------ 1. vacío = «no se puede saber»

test('sin cobros ni gastos el resultado dice «nada cargado», nunca cero', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-01') as id`);
  const r = await uno(db, `select * from resultado_trabajo($1)`, [id]);
  assert.equal(r.ingreso, null);
  assert.equal(r.gastos, null);
  assert.equal(r.margen, null);
  assert.match(r.motivo, /ingreso: nada cargado/);
  assert.match(r.motivo, /gastos: nada cargado/);
});

test('un cobro sin monto o sin índice deja el ingreso en «no se puede saber»', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-01') as id`);
  await db.query(`insert into cobros (trabajo_id, concepto, monto, fecha_factura) values ($1, 'anticipo', 310000, '2026-10-10')`, [id]);
  await db.query(`insert into gastos (trabajo_id, rubro, monto, moneda, fecha) values ($1, 'hosting', 20, 'USD', '2026-10-10')`, [id]);
  let r = await uno(db, `select * from resultado_trabajo($1)`, [id]);
  assert.equal(r.ingreso, null, 'falta el índice de octubre');
  assert.equal(Number(r.gastos), 20);
  assert.equal(r.margen, null);
  assert.match(r.motivo, /ingreso: no se puede saber/);

  await db.query(`insert into indices (mes, valor, fuente) values ('2026-10-01', 1550, 'ejemplo')`);
  await db.query(`insert into cobros (trabajo_id, concepto, fecha_factura) values ($1, 'saldo', '2026-10-20')`, [id]);
  r = await uno(db, `select * from resultado_trabajo($1)`, [id]);
  assert.equal(r.ingreso, null, 'el saldo no tiene monto');
  assert.match(r.motivo, /1 cobro sin monto/);
});

test('un gasto cargado en 0 es un cero de verdad, y entonces hay margen', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-01') as id`);
  await db.query(`insert into indices (mes, valor, fuente) values ('2026-10-01', 1550, 'ejemplo')`);
  await db.query(`insert into cobros (trabajo_id, concepto, monto, fecha_factura) values ($1, 'total', 310000, '2026-10-10')`, [id]);
  await db.query(`insert into gastos (trabajo_id, rubro, monto, fecha) values ($1, 'ninguno', 0, '2026-10-10')`, [id]);
  const r = await uno(db, `select * from resultado_trabajo($1)`, [id]);
  assert.equal(Number(r.ingreso), 200);
  assert.equal(Number(r.gastos), 0);
  assert.equal(Number(r.margen), 200);
  assert.equal(r.motivo, null);
});

test('la tasa de cierre no se publica con menos de 5 trabajos decididos', async () => {
  const db = await base();
  for (let i = 0; i < 3; i++) await db.query(`select nuevo_trabajo('web', 'Ejemplo ' || $1, '2026-10-01')`, [i]);
  await db.query(`select cambiar_estado('IMP-2026-001', 'firmado')`);
  await db.query(`select cambiar_estado('IMP-2026-002', 'perdido', 'precio')`);
  assert.equal((await uno(db, `select tasa_cierre() as t`)).t, 'n muy chico (2), no se publica');
  for (let i = 3; i < 6; i++) {
    const { id } = await uno(db, `select nuevo_trabajo('web', 'Ejemplo ' || $1, '2026-10-01') as id`, [i]);
    await db.query(`select cambiar_estado($1, 'firmado')`, [id]);
  }
  assert.equal((await uno(db, `select tasa_cierre() as t`)).t, '80%');
});

// ------------------------------------------------------------ ESTRUCTURA

test('un gasto o una hora es de un trabajo o de ESTRUCTURA, nunca de los dos ni de ninguno', async () => {
  const db = await base();
  const { id } = await uno(db, `select nuevo_trabajo('web', 'Sitio de ejemplo', '2026-10-01') as id`);
  await db.query(`insert into gastos (es_estructura, rubro, monto, fecha) values (true, 'dominio', 15000, '2026-10-01')`);
  await rechaza(db, `insert into gastos (rubro, monto, fecha) values ('suelto', 1, '2026-10-01')`, [], /trabajo_o_estructura/);
  await rechaza(db, `insert into gastos (trabajo_id, es_estructura, rubro, monto, fecha) values ($1, true, 'doble', 1, '2026-10-01')`, [id], /trabajo_o_estructura/);
  await rechaza(db, `insert into horas (persona, fase, horas) values ('P1', 'relevamiento', 2)`, [], /trabajo_o_estructura/);
  await db.query(`insert into horas (trabajo_id, persona, fase, horas) values ($1, 'P1', 'relevamiento', 2)`, [id]);
});
