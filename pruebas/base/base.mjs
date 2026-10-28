// Una base nueva en memoria con todas las migraciones aplicadas, en orden.
import { PGlite } from '@electric-sql/pglite';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const dirMigraciones = fileURLToPath(new URL('../../db/migraciones/', import.meta.url));

export async function baseNueva() {
  const db = new PGlite();
  await db.waitReady;
  for (const f of readdirSync(dirMigraciones).filter((f) => f.endsWith('.sql')).sort()) {
    await db.exec(readFileSync(dirMigraciones + f, 'utf8'));
  }
  return db;
}

export async function uno(db, sql, params = []) {
  const r = await db.query(sql, params);
  return r.rows[0];
}

// Datos ficticios mínimos: dos personas y un cliente de ejemplo.
export async function conEjemplo(db) {
  await db.exec(`
    insert into personas (codigo, nombre) values ('P1', 'Persona Uno (ejemplo)'), ('P2', 'Persona Dos (ejemplo)');
    insert into clientes (nombre) values ('Cliente Ejemplo S.A.');
  `);
  return db;
}
