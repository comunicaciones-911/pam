# PAM Baruta · Contexto completo del proyecto

*Actualizado: 23 de noviembre de 2026.*

## 1. Qué es
**PAM Baruta** es el Programa de Atención Médica de la Alcaldía de Baruta (Caracas, Venezuela). Lo opera Grupo Nueve Once. Es gratuito para los vecinos desde 2020 e incluye:
- telemedicina,
- médico en casa,
- ambulancia,
- entrega de medicamentos.

El proyecto es la nueva web con un **rebranding**:
- colores `#0e683b` / `#83ba2a` / blanco,
- tipografía Figtree,
- logo con hoja y la línea “Programa de Atención Médica”.

Ya construido:
- sitio público,
- formulario de afiliación,
- eventos con inscripción,
- tips de salud,
- notificaciones,
- mapa de zonas,
- panel admin,
- conexión a Google Sheets con exportación para **Signo** (el sistema de afiliación de la aseguradora/operadora).

**Plan original por fases** (de las notas del proyecto anterior):
1. Rebranding.
2. Web y formularios.
3. PWA (app instalable) conectada a Google Sheets.

NOA y el contact center quedan fuera.

## 2. Contactos públicos que muestra el sitio (validar con Operaciones)
- Médico 24 h: **0212 909 5270** y **0212 628 5270**
- Medicamentos por WhatsApp: **0414 115 8604**. Para pedirlos: foto del récipe, cédula del afiliado y dirección de entrega.
- Instagram: **@pambaruta**
- Cifras del inicio (aún por validar):
  - +67 mil vecinos registrados
  - +7.900 atenciones en 2025
  - 8 de cada 10 casos se resuelven en casa

## 3. Páginas
| Archivo | Qué hace |
|---|---|
| `index.html` | Inicio: hero con foto familiar, accesos rápidos, qué es PAM, verificación de cédula, 4 servicios, 3 pasos, “¿Llegamos a tu urbanización?”, próximas jornadas, consejos, banda de emergencia, FAQ resumida, Instagram, footer. |
| `registro.html` | Primero **verifica la cédula** (si ya está registrado lo dice). Si no, abre un asistente de 6 pasos. |
| `eventos.html` | Jornadas, charlas y operativos con imagen o post de Instagram. Inscripción con cédula y entrega de código. |
| `tips.html` | Consejos de salud con buscador, categorías e imagen/post de Instagram. |
| `cobertura.html` | **Zonas**: mapa SVG interactivo de 66 urbanizaciones con sectores, zoom y lista desplegable. Datos de `Zonas_Cobertura_Baruta.xlsx`. |
| `preguntas.html` | Preguntas frecuentes. |
| `nevera.html` | Hoja para la nevera: se genera sola como imagen A4 (teléfonos, qué decir al llamar, WhatsApp de medicamentos y QR a `registro.html` del dominio actual). Botones para descargar la imagen, imprimir y descargar solo el QR. |
| `admin/index.html` | Panel con login y pestañas Resumen, Registros, Eventos, Tips, Avisos, Zonas y Signo. `admin.html` redirige aquí. |
| `movil.html` | Vista previa del sitio en marcos de teléfono (solo para revisar diseño). |
| `manifest.webmanifest`, `sw.js`, `img/icon-*.png` | Base de la PWA y de las notificaciones push. |

Imágenes en `img/`:
- `familia.jpg`: hero del inicio.
- `comunidad.jpg`: jornada en una urbanización.
- `ig1`–`ig3.jpg`: posts reales de Instagram.

## 4. Formulario de afiliación (pasos y campos)
1. **Quién llena:** para mí / para un familiar (`para`).
2. **Datos personales:**
   - Cédula (`tipo_documento` = NATIONAL_ID, `nro_documento`)
   - Nombres y apellidos
   - Fecha de nacimiento
   - Sexo
   - Teléfono y correo
3. **Dirección:** `direccion` y urbanización/sector (`sector`, con la lista de zonas).
4. **Contacto de emergencia:** `em_nombre`, `em_apellidos`, `em_telefono`.
5. **Salud:**
   - Fuma (cuántas unidades al día)
   - Alcohol (frecuencia)
   - Alergias (cuál)
   - Medicamentos (cuál)
   - Patologías (+ otras)
6. **Familiares y cierre:**
   - Familiares (dependientes) con cédula, nombres, nacimiento, sexo, parentesco y teléfono
   - ¿PAM es tu único plan? (`unico_plan`)
   - Lo más importante para ti (`importante`)
   - ¿Cómo nos conociste? (`conocio`)

Al terminar, el sitio muestra los **códigos únicos**.

## 5. Códigos (tokens)
- **Por persona:** `PAM-U-XXXX-XXXX`.
- **Por registro:** `PAM-R-AAMMDD-XXXXXX`.
- **Por inscripción a evento:** `PAM-E-AAMMDD-XXXXXX`.
- El alfabeto excluye 0, O, 1 e I para que se puedan dictar por teléfono.
- Si alguien se registra de nuevo con la misma cédula, **conserva su código de persona** y se actualizan sus datos.

## 6. Signo: formato y políticas de carga
Plantilla: `referencias/Estructura_de_carga_NUEVE_ONCE_Signo.xlsx`, pestaña **DATOS**. Tiene 15 columnas, en este orden:

`tipo_documento, nro_documento, nombres, apellidos, genero, fecha_nacimiento, nro_afiliacion, rif_company, nombre_company, fecha_inicio, fecha_fin, nro_documento_titular, tipo_documento_titular, parentesco, tlf`

**Reglas que aplica el sistema:**
- `tipo_documento`: `NATIONAL_ID` (o `PASSPORT`).
- Cédula solo con números: sin V-, puntos ni guiones. Un pasaporte va en mayúsculas y sin espacios.
- Nombres y apellidos en **MAYÚSCULAS**.
- `genero`: **F** / **M**.
- Fechas en **DD/MM/AAAA**.
- Vigencia de **1 año menos 1 día**: `fecha_fin` = `fecha_inicio` + 12 meses − 1 día.
- `parentesco`: `SPOUSE` (cónyuge), `CHILD` (hijo/a), `PARENTS` (padre o madre), `IN_LAW` (suegro/a), `OTHERS` (otro).
- **Una fila por persona.** En la fila del titular, `parentesco` y los datos del titular van vacíos. En la fila de un familiar van la cédula y el tipo de documento del titular.
- `tlf`: solo números, con código de área.
- `nro_afiliacion` va vacío (por confirmar si lo asigna Signo).
- `rif_company` y `nombre_company` salen de la pestaña Config de la hoja. **El RIF sigue pendiente.**
- Si una persona se registra otra vez, su fila de Signo se **actualiza**; no se duplica.
- Si alguien que ya es titular aparece luego como familiar de otro, sigue siendo titular.

## 7. Arquitectura
- **Sitio estático** en HTML, CSS y JS, sin frameworks.
  - `assets/app.css` tiene los estilos.
  - `assets/core.js` es generado; se edita `fuente/core.js.tpl`. Contiene CONFIG, Tokens, DataService, el encabezado y el footer compartidos, notificaciones (`Notifs`), el sprite de íconos y los datos `ZONAS`.
- **Datos:** `DataService` decide el modo.
  - **Google Sheets:** cuando `CONFIG.api` tiene la URL de Apps Script y la conexión responde (`RemoteData`).
  - **Demostración:** si no, todo se guarda en el `localStorage` del navegador (`LocalData`, clave `pam_db_v4`). En pambaruta.com nunca cae a demostración.
- **Backend:** Google Apps Script (`google-sheets/Code.gs`) publicado como aplicación web. Los datos se guardan en la hoja.
  - Pestañas: **Registros, Afiliados, Signo, Inscripciones, Eventos, Tips, Avisos, Config, Codigos**.
  - Las imágenes subidas en el admin se guardan en una carpeta de Drive, y la hoja guarda solo el enlace.
- **Admin:** el usuario y la clave se validan en la hoja; la huella SHA-256 de la clave está en la pestaña Config. La sesión dura 6 horas.
- **Notificaciones:** se generan avisos automáticos cuando:
  - se crea un evento,
  - cambia su fecha, hora o lugar,
  - se cancela (al borrarlo si estaba publicado y era futuro),
  - se publica un tip.

  Los avisos manuales se crean en la pestaña Avisos. El sitio los muestra en la campana. El push real del teléfono está preparado (`sw.js`) pero no activado.
- **Íconos:** `herramientas/build-sprite.js` (Node, con `@iconify/utils`, `@iconify-json/solar` y `@iconify-json/mdi`) genera `sprite_iconos.svg.txt`. Para agregar un ícono:
  1. Añádelo al mapa del script y ejecútalo con `node build-sprite.js` (después de `npm install`).
  2. Corre `generar_core.py`.

## 8. Restricciones de los enlaces de Claude (vistas previas)
- Corren en un marco protegido que bloquea conexiones externas, el envío nativo de formularios y las ventanas emergentes. Por eso:
  - El sitio intercepta los botones de enviar con el `formShim` de core.js.
  - El login tiene un respaldo de SHA-256 en JavaScript.
  - En esas vistas los datos quedan en modo demostración. El admin lo avisa con el recuadro “Vista de prueba”.
- Cada enlace guarda sus datos por separado.

## 9. Decisiones de diseño tomadas con el usuario
- Se quitaron:
  - el selector de tamaño de texto,
  - la barra superior de contacto,
  - las cápsulas sobre los títulos,
  - los rangos de edades,
  - el pasaporte,
  - el link “Contacto” del menú,
  - la nota “Cifras por validar con Operaciones”.
- Header: el teléfono se ve como botón; los dos números tienen el mismo tamaño.
- La sección de contacto se reemplazó por la de Instagram, con los 3 posts reales en una sola línea.
- La banda de emergencia tiene 3 botones (2 médicos y 1 de WhatsApp de medicamentos) y un enlace a las preguntas frecuentes.
- Las preguntas frecuentes están en su propia página; en el inicio se ve una versión corta.
- La verificación de cédula va antes del banner “Todo lo que necesitas para cuidarte, sin costo”.
- Eventos y tips: diseño compacto y dinámico. En la tarjeta del evento, la hora y el lugar se ven destacados. En teléfono, la fecha va en un bloque verde completo.
- Zonas: los grupos se pliegan y despliegan para no hacer tanto scroll. En teléfono, la información de la zona sale en una hoja inferior.
- Footer en verde oscuro con llamado a registrarse.
- Admin: el campo de clave tiene el mismo estilo que el de usuario.

## 10. Historial resumido
1. Se recuperaron las notas del proyecto anterior desde la exportación de otra cuenta de Claude. Los chats no venían en la exportación.
2. Se construyó el sitio por fases según los requisitos del usuario y la plantilla de Signo.
3. Se iteró el diseño con muchos comentarios del usuario (ver la sección 9).
4. Se corrigieron fallos del admin en el visor de Claude (login, formularios, carga con sesión abierta).
5. “Cobertura” se renombró a “Zonas” y se agregó el slogan.
6. Se conectó a Google Sheets con Apps Script. El usuario lo implementó y la URL está en CONFIG.
7. Se borró todo el contenido de prueba de la hoja y del sitio: hoy arranca vacío.

8. Se compararon con la primera versión (pambaruta.vercel.app) y se agregaron: hoja para la nevera con QR automático, sección "Instala la app" (Android, iPhone, computadora, con botón de instalar cuando el navegador lo permite), la pregunta "¿Qué necesito al llamar?", los logos de la Alcaldía y de Grupo Nueve Once en el footer, el detalle del tratamiento en casa, "registro obligatorio" y las guardias de prevención en eventos de la Alcaldía. La cifra de +650 entregas de medicamentos se dejó fuera a pedido del usuario.
