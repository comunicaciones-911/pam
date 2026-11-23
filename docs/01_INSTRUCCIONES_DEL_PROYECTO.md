# Instrucciones del proyecto · PAM Baruta

> Pega este texto en **Instrucciones del proyecto** (Project instructions). Es corto a propósito: el detalle está en los archivos de conocimiento.

Trabajas en la web de **PAM Baruta** (Programa de Atención Médica de la Alcaldía de Baruta, Caracas): un plan de salud gratuito para los vecinos (telemedicina 24 h, médico en casa, ambulancia y medicamentos). El sitio vivirá en **pambaruta.com** y el panel en **pambaruta.com/admin**. Responde siempre en **español**.

**Antes de cambiar algo, lee** `02_CONTEXTO_COMPLETO.md` (decisiones, diseño, arquitectura, reglas de Signo) y `04_PENDIENTES.md`.

## Reglas que no se rompen
- **Público principal: personas mayores de 60 y sus familias.** Letra grande, botones grandes, textos cortos, sin tecnicismos. No agregar selector de tamaño de letra.
- **Solo colores de la marca:** verde `#0e683b`, verde hoja `#83ba2a`, blanco, y el verde noche `#082e1b` para bandas oscuras. Ningún otro tono.
- **Verde solo para elementos** (botones, íconos, tarjetas), no como fondo de secciones. Excepción aprobada: el degradado verde oscuro de las bandas “¿Llegamos a tu urbanización?”, “¿Ya estás registrado?” y la de emergencia.
- **Tipografía Figtree.** Bajo el logo: “Programa de Atención Médica”. Slogan: **“PAM Baruta, salud que responde”.**
- Énfasis con **negrita**, nunca resaltado. Sin cápsulas/etiquetas encima de los títulos de sección. Secciones compactas; títulos en una sola línea cuando se pueda.
- **Solo cédula** (sin pasaporte en el formulario público).
- En teléfono **no hay footer**: los enlaces van en el botón “Más” (hoja inferior con cápsulas, sin scroll y sin números de teléfono).
- La sección del mapa se llama **“Zonas”** (no “Cobertura”). El archivo sigue siendo `cobertura.html`.
- Íconos de **Iconify** (Solar + MDI) en un sprite SVG; no usar otras librerías de íconos.
- NOA y el contact center están **fuera del alcance**.

## Cómo se trabaja el código
- Edita `fuente/core.js.tpl`, **nunca** `core.js`; luego ejecuta `python3 herramientas/generar_core.py`.
- Todo dato pasa por `DataService` (en core.js). Con `CONFIG.api` usa Google Sheets; sin ella, modo demostración en el navegador.
- Si cambias el script de la hoja (`google-sheets/Code.gs`), recuerda que el usuario debe pegarlo en Apps Script y, si cambian acciones nuevas, hacer **Implementar → Gestionar implementaciones → Editar → Nueva versión** (la URL /exec no cambia).
- Prueba en escritorio y en teléfono (390 px) antes de entregar.
- Las vistas previas de Claude bloquean conexiones externas: ahí el sitio funciona en modo demostración. La conexión real a la hoja solo funciona en un hosting normal.
