/* =====================================================================
   PAM Baruta · Conexión con Google Sheets (Apps Script)
   ---------------------------------------------------------------------
   Este script vive DENTRO de la hoja de cálculo (Extensiones → Apps Script)
   y funciona como el "servidor" del sitio pambaruta.com:
     - Guarda cada registro, afiliado, inscripción, evento, tip y aviso.
     - Arma la pestaña "Signo" con el formato de carga masiva
       (Estructura_de_carga_NUEVE_ONCE_Signo.xlsx).
     - Valida el usuario y la clave del panel admin (la clave NO está en el sitio).

   Instalación (una sola vez):
     1. Pega este archivo en Extensiones → Apps Script y guarda.
     2. Elige la función "configurar" y pulsa Ejecutar (acepta los permisos).
     3. Implementar → Nueva implementación → Aplicación web
          Ejecutar como: Yo   ·   Quién tiene acceso: Cualquier usuario
     4. Copia la URL que termina en /exec y pégala en CONFIG.api (assets/core.js).
   ===================================================================== */

var VERSION = '1.0';

/* ---------- Pestañas y columnas ---------- */
var HOJAS = {
  Registros: ['token_registro', 'fecha_registro', 'token_afiliado', 'lo_llena', 'tipo_documento', 'nro_documento', 'nombres', 'apellidos',
    'fecha_nacimiento', 'genero', 'telefono', 'correo', 'direccion', 'urbanizacion_sector',
    'emergencia_nombres', 'emergencia_apellidos', 'emergencia_telefono',
    'fuma', 'fuma_unidades_dia', 'alcohol', 'alcohol_frecuencia', 'alergia', 'alergia_cual', 'medicamento', 'medicamento_cual',
    'patologias', 'patologias_otras', 'unico_plan', 'lo_mas_importante', 'como_nos_conocio',
    'nro_familiares', 'estado_signo', 'datos_json'],
  Afiliados: ['token_afiliado', 'rol', 'tipo_documento', 'nro_documento', 'nombres', 'apellidos', 'genero', 'fecha_nacimiento', 'telefono',
    'parentesco', 'parentesco_texto', 'tipo_documento_titular', 'nro_documento_titular', 'token_registro', 'creado', 'actualizado'],
  /* Columnas A–O = plantilla de carga masiva de Signo (pestaña DATOS), en el mismo orden.
     P–R son de control interno: NO se copian a Signo. */
  Signo: ['tipo_documento', 'nro_documento', 'nombres', 'apellidos', 'genero', 'fecha_nacimiento', 'nro_afiliacion', 'rif_company', 'nombre_company',
    'fecha_inicio', 'fecha_fin', 'nro_documento_titular', 'tipo_documento_titular', 'parentesco', 'tlf',
    'estado_carga', 'token_afiliado', 'actualizado'],
  Inscripciones: ['token_inscripcion', 'evento_id', 'evento_titulo', 'evento_fecha', 'fecha_inscripcion', 'token_afiliado', 'tipo_documento', 'nro_documento', 'nombre', 'telefono'],
  Eventos: ['id', 'titulo', 'categoria', 'fecha', 'hora', 'fin', 'lugar', 'sector', 'cupos', 'estado', 'instagram', 'imagen', 'descripcion', 'creado'],
  Tips: ['id', 'titulo', 'categoria', 'resumen', 'contenido', 'publicado', 'fecha', 'instagram', 'imagen'],
  Avisos: ['id', 'tipo', 'titulo', 'mensaje', 'link', 'fecha']
};
var SIGNO_COLS = 15;   // A–O

/* ---------- Códigos y políticas de Signo ---------- */
var PARENTESCO = { SPOUSE: 'Cónyuge', CHILD: 'Hijo/a', PARENTS: 'Padre o madre', IN_LAW: 'Suegro/a', OTHERS: 'Otro familiar' };
var TIPO_DOC = { NATIONAL_ID: 'Cédula de identidad', PASSPORT: 'Pasaporte' };
var GENERO = { Femenino: 'F', Masculino: 'M' };

/* =====================================================================
   1. Configuración inicial: ejecutar UNA vez desde el editor
   ===================================================================== */
function configurar() {
  var ss = SpreadsheetApp.getActive();
  Object.keys(HOJAS).forEach(function (n) { hoja_(n); });
  configHoja_();
  codigosHoja_();
  // La hoja vacía que trae el archivo ("Hoja 1") se borra si no tiene nada
  ['Hoja 1', 'Sheet1', 'Hoja1'].forEach(function (n) {
    var h = ss.getSheetByName(n);
    if (h && h.getLastRow() === 0 && ss.getSheets().length > 1) ss.deleteSheet(h);
  });
  ss.setActiveSheet(ss.getSheetByName('Registros'));
  SpreadsheetApp.flush();
  return 'Listo';
}

function hoja_(nombre) {
  var ss = SpreadsheetApp.getActive(), h = ss.getSheetByName(nombre), cols = HOJAS[nombre];
  if (!h) h = ss.insertSheet(nombre);
  if (h.getMaxColumns() < cols.length) h.insertColumnsAfter(h.getMaxColumns(), cols.length - h.getMaxColumns());
  h.getRange(1, 1, Math.max(h.getMaxRows(), 1000), cols.length).setNumberFormat('@');  // todo como texto: sin conversiones de fecha ni ceros perdidos
  var head = h.getRange(1, 1, 1, cols.length);
  head.setValues([cols]).setFontWeight('bold').setFontColor('#ffffff').setBackground('#0e683b');
  h.setFrozenRows(1);
  if (nombre === 'Signo') {
    h.getRange(1, SIGNO_COLS + 1, 1, cols.length - SIGNO_COLS).setBackground('#83ba2a');
    h.getRange(1, 1).setNote('Copia SOLO las columnas A a O en la pestaña DATOS de la plantilla de Signo. Las columnas verde claro son de control interno.');
  }
  if (nombre === 'Registros') h.hideColumns(cols.indexOf('datos_json') + 1);
  return h;
}

function configHoja_() {
  var ss = SpreadsheetApp.getActive(), h = ss.getSheetByName('Config');
  if (h) return h;
  h = ss.insertSheet('Config');
  h.getRange(1, 1, 50, 3).setNumberFormat('@');
  h.getRange(1, 1, 1, 3).setValues([['clave', 'valor', 'nota']]).setFontWeight('bold').setFontColor('#ffffff').setBackground('#0e683b');
  h.getRange(2, 1, 6, 3).setValues([
    ['rif_company', '', 'RIF de la póliza PAM Baruta en Signo (POR CONFIRMAR). Va en la columna rif_company.'],
    ['nombre_company', 'PAM BARUTA', 'Nombre de la empresa como lo pide Signo (POR CONFIRMAR).'],
    ['vigencia_meses', '12', 'Signo acepta máximo 1 año: fecha_fin = fecha_inicio + 12 meses − 1 día.'],
    ['admin_usuario', 'admin', 'Usuario del panel admin.'],
    ['admin_clave_sha256', 'e389e429535c4968c1374a49d8ae6d0c3cd3807ccfedc9d41f2647bff8748db2', 'Huella SHA-256 de la clave. Para cambiarla usa la función cambiarClaveAdmin().'],
    ['carpeta_imagenes', '', 'Se llena sola: carpeta de Drive donde se guardan las imágenes de eventos y tips.']
  ]);
  h.setFrozenRows(1); h.setColumnWidth(2, 260); h.setColumnWidth(3, 520);
  return h;
}

function codigosHoja_() {
  var ss = SpreadsheetApp.getActive(), h = ss.getSheetByName('Codigos');
  if (h) return h;
  h = ss.insertSheet('Codigos');
  var filas = [['campo', 'código Signo', 'significado / regla']];
  Object.keys(TIPO_DOC).forEach(function (k) { filas.push(['tipo_documento', k, TIPO_DOC[k]]); });
  filas.push(['nro_documento', '—', 'Cédula: solo números, sin V-, puntos ni guiones. Pasaporte: mayúsculas y sin espacios.']);
  filas.push(['nombres / apellidos', '—', 'En MAYÚSCULAS.']);
  Object.keys(GENERO).forEach(function (k) { filas.push(['genero', GENERO[k], k]); });
  filas.push(['fecha_nacimiento / fecha_inicio / fecha_fin', '—', 'Formato DD/MM/AAAA.']);
  filas.push(['fecha_fin', '—', 'Vigencia máxima 1 año: fecha_inicio + 12 meses − 1 día.']);
  Object.keys(PARENTESCO).forEach(function (k) { filas.push(['parentesco', k, PARENTESCO[k]]); });
  filas.push(['parentesco / titular', '(vacío)', 'En la fila del titular, parentesco y datos del titular van vacíos.']);
  filas.push(['nro_afiliacion', '(vacío)', 'Lo asigna Signo / POR CONFIRMAR.']);
  filas.push(['tlf', '—', 'Solo números, con código de área (ej. 04141234567).']);
  filas.push(['estado_carga (interno)', 'Pendiente / Cargado', 'Cambia a "Cargado" cuando la fila ya se subió a Signo.']);
  h.getRange(1, 1, filas.length, 3).setNumberFormat('@').setValues(filas);
  h.getRange(1, 1, 1, 3).setFontWeight('bold').setFontColor('#ffffff').setBackground('#0e683b');
  h.setFrozenRows(1); h.setColumnWidth(1, 300); h.setColumnWidth(2, 160); h.setColumnWidth(3, 520);
  return h;
}

/* Cambiar la clave del admin: edita la clave aquí, ejecuta la función y luego bórrala del código. */
function cambiarClaveAdmin() {
  var nueva = '';   // ← escribe la nueva clave entre las comillas
  if (nueva.length < 8) throw new Error('Escribe una clave de al menos 8 caracteres en la variable "nueva".');
  setConfig_('admin_clave_sha256', sha256_(nueva));
  return 'Clave cambiada. Borra la clave del código y guarda.';
}

/* =====================================================================
   2. API web (la usa el sitio)
   ===================================================================== */
function doGet(e) { return responder_(e && e.parameter ? e.parameter : {}); }
function doPost(e) {
  var req = {};
  try { req = JSON.parse(e.postData.contents || '{}'); } catch (err) { return json_({ ok: false, error: 'Solicitud inválida' }); }
  return responder_(req);
}

function responder_(req) {
  try {
    var fn = ACCIONES[req.action];
    if (!fn) throw new Error('Acción desconocida: ' + req.action);
    if (fn.admin && !sesionValida_(req.auth)) return json_({ ok: false, error: 'Sesión vencida', code: 'auth' });
    var data = fn.escribe ? conCandado_(function () { return fn.run(req); }) : fn.run(req);
    return json_({ ok: true, data: data });
  } catch (err) {
    return json_({ ok: false, error: String(err && err.message || err) });
  }
}
function json_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
function conCandado_(fn) { var l = LockService.getScriptLock(); l.waitLock(20000); try { return fn(); } finally { l.releaseLock(); } }

var ACCIONES = {
  ping: { run: function () { return { version: VERSION, hora: new Date().toISOString() }; } },

  /* ---- Público ---- */
  buscar: { run: function (r) {
    var a = buscarAfiliado_(r.tipo_documento, r.nro_documento);
    return a ? { rol: a.rol, nombre: primerNombre_(a.nombres) } : null;    // nunca datos personales completos
  } },
  registrar: { escribe: true, run: function (r) { return registrar_(r.datos); } },
  eventos: { run: function (r) {
    var todos = r.todos && sesionValida_(r.auth), ins = filas_('Inscripciones');
    return filas_('Eventos').filter(function (e) { return todos || e.estado === 'publicado'; }).map(function (e) {
      e.inscritos = ins.filter(function (i) { return i.evento_id === e.id; }).length;
      e.cupos = e.cupos ? Number(e.cupos) : ''; return e;
    }).sort(function (a, b) { return (a.fecha + a.hora).localeCompare(b.fecha + b.hora); });
  } },
  inscribir: { escribe: true, run: function (r) { return inscribir_(r.eventoId, r); } },
  tips: { run: function (r) {
    var todos = r.todos && sesionValida_(r.auth);
    return filas_('Tips').map(function (t) { t.publicado = t.publicado === 'SI'; return t; })
      .filter(function (t) { return todos || t.publicado; }).sort(function (a, b) { return String(b.fecha).localeCompare(String(a.fecha)); });
  } },
  avisos: { run: function () { return filas_('Avisos').sort(function (a, b) { return String(b.fecha).localeCompare(String(a.fecha)); }); } },

  /* ---- Admin ---- */
  login: { run: function (r) {
    var c = config_();
    var ok = String(r.usuario || '').trim().toLowerCase() === String(c.admin_usuario || '').toLowerCase() && sha256_(String(r.clave || '')) === c.admin_clave_sha256;
    if (!ok) return null;
    var t = Utilities.getUuid();
    CacheService.getScriptCache().put('ses_' + t, '1', 21600);   // 6 horas
    return { sesion: t };
  } },
  resumen: { admin: true, run: function () {
    var af = filas_('Afiliados'), hoy = Utilities.formatDate(new Date(), 'America/Caracas', 'yyyy-MM-dd');
    return {
      titulares: af.filter(function (a) { return a.rol === 'TITULAR'; }).length,
      familiares: af.filter(function (a) { return a.rol === 'DEPENDIENTE'; }).length,
      registros: filas_('Registros').length,
      inscripciones: filas_('Inscripciones').length,
      tipsPublicados: filas_('Tips').filter(function (t) { return t.publicado === 'SI'; }).length,
      hoy: hoy
    };
  } },
  registros: { admin: true, run: function () {
    return filas_('Registros').map(function (r) {
      var d = {}; try { d = JSON.parse(r.datos_json || '{}'); } catch (e) {}
      return { token: r.token_registro, userToken: r.token_afiliado, fecha: r.fecha_registro, estadoSigno: r.estado_signo, datos: d };
    }).reverse();
  } },
  inscritos: { admin: true, run: function (r) {
    return filas_('Inscripciones').filter(function (i) { return i.evento_id === r.eventoId; }).map(function (i) {
      return { token: i.token_inscripcion, eventoId: i.evento_id, userToken: i.token_afiliado, tipo_documento: i.tipo_documento,
        nro_documento: i.nro_documento, nombre: i.nombre, telefono: i.telefono, fecha: i.fecha_inscripcion };
    });
  } },
  guardarEvento: { admin: true, escribe: true, run: function (r) { return guardarEvento_(r.evento); } },
  borrarEvento: { admin: true, escribe: true, run: function (r) { return borrarEvento_(r.id); } },
  guardarTip: { admin: true, escribe: true, run: function (r) { return guardarTip_(r.tip); } },
  borrarTip: { admin: true, escribe: true, run: function (r) { borrarFila_('Tips', 'id', r.id); return true; } },
  crearAviso: { admin: true, escribe: true, run: function (r) { return aviso_(Object.assign({ tipo: 'aviso' }, r.aviso)); } },
  borrarAviso: { admin: true, escribe: true, run: function (r) { borrarFila_('Avisos', 'id', r.id); return true; } },
  signo: { admin: true, run: function () {
    var h = SpreadsheetApp.getActive().getSheetByName('Signo'), n = h.getLastRow();
    var head = HOJAS.Signo.slice(0, SIGNO_COLS);
    if (n < 2) return [head];
    return [head].concat(h.getRange(2, 1, n - 1, SIGNO_COLS).getDisplayValues());
  } },
  marcarSignoCargado: { admin: true, escribe: true, run: function () {
    var h = SpreadsheetApp.getActive().getSheetByName('Signo'), n = h.getLastRow(); if (n < 2) return 0;
    var col = HOJAS.Signo.indexOf('estado_carga') + 1, r = h.getRange(2, col, n - 1, 1), v = r.getValues(), c = 0;
    v.forEach(function (x) { if (x[0] !== 'Cargado') { x[0] = 'Cargado'; c++; } }); r.setValues(v);
    var hr = SpreadsheetApp.getActive().getSheetByName('Registros'), nr = hr.getLastRow();
    if (nr > 1) { var cr = hr.getRange(2, HOJAS.Registros.indexOf('estado_signo') + 1, nr - 1, 1); cr.setValues(cr.getValues().map(function () { return ['Cargado']; })); }
    return c;
  } }
};

/* =====================================================================
   3. Registro de afiliados
   ===================================================================== */
function registrar_(d) {
  if (!d || !d.nro_documento) throw new Error('Faltan datos del registro.');
  var ahora = new Date().toISOString(), usados = tokensUsados_();
  d.tipo_documento = d.tipo_documento || 'NATIONAL_ID';
  d.nro_documento = normDoc_(d.tipo_documento, d.nro_documento);
  d.nombre = mayus_(d.nombre); d.apellidos = mayus_(d.apellidos);
  d.dependientes = (d.dependientes || []).map(function (p) {
    p.tipo_documento = p.tipo_documento || 'NATIONAL_ID'; p.nro_documento = normDoc_(p.tipo_documento, p.nro_documento);
    p.nombre = mayus_(p.nombre); p.apellidos = mayus_(p.apellidos);
    if (p.parentesco && !PARENTESCO[p.parentesco]) p.parentesco = 'OTHERS';
    return p;
  });
  var tokReg = token_('R', usados);
  var tit = upsertAfiliado_(d, 'TITULAR', null, tokReg, ahora, usados);
  d.dependientes.forEach(function (p) { p.token = upsertAfiliado_(p, 'DEPENDIENTE', d, tokReg, ahora, usados).token_afiliado; });

  agregar_('Registros', {
    token_registro: tokReg, fecha_registro: ahora, token_afiliado: tit.token_afiliado, lo_llena: d.para,
    tipo_documento: d.tipo_documento, nro_documento: d.nro_documento, nombres: d.nombre, apellidos: d.apellidos,
    fecha_nacimiento: ddmmaaaa_(d.nacimiento), genero: GENERO[d.sexo] || '', telefono: soloNum_(d.telefono), correo: d.correo,
    direccion: d.direccion, urbanizacion_sector: d.sector,
    emergencia_nombres: d.em_nombre, emergencia_apellidos: d.em_apellidos, emergencia_telefono: soloNum_(d.em_telefono),
    fuma: d.fuma, fuma_unidades_dia: d.fuma_unidades, alcohol: d.alcohol, alcohol_frecuencia: d.alcohol_frec,
    alergia: d.alergia, alergia_cual: d.alergia_cual, medicamento: d.medicamento, medicamento_cual: d.medicamento_cual,
    patologias: d.patologias, patologias_otras: d.patologias_otras, unico_plan: d.unico_plan, lo_mas_importante: d.importante,
    como_nos_conocio: d.conocio, nro_familiares: d.dependientes.length, estado_signo: 'Pendiente', datos_json: JSON.stringify(d)
  });

  // Pestaña Signo: una fila por persona (titular + familiares), con las reglas de carga
  var c = config_(), ini = new Date(ahora), fin = new Date(ini);
  fin.setMonth(fin.getMonth() + (Number(c.vigencia_meses) || 12)); fin.setDate(fin.getDate() - 1);
  var base = { nro_afiliacion: '', rif_company: c.rif_company || '', nombre_company: c.nombre_company || '', fecha_inicio: fmtFecha_(ini), fecha_fin: fmtFecha_(fin),
    estado_carga: 'Pendiente', actualizado: ahora };
  upsertSigno_(Object.assign({}, base, { tipo_documento: d.tipo_documento, nro_documento: d.nro_documento, nombres: d.nombre, apellidos: d.apellidos,
    genero: GENERO[d.sexo] || '', fecha_nacimiento: ddmmaaaa_(d.nacimiento), nro_documento_titular: '', tipo_documento_titular: '', parentesco: '',
    tlf: soloNum_(d.telefono), token_afiliado: tit.token_afiliado }));
  d.dependientes.forEach(function (p) {
    upsertSigno_(Object.assign({}, base, { tipo_documento: p.tipo_documento, nro_documento: p.nro_documento, nombres: p.nombre, apellidos: p.apellidos,
      genero: GENERO[p.sexo] || '', fecha_nacimiento: ddmmaaaa_(p.nacimiento), nro_documento_titular: d.nro_documento, tipo_documento_titular: d.tipo_documento,
      parentesco: p.parentesco || 'OTHERS', tlf: soloNum_(p.telefono), token_afiliado: p.token }));
  });

  return { userToken: tit.token_afiliado, regToken: tokReg, deps: d.dependientes.map(function (p) { return { nombre: p.nombre, token: p.token }; }) };
}

function upsertAfiliado_(p, rol, titular, tokReg, ahora, usados) {
  var existente = buscarAfiliado_(p.tipo_documento, p.nro_documento, true);
  var a = {
    rol: rol, tipo_documento: p.tipo_documento, nro_documento: p.nro_documento, nombres: p.nombre, apellidos: p.apellidos,
    genero: GENERO[p.sexo] || '', fecha_nacimiento: ddmmaaaa_(p.nacimiento), telefono: soloNum_(p.telefono),
    parentesco: titular ? (p.parentesco || 'OTHERS') : '', parentesco_texto: titular ? PARENTESCO[p.parentesco || 'OTHERS'] : '',
    tipo_documento_titular: titular ? titular.tipo_documento : '', nro_documento_titular: titular ? titular.nro_documento : '',
    token_registro: tokReg, actualizado: ahora
  };
  if (existente) {
    a.token_afiliado = existente.datos.token_afiliado; a.creado = existente.datos.creado;
    if (!a.telefono) a.telefono = existente.datos.telefono;
    // Un titular que luego aparece como familiar de otro sigue siendo titular
    if (existente.datos.rol === 'TITULAR' && rol === 'DEPENDIENTE') { return existente.datos; }
    escribirFila_('Afiliados', existente.fila, a);
  } else {
    a.token_afiliado = token_('U', usados); a.creado = ahora;
    agregar_('Afiliados', a);
  }
  return a;
}

function upsertSigno_(o) {
  var h = SpreadsheetApp.getActive().getSheetByName('Signo'), n = h.getLastRow();
  if (n > 1) {
    var v = h.getRange(2, 1, n - 1, 2).getValues();
    for (var i = 0; i < v.length; i++) if (String(v[i][0]) === o.tipo_documento && String(v[i][1]) === o.nro_documento) { escribirFila_('Signo', i + 2, o); return; }
  }
  agregar_('Signo', o);
}

function buscarAfiliado_(tipo, nro, conFila) {
  tipo = tipo || 'NATIONAL_ID'; nro = normDoc_(tipo, nro);
  var h = SpreadsheetApp.getActive().getSheetByName('Afiliados'), n = h.getLastRow(); if (n < 2) return null;
  var cols = HOJAS.Afiliados, v = h.getRange(2, 1, n - 1, cols.length).getValues();
  var it = cols.indexOf('tipo_documento'), in_ = cols.indexOf('nro_documento');
  for (var i = 0; i < v.length; i++) if (String(v[i][it]) === tipo && String(v[i][in_]) === nro) {
    var o = objeto_(cols, v[i]); return conFila ? { fila: i + 2, datos: o } : o;
  }
  return null;
}

/* =====================================================================
   4. Eventos, inscripciones, tips y avisos
   ===================================================================== */
function inscribir_(eventoId, r) {
  var ev = filas_('Eventos').filter(function (e) { return e.id === eventoId; })[0];
  if (!ev) throw new Error('El evento ya no está disponible.');
  var a = buscarAfiliado_(r.tipo_documento, r.nro_documento);
  if (!a) return { estado: 'no_registrado' };
  var ins = filas_('Inscripciones').filter(function (i) { return i.evento_id === eventoId; });
  var ya = ins.filter(function (i) { return i.token_afiliado === a.token_afiliado; })[0];
  if (ya) return { estado: 'ya_inscrito', token: ya.token_inscripcion, nombre: a.nombres };
  if (ev.cupos && ins.length >= Number(ev.cupos)) return { estado: 'sin_cupos' };
  var t = token_('E', tokensUsados_());
  agregar_('Inscripciones', { token_inscripcion: t, evento_id: eventoId, evento_titulo: ev.titulo, evento_fecha: ev.fecha, fecha_inscripcion: new Date().toISOString(),
    token_afiliado: a.token_afiliado, tipo_documento: a.tipo_documento, nro_documento: a.nro_documento, nombre: a.nombres + ' ' + a.apellidos,
    telefono: soloNum_(r.telefono) || a.telefono });
  return { estado: 'ok', token: t, nombre: a.nombres };
}

function guardarEvento_(ev) {
  ev = Object.assign({}, ev); ev.imagen = guardarImagen_(ev.imagen, 'evento');
  var lista = filas_('Eventos');
  if (!ev.id) {
    ev.id = 'ev' + Date.now().toString(36); ev.creado = new Date().toISOString(); agregar_('Eventos', ev);
    if (ev.estado === 'publicado') aviso_({ tipo: 'evento', titulo: 'Nueva jornada: ' + ev.titulo, mensaje: fechaLarga_(ev.fecha) + ' · ' + hora12_(ev.hora) + ' · ' + ev.lugar + '. ¡Inscríbete!', link: 'eventos.html#' + ev.id });
    return ev;
  }
  var i = indice_(lista, 'id', ev.id); if (i < 0) throw new Error('El evento ya no existe.');
  var old = lista[i], nu = Object.assign({}, old, ev); escribirFila_('Eventos', i + 2, nu);
  var cambios = [];
  if (old.fecha !== nu.fecha) cambios.push('nueva fecha: ' + fechaLarga_(nu.fecha));
  if (old.hora !== nu.hora) cambios.push('nueva hora: ' + hora12_(nu.hora));
  if (old.lugar !== nu.lugar) cambios.push('nuevo lugar: ' + nu.lugar);
  if (nu.estado === 'publicado' && old.estado !== 'publicado') aviso_({ tipo: 'evento', titulo: 'Nueva jornada: ' + nu.titulo, mensaje: fechaLarga_(nu.fecha) + ' · ' + hora12_(nu.hora) + ' · ' + nu.lugar + '. ¡Inscríbete!', link: 'eventos.html#' + nu.id });
  else if (nu.estado === 'publicado' && cambios.length) { var m = cambios.join(' · '); aviso_({ tipo: 'cambio', titulo: 'Cambio en: ' + nu.titulo, mensaje: m.charAt(0).toUpperCase() + m.slice(1) + '.', link: 'eventos.html#' + nu.id }); }
  return nu;
}

function borrarEvento_(id) {
  var ev = filas_('Eventos').filter(function (e) { return e.id === id; })[0];
  borrarFila_('Eventos', 'id', id);
  var hoy = Utilities.formatDate(new Date(), 'America/Caracas', 'yyyy-MM-dd');
  if (ev && ev.estado === 'publicado' && ev.fecha >= hoy) aviso_({ tipo: 'cancelado', titulo: 'Evento cancelado: ' + ev.titulo, mensaje: 'La actividad del ' + fechaLarga_(ev.fecha) + ' no se realizará. Disculpa las molestias.', link: 'eventos.html' });
  return true;
}

function guardarTip_(t) {
  t = Object.assign({}, t); t.imagen = guardarImagen_(t.imagen, 'tip');
  var pub = !!t.publicado; t.publicado = pub ? 'SI' : 'NO';
  var lista = filas_('Tips');
  if (!t.id) {
    t.id = 'tp' + Date.now().toString(36); agregar_('Tips', t);
    if (pub) aviso_({ tipo: 'tip', titulo: 'Nuevo consejo: ' + t.titulo, mensaje: t.resumen, link: 'tips.html#' + t.id });
  } else {
    var i = indice_(lista, 'id', t.id); if (i < 0) throw new Error('El tip ya no existe.');
    var was = lista[i].publicado === 'SI'; escribirFila_('Tips', i + 2, Object.assign({}, lista[i], t));
    if (pub && !was) aviso_({ tipo: 'tip', titulo: 'Nuevo consejo: ' + t.titulo, mensaje: t.resumen, link: 'tips.html#' + t.id });
  }
  t.publicado = pub; return t;
}

function aviso_(a) {
  a = Object.assign({ id: 'av' + Date.now().toString(36) + Math.random().toString(36).slice(2, 5), fecha: new Date().toISOString() }, a);
  agregar_('Avisos', a); return a;
}

/* Las imágenes subidas (data:...) no caben en una celda: se guardan en Drive y la hoja guarda el enlace */
function guardarImagen_(img, tipo) {
  if (!img || String(img).indexOf('data:') !== 0) return img || '';
  var m = String(img).match(/^data:([^;]+);base64,(.*)$/); if (!m) return '';
  var c = config_(), carpeta;
  try { carpeta = c.carpeta_imagenes ? DriveApp.getFolderById(c.carpeta_imagenes) : null; } catch (e) { carpeta = null; }
  if (!carpeta) { carpeta = DriveApp.createFolder('PAM Baruta · imágenes del sitio'); setConfig_('carpeta_imagenes', carpeta.getId()); }
  var f = carpeta.createFile(Utilities.newBlob(Utilities.base64Decode(m[2]), m[1], tipo + '-' + Date.now() + '.jpg'));
  f.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  return 'https://lh3.googleusercontent.com/d/' + f.getId();
}

/* =====================================================================
   5. Utilidades
   ===================================================================== */
function filas_(nombre) {
  var h = SpreadsheetApp.getActive().getSheetByName(nombre); if (!h) return [];
  var n = h.getLastRow(), cols = HOJAS[nombre]; if (n < 2) return [];
  return h.getRange(2, 1, n - 1, cols.length).getValues().filter(function (r) { return String(r[0]) !== ''; }).map(function (r) { return objeto_(cols, r); });
}
function objeto_(cols, r) { var o = {}; cols.forEach(function (c, i) { o[c] = texto_(r[i], c); }); return o; }
function texto_(v, col) {
  if (v instanceof Date) {   // por si alguien escribe a mano y Sheets lo convierte en fecha
    if (col === 'hora' || col === 'fin') return Utilities.formatDate(v, 'America/Caracas', 'HH:mm');
    if (col === 'fecha' || col === 'evento_fecha') return Utilities.formatDate(v, 'America/Caracas', 'yyyy-MM-dd');
    return Utilities.formatDate(v, 'America/Caracas', 'dd/MM/yyyy');
  }
  return v === null || v === undefined ? '' : String(v);
}
function fila_(nombre, o) { return HOJAS[nombre].map(function (c) { var v = o[c]; return v === undefined || v === null ? '' : String(v); }); }
function agregar_(nombre, o) {
  var h = SpreadsheetApp.getActive().getSheetByName(nombre) || hoja_(nombre), r = h.getLastRow() + 1, cols = HOJAS[nombre];
  var rg = h.getRange(r, 1, 1, cols.length); rg.setNumberFormat('@'); rg.setValues([fila_(nombre, o)]);
}
function escribirFila_(nombre, fila, o) {
  var h = SpreadsheetApp.getActive().getSheetByName(nombre), cols = HOJAS[nombre];
  var rg = h.getRange(fila, 1, 1, cols.length); rg.setNumberFormat('@'); rg.setValues([fila_(nombre, o)]);
}
function borrarFila_(nombre, campo, valor) {
  var lista = filas_(nombre), i = indice_(lista, campo, valor);
  if (i >= 0) SpreadsheetApp.getActive().getSheetByName(nombre).deleteRow(i + 2);
}
function indice_(lista, campo, valor) { for (var i = 0; i < lista.length; i++) if (lista[i][campo] === valor) return i; return -1; }

function config_() {
  var h = SpreadsheetApp.getActive().getSheetByName('Config') || configHoja_(), n = h.getLastRow(), o = {};
  if (n > 1) h.getRange(2, 1, n - 1, 2).getValues().forEach(function (r) { o[String(r[0])] = String(r[1]); });
  return o;
}
function setConfig_(k, v) {
  var h = SpreadsheetApp.getActive().getSheetByName('Config') || configHoja_(), n = h.getLastRow();
  var v0 = n > 1 ? h.getRange(2, 1, n - 1, 1).getValues() : [];
  for (var i = 0; i < v0.length; i++) if (String(v0[i][0]) === k) { h.getRange(i + 2, 2).setValue(String(v)); return; }
  h.appendRow([k, String(v), '']);
}
function sesionValida_(t) { return !!t && CacheService.getScriptCache().get('ses_' + t) === '1'; }

var ABC = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';   // sin 0/O/1/I para dictar por teléfono
function rand_(n) { var s = ''; for (var i = 0; i < n; i++) s += ABC.charAt(Math.floor(Math.random() * ABC.length)); return s; }
function token_(tipo, usados) {
  var t;
  do {
    if (tipo === 'U') t = 'PAM-U-' + rand_(4) + '-' + rand_(4);
    else t = 'PAM-' + tipo + '-' + Utilities.formatDate(new Date(), 'America/Caracas', 'yyMMdd') + '-' + rand_(6);
  } while (usados[t]);
  usados[t] = 1; return t;
}
function tokensUsados_() {
  var u = {};
  [['Afiliados', 'token_afiliado'], ['Registros', 'token_registro'], ['Inscripciones', 'token_inscripcion']].forEach(function (p) {
    filas_(p[0]).forEach(function (r) { u[r[p[1]]] = 1; });
  });
  return u;
}

function normDoc_(tipo, nro) { return tipo === 'PASSPORT' ? String(nro || '').toUpperCase().replace(/\s/g, '') : String(nro || '').replace(/\D/g, ''); }
function soloNum_(t) { return String(t || '').replace(/\D/g, ''); }
function mayus_(s) { return String(s || '').trim().toUpperCase(); }
function primerNombre_(s) { var p = String(s || '').split(' ')[0].toLowerCase(); return p.charAt(0).toUpperCase() + p.slice(1); }
function ddmmaaaa_(iso) { if (!iso) return ''; var p = String(iso).split('-'); return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : String(iso); }
function fmtFecha_(d) { return Utilities.formatDate(d, 'America/Caracas', 'dd/MM/yyyy'); }
function sha256_(t) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, t, Utilities.Charset.UTF_8)
    .map(function (b) { return ('0' + (b & 255).toString(16)).slice(-2); }).join('');
}
var MESES_ = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
var DIAS_ = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
function fechaLarga_(iso) { var p = String(iso).split('-').map(Number), d = new Date(p[0], p[1] - 1, p[2]); return DIAS_[d.getDay()] + ' ' + p[2] + ' de ' + MESES_[p[1] - 1]; }
function hora12_(h) { if (!h) return ''; var p = String(h).split(':').map(Number), s = p[0] >= 12 ? 'pm' : 'am', H = p[0] % 12 || 12; return H + ':' + ('0' + p[1]).slice(-2) + ' ' + s; }
