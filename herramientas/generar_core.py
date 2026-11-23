"""Genera sitio/assets/core.js a partir de fuente/core.js.tpl + el sprite de íconos.
Uso (desde la raíz del repositorio):  python3 herramientas/generar_core.py
Siempre edita core.js.tpl, nunca core.js directamente."""
import os
base = os.path.dirname(os.path.abspath(__file__))
sprite = open(os.path.join(base, 'sprite_iconos.svg.txt'), encoding='utf-8').read().replace('`', '\\`')
tpl = os.path.join(base, '..', 'fuente', 'core.js.tpl')
out = os.path.join(base, '..', 'sitio', 'assets', 'core.js')
open(out, 'w', encoding='utf-8').write(open(tpl, encoding='utf-8').read().replace('__SPRITE__', sprite))
print('core.js generado')
