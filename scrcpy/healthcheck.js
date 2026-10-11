// Docker HEALTHCHECK for the scrcpy service.
// Passes only if BOTH the ws-scrcpy server (:8000) and the device api (:8001)
// answer HTTP. Called as: node /opt/healthcheck.js
const checks = [
  fetch('http://127.0.0.1:8000/s/').then((r) => {
    if (!r.ok) throw new Error('ws-scrcpy http not ok');
  }),
  fetch('http://127.0.0.1:8001/api/ping').then((r) => {
    if (!r.ok) throw new Error('api not ok');
  }),
];

const killer = setTimeout(() => process.exit(1), 8000);

Promise.all(checks)
  .then(() => {
    clearTimeout(killer);
    process.exit(0);
  })
  .catch(() => {
    clearTimeout(killer);
    process.exit(1);
  });
