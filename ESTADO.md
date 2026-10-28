# Estado del panel

## Etapa 1 · El libro en el celular (6 sesiones estimadas, tope 8)

### Sesión 1 (28/10/2026) — SESION 1 CERRADA (falta solo el push)

Autorizada por Mati: solo esta sesión; después se frena hasta que él repase.

- [x] Decisiones en rol (`DECISIONES.md`)
- [x] Carpeta y repo local
- [x] Esquema base (`db/migraciones/0001_base.sql`)
- [x] Pruebas de las tres decisiones con PGlite, en verde (`npm test`: 13 de 13)
- [x] Commit local. [ ] Push: BLOQUEADO. `gh` sin sesión en la Acer; Mati creó el repo desde Chrome pero `git push -u origin main` responde «Repository not found» (o el repo quedó con otro dueño u otro nombre, o Git en la Acer usa una cuenta sin acceso a la organización). Falta: la URL exacta del repo y que la cuenta con la que Git sube sea miembro de `impulsocreativo-ba`. Después, `git push -u origin main` (el remoto ya está configurado).
- [x] Sección de decisiones en el Doc y PDF 8 en `H:\Mi unidad\Desarrollo\Impulso` (actualizado)

### Lo que sigue (sesión 2 en adelante, no empezar sin OK de Mati)

1. Permisos (RLS) con roles simulados de Supabase en PGlite, como `C:\AXSION\sistema-ot-pr\pruebas\base\poc\prueba-rls.mjs`.
2. Copiar el arnés de velocidad de AXSION (`pruebas\velocidad\`) y fijar las metas.
3. Pantallas: Hoy, Trabajos, carga de gasto con foto, cobros, horas (Preact + Vite, instalable).
4. Importador del Libro de eventos y exportación a sus 9 pestañas.
5. Tablero de 7 bloques.
6. Cuentas de Supabase y Cloudflare (las crea Mati) y primer despliegue.
