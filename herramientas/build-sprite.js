const { getIconData, iconToSVG } = require('@iconify/utils');
const sets = { solar: require('@iconify-json/solar/icons.json'), mdi: require('@iconify-json/mdi/icons.json') };
const map = {
  'i-phone':'solar:phone-calling-rounded-bold-duotone','i-check':'mdi:check-bold','i-arr':'solar:arrow-right-up-linear',
  'i-video':'solar:videocamera-record-bold-duotone','i-home':'solar:home-add-bold-duotone','i-amb':'mdi:ambulance',
  'i-pill':'solar:pills-bold-duotone','i-heart':'solar:heart-pulse-bold-duotone','i-lock':'solar:shield-keyhole-bold-duotone',
  'i-cal':'solar:calendar-bold-duotone','i-pin':'solar:map-point-bold-duotone','i-clock':'solar:clock-circle-bold-duotone',
  'i-bulb':'solar:lightbulb-bold-duotone','i-search':'solar:magnifer-linear','i-x':'mdi:close','i-users':'solar:users-group-rounded-bold-duotone',
  'i-wa':'mdi:whatsapp','i-ig':'mdi:instagram','i-user':'solar:user-id-bold-duotone','i-logout':'solar:logout-2-bold-duotone',
  'i-edit':'solar:pen-2-bold-duotone','i-trash':'solar:trash-bin-trash-bold-duotone','i-add':'solar:add-circle-bold-duotone',
  'i-copy':'solar:copy-bold-duotone','i-doc':'solar:document-medicine-bold-duotone','i-chart':'solar:chart-2-bold-duotone',
  'i-bell':'solar:bell-bing-bold-duotone','i-export':'solar:export-bold-duotone','i-steth':'solar:stethoscope-bold-duotone',
  'i-kit':'solar:medical-kit-bold-duotone','i-info':'solar:info-circle-bold-duotone','i-danger':'solar:danger-triangle-bold-duotone',
  'i-eye':'solar:eye-bold-duotone','i-login':'solar:login-2-bold-duotone','i-list':'solar:checklist-minimalistic-bold-duotone',
  'i-hand':'solar:hand-heart-bold-duotone','i-shield':'solar:shield-check-bold-duotone','i-letter':'solar:letter-bold-duotone','i-home2':'solar:home-smile-bold-duotone','i-chat':'solar:chat-round-dots-bold-duotone','i-card':'solar:card-search-bold-duotone','i-star':'solar:star-bold-duotone','i-grid':'solar:widget-4-bold-duotone','i-quest':'solar:question-circle-bold-duotone',
  'i-down':'solar:download-minimalistic-bold-duotone','i-print':'solar:printer-bold-duotone','i-qr':'solar:qr-code-bold-duotone','i-mobile':'solar:smartphone-bold-duotone','i-contact':'solar:user-plus-bold-duotone','i-pc':'solar:monitor-bold-duotone','i-android':'mdi:android','i-apple':'mdi:apple','i-fridge':'mdi:fridge-outline'
};
let out = '<svg width="0" height="0" style="position:absolute" aria-hidden="true">\n  <symbol id="leaf" viewBox="0 0 100 100"><path d="M88 10C50 8 18 26 12 62c-2 12 1 22 6 28 4-18 16-36 36-48-16 14-26 30-30 50 6 2 14 2 22-1 34-12 44-46 42-81z" fill="currentColor"/></symbol>\n';
for (const [id, name] of Object.entries(map)) {
  const [p, n] = name.split(':'); const d = getIconData(sets[p], n); if (!d) throw new Error('missing ' + name);
  const r = iconToSVG(d); out += `  <symbol id="${id}" viewBox="${r.attributes.viewBox}">${r.body}</symbol>\n`;
}
out += '</svg>';
require('fs').writeFileSync(''+__dirname+'/sprite_iconos.svg.txt', out);
console.log(Object.keys(map).length, 'icons,', out.length, 'bytes');
