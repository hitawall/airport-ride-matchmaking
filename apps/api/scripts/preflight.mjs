// Launch preflight: asks the deployed API whether it is ready for real users.
//
//   node apps/api/scripts/preflight.mjs https://<api-host> <CRON_SECRET>
//   (or set API_URL and CRON_SECRET in the environment)
//
// Exits 1 if any required check fails. Prints yes/no facts only.
const apiUrl = (process.argv[2] ?? process.env.API_URL ?? "").replace(/\/$/, "");
const secret = process.argv[3] ?? process.env.CRON_SECRET ?? "";

if (!apiUrl || !secret) {
  console.error("Usage: node preflight.mjs <api-url> <cron-secret>");
  process.exit(2);
}

const health = await fetch(`${apiUrl}/api/health`).then(async (r) => ({ status: r.status, body: await r.json().catch(() => null) }));
console.log(`health: HTTP ${health.status} ${JSON.stringify(health.body)}`);

const res = await fetch(`${apiUrl}/api/internal/readiness`, { headers: { authorization: `Bearer ${secret}` } });
if (!res.ok) {
  console.error(`readiness: HTTP ${res.status} (wrong secret, or this deploy does not have the endpoint yet)`);
  process.exit(2);
}
const report = await res.json();
console.log(`environment: ${report.environment}\n`);

let blocking = 0;
for (const check of report.checks) {
  const mark = check.ok ? "OK  " : check.level === "required" ? "FAIL" : "warn";
  console.log(`${mark} [${check.level}] ${check.name}: ${check.message}`);
  if (!check.ok && check.level === "required") blocking++;
}

console.log(blocking === 0 && health.status === 200 ? "\nREADY" : `\nNOT READY (${blocking} required check(s) failing${health.status === 200 ? "" : ", health check failing"})`);
process.exit(blocking === 0 && health.status === 200 ? 0 : 1);
