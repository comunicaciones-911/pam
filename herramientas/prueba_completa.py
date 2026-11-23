import os  # la clave del admin se pasa con: PAM_CLAVE_ADMIN=... python3 herramientas/prueba_completa.py
from playwright.sync_api import sync_playwright
B='http://localhost:8765/'
with sync_playwright() as p:
  b=p.chromium.launch(); ctx=b.new_context(viewport={'width':1280,'height':900}); errs=[]
  pg=ctx.new_page(); pg.on('pageerror',lambda e:errs.append(('pg',str(e)))); pg.on('console',lambda m: m.type=='error' and errs.append(('con',m.text)))
  pg.goto(B+'index.html'); pg.wait_for_timeout(500); pg.screenshot(path='/tmp/s_index.png',full_page=True)
  # registro: verificar
  pg.goto(B+'registro.html'); pg.wait_for_timeout(300)
  pg.click('#vform button[type=submit]'); print('bad empty', pg.locator('#vform .field.bad').count())
  pg.fill('#vdoc','V-15.236.963'); pg.click('#vform button[type=submit]'); pg.wait_for_timeout(200)
  print('vres:', pg.text_content('#vres')[:70]); pg.screenshot(path='/tmp/s_verify.png')
  pg.click('#vgo'); pg.wait_for_timeout(300); print('doc locked:', pg.input_value('#cedula'), pg.get_attribute('#cedula','readonly'))
  pg.fill('#nombre','nancy gabriela'); pg.fill('#apellidos','ospino ruiz'); pg.fill('#nacimiento','1962-04-07'); pg.fill('#telefono','04242684111'); pg.fill('#correo','n@c.com'); pg.click('label[for=sx1]'); pg.click('#next')
  pg.fill('#direccion','Av X'); pg.fill('#sector','Las Mercedes'); pg.click('#next')
  pg.fill('#em_nombre','Luis'); pg.fill('#em_apellidos','P'); pg.fill('#em_telefono','04127654321'); pg.click('#next')
  for l in ['fu2','al2','ag2','md2','pt7','up1']: pg.click(f'label[for={l}]')
  pg.select_option('#importante',index=1); pg.select_option('#conocio',index=1); pg.click('#next')
  pg.click('#adddep'); d=pg.locator('.dep').first
  d.locator('[data-k=nombre]').fill('jorge'); d.locator('[data-k=apellidos]').fill('ospino'); d.locator('[data-k=parentesco]').select_option('CHILD'); d.locator('[data-k=sexo]').select_option('Masculino'); d.locator('[data-k=nro_documento]').fill('23659632'); d.locator('[data-k=nacimiento]').fill('2002-02-07')
  pg.click('#next'); pg.click('#acepto'); pg.click('#next'); pg.wait_for_timeout(300); print('tokens', pg.text_content('#tkU'), pg.text_content('#tkR'))
  pg.click('#otro'); pg.fill('#vdoc','23659632'); pg.click('#vform button[type=submit]'); pg.wait_for_timeout(200); print('dep check:', pg.text_content('#vres')[:90])
  # eventos
  pg.goto(B+'eventos.html'); pg.wait_for_timeout(300); pg.screenshot(path='/tmp/s_ev.png',full_page=True)
  pg.click('#ev1 [data-ins]'); pg.fill('#idoc','99999999'); pg.click('#insf button[type=submit]'); pg.wait_for_timeout(200); print('ins noreg:', pg.text_content('#insr')[:40])
  pg.fill('#idoc','15236963'); pg.click('#insf button[type=submit]'); pg.wait_for_timeout(200); print('ins ok:', pg.text_content('#insr')[:60]); pg.locator('.mbox').screenshot(path='/tmp/s_ins.png')
  # tips
  pg.goto(B+'tips.html'); pg.wait_for_timeout(300); pg.fill('#q','tension'); pg.wait_for_timeout(100); print('tips found', pg.locator('.tpx').count()); pg.fill('#q','')
  pg.screenshot(path='/tmp/s_tips.png',full_page=True); pg.click('.tpx >> nth=0'); pg.wait_for_timeout(200); pg.locator('.mbox').screenshot(path='/tmp/s_tip.png')
  # admin
  pg.goto(B+'admin.html'); pg.wait_for_timeout(300); pg.fill('#lu','admin'); pg.fill('#lp','mala'); pg.click('#lform button[type=submit]'); pg.wait_for_timeout(200); print('bad login shown', pg.is_visible('#lerr'))
  pg.screenshot(path='/tmp/s_login.png')
  pg.fill('#lp',os.environ.get('PAM_CLAVE_ADMIN','')); pg.click('#lform button[type=submit]'); pg.wait_for_timeout(300); pg.screenshot(path='/tmp/s_admin.png',full_page=True)
  pg.click('[data-v=eventos]'); pg.click('#newEv'); pg.fill('#f_t','Jornada en Santa Fe'); pg.fill('#f_f','2026-12-13'); pg.fill('#f_l','Plaza Santa Fe'); pg.fill('#f_s','Santa Fe'); pg.fill('#f_d','Despistaje'); pg.click('#evf button[type=submit]'); pg.wait_for_timeout(200)
  print('events admin', pg.locator('#evs .rowi').count())
  pg.click('#evs [data-ins=ev1]'); pg.wait_for_timeout(200); print('inscritos rows', pg.locator('.mbox tbody tr').count()); pg.keyboard.press('Escape')
  pg.click('[data-v=tips]'); pg.click('#newTip'); pg.fill('#t_t','Lávate las manos'); pg.fill('#t_r','Antes de comer'); pg.fill('#t_x','Texto'); pg.click('#tf button[type=submit]'); pg.wait_for_timeout(200); print('tips admin', pg.locator('#tipsl .rowi').count())
  pg.click('[data-v=registros]'); pg.wait_for_timeout(200); pg.click('#regs tr.click'); pg.wait_for_timeout(200); pg.locator('.mbox').screenshot(path='/tmp/s_reg.png'); pg.keyboard.press('Escape')
  pg.click('[data-v=signo]'); pg.wait_for_timeout(200); print('signo rows', pg.locator('#signoT tbody tr').count()); pg.screenshot(path='/tmp/s_signo.png')
  pg.goto(B+'eventos.html'); pg.wait_for_timeout(200); print('public events', pg.locator('.evx').count())
  m=ctx.new_page(); m.set_viewport_size({'width':390,'height':844}); m.goto(B+'registro.html'); m.wait_for_timeout(300); m.screenshot(path='/tmp/s_mob.png')
  print('errors', errs); b.close()
