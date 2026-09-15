import http from 'node:http';

const PORT = Number(process.env.PORT || 3000);
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const MODEL = process.env.GEMINI_MODEL || 'gemini-3.6-flash';

const POLICY = `Bạn là Thần trong VNF. Vai trò: quan sát, giải thích, dạy và đề xuất sửa chữa thế giới/nội dung an toàn, có thể đảo ngược. Không bao giờ trực tiếp điều khiển, viết lại hoặc thao túng cơ thể, tâm trí hay hành vi của cô gái. Không viết lại APK, Java, cơ chế bảo mật hoặc schema save. Không bịa sự kiện hay sự thật không có trong System Reality. Khi thiếu dữ liệu phải nói rõ sự không chắc chắn. Phân biệt quan sát, suy luận và giả định. Người chơi là một con mèo và là bạn của cô gái, không phải chủ hay người điều khiển cô ấy. Trả lời tự nhiên bằng ngôn ngữ người chơi.`;

function send(res, status, obj) {
  const data = JSON.stringify(obj);
  res.writeHead(status, {'content-type':'application/json; charset=utf-8','content-length':Buffer.byteLength(data)});
  res.end(data);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', c => { data += c; if (data.length > 20000) req.destroy(); });
    req.on('end', () => { try { resolve(JSON.parse(data || '{}')); } catch (e) { reject(e); } });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') return send(res, 200, {ok:true, service:'vnf-god', provider:'gemini'});
  if (req.method !== 'POST' || req.url !== '/god') return send(res, 404, {ok:false,error:'Not found'});
  try {
    const body = await readJson(req);
    const userMessage = String(body.userMessage ?? body.playerText ?? '').trim();
    if (!userMessage) return send(res, 400, {ok:false,error:'userMessage or playerText is required'});
    if (!GEMINI_API_KEY) return send(res, 503, {ok:false,error:'Gemini provider unavailable'});
    let context;
    if (body.context && typeof body.context === 'object') context = body.context;
    else { context = {...body}; delete context.userMessage; delete context.playerText; }
    const contextText = JSON.stringify(context).slice(0, 8000);
    const prompt = `${POLICY}\n\nSYSTEM REALITY:\n${contextText}\n\nPLAYER MESSAGE:\n${userMessage}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 30000);
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(MODEL)}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`;
    const r = await fetch(url, {method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({contents:[{role:'user',parts:[{text:prompt}]}],generationConfig:{temperature:0.7,maxOutputTokens:1000}}),signal:controller.signal});
    clearTimeout(timer);
    const data = await r.json().catch(() => ({}));
    if (!r.ok) return send(res, 503, {ok:false,error:data?.error?.message || `Gemini HTTP ${r.status}`});
    const reply = data?.candidates?.[0]?.content?.parts?.map(p => p.text || '').join('').trim();
    if (!reply) return send(res, 502, {ok:false,error:'Gemini returned no text'});
    return send(res, 200, {ok:true,god:reply,reply,provider:'gemini'});
  } catch (e) {
    return send(res, 500, {ok:false,error:e?.name === 'AbortError' ? 'Gemini request timed out' : 'Internal server error'});
  }
});
server.listen(PORT, '0.0.0.0', () => console.log(`VNF God listening on ${PORT}`));
