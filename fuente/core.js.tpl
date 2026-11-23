/* =====================================================================
   PAM Baruta · núcleo compartido por todas las páginas
   - CONFIG: datos fijos (Signo, admin, teléfonos)
   - DataService: CAPA DE DATOS. Hoy guarda en el navegador (modo demo).
     Sistemas debe reemplazar SOLO estas funciones por llamadas a su API.
   - Tokens, encabezado, pie, utilidades
   ===================================================================== */
const CONFIG = {
  tel: '0212 909 5270', telHref: 'tel:+582129095270',
  tel2: '0212 628 5270', tel2Href: 'tel:+582126285270',
  waMed: '0414 115 8604', waMedHref: 'https://wa.me/584141158604',
  signo: {
    rif_company: '',              // RIF de la póliza PAM Baruta — POR CONFIRMAR
    nombre_company: 'PAM BARUTA', // Nombre como lo pide Signo — POR CONFIRMAR
    vigencia_meses: 12            // Signo acepta máximo 1 año
  },
  /* ---- Base de datos ----
     backend: 'sheets' (Google Sheets, la que se usa hoy) o 'supabase' (preparada en supabase/).
     Para pasar a Supabase: llena supabase.url y supabase.anonKey y cambia backend a 'supabase'. */
  backend: 'sheets',
  supabase: {
    url: '',      // https://TU-PROYECTO.supabase.co
    anonKey: ''   // clave pública (anon o publishable). Es segura en el navegador: solo puede llamar a pam_api().
  },
  /* ---- Google Sheets ----
     api: URL de la aplicación web de Apps Script (termina en /exec). Vacía = modo demostración (datos solo en este navegador).
     hojaUrl: enlace a la hoja de cálculo (solo se muestra en el admin). */
  api: 'https://script.google.com/macros/s/AKfycbzN45Bs5WS83AQ3Iy4lcslnkOs04IZr1Yb4Bz8SL46ZpS3EyO1YD--Zt8KazaWab_8/exec',
  hojaUrl: 'https://docs.google.com/spreadsheets/d/1ws9OlMUZvJaidVZ5vr9XjTSU_zAz4LmF-CH8rr3JRzE/edit',
  hostsProduccion: ['pambaruta.com', 'www.pambaruta.com'],
  /* Solo para el MODO DEMO. Con Google Sheets el usuario y la clave se validan en la hoja (pestaña Config). */
  admin: { usuario: 'admin', claveSha256: 'e389e429535c4968c1374a49d8ae6d0c3cd3807ccfedc9d41f2647bff8748db2' }
};

const Tokens = {
  ABC: '23456789ABCDEFGHJKLMNPQRSTUVWXYZ',          // sin 0/O/1/I para dictar por teléfono
  rand(n){ const a = new Uint32Array(n); crypto.getRandomValues(a); return [...a].map(x => this.ABC[x % this.ABC.length]).join(''); },
  make(kind){
    if (kind === 'U') return `PAM-U-${this.rand(4)}-${this.rand(4)}`;            // persona
    const d = new Date(), p = v => String(v).padStart(2, '0');
    return `PAM-${kind}-${String(d.getFullYear()).slice(2)}${p(d.getMonth()+1)}${p(d.getDate())}-${this.rand(6)}`; // R registro, E inscripción a evento
  },
  unique(kind, used){ let t; do { t = this.make(kind); } while (used.has(t)); used.add(t); return t; },
  /* Signo: cédula solo números; pasaporte en mayúsculas sin espacios */
  normDoc(tipo, nro){ return tipo === 'PASSPORT' ? String(nro).toUpperCase().replace(/\s/g, '') : String(nro).replace(/\D/g, ''); },
  validDoc(tipo, nro){ return tipo === 'PASSPORT' ? /^[A-Z0-9]{5,15}$/i.test(String(nro).replace(/\s/g, '')) : /^[VE]?\d{6,9}$/i.test(String(nro).replace(/[\s.\-]/g, '')); }
};

const SEED = { avisos: [], eventos: [], tips: [] };   // sin contenido de ejemplo: todo se crea desde el admin

/* Zonas de cobertura (fuente: Zonas_Cobertura_Baruta.xlsx). lat/lon APROXIMADOS para el mapa referencial.
   obs_interna: nota operativa original, solo para el admin. */
const ZONAS = [{"id": "z1", "nombre": "Baruta", "sector": "Baruta casco / Las Minas", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am. Si se necesita ambulancia de noche, se puede acordar un punto de encuentro. Aplica en la zona residencial.", "obs_interna": "SERVICIOS HASTA LAS 9 PM - PE NEGOCIABLE (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.435, "lon": -66.875}, {"id": "z2", "nombre": "La Limonera", "sector": "Baruta casco / Las Minas", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio hasta las 6:00 pm. Después, te atendemos por telemedicina o en un punto de encuentro acordado.", "obs_interna": "SERVICIO HASTA LAS 6:00PM - A PARTIR 6:01PM OFRECER P.E / TLM", "lat": 10.4285, "lon": -66.8835}, {"id": "z3", "nombre": "Las Minas de Baruta", "sector": "Baruta casco / Las Minas", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am. Si se necesita ambulancia de noche, se puede acordar un punto de encuentro (por ejemplo, la redoma de Las Minas o la Av. Principal).", "obs_interna": "SERVICIOS HASTA LAS 9 PM - PE NEGOCIABLE PREFERIBLEMENTE EN REDOMA MINAS DE BARUTA, REDOMA LOS MANGOS, AV. PRINCIPAL, LA REDOMA DE LA VIRGEN, EL AMBULATORIO DE LAS MINAS (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.441, "lon": -66.87}, {"id": "z4", "nombre": "C.C.C. Tamanaco (CCCT)", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4845, "lon": -66.8525}, {"id": "z5", "nombre": "C.C. las Mercedes", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4815, "lon": -66.8615}, {"id": "z6", "nombre": "C.C. Tolón", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.479, "lon": -66.8595}, {"id": "z7", "nombre": "Chuao", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.483, "lon": -66.846}, {"id": "z8", "nombre": "Colinas de Bello Monte", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4875, "lon": -66.87}, {"id": "z9", "nombre": "Colinas de Tamanaco", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4765, "lon": -66.8505}, {"id": "z10", "nombre": "Colinas de Valle Arriba", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.469, "lon": -66.8605}, {"id": "z11", "nombre": "Colinas del Tamanaco", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4745, "lon": -66.848}, {"id": "z12", "nombre": "Cumbres de Curumo", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.465, "lon": -66.871}, {"id": "z13", "nombre": "La Peña de las Mercedes", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4745, "lon": -66.863}, {"id": "z14", "nombre": "Las Mercedes", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.48, "lon": -66.8575}, {"id": "z15", "nombre": "Lomas de Chuao", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.479, "lon": -66.842}, {"id": "z16", "nombre": "Los Naranjos de las Mercedes", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.47, "lon": -66.8455}, {"id": "z17", "nombre": "San Román", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4765, "lon": -66.8665}, {"id": "z18", "nombre": "Valle Arriba", "sector": "Las Mercedes / Chuao", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.473, "lon": -66.8555}, {"id": "z19", "nombre": "Caurimare", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.474, "lon": -66.825}, {"id": "z20", "nombre": "C.C. Plaza las Americas", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4715, "lon": -66.8285}, {"id": "z21", "nombre": "Chulavista", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4785, "lon": -66.832}, {"id": "z22", "nombre": "El Cafetal", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.469, "lon": -66.831}, {"id": "z23", "nombre": "San Luis", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.463, "lon": -66.8215}, {"id": "z24", "nombre": "Santa Inés", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4565, "lon": -66.829}, {"id": "z25", "nombre": "Santa Marta", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4605, "lon": -66.8255}, {"id": "z26", "nombre": "Santa Paula", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.465, "lon": -66.834}, {"id": "z27", "nombre": "Santa Rosa de Lima", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4845, "lon": -66.8355}, {"id": "z28", "nombre": "Santa Sofía", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4695, "lon": -66.8385}, {"id": "z29", "nombre": "Vizcaya", "sector": "El Cafetal", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.455, "lon": -66.836}, {"id": "z30", "nombre": "Granjerías de la Trinidad", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am.", "obs_interna": "SERVICIOS HASTA LAS 9 PM (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.425, "lon": -66.8505}, {"id": "z31", "nombre": "Hoyo de la Puerta", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am.", "obs_interna": "SERVICIOS HASTA LAS 9 PM (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.4105, "lon": -66.87}, {"id": "z32", "nombre": "Santa Cruz del Este", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio hasta las 6:00 pm. En la noche, la atención se coordina en un punto de encuentro en el C.C. Concresa.", "obs_interna": "SERVICIO HASTA LAS 6PM - (NOCTURNO) P.E C.C. CONCRESA", "lat": 10.4285, "lon": -66.8395}, {"id": "z33", "nombre": "Alto Prado", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.456, "lon": -66.8825}, {"id": "z34", "nombre": "C.C. Concresa", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4585, "lon": -66.869}, {"id": "z35", "nombre": "C.C. Santa Fe", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.459, "lon": -66.862}, {"id": "z36", "nombre": "Cerro Verde", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.468, "lon": -66.865}, {"id": "z37", "nombre": "Conjunto Residencial Santa Fe", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.454, "lon": -66.86}, {"id": "z38", "nombre": "El Peñon", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4605, "lon": -66.8755}, {"id": "z39", "nombre": "El Placer", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am.", "obs_interna": "SERVICIOS HASTA LAS 9 PM (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.4305, "lon": -66.856}, {"id": "z40", "nombre": "La Alameda", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.452, "lon": -66.8725}, {"id": "z41", "nombre": "La Tahona", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.442, "lon": -66.843}, {"id": "z42", "nombre": "La Trinidad", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.436, "lon": -66.86}, {"id": "z43", "nombre": "Lomas de Prados del Este", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4655, "lon": -66.8855}, {"id": "z44", "nombre": "Los Campitos", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.47, "lon": -66.878}, {"id": "z45", "nombre": "Los Guayabitos", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4285, "lon": -66.866}, {"id": "z46", "nombre": "Los Samanes", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4445, "lon": -66.856}, {"id": "z47", "nombre": "Manzanares", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.45, "lon": -66.865}, {"id": "z48", "nombre": "Mirador de los Campitos", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4725, "lon": -66.8825}, {"id": "z49", "nombre": "Piedra Azul", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.447, "lon": -66.878}, {"id": "z50", "nombre": "Prados del Este", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.462, "lon": -66.88}, {"id": "z51", "nombre": "Santa Fe", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4565, "lon": -66.865}, {"id": "z52", "nombre": "Sorocaima", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.458, "lon": -66.892}, {"id": "z53", "nombre": "Universidad Simón Bolívar", "sector": "Prados del Este / Santa Fe / La Trinidad", "confirmada": true, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.41, "lon": -66.889}, {"id": "z54", "nombre": "El Pedregal", "sector": "Limítrofe", "confirmada": false, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am.", "obs_interna": "SERVICIOS HASTA LAS 9 PM (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.495, "lon": -66.856}, {"id": "z55", "nombre": "La Guairita", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.432, "lon": -66.838}, {"id": "z56", "nombre": "Las Esmeraldas", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.433, "lon": -66.845}, {"id": "z57", "nombre": "Las Marías", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.449, "lon": -66.8245}, {"id": "z58", "nombre": "Lomas del Club Hípico", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4445, "lon": -66.8905}, {"id": "z59", "nombre": "Los Castaños", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.451, "lon": -66.8345}, {"id": "z60", "nombre": "Los Geranios", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.462, "lon": -66.841}, {"id": "z61", "nombre": "Los Pomelos", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.447, "lon": -66.84}, {"id": "z62", "nombre": "Monte Alto", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.452, "lon": -66.83}, {"id": "z63", "nombre": "Monte Pino", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4465, "lon": -66.831}, {"id": "z64", "nombre": "Monterrey", "sector": "Limítrofe", "confirmada": false, "estado": "parcial", "h24": "PARCIAL", "detalle": "Médico a domicilio de 7:00 am a 9:00 pm. En la noche te atendemos por telemedicina y, si hace falta, la visita a tu casa se programa para las 7:00 am.", "obs_interna": "SERVICIOS HASTA LAS 9 PM (OFRECER TLM, PROGRAMAR LA AMD PARA LAS 7 AM)", "lat": 10.46, "lon": -66.8175}, {"id": "z65", "nombre": "Santa Clara", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.4535, "lon": -66.845}, {"id": "z66", "nombre": "Terrazas del Club Hípico", "sector": "Limítrofe", "confirmada": false, "estado": "completa", "h24": "SI", "detalle": "", "obs_interna": "", "lat": 10.448, "lon": -66.896}];

/* ===================== Datos: modo demostración (navegador) ===================== */
const LocalData = {
  KEY: 'pam_db_v4',
  _empty(){ return { usuarios: {}, registros: [], eventos: SEED.eventos.slice(), inscripciones: [], tips: SEED.tips.slice(), avisos: SEED.avisos.slice() }; },
  _load(){
    if (this._mem) return this._mem;
    try { const d = JSON.parse(localStorage.getItem(this.KEY)); if (d) { d.avisos ||= SEED.avisos.slice(); return d; } } catch (e) { return (this._mem = this._empty()); }
    const d = this._empty(); this._save(d); return d;
  },
  _save(db){ try { if (this._mem) throw 0; localStorage.setItem(this.KEY, JSON.stringify(db)); } catch (e) { this._mem = db; } },
  _used(db){ return new Set([...Object.values(db.usuarios).map(u => u.token), ...db.registros.map(r => r.token), ...db.inscripciones.map(i => i.token)]); },
  key: (tipo, nro) => tipo + ':' + nro,

  /* ---- Afiliados ---- Producción: consultar la base de afiliados (Signo / backend) */
  async findUser(tipo, nro){ return this._load().usuarios[this.key(tipo, Tokens.normDoc(tipo, nro))] || null; },
  async saveRegistration(data){
    const db = this._load(), now = new Date().toISOString(), used = this._used(db);
    const upsert = (p, rol, titular) => {
      const k = this.key(p.tipo_documento, p.nro_documento); let u = db.usuarios[k];
      if (!u) { u = { token: Tokens.unique('U', used), tipo_documento: p.tipo_documento, nro_documento: p.nro_documento, creado: now }; db.usuarios[k] = u; }
      Object.assign(u, { rol, nombre: p.nombre, apellidos: p.apellidos, telefono: p.telefono || u.telefono || '', titular: titular || null, actualizado: now });
      return u;
    };
    const tit = upsert(data, 'TITULAR');
    data.dependientes.forEach(d => { d.token = upsert(d, 'DEPENDIENTE', data.nro_documento).token; });
    const reg = { token: Tokens.unique('R', used), userToken: tit.token, fecha: now, datos: data };
    db.registros.push(reg); this._save(db);
    return { userToken: tit.token, regToken: reg.token, deps: data.dependientes.map(d => ({ nombre: d.nombre, token: d.token })) };
  },
  async listRegistros(){ return this._load().registros.slice().reverse(); },

  /* ---- Eventos ---- */
  async listEventos({ soloPublicados = true } = {}){
    const db = this._load();
    return db.eventos.filter(e => !soloPublicados || e.estado === 'publicado')
      .map(e => ({ ...e, inscritos: db.inscripciones.filter(i => i.eventoId === e.id).length }))
      .sort((a, b) => (a.fecha + a.hora).localeCompare(b.fecha + b.hora));
  },
  async saveEvento(ev){
    const db = this._load();
    if (!ev.id) {
      ev.id = 'ev' + Date.now().toString(36); ev.creado = new Date().toISOString(); db.eventos.push(ev);
      if (ev.estado === 'publicado') this._aviso(db, { tipo: 'evento', titulo: 'Nueva jornada: ' + ev.titulo, mensaje: `${fechaLarga(ev.fecha)} · ${hora12(ev.hora)} · ${ev.lugar}. ¡Inscríbete!`, link: 'eventos.html#' + ev.id });
    } else {
      const i = db.eventos.findIndex(e => e.id === ev.id), old = db.eventos[i]; db.eventos[i] = { ...old, ...ev }; const nu = db.eventos[i];
      const cambios = [];
      if (old.fecha !== nu.fecha) cambios.push('nueva fecha: ' + fechaLarga(nu.fecha));
      if (old.hora !== nu.hora) cambios.push('nueva hora: ' + hora12(nu.hora));
      if (old.lugar !== nu.lugar) cambios.push('nuevo lugar: ' + nu.lugar);
      if (nu.estado === 'publicado' && old.estado !== 'publicado') this._aviso(db, { tipo: 'evento', titulo: 'Nueva jornada: ' + nu.titulo, mensaje: `${fechaLarga(nu.fecha)} · ${hora12(nu.hora)} · ${nu.lugar}. ¡Inscríbete!`, link: 'eventos.html#' + nu.id });
      else if (nu.estado === 'publicado' && cambios.length) this._aviso(db, { tipo: 'cambio', titulo: 'Cambio en: ' + nu.titulo, mensaje: cambios.join(' · ').replace(/^./, c => c.toUpperCase()) + '.', link: 'eventos.html#' + nu.id });
    }
    this._save(db); return ev;
  },
  async deleteEvento(id){
    const db = this._load(), ev = db.eventos.find(e => e.id === id);
    db.eventos = db.eventos.filter(e => e.id !== id);
    if (ev && ev.estado === 'publicado' && ev.fecha >= new Date().toISOString().slice(0, 10)) this._aviso(db, { tipo: 'cancelado', titulo: 'Evento cancelado: ' + ev.titulo, mensaje: `La actividad del ${fechaLarga(ev.fecha)} no se realizará. Disculpa las molestias.`, link: 'eventos.html' });
    this._save(db);
  },
  async inscribir(eventoId, { tipo_documento, nro_documento, telefono }){
    const db = this._load(), ev = db.eventos.find(e => e.id === eventoId);
    if (!ev) throw new Error('El evento ya no está disponible.');
    const nro = Tokens.normDoc(tipo_documento, nro_documento), u = db.usuarios[this.key(tipo_documento, nro)];
    if (!u) return { estado: 'no_registrado' };
    const ya = db.inscripciones.find(i => i.eventoId === eventoId && i.userToken === u.token);
    if (ya) return { estado: 'ya_inscrito', token: ya.token, nombre: u.nombre };
    if (ev.cupos && db.inscripciones.filter(i => i.eventoId === eventoId).length >= +ev.cupos) return { estado: 'sin_cupos' };
    const ins = { token: Tokens.unique('E', this._used(db)), eventoId, userToken: u.token, tipo_documento, nro_documento: nro, nombre: u.nombre + ' ' + u.apellidos, telefono: telefono || u.telefono, fecha: new Date().toISOString() };
    db.inscripciones.push(ins); this._save(db);
    return { estado: 'ok', token: ins.token, nombre: u.nombre };
  },
  async listInscritos(eventoId){ return this._load().inscripciones.filter(i => i.eventoId === eventoId); },

  /* ---- Cobertura ---- */
  async listZonas(){ return ZONAS; },

  /* ---- Tips ---- */
  async listTips({ soloPublicados = true } = {}){ return this._load().tips.filter(t => !soloPublicados || t.publicado).sort((a, b) => b.fecha.localeCompare(a.fecha)); },
  async saveTip(t){
    const db = this._load();
    if (!t.id) { t.id = 'tp' + Date.now().toString(36); db.tips.push(t); if (t.publicado) this._aviso(db, { tipo: 'tip', titulo: 'Nuevo consejo: ' + t.titulo, mensaje: t.resumen, link: 'tips.html#' + t.id }); }
    else { const i = db.tips.findIndex(x => x.id === t.id), was = db.tips[i].publicado; db.tips[i] = { ...db.tips[i], ...t };
      if (t.publicado && !was) this._aviso(db, { tipo: 'tip', titulo: 'Nuevo consejo: ' + t.titulo, mensaje: t.resumen, link: 'tips.html#' + t.id }); }
    this._save(db); return t;
  },

  /* ---- Avisos / notificaciones ---- Producción: al crear un aviso, el servidor envía también la notificación push */
  _aviso(db, a){ db.avisos ||= []; db.avisos.push({ id: 'av' + Date.now().toString(36) + Math.random().toString(36).slice(2, 5), fecha: new Date().toISOString(), ...a }); },
  async listAvisos(){ return (this._load().avisos || []).slice().sort((a, b) => b.fecha.localeCompare(a.fecha)); },
  async crearAviso(a){ const db = this._load(); this._aviso(db, { tipo: 'aviso', ...a }); this._save(db); },
  async deleteAviso(id){ const db = this._load(); db.avisos = (db.avisos || []).filter(a => a.id !== id); this._save(db); },
  async deleteTip(id){ const db = this._load(); db.tips = db.tips.filter(t => t.id !== id); this._save(db); },

  /* ---- Admin (demo) ---- */
  async login(usuario, clave){
    const h = await sha256(clave);
    const ok = usuario.trim().toLowerCase() === CONFIG.admin.usuario && h === CONFIG.admin.claveSha256;
    if (ok) Sesion.set('demo');
    return ok;
  },
  async resumen(){
    const db = this._load(), us = Object.values(db.usuarios);
    return { titulares: us.filter(u => u.rol === 'TITULAR').length, familiares: us.filter(u => u.rol === 'DEPENDIENTE').length,
      registros: db.registros.length, inscripciones: db.inscripciones.length, tipsPublicados: db.tips.filter(t => t.publicado).length };
  },
  async signoRows(){ return this.toSignoRows(); },
  async marcarSignoCargado(){ return 0; },

  /* ---- Exportación Signo (pestaña DATOS) ---- */
  toSignoRows(){
    const db = this._load(), last = {};
    db.registros.forEach(r => { last[r.userToken] = r; });
    const f = d => { const x = new Date(d); return [x.getDate(), x.getMonth()+1].map(v => String(v).padStart(2, '0')).join('/') + '/' + x.getFullYear(); };
    const iso = s => { const [y, m, d] = s.split('-'); return `${d}/${m}/${y}`; };
    const tel = t => (t || '').replace(/\D/g, '');
    const g = sx => sx === 'Femenino' ? 'F' : sx === 'Masculino' ? 'M' : '';
    const S = CONFIG.signo;
    const head = ['tipo_documento','nro_documento','nombres','apellidos','genero','fecha_nacimiento','nro_afiliacion','rif_company','nombre_company','fecha_inicio','fecha_fin','nro_documento_titular','tipo_documento_titular','parentesco','tlf'];
    const rows = [];
    Object.values(last).forEach(r => {
      const d = r.datos, ini = new Date(r.fecha), fin = new Date(ini); fin.setMonth(fin.getMonth() + S.vigencia_meses); fin.setDate(fin.getDate() - 1);
      const base = ['', S.rif_company, S.nombre_company, f(ini), f(fin)];
      rows.push([d.tipo_documento, d.nro_documento, d.nombre, d.apellidos, g(d.sexo), iso(d.nacimiento), ...base, '', '', '', tel(d.telefono)]);
      d.dependientes.forEach(p => rows.push([p.tipo_documento, p.nro_documento, p.nombre, p.apellidos, g(p.sexo), iso(p.nacimiento), ...base, d.nro_documento, d.tipo_documento, p.parentesco, tel(p.telefono)]));
    });
    return [head, ...rows];
  }
};
/* ===================== Sesión del admin ===================== */
const Sesion = {
  get(){ if (window.__admS) return window.__admS; try { return sessionStorage.getItem('pam_admin_s') || ''; } catch (e) { return ''; } },
  set(t){ window.__admS = t; try { sessionStorage.setItem('pam_admin_s', t); } catch (e) {} },
  clear(){ window.__admS = ''; try { sessionStorage.removeItem('pam_admin_s'); sessionStorage.removeItem('pam_admin'); } catch (e) {} }
};

/* ===================== Datos: Google Sheets (Apps Script) ===================== */
/* Las dos bases hablan el mismo idioma: { action, auth, ...datos } → { ok, data }.
   Google Sheets responde en CONFIG.api (/exec); Supabase en la función pam_api() (supabase/migrations). */
const RemoteData = {
  _cache: {},
  supabase(){ return CONFIG.backend === 'supabase'; },
  configurado(){ return this.supabase() ? !!(CONFIG.supabase.url && CONFIG.supabase.anonKey) : !!CONFIG.api; },
  nombre(){ return this.supabase() ? 'Supabase' : 'Google Sheets'; },
  _fetch(body, signal){
    if (this.supabase()) {
      const k = CONFIG.supabase.anonKey, h = { 'Content-Type': 'application/json', apikey: k };
      if (/^eyJ/.test(k)) h.Authorization = 'Bearer ' + k;   // claves anon antiguas (JWT)
      return fetch(CONFIG.supabase.url.replace(/\/$/, '') + '/rest/v1/rpc/pam_api', { method: 'POST', signal, headers: h, body: JSON.stringify({ req: body }) });
    }
    return fetch(CONFIG.api, { method: 'POST', redirect: 'follow', signal, headers: { 'Content-Type': 'text/plain;charset=utf-8' }, body: JSON.stringify(body) });
  },
  async call(action, payload = {}, ms = 25000){
    const ctl = typeof AbortController !== 'undefined' ? new AbortController() : null, tm = ctl && setTimeout(() => ctl.abort(), ms);
    try {
      const r = await this._fetch({ action, auth: Sesion.get(), ...payload }, ctl?.signal);
      const j = await r.json();
      if (!j.ok) {
        if (j.code === 'auth' && action !== 'login') { Sesion.clear(); if (/\/admin\/|admin/.test(location.pathname)) location.reload(); }
        throw new Error(j.error || 'Error del servidor');
      }
      return j.data;
    } finally { if (tm) clearTimeout(tm); }
  },
  _memo(k, fn){ return this._cache[k] ||= fn().catch(e => { delete this._cache[k]; throw e; }); },
  async _write(action, payload){ const r = await this.call(action, payload); this._cache = {}; return r; },

  findUser(tipo, nro){ return this.call('buscar', { tipo_documento: tipo, nro_documento: Tokens.normDoc(tipo, nro) }); },
  saveRegistration(datos){ return this._write('registrar', { datos }); },
  listRegistros(){ return this._memo('regs', () => this.call('registros')); },
  listEventos({ soloPublicados = true } = {}){ return this._memo('ev' + soloPublicados, () => this.call('eventos', { todos: !soloPublicados })); },
  saveEvento(evento){ return this._write('guardarEvento', { evento }); },
  deleteEvento(id){ return this._write('borrarEvento', { id }); },
  inscribir(eventoId, d){ return this._write('inscribir', { eventoId, ...d, nro_documento: Tokens.normDoc(d.tipo_documento, d.nro_documento) }); },
  listInscritos(eventoId){ return this.call('inscritos', { eventoId }); },
  async listZonas(){ return ZONAS; },
  listTips({ soloPublicados = true } = {}){ return this._memo('tp' + soloPublicados, () => this.call('tips', { todos: !soloPublicados })); },
  saveTip(tip){ return this._write('guardarTip', { tip }); },
  deleteTip(id){ return this._write('borrarTip', { id }); },
  listAvisos(){ return this._memo('av', () => this.call('avisos')); },
  crearAviso(aviso){ return this._write('crearAviso', { aviso }); },
  deleteAviso(id){ return this._write('borrarAviso', { id }); },
  async login(usuario, clave){ const r = await this.call('login', { usuario, clave }); if (r && r.sesion) { Sesion.set(r.sesion); return true; } return false; },
  resumen(){ return this.call('resumen'); },
  signoRows(){ return this.call('signo'); },
  marcarSignoCargado(){ return this._write('marcarSignoCargado'); }
};

/* ===================== DataService: elige el modo =====================
   Con CONFIG.api (o Supabase configurado): usa la base remota. Si la conexión no responde fuera de pambaruta.com
   (por ejemplo, en la vista previa de Claude, que bloquea conexiones externas),
   cae al modo demostración y lo avisa. En pambaruta.com nunca guarda solo en el navegador. */
const Modo = {
  remoto: false, _p: null,
  decidir(){
    return this._p ||= (async () => {
      if (!RemoteData.configurado()) return false;
      try { await RemoteData.call('ping', {}, 8000); return true; }
      catch (e) { if (CONFIG.hostsProduccion.includes(location.hostname)) return true; this.demo = true; return false; }
    })().then(r => (this.remoto = r));
  }
};
const DataService = {
  isAdmin(){ return !!Sesion.get(); },
  logout(){ Sesion.clear(); }
};
['findUser','saveRegistration','listRegistros','listEventos','saveEvento','deleteEvento','inscribir','listInscritos','listZonas',
 'listTips','saveTip','deleteTip','listAvisos','crearAviso','deleteAviso','login','resumen','signoRows','marcarSignoCargado']
  .forEach(m => { DataService[m] = async (...a) => ((await Modo.decidir()) ? RemoteData : LocalData)[m](...a); });

/* SHA-256: usa crypto.subtle si existe; si no (algunos visores), una versión en JavaScript */
function sha256js(ascii){
  const rr=(v,a)=>(v>>>a)|(v<<(32-a)); let maxWord=Math.pow(2,32), result='', words=[], bitLen=ascii.length*8, hash=[], k=[], primeCounter=0, isC={};
  for(let c=2;primeCounter<64;c++){ if(!isC[c]){ for(let i=0;i<313;i+=c) isC[i]=c; hash[primeCounter]=(Math.pow(c,.5)*maxWord)|0; k[primeCounter++]=(Math.pow(c,1/3)*maxWord)|0; } }
  hash=hash.slice(0,8); ascii+='\x80'; while(ascii.length%64-56) ascii+='\x00';
  for(let i=0;i<ascii.length;i++){ const j=ascii.charCodeAt(i); words[i>>2]|=j<<((3-i)%4)*8; }
  words[words.length]=((bitLen/maxWord)|0); words[words.length]=bitLen;
  for(let j=0;j<words.length;){ const w=words.slice(j,j+=16), old=hash.slice(0); hash=hash.slice(0,8);
    for(let i=0;i<64;i++){ const w15=w[i-15], w2=w[i-2], a=hash[0], e=hash[4];
      const t1=hash[7]+(rr(e,6)^rr(e,11)^rr(e,25))+((e&hash[5])^((~e)&hash[6]))+k[i]+(w[i]=(i<16)?w[i]:(w[i-16]+(rr(w15,7)^rr(w15,18)^(w15>>>3))+w[i-7]+(rr(w2,17)^rr(w2,19)^(w2>>>10)))|0);
      const t2=(rr(a,2)^rr(a,13)^rr(a,22))+((a&hash[1])^(a&hash[2])^(hash[1]&hash[2]));
      hash=[(t1+t2)|0].concat(hash); hash[4]=(hash[4]+t1)|0; }
    for(let i=0;i<8;i++) hash[i]=(hash[i]+old[i])|0; }
  for(let i=0;i<8;i++) for(let j=3;j+1;j--){ const b=(hash[i]>>(j*8))&255; result+=((b<16)?0:'')+b.toString(16); }
  return result;
}
async function sha256(t){
  try { if (window.crypto && crypto.subtle) { const b = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(t)); return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join(''); } } catch (e) {}
  return sha256js(unescape(encodeURIComponent(t)));
}
window.PAM = { DataService, CONFIG, Tokens, Modo, RemoteData };

/* ===================== Utilidades de interfaz ===================== */
const $ = (s, r = document) => r.querySelector(s), $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const MESES = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
const DIAS = ['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
function fechaLarga(iso){ const [y, m, d] = iso.split('-').map(Number); const dt = new Date(y, m-1, d); return `${DIAS[dt.getDay()]} ${d} de ${['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'][m-1]}`; }
function hora12(h){ if (!h) return ''; let [H, M] = h.split(':').map(Number); const s = H >= 12 ? 'pm' : 'am'; H = H % 12 || 12; return `${H}:${String(M).padStart(2, '0')} ${s}`; }
function toast(t){ let el = $('#toast'); if (!el) { el = document.createElement('div'); el.id = 'toast'; el.className = 'toast'; el.setAttribute('role', 'status'); document.body.append(el); } el.textContent = t; el.classList.add('on'); clearTimeout(toast.t); toast.t = setTimeout(() => el.classList.remove('on'), 3400); }
async function copyText(t){
  try { await navigator.clipboard.writeText(t); return toast('Copiado'); } catch (e) {}
  try { const ta = document.createElement('textarea'); ta.value = t; ta.style.cssText = 'position:fixed;opacity:0;top:0'; document.body.appendChild(ta); ta.select(); const ok = document.execCommand('copy'); ta.remove(); if (ok) return toast('Copiado'); } catch (e) {}
  toast('No se pudo copiar automáticamente: selecciónalo y cópialo');
}

/* ===================== Encabezado y pie comunes ===================== */
(function shell(){
  document.body.insertAdjacentHTML('afterbegin', `__SPRITE__`);
  const page = document.body.dataset.page || 'inicio';
  const link = (href, txt, id) => `<li><a href="${href}"${page === id ? ' aria-current="page"' : ''}>${txt}</a></li>`;
  const hdr = document.getElementById('hdr');
  const topbar = `<div class="topbar" id="topbar"><div class="wrap tbin">
    <div class="tbgrp"><span class="tblab"><svg><use href="#i-steth"/></svg>Médico 24 horas</span><a href="${CONFIG.telHref}">${CONFIG.tel}</a><span class="tbsep">·</span><a href="${CONFIG.tel2Href}">${CONFIG.tel2}</a></div>
    <div class="tbgrp"><span class="tblab"><svg><use href="#i-pill"/></svg>Medicamentos (WhatsApp)</span><a href="${CONFIG.waMedHref}">${CONFIG.waMed}</a>
      <button type="button" class="tbmore" id="tbmore" aria-expanded="false" aria-controls="tbmed">¿Qué necesito?<svg><use href="#i-arr"/></svg></button></div>
  </div>
  <div class="tbmed" id="tbmed" hidden><div class="wrap">
    <h3><svg><use href="#i-pill"/></svg>Cómo pedir tus medicamentos</h3>
    <ol>
      <li><b>Escribe por WhatsApp</b> al <a href="${CONFIG.waMedHref}">${CONFIG.waMed}</a>.</li>
      <li><b>Envía tu informe médico</b> y el <b>récipe vigente</b> (foto clara de ambos).</li>
      <li><b>Recibe tus medicamentos en casa.</b> Aplica para tratamientos de hasta 7 días.</li>
    </ol>
    <p class="tbhor"><svg><use href="#i-clock"/></svg><span><b>Horario de atención:</b> lunes a viernes de 7:00 am a 4:00 pm · fines de semana y feriados de 8:00 am a 4:00 pm.</span></p>
  </div></div></div>`;
  if (hdr) hdr.outerHTML = `<header><div class="wrap bar">
    <a class="logo" href="index.html" aria-label="PAM Baruta, inicio"><svg viewBox="0 0 100 100" aria-hidden="true"><circle cx="50" cy="50" r="50" fill="#0e683b"/><use href="#leaf" x="18" y="16" width="64" height="64" style="color:#83ba2a"/></svg><span><b>PAM <span>Baruta</span></b><small>Programa de Atención Médica</small></span></a>
    <nav aria-label="Principal"><ul>${link('index.html', 'Inicio', 'inicio')}${link('cobertura.html', 'Zonas', 'cobertura')}${link('eventos.html', 'Eventos', 'eventos')}${link('tips.html', 'Tips de salud', 'tips')}</ul></nav>
    <div class="hright"><button class="bell" id="bell" type="button" aria-label="Novedades" aria-expanded="false"><svg><use href="#i-bell"/></svg><span class="bdg" id="bdg" hidden>0</span></button><a class="hcall" href="${CONFIG.telHref}" aria-label="Llamar al médico: ${CONFIG.tel}" title="Médico 24 horas: ${CONFIG.tel}"><span class="ring"><svg><use href="#i-phone"/></svg></span><span><small>Médico 24 horas</small><b>${CONFIG.tel}</b></span></a><a class="btn b-noche" href="registro.html">Regístrate <svg><use href="#i-arr"/></svg></a></div>
  </div></header>
  `;
  const tbm = document.getElementById('tbmore');
  if (tbm) tbm.onclick = () => { const p = document.getElementById('tbmed'), on = p.hidden; p.hidden = !on; tbm.setAttribute('aria-expanded', on); };
  const ftr = document.getElementById('ftr');
  if (ftr) ftr.outerHTML = `<footer class="ft2">
    <svg class="ftleaf" viewBox="0 0 100 100" aria-hidden="true"><use href="#leaf"/></svg>
    <div class="wrap">
      <div class="ftcta">
        <div><h2>PAM Baruta, <span>salud que responde.</span></h2><p>Regístrate gratis y ten un médico a un toque cuando lo necesites.</p></div>
        <div class="ftbtns"><a class="btn b-hoja" href="registro.html">Regístrate gratis <span class="arr"><svg><use href="#i-arr"/></svg></span></a><a class="btn ftout" href="${CONFIG.telHref}"><svg><use href="#i-phone"/></svg>${CONFIG.tel}</a></div>
      </div>
      <div class="ftgrid">
        <div class="ftbrand">
          <a class="ftlogo" href="index.html"><svg viewBox="0 0 100 100" aria-hidden="true"><circle cx="50" cy="50" r="50" fill="#83ba2a"/><use href="#leaf" x="18" y="16" width="64" height="64" style="color:#082e1b"/></svg><span><b>PAM Baruta</b><small>Programa de Atención Médica</small></span></a>
          <p>Plan de salud gratuito de la Alcaldía de Baruta para todos los vecinos. Telemedicina, médico en casa, ambulancia y medicamentos.</p>
          <a class="ftig" href="https://www.instagram.com/pambaruta" target="_blank" rel="noopener" aria-label="Instagram @pambaruta"><svg><use href="#i-ig"/></svg>@pambaruta</a>
        </div>
        <div class="ftcol"><h3>Explora</h3><a href="index.html">Inicio</a><a href="cobertura.html">Zonas</a><a href="eventos.html">Eventos</a><a href="tips.html">Tips de salud</a><a href="preguntas.html">Preguntas frecuentes</a></div>
        <div class="ftcol"><h3>Afiliados</h3><a href="registro.html">Registrarme</a><a href="registro.html">¿Ya estoy registrado?</a><a href="eventos.html">Inscribirme en una jornada</a><a href="preguntas.html#medicamentos">Pedir medicamentos</a><a href="nevera.html">Hoja para la nevera</a><a href="index.html#instalar">Instalar la app</a></div>
        <div class="ftcol ftcont"><h3>Contacto</h3>
          <a href="${CONFIG.telHref}"><span class="fti"><svg><use href="#i-phone"/></svg></span><span><small>Médico 24 horas</small>${CONFIG.tel}</span></a>
          <a href="${CONFIG.tel2Href}"><span class="fti"><svg><use href="#i-phone"/></svg></span><span><small>Médico 24 horas</small>${CONFIG.tel2}</span></a>
          <a href="${CONFIG.waMedHref}"><span class="fti"><svg><use href="#i-wa"/></svg></span><span><small>Medicamentos · WhatsApp</small>${CONFIG.waMed}</span></a>
        </div>
      </div>
      <div class="ftlogos">
        <div class="ftl"><small>Un programa de</small><img src="img/logo-baruta-blanco.png" alt="Alcaldía de Baruta, Calidad de vida" width="72" height="64" loading="lazy"></div>
        <div class="ftl"><small>Operado por</small><img src="img/logo-nueveonce-blanco.png" alt="Grupo Nueve Once" width="157" height="46" loading="lazy"></div>
      </div>
      <div class="ftbot"><span>© 2026 Alcaldía de Baruta · Operado por Grupo Nueve Once</span><span>Servicio gratuito en línea y por teléfono · <a href="admin/index.html">Acceso equipo</a></span></div>
    </div>
  </footer>
  <nav class="tabbar" aria-label="Navegación principal"><a href="index.html"${page === 'inicio' ? ' aria-current="page"' : ''}><svg><use href="#i-home2"/></svg><span>Inicio</span></a><a href="registro.html"${page === 'registro' ? ' aria-current="page"' : ''}><svg><use href="#i-user"/></svg><span>Registro</span></a><a class="tcall" href="${CONFIG.telHref}"><span class="tcircle"><svg><use href="#i-phone"/></svg></span><span>Llamar</span></a><a href="eventos.html"${page === 'eventos' ? ' aria-current="page"' : ''}><svg><use href="#i-cal"/></svg><span>Eventos</span></a><button type="button" class="tmore" id="tmore" aria-expanded="false" aria-controls="msheet"${['tips','cobertura','preguntas'].includes(page) ? ' aria-current="page"' : ''}><svg><use href="#i-grid"/></svg><span>Más</span></button></nav>
  <div class="mback" id="mback" hidden></div>
  <div class="msheet" id="msheet" role="dialog" aria-label="Más opciones" hidden>
    <div class="mgrab" aria-hidden="true"></div>
    <div class="mhead2"><b>Más opciones</b><button type="button" class="mx" id="mx" aria-label="Cerrar"><svg><use href="#i-x"/></svg></button></div>
    <div class="mgrid">
      <a href="tips.html"><span class="mi"><svg><use href="#i-bulb"/></svg></span>Tips de salud</a>
      <a href="cobertura.html"><span class="mi"><svg><use href="#i-pin"/></svg></span>Zonas</a>
      <a href="preguntas.html"><span class="mi"><svg><use href="#i-quest"/></svg></span>Preguntas frecuentes</a>
      <a href="https://www.instagram.com/pambaruta" target="_blank" rel="noopener"><span class="mi"><svg><use href="#i-ig"/></svg></span>Instagram</a>
      <a href="#" data-novedades><span class="mi"><svg><use href="#i-bell"/></svg></span>Novedades</a>
      <a href="registro.html"><span class="mi"><svg><use href="#i-user"/></svg></span>¿Estoy registrado?</a>
      <a href="index.html#instalar"><span class="mi"><svg><use href="#i-mobile"/></svg></span>Instalar la app</a>
      <a href="nevera.html"><span class="mi"><svg><use href="#i-print"/></svg></span>Hoja para la nevera</a>
    </div>

  </div>`;
  const tm = document.getElementById('tmore');
  if (tm) { const sh = document.getElementById('msheet'), bk = document.getElementById('mback');
    const set = on => { sh.hidden = !on; bk.hidden = !on; tm.setAttribute('aria-expanded', on); document.body.style.overflow = on ? 'hidden' : ''; if (on) document.getElementById('mx').focus(); };
    tm.onclick = () => set(sh.hidden);
    sh.querySelector('[data-novedades]').onclick = e => { e.preventDefault(); set(false); document.getElementById('bell')?.click(); }; bk.onclick = () => set(false); document.getElementById('mx').onclick = () => set(false);
    document.addEventListener('keydown', e => { if (e.key === 'Escape' && !sh.hidden) set(false); }); }

})();

/* ===================== Tarjetas dinámicas de eventos y tips ===================== */
const CAT_EV = { 'Jornada de salud': 'i-steth', 'Charla': 'i-chat', 'Vacunación': 'i-kit', 'Operativo': 'i-amb', 'Actividad comunitaria': 'i-users' };
const CAT_TIP = { 'Prevención': 'i-shield', 'Adulto mayor': 'i-hand', 'Cómo usar PAM': 'i-phone', 'Primeros auxilios': 'i-kit', 'Nutrición': 'i-heart' };
const DIAS_C = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
function faltan(fecha){
  const d = new Date(fecha + 'T00:00'), h = new Date(); h.setHours(0, 0, 0, 0);
  const n = Math.round((d - h) / 864e5);
  return n < 0 ? 'Finalizado' : n === 0 ? '¡Es hoy!' : n === 1 ? 'Es mañana' : `Faltan ${n} días`;
}
function evCard(e, { featured = false, href = null } = {}){
  const [y, m, d] = e.fecha.split('-').map(Number), dia = DIAS_C[new Date(y, m-1, d).getDay()];
  const libres = e.cupos ? Math.max(0, e.cupos - (e.inscritos || 0)) : null, pct = e.cupos ? Math.min(100, Math.round((e.inscritos || 0) / e.cupos * 100)) : 0;
  const pasado = faltan(e.fecha) === 'Finalizado', ic = CAT_EV[e.categoria] || 'i-cal';
  const cta = href ? `<a class="evbtn" href="${href}">Inscribirme <span class="arr"><svg><use href="#i-arr"/></svg></span></a>`
    : pasado ? '<span class="evoff">Evento finalizado</span>' : libres === 0 ? '<span class="evoff">Cupos agotados</span>'
    : `<button class="evbtn" type="button" data-ins="${e.id}">Inscribirme <span class="arr"><svg><use href="#i-arr"/></svg></span></button>`;
  const bar = e.cupos ? `<div class="cup"><div class="cupt"><span>${libres} cupos libres</span><span>${pct}% ocupado</span></div><div class="cupb"><i style="width:${Math.max(pct, 3)}%"></i></div></div>` : '';
  return `<article class="evx rv${featured ? ' feat' : ''}" id="${e.id}">
    <div class="evtop"><span class="evcat"><svg><use href="#${ic}"/></svg>${esc(e.categoria)}</span><span class="evcount${faltan(e.fecha).startsWith('Faltan') ? '' : ' hot'}">${faltan(e.fecha)}</span></div>
    ${e.imagen ? `<div class="evimg"><img src="${e.imagen}" alt="Imagen del evento ${esc(e.titulo)}" loading="lazy"></div>` : ''}
    <div class="evbody">
      <div class="evd"><span>${dia}</span><b>${d}</b><span>${MESES[m-1].toUpperCase()}</span></div>
      <div class="evinfo"><h3>${esc(e.titulo)}</h3>${featured ? `<p>${esc(e.descripcion)}</p>` : ''}</div>
    </div>
    <ul class="evm evbox"><li><span class="emi"><svg><use href="#i-clock"/></svg></span><span><small>Hora</small>${hora12(e.hora)}${e.fin ? ' – ' + hora12(e.fin) : ''}</span></li><li><span class="emi"><svg><use href="#i-pin"/></svg></span><span><small>Lugar</small>${esc(e.lugar)}, ${esc(e.sector)}</span></li></ul>
    ${featured && !e.imagen ? `<svg class="evbig" aria-hidden="true"><use href="#${ic}"/></svg>` : ''}${bar}${e.instagram ? `<a class="igl" href="${esc(e.instagram)}" target="_blank" rel="noopener"><svg><use href="#i-ig"/></svg>Ver publicación en Instagram</a>` : ''}${cta}
  </article>`;
}
const TIP_COLORS = ['c-verde', 'c-blanco', 'c-hoja', 'c-carbon', 'c-blanco', 'c-verde'];
function tipCard(t, i, { big = false, href = null } = {}){
  const tag = href ? 'a' : 'button', attr = href ? `href="${href}"` : `type="button" data-id="${t.id}"`;
  return `<${tag} class="tpx rv ${TIP_COLORS[i % TIP_COLORS.length]}${big ? ' big' : ''}${t.imagen ? ' has-img' : ''}" ${attr} id="${t.id}">
    ${t.imagen ? `<span class="tpimg"><img src="${t.imagen}" alt="" loading="lazy"></span>` : ''}${t.instagram ? '<span class="tpig" title="Tiene publicación en Instagram"><svg><use href="#i-ig"/></svg></span>' : ''}
    <span class="tpcat">${esc(t.categoria)}</span><span class="tparr"><svg><use href="#i-arr"/></svg></span>
    <svg class="tpblob" viewBox="0 0 200 200" aria-hidden="true"><path d="M150 20c35 25 45 80 25 120s-80 55-120 35S0 105 20 60 115-5 150 20z"/></svg>
    <span class="tpico"><svg><use href="#${CAT_TIP[t.categoria] || 'i-bulb'}"/></svg></span>
    <span class="tptxt"><h3>${esc(t.titulo)}</h3><p>${esc(t.resumen)}</p></span>
  </${tag}>`;
}
/* Aparición suave al hacer scroll */
const _io = 'IntersectionObserver' in window ? new IntersectionObserver(es => es.forEach(x => { if (x.isIntersecting) { x.target.classList.add('in'); _io.unobserve(x.target); } }), { threshold: .12 }) : null;
function reveal(root = document){ $$('.rv:not(.in)', root).forEach((el, i) => { el.style.transitionDelay = (i % 4) * 70 + 'ms'; _io ? _io.observe(el) : el.classList.add('in'); }); }

/* Instagram: enlace a una publicación (post, reel) */
const igValid = u => /^https:\/\/(www\.)?instagram\.com\/(p|reel|reels|tv)\/[A-Za-z0-9_-]+\/?(\?.*)?$/.test((u || '').trim());
/* Reduce una imagen subida a máx. 1080 px y la convierte en JPEG para guardarla */
function imgToDataURL(file, max = 1080){
  return new Promise((res, rej) => {
    const r = new FileReader();
    r.onload = () => { const im = new Image(); im.onload = () => {
      const k = Math.min(1, max / Math.max(im.width, im.height)), c = document.createElement('canvas');
      c.width = Math.round(im.width * k); c.height = Math.round(im.height * k); c.getContext('2d').drawImage(im, 0, 0, c.width, c.height);
      res(c.toDataURL('image/jpeg', .82)); }; im.onerror = rej; im.src = r.result; };
    r.onerror = rej; r.readAsDataURL(file);
  });
}


/* ===================== Centro de novedades (notificaciones) ===================== */
const Notifs = {
  VISTO: 'pam_avisos_visto', TOASTED: 'pam_avisos_toast',
  get visto(){ try { return localStorage.getItem(this.VISTO) || ''; } catch (e) { return this._v || ''; } },
  set visto(v){ try { localStorage.setItem(this.VISTO, v); } catch (e) { this._v = v; } },
  ICO: { evento: 'i-cal', cambio: 'i-info', cancelado: 'i-danger', tip: 'i-bulb', aviso: 'i-bell' },
  hace(iso){ const m = Math.round((Date.now() - new Date(iso)) / 6e4); return m < 1 ? 'ahora' : m < 60 ? `hace ${m} min` : m < 1440 ? `hace ${Math.round(m / 60)} h` : m < 2880 ? 'ayer' : `hace ${Math.round(m / 1440)} días`; },
  async init(){
    const bell = $('#bell'); if (!bell) return;
    document.body.insertAdjacentHTML('beforeend', `<div class="npanel" id="npanel" role="dialog" aria-label="Novedades" hidden>
      <div class="nhead"><h2>Novedades</h2><button type="button" class="nclose" aria-label="Cerrar"><svg><use href="#i-x"/></svg></button></div>
      <div class="npush" id="npush"></div><div class="nlist" id="nlist"></div>
      <button type="button" class="nread" id="nread">Marcar todo como leído</button></div><div class="nback" id="nback" hidden></div>`);
    bell.onclick = () => this.toggle();
    $('#npanel .nclose').onclick = () => this.toggle(false); $('#nback').onclick = () => this.toggle(false);
    $('#nread').onclick = () => { this.marcar(); this.render(); };
    document.addEventListener('keydown', e => { if (e.key === 'Escape') this.toggle(false); });
    await this.render(); this.toast(); this.sistema();
  },
  async render(){
    const av = await DataService.listAvisos(), v = this.visto, n = av.filter(a => a.fecha > v).length;
    $('#bdg').hidden = !n; $('#bdg').textContent = n > 9 ? '9+' : n; $('#bell').classList.toggle('ring', !!n);
    $('#nlist').innerHTML = av.length ? av.slice(0, 30).map(a => `<a class="nitem t-${a.tipo}${a.fecha > v ? ' new' : ''}" href="${esc(a.link || '#')}"><span class="nic"><svg><use href="#${this.ICO[a.tipo] || 'i-bell'}"/></svg></span><span><b>${esc(a.titulo)}</b><span>${esc(a.mensaje || '')}</span><small>${this.hace(a.fecha)}</small></span></a>`).join('') : '<p class="nempty">No hay novedades por ahora.</p>';
    $('#nread').hidden = !n;
    this.pushUI();
  },
  async marcar(){ const av = await DataService.listAvisos(); if (av[0]) this.visto = av[0].fecha; },
  toggle(on){
    const p = $('#npanel'); on ??= p.hidden; p.hidden = !on; $('#nback').hidden = !on; $('#bell').setAttribute('aria-expanded', on);
    if (on) { p.querySelector('.nclose').focus(); } else { this.marcar().then(() => this.render()); }
  },
  /* Aviso emergente con la novedad más reciente, una vez por novedad */
  async toast(){
    const av = await DataService.listAvisos(), a = av[0]; if (!a || a.fecha <= this.visto) return;
    let t = ''; try { t = sessionStorage.getItem(this.TOASTED) || ''; } catch (e) {}
    if (t === a.id) return; try { sessionStorage.setItem(this.TOASTED, a.id); } catch (e) {}
    const n = av.filter(x => x.fecha > this.visto).length;
    document.body.insertAdjacentHTML('beforeend', `<div class="ntoast" id="ntoast" role="status"><span class="nic"><svg><use href="#${this.ICO[a.tipo] || 'i-bell'}"/></svg></span><span><small>${n > 1 ? n + ' novedades' : 'Novedad'}</small><b>${esc(a.titulo)}</b></span><a class="btn b-noche" href="${esc(a.link || '#')}">Ver</a><button type="button" aria-label="Cerrar" class="nx"><svg><use href="#i-x"/></svg></button></div>`);
    const el = $('#ntoast'); setTimeout(() => el.classList.add('on'), 600);
    el.querySelector('.nx').onclick = () => el.remove(); setTimeout(() => el?.classList.remove('on'), 12000);
  },
  /* Notificaciones del teléfono (requiere el sitio publicado en su dominio, con HTTPS) */
  soporta(){ try { return 'Notification' in window && window.isSecureContext && window.top === window.self; } catch (e) { return false; } },
  pushUI(){
    const box = $('#npush'); if (!box) return;
    if (!this.soporta()) { box.innerHTML = `<div class="npinfo"><svg><use href="#i-info"/></svg><span>Los avisos en el teléfono se activarán cuando la página esté publicada en <b>pambaruta.com</b>.</span></div>`; return; }
    if (Notification.permission === 'granted') { box.innerHTML = `<div class="npinfo ok"><svg><use href="#i-check"/></svg><span>Recibirás avisos de jornadas, cambios y novedades en este teléfono.</span></div>`; return; }
    if (Notification.permission === 'denied') { box.innerHTML = `<div class="npinfo"><svg><use href="#i-info"/></svg><span>Bloqueaste los avisos. Puedes activarlos en la configuración del navegador.</span></div>`; return; }
    box.innerHTML = `<button type="button" class="btn b-verde" id="npon" style="width:100%"><svg><use href="#i-bell"/></svg>Recibir avisos en este teléfono</button>`;
    $('#npon').onclick = async () => { try { const r = await Notification.requestPermission(); if (r === 'granted') { await this.registrarSW(); toast('¡Listo! Te avisaremos de las novedades'); } } catch (e) { toast('Tu navegador no permite avisos'); } this.pushUI(); };
  },
  async registrarSW(){ try { if ('serviceWorker' in navigator) return await navigator.serviceWorker.register('sw.js'); } catch (e) {} },
  /* Con permiso, muestra en el teléfono las novedades no vistas (sin servidor de push, solo al abrir el sitio) */
  async sistema(){
    if (!this.soporta() || Notification.permission !== 'granted') return;
    const av = (await DataService.listAvisos()).filter(a => a.fecha > this.visto).slice(0, 3), reg = await this.registrarSW();
    av.forEach(a => { const o = { body: a.mensaje, icon: 'img/icon-192.png', badge: 'img/icon-192.png', tag: a.id, data: { link: a.link } };
      try { reg?.showNotification ? reg.showNotification(a.titulo, o) : new Notification(a.titulo, o); } catch (e) {} });
  }
};
Notifs.init();

/* ===================== Instalar la app (PWA) ===================== */
const Instalar = {
  ev: null,
  /* 'ios' | 'android' | 'pc' según el aparato del vecino */
  so(){ const u = navigator.userAgent || ''; if (/iPhone|iPad|iPod/i.test(u) || (/Macintosh/.test(u) && navigator.maxTouchPoints > 1)) return 'ios'; if (/Android/i.test(u)) return 'android'; return 'pc'; },
  instalada(){ try { return matchMedia('(display-mode: standalone)').matches || navigator.standalone === true; } catch (e) { return false; } },
  /* Los botones [data-instalar] aparecen cuando el navegador permite instalar con un toque */
  init(){
    try { if ('serviceWorker' in navigator && window.isSecureContext && window.top === window.self) navigator.serviceWorker.register('sw.js').catch(() => {}); } catch (e) {}
    window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); this.ev = e; $$('[data-instalar]').forEach(b => b.hidden = false); });
    window.addEventListener('appinstalled', () => { this.ev = null; $$('[data-instalar]').forEach(b => b.hidden = true); toast('¡Listo! Ya tienes PAM Baruta en tu teléfono'); });
    document.addEventListener('click', e => { const b = e.target.closest('[data-instalar]'); if (b) { e.preventDefault(); this.pedir(); } });
  },
  async pedir(){
    if (!this.ev) { location.href = 'index.html#instalar'; return; }
    this.ev.prompt(); try { await this.ev.userChoice; } catch (e) {}
    this.ev = null; $$('[data-instalar]').forEach(b => b.hidden = true);
  }
};
Instalar.init();

/* ===================== QR ===================== */
/* El QR lleva a la página de registro del dominio actual (desde pambaruta.com apunta a pambaruta.com/registro.html).
   Imprime las hojas definitivas desde pambaruta.com. Requiere assets/qrcode.js en la página. */
const QR = {
  registro(){ return new URL('registro.html', location.href).href.replace(/[?#].*$/, ''); },
  canvas(texto, px = 600, color = '#082e1b'){
    const q = qrcode(0, 'M'); q.addData(texto); q.make();
    const n = q.getModuleCount(), margen = 4, k = Math.max(1, Math.floor(px / (n + margen * 2))), lado = k * (n + margen * 2);
    const c = document.createElement('canvas'); c.width = c.height = lado; const g = c.getContext('2d');
    g.fillStyle = '#fff'; g.fillRect(0, 0, lado, lado); g.fillStyle = color;
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (q.isDark(y, x)) g.fillRect((x + margen) * k, (y + margen) * k, k, k);
    return c;
  },
  bajar(canvas, nombre){ const a = document.createElement('a'); a.href = canvas.toDataURL('image/png'); a.download = nombre; document.body.append(a); a.click(); a.remove(); }
};

/* Envío de formularios sin depender del envío nativo:
   algunos visores (marcos protegidos) bloquean el envío de formularios y los botones "no hacen nada".
   Interceptamos el clic en los botones de enviar y disparamos el evento 'submit' nosotros mismos. */
(function formShim(){
  const fire = form => { const ev = new Event('submit', { bubbles: true, cancelable: true }); form.dispatchEvent(ev); };
  document.addEventListener('click', e => {
    const b = e.target.closest('button, input[type=submit]'); if (!b || !b.form) return;
    const t = (b.getAttribute('type') || 'submit').toLowerCase(); if (t !== 'submit') return;
    e.preventDefault(); fire(b.form);
  }, true);
  document.addEventListener('keydown', e => {
    if (e.key !== 'Enter' || e.isComposing) return;
    const el = e.target; if (!el.form || el.tagName === 'TEXTAREA' || el.tagName === 'BUTTON') return;
    if (el.tagName === 'INPUT' && /^(checkbox|radio|file|button|reset)$/i.test(el.type)) return;
    e.preventDefault(); fire(el.form);
  }, true);
  HTMLFormElement.prototype.requestSubmit = function(){ fire(this); };
})();
