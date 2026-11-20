// Vercel serverless function: stuurt app-aanvragen door naar Supabase.
// Het Supabase-adres en de sleutel staan alleen in de omgevingsvariabelen (Vercel / .env),
// zodat ze niet in de code, op GitHub of in de browser terechtkomen.
const ALLOWED = /^kt_[a-z][a-z_]*$/; // alleen publieke kroegentocht-functies, geen interne kt__...

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') { res.statusCode = 405; return res.end(JSON.stringify({ message: 'Alleen POST' })); }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_KEY;
  if (!url || !key) { res.statusCode = 500; return res.end(JSON.stringify({ message: 'SUPABASE_URL / SUPABASE_KEY ontbreken in de omgevingsvariabelen' })); }

  const fn = String((req.query && req.query.fn) || new URL(req.url, 'http://x').searchParams.get('fn') || '');
  if (!ALLOWED.test(fn)) { res.statusCode = 400; return res.end(JSON.stringify({ message: 'Onbekende functie' })); }

  let body = req.body;
  if (body === undefined || typeof body === 'string') {
    if (typeof body !== 'string') body = await new Promise(r => { let s = ''; req.on('data', d => s += d); req.on('end', () => r(s)); });
    try { body = body ? JSON.parse(body) : {}; } catch (e) { res.statusCode = 400; return res.end(JSON.stringify({ message: 'Ongeldige JSON' })); }
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) body = {};
  // Geen pincodes in de app: de server vult de pincode zelf in (KT_PIN), de browser ziet hem nooit.
  if (process.env.KT_PIN && fn !== 'kt_state') body.p_pin = process.env.KT_PIN;
  if (fn === 'kt_state') body.p_pin = process.env.KT_PIN || null;
  const payload = JSON.stringify(body);
  if (payload.length > 20000) { res.statusCode = 413; return res.end(JSON.stringify({ message: 'Te groot' })); }

  try {
    const r = await fetch(url.replace(/\/$/, '') + '/rest/v1/rpc/' + fn, {
      method: 'POST',
      headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
      body: payload,
    });
    const text = await r.text();
    res.statusCode = r.status;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    return res.end(text);
  } catch (e) {
    res.statusCode = 502;
    return res.end(JSON.stringify({ message: 'Database niet bereikbaar' }));
  }
};
