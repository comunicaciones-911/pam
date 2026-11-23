# Guía técnica para Sistemas · PAM Baruta

## Publicar el sitio
1. Publica la carpeta `sitio/` en la raíz de **pambaruta.com**. Con Vercel, `vercel.json` ya lo hace (ver `README.md`). Es un sitio estático: sirve cualquier hosting con HTTPS (cPanel, Nginx, Netlify, Vercel, Cloudflare Pages…).
   - `core.js.tpl` y `movil.html` están en `fuente/`, fuera de lo que se publica.
2. `pambaruta.com/admin` abre `admin/index.html`. Si el servidor no sirve `index.html` por defecto en carpetas, configúralo o enlaza `/admin/index.html`.
3. El QR de `nevera.html` se arma con el dominio desde el que se abre la página. Imprime y reparte las hojas definitivas desde **pambaruta.com**, no desde una URL de prueba. El generador de QR es `assets/qrcode.js` (Kazuhiko Arase, licencia MIT).
4. HTTPS es obligatorio: lo necesitan la PWA, el service worker y las notificaciones.
4. Comprueba que funcione:
   - Al entrar al admin, arriba debe decir **“Conectado a Google Sheets”**.
   - Si dice “Vista de prueba”, el sitio no está llegando a la URL de Apps Script. Revisa `CONFIG.api` en `assets/core.js` y que no haya una política CSP que bloquee `script.google.com` y `script.googleusercontent.com`.

## Cómo habla el sitio con la hoja
- Peticiones `POST` a la URL `/exec` con `Content-Type: text/plain` y un cuerpo JSON `{action, auth, ...}`. El tipo `text/plain` evita la verificación previa de CORS que Apps Script no responde.
- Respuesta: `{ok: true, data}` o `{ok: false, error, code}`.
- Acciones **públicas**: `ping`, `buscar`, `registrar`, `eventos`, `inscribir`, `tips`, `avisos`, `login`.
  - `buscar` solo devuelve el rol y el primer nombre de la persona, nunca sus datos completos.
- Acciones de **admin** (requieren `auth` con la sesión que devuelve `login`, válida 6 horas): `resumen`, `registros`, `inscritos`, `guardarEvento`, `borrarEvento`, `guardarTip`, `borrarTip`, `crearAviso`, `borrarAviso`, `signo`, `marcarSignoCargado`.
- Las escrituras usan `LockService` para que dos registros simultáneos no choquen.

## Actualizar el script de la hoja
1. Pega el nuevo `Code.gs` en **Extensiones → Apps Script** y guarda.
2. Ve a **Implementar → Gestionar implementaciones → (lápiz) Editar → Versión: Nueva versión → Implementar.** Así la URL no cambia.
3. La función `configurar` se puede volver a ejecutar sin perder datos: solo crea las pestañas que falten y reaplica los encabezados.

## Límites a tener en cuenta
- Apps Script tiene cuotas diarias: unas 20.000 llamadas por día en cuentas gratuitas y más en Workspace. Alcanza para un programa municipal. Supabase ya está preparado como alternativa (`supabase/` y `CONFIG.backend` en `fuente/core.js.tpl`; pasos en `README.md`). Si el volumen crece mucho, conviene migrar `DataService` a una base de datos (Supabase, Firebase o un servidor propio). El sitio está preparado: solo cambia `RemoteData` en `core.js.tpl`.
- Cada llamada tarda entre 1 y 3 segundos.
- La hoja contiene **datos de salud**: compártela solo con quien la necesite.

## Desarrollo local
- Para servir el sitio: `python3 -m http.server 8765 --directory sitio`. Sin conexión a la hoja, funciona en modo demostración.
- Para simular la hoja sin tocar la real: `node herramientas/gas-mock/server.js google-sheets/Code.gs 8790`. Luego apunta `CONFIG.api` a `http://localhost:8790/` en una copia.
- Prueba completa con Playwright: `python3 herramientas/prueba_completa.py`, con el sitio servido en el puerto 8765.
- Después de editar `core.js.tpl`, ejecuta `python3 herramientas/generar_core.py`.
