// cloudflare/src/crm.js

function balasJson(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status: status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

function balasHtml(html, status = 200) {
  return new Response(html, {
    status: status,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}

export async function tanganiCrmApp(request, env, url, metode, jalur) {
    if (metode === 'GET' && (jalur === '/' || jalur === '/crm' || jalur === '/crm/')) {
        return balasHtml(halamanCrm());
    }

    if (jalur.startsWith('/api/crm/')) {
        const email = request.headers.get('x-crm-email');
        const password = request.headers.get('x-crm-password');
        
        // Cek login admin (hanya anton.ambon90@gmail.com)
        if (email !== 'anton.ambon90@gmail.com' || password !== (env.CRM_PASSWORD || 'Dompetku2026')) {
            return balasJson({ ok: false, reason: 'unauthorized' }, 401);
        }

        // Endpoint: Dasbor Statistik
        if (metode === 'GET' && jalur === '/api/crm/dashboard') {
            const stats = await env.DB.prepare(`
                SELECT 
                    SUM(CASE WHEN status = 'paid' THEN price ELSE 0 END) as total_income,
                    SUM(CASE WHEN status = 'paid' AND source LIKE '%tokoku%' THEN price ELSE 0 END) as income_app2,
                    SUM(CASE WHEN status = 'paid' AND source NOT LIKE '%tokoku%' THEN price ELSE 0 END) as income_app1
                FROM orders
            `).first();

            const { results } = await env.DB.prepare(`
                SELECT order_id, source, customer_name, customer_email, customer_phone, product_name, price, status, created_at 
                FROM orders 
                ORDER BY created_at DESC 
                LIMIT 200
            `).all();

            return balasJson({
                ok: true,
                stats: stats,
                orders: results
            });
        }

        if (metode === 'POST' && jalur === '/api/crm/migrate') {
            try {
                await env.DB.prepare("ALTER TABLE orders ADD COLUMN customer_phone TEXT NOT NULL DEFAULT ''").run().catch(() => {});
                
                // Buat tabel tiket
                await env.DB.prepare(`
                    CREATE TABLE IF NOT EXISTS tickets (
                        id TEXT PRIMARY KEY,
                        user_email TEXT NOT NULL,
                        user_name TEXT,
                        status TEXT DEFAULT 'open',
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    )
                `).run();
                
                await env.DB.prepare(`
                    CREATE TABLE IF NOT EXISTS ticket_messages (
                        id TEXT PRIMARY KEY,
                        ticket_id TEXT NOT NULL,
                        direction TEXT NOT NULL,
                        subject TEXT,
                        body_text TEXT,
                        created_at TEXT NOT NULL
                    )
                `).run();
                
                return new Response(JSON.stringify({ok: true, msg: "Migration success"}), { headers: { 'Content-Type': 'application/json' } });
            } catch(e) {
                return new Response(JSON.stringify({ok: false, error: e.message}), { headers: { 'Content-Type': 'application/json' } });
            }
        }

        // Endpoint Tiket
        if (metode === 'GET' && jalur === '/api/crm/tickets') {
            const { results } = await env.DB.prepare(`
                SELECT t.*, 
                       (SELECT body_text FROM ticket_messages WHERE ticket_id = t.id ORDER BY created_at DESC LIMIT 1) as last_message 
                FROM tickets t 
                ORDER BY t.updated_at DESC
            `).all();
            return balasJson({ ok: true, tickets: results });
        }

        if (metode === 'GET' && jalur.startsWith('/api/crm/tickets/') && !jalur.includes('/reply') && !jalur.includes('/status')) {
            const ticketId = jalur.split('/')[4];
            const { results } = await env.DB.prepare(`
                SELECT * FROM ticket_messages WHERE ticket_id = ? ORDER BY created_at ASC
            `).bind(ticketId).all();
            return balasJson({ ok: true, messages: results });
        }

        if (metode === 'POST' && jalur.match(/\/api\/crm\/tickets\/[^\/]+\/status/)) {
            const ticketId = jalur.split('/')[4];
            const body = await request.json().catch(() => ({}));
            const status = body.status || 'done';
            await env.DB.prepare("UPDATE tickets SET status = ?, updated_at = ? WHERE id = ?")
                .bind(status, new Date().toISOString(), ticketId).run();
            return balasJson({ ok: true });
        }

        if (metode === 'POST' && jalur.match(/\/api\/crm\/tickets\/[^\/]+\/reply/)) {
            const ticketId = jalur.split('/')[4];
            const body = await request.json().catch(() => ({}));
            
            const ticket = await env.DB.prepare("SELECT * FROM tickets WHERE id = ?").bind(ticketId).first();
            if (!ticket) return balasJson({ ok: false, reason: 'not_found' }, 404);

            const msgId = crypto.randomUUID();
            const now = new Date().toISOString();
            const subject = "Re: Balasan dari Support DompetKu";

            let finalMessage = body.message;
            if (!finalMessage.includes("Tim DompetkuAI") && !finalMessage.includes("Tim DompetKuAI")) {
                finalMessage += "<br><br>Regards,<br><b>Tim DompetkuAI</b>";
            }

            // Simpan balasan ke DB (lampiran tidak disimpan di DB agar hemat space)
            await env.DB.prepare("INSERT INTO ticket_messages (id, ticket_id, direction, subject, body_text, created_at) VALUES (?, ?, ?, ?, ?, ?)")
                .bind(msgId, ticketId, 'out', subject, finalMessage, now).run();
            
            await env.DB.prepare("UPDATE tickets SET status = 'open', updated_at = ? WHERE id = ?")
                .bind(now, ticketId).run();

            // Kirim email via Resend
            const kunci = String(env.RESEND_API_KEY || '').trim();
            const dari = String(env.EMAIL_DARI || '').trim();
            if (kunci && dari) {
                const payload = {
                    from: dari,
                    to: [ticket.user_email],
                    subject: subject,
                    html: finalMessage,
                };
                if (body.attachments && body.attachments.length > 0) {
                    payload.attachments = body.attachments;
                }

                await fetch('https://api.resend.com/emails', {
                    method: 'POST',
                    headers: { 'Authorization': `Bearer ${kunci}`, 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload),
                });
            }

            return balasJson({ ok: true });
        }

        if (metode === 'POST' && jalur === '/api/crm/followup') {
            const body = await request.json().catch(() => ({}));
            const targetEmail = body.email;
            const targetName = body.name;
            const targetProduct = body.product;
            const targetSource = body.source || 'dompetkuai.my.id';
            
            if (!targetEmail) return balasJson({ ok: false, reason: 'no_email' }, 400);

            const kunci = String(env.RESEND_API_KEY || '').trim();
            const dari = String(env.EMAIL_DARI || '').trim();
            if (!kunci) return balasJson({ ok: false, reason: 'api_key_kosong_di_cloudflare' }, 500);
            if (!dari) return balasJson({ ok: false, reason: 'email_dari_kosong_di_cloudflare' }, 500);
            
            // Tentukan link checkout berdasarkan sumber
            let checkoutLink = `https://${targetSource}/beli`;
            if (targetSource.includes('tokoku')) {
                checkoutLink = `https://${targetSource}`; // Halaman utama tokoku adalah sales page
            }

            // Template isi email follow up dengan Tombol Bayar
            const html = `
                <div style="font-family: Arial, sans-serif; padding: 20px; background-color: #f9f9f9; border-radius: 8px;">
                    <h2 style="color: #3b82f6;">Halo ${targetName},</h2>
                    <p>Kami melihat Anda tertarik dengan <b>${targetProduct}</b>, namun proses pembayaran Anda belum diselesaikan.</p>
                    <p>Apakah Anda mengalami kendala saat melakukan pembayaran? Atau ada pertanyaan tentang aplikasinya? Anda bisa langsung membalas email ini untuk berdiskusi dengan tim kami.</p>
                    <div style="margin: 25px 0;">
                        <a href="${checkoutLink}" style="background-color: #3b82f6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Lanjutkan Pembayaran</a>
                    </div>
                    <p>Salam hangat,<br><b>Tim DompetkuAI</b></p>
                </div>
            `;

            try {
                const res = await fetch('https://api.resend.com/emails', {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${kunci}`,
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        from: dari,
                        to: [targetEmail],
                        subject: `Kendala Pembayaran ${targetProduct}? Kami Siap Membantu`,
                        html: html,
                        text: `Halo ${targetName}, silakan selesaikan pesanan Anda untuk ${targetProduct} melalui link berikut: ${checkoutLink} atau balas pesan ini jika butuh bantuan.`,
                    }),
                    signal: AbortSignal.timeout(6000),
                });
                if (!res.ok) {
                    const text = await res.text();
                    return balasJson({ ok: false, error: text }, 500);
                }
                return balasJson({ ok: true });
            } catch (err) {
                return balasJson({ ok: false, error: err.toString() }, 500);
            }
        }
        
        return balasJson({ ok: false, reason: 'not_found' }, 404);
    }
    
    return balasJson({ ok: false, reason: 'not_found' }, 404);
}

// ------------------------------------------------------------------
// KODE FRONTEND HTML/CSS/JS UNTUK CRM (Aplikasi Singel Page)
// ------------------------------------------------------------------
function halamanCrm() {
    return `<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM Dasbor - DompetkuAI</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #4f46e5;
            --primary-hover: #4338ca;
            --secondary: #0ea5e9;
            --bg-color: #f8fafc;
            --card-bg: #ffffff;
            --text-main: #0f172a;
            --text-muted: #64748b;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --border-radius: 16px;
            --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
            --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.05), 0 2px 4px -2px rgb(0 0 0 / 0.05);
            --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.05), 0 4px 6px -4px rgb(0 0 0 / 0.05);
        }
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: var(--bg-color); margin: 0; padding: 0; color: var(--text-main); line-height: 1.5; -webkit-font-smoothing: antialiased; }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        h1, h2, h3 { margin-top: 0; color: var(--text-main); font-weight: 700; letter-spacing: -0.02em; }
        
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; margin-bottom: 2.5rem; }
        .card { background: var(--card-bg); padding: 1.75rem; border-radius: var(--border-radius); box-shadow: var(--shadow-md); border: 1px solid rgba(255,255,255,0.5); transition: transform 0.2s ease, box-shadow 0.2s ease; position: relative; overflow: hidden; }
        .card:hover { transform: translateY(-4px); box-shadow: var(--shadow-lg); }
        .card h3 { margin: 0 0 0.5rem 0; font-size: 0.85rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; }
        .card .value { font-size: 2.25rem; font-weight: 800; color: var(--text-main); display: flex; align-items: baseline; gap: 0.5rem; }
        .card .sub { font-size: 0.85rem; color: var(--text-muted); margin-top: 8px; font-weight: 500; }
        
        /* Glassmorphism Header */
        .top-header { background: rgba(255, 255, 255, 0.7); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); padding: 1rem 2rem; border-radius: var(--border-radius); box-shadow: var(--shadow-sm); border: 1px solid rgba(255,255,255,0.8); display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; flex-wrap: wrap; gap: 1rem; }
        .top-header h1 { margin: 0; font-size: 1.5rem; background: linear-gradient(135deg, var(--primary), var(--secondary)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-weight: 800; }
        
        /* Table Design */
        .table-container { background: var(--card-bg); box-shadow: var(--shadow-md); border-radius: var(--border-radius); overflow-x: auto; border: 1px solid #f1f5f9; margin-bottom: 1.5rem; }
        table { width: 100%; border-collapse: separate; border-spacing: 0; text-align: left; }
        th { background: #f8fafc; font-weight: 600; color: var(--text-muted); text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e2e8f0; }
        td { padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
        tr:last-child td { border-bottom: none; }
        tr { transition: background-color 0.2s ease; }
        tr:hover { background-color: #fbfbfc; }
        
        /* Badges */
        .badge { padding: 0.35rem 0.85rem; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; display: inline-flex; align-items: center; gap: 0.3rem; }
        .badge.paid { background: #ecfdf5; color: #059669; border: 1px solid #a7f3d0; }
        .badge.pending { background: #fffbeb; color: #d97706; border: 1px solid #fde68a; }
        .badge.open { background: #eff6ff; color: #2563eb; border: 1px solid #bfdbfe; }
        .badge.done { background: #f3f4f6; color: #64748b; border: 1px solid #e2e8f0; }
        
        /* Buttons */
        button { background: linear-gradient(135deg, var(--primary), #6366f1); color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 0.85rem; font-family: inherit; transition: all 0.2s ease; box-shadow: var(--shadow-sm); display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; }
        button:hover { transform: translateY(-1px); box-shadow: var(--shadow-md); filter: brightness(1.1); }
        button:active { transform: translateY(0); }
        button:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
        button.btn-outline { background: transparent; color: var(--text-main); border: 1px solid #cbd5e1; box-shadow: none; }
        button.btn-outline:hover { background: #f8fafc; border-color: #94a3b8; color: var(--primary); }
        button.btn-danger { background: linear-gradient(135deg, #ef4444, #f43f5e); }
        button.btn-success { background: linear-gradient(135deg, #10b981, #059669); }
        
        /* Login Box */
        .login-box { max-width: 420px; margin: 10vh auto; background: rgba(255,255,255,0.9); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); padding: 3rem 2.5rem; border-radius: 24px; box-shadow: var(--shadow-lg); border: 1px solid rgba(255,255,255,0.5); text-align: center; }
        .login-box h2 { margin-top: 0; color: #0f172a; margin-bottom: 2rem; font-size: 1.75rem; }
        .login-logo { width: 72px; height: 72px; background: linear-gradient(135deg, var(--primary), var(--secondary)); border-radius: 20px; margin: 0 auto 1.5rem; display: flex; align-items: center; justify-content: center; color: white; font-size: 28px; font-weight: 800; box-shadow: 0 10px 15px -3px rgba(79, 70, 229, 0.3); }
        
        /* Inputs */
        input, select { width: 100%; padding: 0.85rem 1rem; margin-bottom: 1.25rem; border: 1px solid #cbd5e1; border-radius: 10px; box-sizing: border-box; font-family: inherit; font-size: 0.95rem; transition: all 0.2s ease; background: #fff; color: var(--text-main); }
        input:focus, select:focus { outline: none; border-color: var(--primary); box-shadow: 0 0 0 4px rgba(79, 70, 229, 0.15); }
        
        /* Tabs */
        .tabs { display: flex; gap: 0.75rem; margin-bottom: 2rem; background: #e2e8f0; padding: 0.5rem; border-radius: 12px; display: inline-flex; }
        .tab { background: transparent; color: var(--text-muted); border: none; font-size: 0.95rem; font-weight: 600; cursor: pointer; padding: 0.6rem 1.25rem; border-radius: 8px; transition: all 0.2s ease; box-shadow: none; }
        .tab:hover { color: var(--text-main); }
        .tab.active { background: #fff; color: var(--primary); box-shadow: var(--shadow-sm); }

        /* Ticket List */
        .ticket-list { display: flex; flex-direction: column; gap: 1rem; }
        .ticket-item { background: var(--card-bg); padding: 1.5rem; border-radius: var(--border-radius); border: 1px solid #e2e8f0; cursor: pointer; transition: all 0.2s ease; box-shadow: var(--shadow-sm); }
        .ticket-item:hover { border-color: var(--primary); box-shadow: var(--shadow-md); transform: translateX(4px); }
        .ticket-item.done { opacity: 0.6; background: #f8fafc; }
        .ticket-item.done:hover { opacity: 1; transform: translateX(2px); }
        
        /* Chat */
        .chat-container { display: flex; flex-direction: column; gap: 1.25rem; max-height: 550px; overflow-y: auto; padding: 1.5rem; background: #f8fafc; border-radius: var(--border-radius); margin-bottom: 1.5rem; border: 1px solid #e2e8f0; scroll-behavior: smooth; }
        .chat-bubble { max-width: 85%; padding: 1.25rem; border-radius: 16px; position: relative; box-shadow: var(--shadow-sm); font-size: 0.95rem; line-height: 1.6; }
        .chat-bubble.in { align-self: flex-start; background: white; border: 1px solid #e2e8f0; border-bottom-left-radius: 4px; }
        .chat-bubble.out { align-self: flex-end; background: linear-gradient(135deg, var(--primary), #6366f1); color: white; border-bottom-right-radius: 4px; }
        .chat-meta { font-size: 0.75rem; color: #94a3b8; margin-bottom: 0.5rem; font-weight: 500; display: flex; justify-content: space-between; }
        .chat-bubble.out .chat-meta { color: #c7d2fe; }
        .chat-content a { color: inherit; text-decoration: underline; }
        
        /* Quill Adjustments */
        .ql-container { font-family: 'Plus Jakarta Sans', sans-serif !important; font-size: 0.95rem !important; border-bottom-left-radius: 12px; border-bottom-right-radius: 12px; }
        .ql-toolbar { border-radius: 12px 12px 0 0; background: #f8fafc; border-color: #cbd5e1 !important; }
        .ql-container.ql-snow { border-color: #cbd5e1 !important; }
        #replyEditor { height: 160px; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link href="https://cdn.quilljs.com/1.3.6/quill.snow.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/quill-emoji@0.2.0/dist/quill-emoji.css" rel="stylesheet">
    <script src="https://cdn.quilljs.com/1.3.6/quill.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/quill-emoji@0.2.0/dist/quill-emoji.min.js"></script>
</head>
<body>
    <div id="app"></div>

    <script>
        const app = document.getElementById('app');
        
        let email = localStorage.getItem('crm_email') || '';
        let password = localStorage.getItem('crm_password') || '';

        function formatRupiah(num) {
            return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(num);
        }

        async function fetchDashboard() {
            try {
                const res = await fetch('/api/crm/dashboard', {
                    headers: { 'x-crm-email': email, 'x-crm-password': password }
                });
                if (res.status === 401) {
                    renderLogin('Sesi berakhir atau kredensial salah.');
                    return;
                }
                const data = await res.json();
                renderDashboard(data.stats, data.orders);
            } catch (err) {
                app.innerHTML = '<div class="container" style="color:red;text-align:center;padding-top:100px;">Terjadi galat jaringan saat memuat data. Periksa koneksi Anda.</div>';
            }
        }

        async function followUp(custEmail, custName, product, source, btn) {
            btn.disabled = true;
            const originalText = btn.innerText;
            btn.innerText = 'Mengirim...';
            try {
                const res = await fetch('/api/crm/followup', {
                    method: 'POST',
                    headers: { 'x-crm-email': email, 'x-crm-password': password, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: custEmail, name: custName, product: product, source: source })
                });
                if (res.ok) {
                    btn.innerText = 'Terkirim ✓';
                    btn.style.background = 'var(--success)';
                    // Kembalikan tombol agar bisa dipencet ulang setelah 3 detik
                    setTimeout(() => {
                        btn.disabled = false;
                        btn.innerText = '✉ Kirim Ulang';
                        btn.style.background = 'var(--primary)';
                    }, 3000);
                } else {
                    const data = await res.json().catch(() => ({}));
                    btn.innerText = 'Gagal';
                    btn.style.background = 'var(--warning)';
                    alert('Gagal mengirim! Alasan dari server: ' + (data.error || data.reason || 'Tidak diketahui'));
                    btn.disabled = false;
                    btn.innerText = originalText;
                }
            } catch (e) {
                btn.innerText = 'Error';
                btn.disabled = false;
            }
        }

        function renderLogin(errorMsg = '') {
            app.innerHTML = \`
                <div class="login-box">
                    <div class="login-logo">✦</div>
                    <h2>Portal Dasbor</h2>
                    \${errorMsg ? \`<p style="color:var(--danger);font-size:0.9rem;background:#fef2f2;padding:12px;border-radius:10px; border:1px solid #fecaca;">\${errorMsg}</p>\` : ''}
                    <input type="email" id="inEmail" placeholder="Alamat Email (anton...)" value="\${email}">
                    <input type="password" id="inPass" placeholder="Kata Sandi Rahasia">
                    <button onclick="doLogin()" style="width:100%; padding:0.85rem; font-size:1rem; border-radius:10px; margin-top:0.5rem;">Masuk Sekarang</button>
                    <p style="font-size:0.8rem; color:var(--text-muted); margin-top:1.5rem;">Terbatas hanya untuk staf dan administrator DompetKuAI.</p>
                </div>
            \`;
        }

        window.doLogin = function() {
            email = document.getElementById('inEmail').value;
            password = document.getElementById('inPass').value;
            localStorage.setItem('crm_email', email);
            localStorage.setItem('crm_password', password);
            app.innerHTML = '<div class="container" style="text-align:center;padding-top:100px;">Memuat data secara aman...</div>';
            fetchDashboard();
        }

        
        let globalOrders = [];
        let globalStats = {};
        let globalTickets = [];
        let currentPage = 1;
        let itemsPerPage = 10;
        let filterApp = 'all';
        let searchQuery = '';
        let activeTab = 'dashboard';

        function switchTab(tab) {
            activeTab = tab;
            if (tab === 'dashboard') {
                renderDashboard(globalStats, globalOrders);
            } else if (tab === 'tickets') {
                renderTickets();
            }
        }

        async function fetchTickets() {
            try {
                const res = await fetch('/api/crm/tickets', { headers: { 'x-crm-email': email, 'x-crm-password': password } });
                const data = await res.json();
                if (data.ok) {
                    globalTickets = data.tickets;
                    if (activeTab === 'tickets') renderTickets();
                }
            } catch (err) { console.error('Gagal memuat tiket', err); }
        }

        function renderTickets() {
            app.innerHTML = \`
                <div class="container">
                    \${renderHeader()}
                    
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 1.5rem;">
                        <h2 style="margin:0;">Tiket Dukungan</h2>
                        <button onclick="fetchTickets()" class="btn-outline">🔄 Segarkan Data</button>
                    </div>

                    <div class="ticket-list" id="ticketListArea">
                        \${globalTickets.map(t => {
                            let badgeClass = t.status === 'done' ? 'done' : 'open';
                            let badgeLabel = t.status === 'done' ? '✓ Selesai' : '✉ Terbuka';
                            return \`
                            <div class="ticket-item \${t.status}" onclick="openTicket('\${t.id}')">
                                <div style="display:flex; justify-content:space-between; margin-bottom:0.75rem; align-items:flex-start;">
                                    <div>
                                        <div style="font-weight:700; font-size:1.15rem; color:var(--text-main);">\${t.user_name || 'Pengguna'}</div>
                                        <div style="color:var(--text-muted); font-size:0.9rem; margin-top:2px;">\${t.user_email}</div>
                                    </div>
                                    <span class="badge \${badgeClass}">\${badgeLabel}</span>
                                </div>
                                <div style="color:var(--text-muted); font-size:0.95rem; margin-bottom:1rem; display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; line-height:1.5;">
                                    \${t.last_message || 'Belum ada pesan.'}
                                </div>
                                <div style="font-size:0.8rem; color:#94a3b8; font-weight:500;">📅 \${new Date(t.updated_at).toLocaleString('id-ID')}</div>
                            </div>
                            \`;
                        }).join('')}
                        \${globalTickets.length === 0 ? '<div style="text-align:center; padding:3rem; color:var(--text-muted); background:var(--card-bg); border-radius:16px; border:1px dashed #cbd5e1;">Belum ada tiket email yang masuk.</div>' : ''}
                    </div>
                </div>
            \`;
        }

        async function openTicket(ticketId) {
            const ticket = globalTickets.find(t => t.id === ticketId);
            if (!ticket) return;

            app.innerHTML = \`
                <div class="container">
                    <button onclick="renderTickets()" class="btn-outline" style="margin-bottom:1.5rem;">← Kembali ke Daftar Tiket</button>
                    
                    <div class="top-header" style="margin-bottom:1.5rem;">
                        <div>
                            <h2 style="margin:0 0 0.2rem 0; font-size:1.4rem;">\${ticket.user_name || 'Pengguna'}</h2>
                            <div style="color:var(--text-muted); font-weight:500;">✉ \${ticket.user_email}</div>
                        </div>
                        \${ticket.status !== 'done' ? \`<button onclick="markTicketDone('\${ticket.id}')" class="btn-success">✔ Tandai Selesai</button>\` : \`<span class="badge done">✓ Tiket Selesai</span>\`}
                    </div>

                    <div class="chat-container" id="chatArea">
                        <div style="text-align:center; padding:3rem; color:var(--text-muted);">Memuat percakapan...</div>
                    </div>

                    <div style="background:var(--card-bg); padding:1.5rem; border-radius:16px; border:1px solid #e2e8f0; box-shadow:var(--shadow-sm);">
                        <div id="replyEditor"></div>
                        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px; margin-top:1rem; padding-top:0.5rem; border-top:1px solid #f1f5f9;">
                            <input type="file" id="replyFiles" multiple accept="image/*,.pdf,.doc,.docx" style="width:auto; padding:0.4rem; border:none; margin:0; font-size:0.85rem;" />
                            <button onclick="sendReply('\${ticket.id}')" id="btnReply">➤ Kirim Balasan</button>
                        </div>
                    </div>
                </div>
            \`;

            // Fetch messages
            try {
                const res = await fetch(\`/api/crm/tickets/\${ticketId}\`, { headers: { 'x-crm-email': email, 'x-crm-password': password } });
                const data = await res.json();
                if (data.ok) {
                    const chatArea = document.getElementById('chatArea');
                    chatArea.innerHTML = data.messages.map(m => {
                        let safeHtml = m.body_text;
                        if (m.direction === 'in') {
                            safeHtml = safeHtml.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\\n/g, '<br>');
                        }
                        return \`
                        <div class="chat-bubble \${m.direction}">
                            <div class="chat-meta">\${m.direction === 'in' ? ticket.user_name : 'Support (Anda)'} • \${new Date(m.created_at).toLocaleString('id-ID')}</div>
                            <div style="word-break:break-word;" class="chat-content">\${safeHtml}</div>
                        </div>
                        \`;
                    }).join('');
                    chatArea.scrollTop = chatArea.scrollHeight;

                    // Initialize Quill Editor
                    setTimeout(() => {
                        if (!window.quill) {
                            window.quill = new Quill('#replyEditor', {
                                theme: 'snow',
                                placeholder: 'Ketik balasan profesional Anda di sini... (Otomatis ditambahkan Regards, Tim DompetkuAI)',
                                modules: {
                                    toolbar: [
                                        ['bold', 'italic', 'underline'],
                                        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                                        ['link', 'emoji'],
                                        ['clean']
                                    ],
                                    "emoji-toolbar": true,
                                    "emoji-shortname": true
                                }
                            });
                        } else {
                            // If re-opening a ticket, clean the previous editor instance or just clear it
                            document.getElementById('replyEditor').innerHTML = '';
                            window.quill = new Quill('#replyEditor', {
                                theme: 'snow',
                                placeholder: 'Ketik balasan profesional Anda di sini... (Otomatis ditambahkan Regards, Tim DompetkuAI)',
                                modules: {
                                    toolbar: [
                                        ['bold', 'italic', 'underline'],
                                        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                                        ['link', 'emoji'],
                                        ['clean']
                                    ],
                                    "emoji-toolbar": true,
                                    "emoji-shortname": true
                                }
                            });
                        }
                    }, 100);
                }
            } catch (err) {}
        }

        async function sendReply(ticketId) {
            if (!window.quill) return;
            const txt = window.quill.root.innerHTML;
            if (txt === '<p><br></p>' || txt.trim() === '') return;
            
            const btn = document.getElementById('btnReply');
            const fileInput = document.getElementById('replyFiles');
            
            btn.disabled = true;
            btn.innerText = 'Mengirim...';

            const attachments = [];
            if (fileInput.files.length > 0) {
                for (const file of fileInput.files) {
                    if (file.size > 5 * 1024 * 1024) {
                        alert('Ukuran file maksimal 5MB per file.');
                        btn.disabled = false;
                        btn.innerText = 'Kirim Balasan';
                        return;
                    }
                    const base64 = await new Promise((resolve) => {
                        const reader = new FileReader();
                        reader.onload = (e) => resolve(e.target.result.split(',')[1]);
                        reader.readAsDataURL(file);
                    });
                    attachments.push({ filename: file.name, content: base64 });
                }
            }

            try {
                const res = await fetch(\`/api/crm/tickets/\${ticketId}/reply\`, {
                    method: 'POST',
                    headers: { 'x-crm-email': email, 'x-crm-password': password, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message: txt, attachments })
                });
                if (res.ok) {
                    await fetchTickets(); // Update list
                    openTicket(ticketId); // Reload chat
                } else {
                    alert('Gagal membalas tiket.');
                    btn.disabled = false;
                    btn.innerText = 'Kirim Balasan';
                }
            } catch (err) {
                btn.disabled = false;
                btn.innerText = 'Kirim Balasan';
            }
        }

        async function markTicketDone(ticketId) {
            try {
                await fetch(\`/api/crm/tickets/\${ticketId}/status\`, {
                    method: 'POST',
                    headers: { 'x-crm-email': email, 'x-crm-password': password, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ status: 'done' })
                });
                await fetchTickets();
                renderTickets();
            } catch (err) {}
        }

        function renderHeader() {
            return \`
                <div class="top-header">
                    <div>
                        <h1>CRM Dasbor Pro</h1>
                        <p style="color:var(--text-muted); margin:0; font-weight:500;">Kelola konversi & layanan pelanggan dengan presisi</p>
                    </div>
                    <button onclick="localStorage.clear(); location.reload();" class="btn-danger" style="border-radius:20px; padding: 0.5rem 1.5rem;">Log Out</button>
                </div>
                <div class="tabs">
                    <button class="tab \${activeTab === 'dashboard' ? 'active' : ''}" onclick="switchTab('dashboard')">📊 Ringkasan Penjualan</button>
                    <button class="tab \${activeTab === 'tickets' ? 'active' : ''}" onclick="switchTab('tickets')">✉️ Tiket Bantuan</button>
                </div>
            \`;
        }

        function renderDashboard(stats, orders) {
            globalStats = stats;
            globalOrders = orders;
            
            let totalUsers = [...new Set(orders.map(o => o.customer_email))].length;
            
            let ordersApp1 = orders.filter(o => o.source && !o.source.includes('tokoku'));
            let ordersApp2 = orders.filter(o => o.source && o.source.includes('tokoku'));
            let totalUsersApp1 = [...new Set(ordersApp1.map(o => o.customer_email))].length;
            let totalUsersApp2 = [...new Set(ordersApp2.map(o => o.customer_email))].length;
            
            let paidOrders = orders.filter(o => o.status === 'paid');
            
            const now = new Date();
            const today = now.toISOString().split('T')[0];
            const lastWeek = new Date(now.getTime() - 7*24*60*60*1000).toISOString();
            const lastMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
            
            let dailyInc = paidOrders.filter(o => (o.created_at||'').startsWith(today)).reduce((sum, o)=>sum+(Number(o.price)||0), 0);
            let weeklyInc = paidOrders.filter(o => (o.created_at||'') >= lastWeek).reduce((sum, o)=>sum+(Number(o.price)||0), 0);
            let monthlyInc = paidOrders.filter(o => (o.created_at||'') >= lastMonth).reduce((sum, o)=>sum+(Number(o.price)||0), 0);

            app.innerHTML = \`
                <div class="container">
                    \${renderHeader()}
                    
                    <div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
                        <div class="card" style="border-left: 4px solid var(--primary);">
                            <h3>Pengguna DompetKu</h3>
                            <div class="value">\${totalUsersApp1} <span style="font-size:1.2rem;">👤</span></div>
                            <div class="sub">Unik berdasarkan email</div>
                        </div>
                        <div class="card" style="border-left: 4px solid var(--secondary);">
                            <h3>Pengguna TokoKu</h3>
                            <div class="value" style="color: var(--secondary);">\${totalUsersApp2} <span style="font-size:1.2rem;">👤</span></div>
                            <div class="sub">Unik berdasarkan email</div>
                        </div>
                        <div class="card">
                            <h3>Total Gabungan</h3>
                            <div class="value" style="color: var(--text-main);">\${totalUsers} <span style="font-size:1.2rem;">👥</span></div>
                            <div class="sub">Seluruh aplikasi</div>
                        </div>
                        <div class="card">
                            <h3>Pemasukan Hari Ini</h3>
                            <div class="value" style="color: var(--success);">\${formatRupiah(dailyInc)}</div>
                            <div class="sub">Semua pendapatan lunas</div>
                        </div>
                        <div class="card">
                            <h3>Pemasukan 7 Hari</h3>
                            <div class="value">\${formatRupiah(weeklyInc)}</div>
                            <div class="sub">7 hari terakhir</div>
                        </div>
                        <div class="card">
                            <h3>Bulan Ini</h3>
                            <div class="value">\${formatRupiah(monthlyInc)}</div>
                            <div class="sub">Total di bulan berjalan</div>
                        </div>
                    </div>

                    <div class="card" style="margin-bottom:2.5rem; padding: 2rem;">
                        <h3 style="margin-bottom:1.5rem; color:var(--text-main); font-size:1rem;">Grafik Pendapatan 7 Hari Terakhir</h3>
                        <canvas id="salesChart" height="70"></canvas>
                    </div>

                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 1.5rem; flex-wrap:wrap; gap:10px;">
                        <h2 style="font-size:1.4rem; color:var(--text-main); margin:0;">Riwayat Pesanan</h2>
                        <div style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
                            <input type="text" id="searchInput" placeholder="🔍 Cari nama/email..." onkeyup="searchOrders(this.value)" style="margin:0; min-width:220px;">
                            <select onchange="filterOrders(this.value)" style="margin:0;">
                                <option value="all">🌐 Semua Aplikasi</option>
                                <option value="dompetkuai">DompetKuAI</option>
                                <option value="tokoku">TokoKu</option>
                            </select>
                        </div>
                    </div>
                    <div class="table-container">
                        <table id="ordersTable">
                        </table>
                    </div>
                    <div id="pagination" style="margin-top:1.5rem; display:flex; justify-content:space-between; align-items:center;">
                    </div>
                </div>
            \`;

            renderChart(paidOrders);
            renderTable();
        }

        window.filterOrders = function(appSource) {
            filterApp = appSource;
            currentPage = 1;
            renderTable();
        }

        window.searchOrders = function(query) {
            searchQuery = query.toLowerCase();
            currentPage = 1;
            renderTable();
        }

        function renderTable() {
            let filtered = globalOrders;
            if (filterApp !== 'all') {
                filtered = filtered.filter(o => (o.source || '').includes(filterApp));
            }
            if (searchQuery) {
                filtered = filtered.filter(o => o.customer_name.toLowerCase().includes(searchQuery) || o.customer_email.toLowerCase().includes(searchQuery));
            }
            
            const totalPages = Math.ceil(filtered.length / itemsPerPage);
            if (currentPage > totalPages && totalPages > 0) currentPage = totalPages;
            
            const startIdx = (currentPage - 1) * itemsPerPage;
            const currentData = filtered.slice(startIdx, startIdx + itemsPerPage);

            document.getElementById('ordersTable').innerHTML = \`
                <thead>
                    <tr>
                        <th style="min-width:120px">Tanggal</th>
                        <th>Pelanggan</th>
                        <th>Kontak / WA</th>
                        <th>Aplikasi</th>
                        <th>Nominal</th>
                        <th>Status</th>
                        <th>Aksi</th>
                    </tr>
                </thead>
                <tbody>
                    \${currentData.map(o => \`
                        <tr>
                            <td>
                                <div style="font-weight:600">\${new Date(o.created_at).toLocaleDateString('id-ID')}</div>
                                <div style="font-size:0.75rem;color:var(--text-muted);font-weight:500;">\${new Date(o.created_at).toLocaleTimeString('id-ID', {hour:'2-digit', minute:'2-digit'})} WIB</div>
                            </td>
                            <td>
                                <div style="font-weight:700; color:var(--text-main)">\${o.customer_name}</div>
                                <div style="font-size:0.85rem;color:var(--text-muted);font-weight:500;">\${o.customer_email}</div>
                            </td>
                            <td>
                                \${o.customer_phone ? 
                                    \`<a href="https://wa.me/\${o.customer_phone.replace(/\\D/g,'').replace(/^0/,'62')}" target="_blank" style="display:inline-flex; align-items:center; margin-bottom:4px; padding:4px 10px; background:#10b981; color:white; border-radius:6px; text-decoration:none; font-size:0.8rem; font-weight:600; box-shadow:var(--shadow-sm); transition:all 0.2s;">💬 WA: \${o.customer_phone}</a>\` 
                                    : '<span style="color:#94a3b8;font-size:0.85rem;font-weight:500;"><i>- kosong -</i></span>'
                                }
                            </td>
                            <td>
                                <div style="font-weight:600">\${o.product_name}</div>
                                <div style="font-size:0.8rem;color:var(--text-muted);font-weight:500;">\${o.source}</div>
                            </td>
                            <td style="font-weight:800; color:var(--text-main)">\${formatRupiah(o.price)}</td>
                            <td>
                                <span class="badge \${o.status}">\${o.status === 'paid' ? '✔ Lunas' : 'Menunggu Bayar'}</span>
                            </td>
                            <td>
                                \${o.status !== 'paid' ? 
                                    \`<button onclick="followUp('\${o.customer_email}', '\${o.customer_name}', '\${o.product_name}', '\${o.source}', this)" style="padding:0.4rem 0.8rem; font-size:0.8rem;">✉ Email Follow Up</button>\` : 
                                    '<span style="color:var(--success);font-weight:700;font-size:0.9rem">Selesai</span>'}
                            </td>
                        </tr>
                    \`).join('')}
                    \${currentData.length === 0 ? '<tr><td colspan="7" style="text-align:center;color:#94a3b8;padding:3rem;font-weight:500;">Tidak ada pesanan ditemukan.</td></tr>' : ''}
                </tbody>
            \`;

            document.getElementById('pagination').innerHTML = \`
                <div style="font-size:0.9rem; color:var(--text-muted); font-weight:500;">
                    Menampilkan <b style="color:var(--text-main)">\${filtered.length > 0 ? startIdx + 1 : 0} - \${Math.min(startIdx + itemsPerPage, filtered.length)}</b> dari \${filtered.length} pesanan
                </div>
                <div style="display:flex; gap:10px;">
                    <button onclick="changePage(-1)" \${currentPage <= 1 ? 'disabled' : ''} class="btn-outline">← Mundur</button>
                    <button onclick="changePage(1)" \${currentPage >= totalPages ? 'disabled' : ''} class="btn-outline">Lanjut →</button>
                </div>
            \`;
        }

        window.changePage = function(dir) {
            currentPage += dir;
            renderTable();
        };

        function renderChart(paidOrders) {
            const labels = [];
            const data = [];
            const now = new Date();
            for(let i=6; i>=0; i--) {
                const d = new Date(now.getTime() - i*24*60*60*1000);
                const ds = d.toISOString().split('T')[0];
                labels.push(d.toLocaleDateString('id-ID', {day:'numeric', month:'short'}));
                const sum = paidOrders.filter(o => (o.created_at||'').startsWith(ds)).reduce((s,o)=>s+(Number(o.price)||0), 0);
                data.push(sum);
            }
            
            if (window.salesChartInstance) window.salesChartInstance.destroy();
            
            const ctx = document.getElementById('salesChart').getContext('2d');
            window.salesChartInstance = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Pendapatan (Rp)',
                        data: data,
                        borderColor: '#3b82f6',
                        backgroundColor: 'rgba(59, 130, 246, 0.2)',
                        borderWidth: 3,
                        pointBackgroundColor: '#2563eb',
                        fill: true,
                        tension: 0.4
                    }]
                },
                options: {
                    responsive: true,
                    plugins: { legend: { display: false } },
                    scales: { 
                        y: { 
                            beginAtZero: true, 
                            ticks: { callback: function(val){ return val >= 1000 ? (val/1000) + 'k' : val; } },
                            grid: { borderDash: [5, 5] }
                        },
                        x: { grid: { display: false } }
                    }
                }
            });
        }

        // Mulai aplikasi
        if (email && password) {
            fetchDashboard();
            fetchTickets(); // Muat tiket di belakang layar
        } else {
            renderLogin();
        }
    </script>


</body>
</html>`;
}
