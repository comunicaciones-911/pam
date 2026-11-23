# PAM Baruta · Sitio web

Sitio del **Programa de Atención Médica de la Alcaldía de Baruta**: información para los vecinos, registro de afiliados, eventos, tips de salud, zonas, hoja para la nevera y panel admin.

- Sitio estático (HTML, CSS y JS), sin frameworks ni paso de compilación.
- Base de datos actual: **Google Sheets** (Apps Script).
- Base de datos preparada: **Supabase**. Se activa cambiando una línea (ver paso 4).

## Qué hay en el repositorio

| Carpeta | Qué contiene |
|---|---|
| `sitio/` | **Lo que se publica.** Vercel sirve solo esta carpeta. |
| `fuente/core.js.tpl` | Fuente de `sitio/assets/core.js`. Se edita aquí, nunca `core.js`. |
| `fuente/movil.html` | Vista del sitio en marcos de teléfono (solo para revisar el diseño en local). |
| `google-sheets/Code.gs` | Script de la hoja de cálculo (la base de datos actual). |
| `supabase/migrations/` | Base de datos para Supabase: tablas, permisos y la función `pam_api`. |
| `herramientas/` | Generador de `core.js`, generador de íconos, simulador de la hoja y prueba completa. |
| `docs/` | Contexto del proyecto, pendientes y guía técnica. |
| `referencias/` | Plantilla de carga de Signo y Excel de zonas. |
| `vercel.json` | Configuración de Vercel (carpeta `sitio/`, redirección de `/admin.html`, encabezados). |

> **No subas `03_ACCESOS_Y_CLAVES.md`** ni ningún archivo con claves. El `.gitignore` ya lo bloquea.

---

## 1. Subir a GitHub

Crea el repositorio como **privado** en la cuenta u organización de la empresa (por ejemplo `pam-baruta`), sin README ni .gitignore, porque ya vienen incluidos.

Con la terminal, desde esta carpeta:

```bash
git init
git add .
git commit -m "PAM Baruta: sitio, Google Sheets y Supabase preparado"
git branch -M main
git remote add origin https://github.com/EMPRESA/pam-baruta.git
git push -u origin main
```

Sin terminal también se puede: en el repositorio vacío, usa **Add file → Upload files** y arrastra todo el contenido de esta carpeta. Si tu sistema oculta los archivos que empiezan con punto, revisa que `.gitignore` también se suba.

## 2. Publicar en Vercel

1. En Vercel, entra con la cuenta de la empresa: **Add New… → Project → Import** el repositorio de GitHub.
2. Deja **Framework Preset: Other** y **Root Directory** vacío. No hace falta comando de build: `vercel.json` ya le dice a Vercel que publique la carpeta `sitio/`.
3. Pulsa **Deploy**. Vercel te da una URL de prueba (`…vercel.app`).
4. Verifica:
   - Abre `/admin`. Arriba debe decir **“Conectado a Google Sheets”**.
   - Haz un registro de prueba y revisa que aparezca en la hoja (pestañas Registros, Afiliados y Signo). Bórralo después.
5. Cada `git push` a `main` vuelve a publicar solo.

### Dominio pambaruta.com
En el proyecto de Vercel: **Settings → Domains → Add** `pambaruta.com` y `www.pambaruta.com`. Vercel te muestra los registros DNS exactos que hay que crear donde está registrado el dominio (normalmente un registro **A** para `pambaruta.com` y un **CNAME** para `www`). Usa los valores que muestra Vercel en ese momento.

> **QR de la hoja para la nevera:** el QR apunta a `registro.html` del dominio desde el que se abre la página. Imprime las hojas definitivas desde **pambaruta.com**, no desde la URL `vercel.app`.

## 3. Google Sheets (base de datos actual)

Ya está conectada: la URL de Apps Script está en `CONFIG.api` (`fuente/core.js.tpl`). Si se cambia `Code.gs`, hay que pegarlo en **Extensiones → Apps Script** y hacer **Implementar → Gestionar implementaciones → Editar → Nueva versión**. Así la URL no cambia. Más detalle en `docs/05_GUIA_SISTEMAS.md`.

## 4. Supabase (preparado, se activa cuando quieran)

El sitio habla con Supabase igual que con la hoja: las mismas acciones, las mismas reglas de Signo y las mismas respuestas. Todo pasa por una sola función, `pam_api`. Las tablas tienen RLS activo y sin políticas: con la clave pública nadie puede leerlas directamente, solo llamar a `pam_api`, que valida la sesión del admin en cada acción privada.

### Crear la base
1. En Supabase, con la cuenta de la empresa: **New project** (región sugerida: `us-east-1`, la más cercana a Venezuela).
2. **SQL Editor → New query**: pega todo el archivo `supabase/migrations/20261123000000_pam_baruta.sql` y pulsa **Run**.
3. Define la clave del admin (en el mismo SQL Editor):
   ```sql
   select pam_cambiar_clave('UNA-CLAVE-NUEVA-Y-LARGA');
   ```
   El usuario es `admin`. Para cambiarlo: `update config set valor = 'otro' where clave = 'admin_usuario';`
4. Cuando lo tengan, coloca el RIF de la póliza:
   ```sql
   update config set valor = 'J-00000000-0' where clave = 'rif_company';
   ```
   Si tienes el CLI de Supabase, en vez de los pasos 2 y 3 puedes usar `supabase link` y `supabase db push`.

### Conectar el sitio
1. En Supabase: **Project Settings → API Keys**. Copia la **Project URL** y la clave **publishable** (o la `anon` si es un proyecto antiguo). Nunca uses la `service_role` ni la `secret` en el sitio.
2. En `fuente/core.js.tpl`, dentro de `CONFIG`:
   ```js
   backend: 'supabase',
   supabase: {
     url: 'https://TU-PROYECTO.supabase.co',
     anonKey: 'sb_publishable_…'
   },
   ```
3. Regenera `core.js`, sube el cambio y Vercel publica solo:
   ```bash
   python3 herramientas/generar_core.py
   git commit -am "Activar Supabase" && git push
   ```
4. Verifica que `/admin` diga **“Conectado a Supabase”**.

Para volver a Google Sheets, cambia `backend` a `'sheets'`.

**Ten en cuenta:**
- Los registros que ya están en la hoja de Google **no se pasan solos** a Supabase. Si hace falta, se puede preparar una importación.
- Las imágenes de eventos y tips se guardan dentro de la base (en Google Sheets iban a Drive). Para muchas imágenes conviene moverlas a Supabase Storage más adelante.
- La exportación a Signo funciona igual: en el admin, **Exportar a Signo → Copiar**.

## 5. Cambiar el código

- Estilos: `sitio/assets/app.css`. Páginas: `sitio/*.html`.
- Lógica compartida (datos, encabezado, footer, notificaciones): edita `fuente/core.js.tpl` y luego ejecuta `python3 herramientas/generar_core.py`.
- Íconos: `herramientas/build-sprite.js` (`npm install` dentro de `herramientas/`, luego `node build-sprite.js` y `generar_core.py`).
- Probar en local: `python3 -m http.server 8765 --directory sitio` y abre `http://localhost:8765`.

## 6. Seguridad

- Mantén el repositorio **privado**.
- `core.js` contiene la URL pública de Apps Script y la huella de la clave del modo demostración. Las dos se ven igual en el sitio publicado. **Cambia la clave del admin antes de abrir el sitio al público** (ver `docs/04_PENDIENTES.md`).
- La hoja y la base contienen **datos de salud**: compártelas solo con quien las necesite.
