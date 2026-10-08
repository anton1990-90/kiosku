/**
 * Isi email yang dikirim ke pelanggan setelah pembayaran terkonfirmasi.
 *
 * Ditulis dengan gaya surat biasa (bukan halaman web): memakai tabel dan
 * gaya sebaris, karena banyak aplikasi email membuang <style> di <head>.
 *
 * PENTING: jangan pernah mencantumkan tautan GitHub di sini. Semua tautan
 * harus menunjuk ke server aktivasi sendiri, supaya akun GitHub penjual
 * tidak terlihat pelanggan.
 */

function aman(teks, cadangan) {
  const nilai = String(teks ?? '').trim();
  const dipakai = nilai === '' ? cadangan : nilai;
  return dipakai
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Susun email untuk satu pembeli.
 *
 * @param {object} o
 * @param {string} o.namaPembeli  nama pembeli (boleh kosong)
 * @param {string} o.kodeVoucher  kode yang baru dibuat, mis. VC-XXXX-XXXX-XXXX
 * @param {string} o.namaAplikasi nama aplikasi, mis. "TokoKu"
 * @param {string} o.halamanUnduh alamat halaman unduh
 * @param {string} o.portal       alamat portal aktivasi
 * @returns {{subject: string, html: string, text: string}}
 */
function emailVoucher(o) {
  const namaAplikasi = aman(o && o.namaAplikasi, 'TokoKu');
  const kode = aman(o && o.kodeVoucher, '');
  const halamanUnduh = String((o && o.halamanUnduh) || '').trim();
  const portal = String((o && o.portal) || '').trim();

  const nama = String((o && o.namaPembeli) || '').trim();
  const sapaan = nama === '' ? 'Halo' : `Halo ${nama}`;

  const subject = `Kode Aktivasi ${namaAplikasi} Anda — ${kode}`;

  const teks = [
    `${sapaan},`,
    '',
    `Terima kasih sudah membeli ${namaAplikasi}.`,
    '',
    `KODE VOUCHER ANDA: ${kode}`,
    '',
    'Cara pakai:',
    `1. Unduh aplikasinya di ${halamanUnduh}`,
    '2. Pasang di HP Android Anda',
    `3. Buka aplikasi, lalu buka ${portal}`,
    '4. Masukkan Kode Perangkat dari aplikasi dan Kode Voucher di atas',
    '5. Kode Aktivasi yang muncul, tempel di aplikasi lalu tekan Aktivasi',
    '',
    'Setelah aktif, aplikasi bisa dipakai tanpa internet.',
    '',
    `Simpan email ini. Kode voucher hanya berlaku untuk satu HP.`,
  ].join('\n');

  const baris = (nomor, isi) =>
    '<tr>' +
    '<td style="padding:0 10px 8px 0;vertical-align:top;font-size:14px;line-height:22px;color:#0F6E56;font-weight:bold;width:16px">' +
    nomor +
    '</td>' +
    '<td style="padding:0 0 8px 0;font-size:14px;line-height:22px;color:#3F3F46">' +
    isi +
    '</td>' +
    '</tr>';

  const html =
    '<!DOCTYPE html><html lang="id"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    `<title>${subject}</title></head>` +
    '<body style="margin:0;padding:0;background:#F4F5F7">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F4F5F7">' +
    '<tr><td align="center" style="padding:24px 12px">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" ' +
    'style="max-width:520px;background:#ffffff;border-radius:14px;overflow:hidden">' +

    '<tr><td style="background:#0F6E56;padding:26px 24px">' +
    `<div style="font-family:Arial,Helvetica,sans-serif;font-size:19px;font-weight:bold;color:#ffffff;letter-spacing:-0.3px">${namaAplikasi}</div>` +
    '<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#CFEAE0;padding-top:4px">Aplikasi kasir untuk toko Anda</div>' +
    '</td></tr>' +

    '<tr><td style="padding:24px 24px 8px 24px;font-family:Arial,Helvetica,sans-serif">' +
    `<p style="margin:0 0 14px 0;font-size:15px;line-height:24px;color:#1A1A2E">${sapaan}, terima kasih sudah membeli <b>${namaAplikasi}</b>. Pembayaran Anda sudah kami terima.</p>` +
    '<p style="margin:0 0 8px 0;font-size:13px;line-height:20px;color:#71717A">Kode Voucher Anda:</p>' +
    '<div style="background:#E1F5EE;border:1.5px solid #1D9E75;border-radius:12px;padding:16px 12px;text-align:center">' +
    `<div style="font-family:'Courier New',Courier,monospace;font-size:22px;font-weight:bold;color:#085041;letter-spacing:2px;word-break:break-all">${kode}</div>` +
    '</div>' +
    '<p style="margin:12px 0 20px 0;font-size:12px;line-height:19px;color:#71717A">Satu kode berlaku untuk satu HP. Simpan email ini.</p>' +

    '<div style="border-top:1px solid #E8E9EB;padding-top:18px">' +
    '<p style="margin:0 0 10px 0;font-size:14px;font-weight:bold;color:#1A1A2E">Cara pakai</p>' +
    '<table role="presentation" cellpadding="0" cellspacing="0" border="0">' +
    baris('1', `Unduh aplikasinya di <a href="${aman(halamanUnduh, '#')}" style="color:#0F6E56;font-weight:bold">halaman unduh</a>` +
      (halamanUnduh === '' ? ' (hubungi penjual)' : '')) +
    baris('2', 'Pasang di HP Android Anda') +
    baris('3', `Buka <a href="${aman(portal, '#')}" style="color:#0F6E56;font-weight:bold">portal aktivasi</a>, lalu masukkan <b>Kode Perangkat</b> dari aplikasi dan <b>Kode Voucher</b> di atas`) +
    baris('4', 'Kode Aktivasi yang muncul, tempel di aplikasi lalu tekan tombol <b>Aktivasi</b>') +
    '</table>' +
    '</div>' +

    '<div style="background:#FAEEDA;border-radius:10px;padding:12px 14px;margin-top:14px">' +
    '<p style="margin:0;font-size:12px;line-height:19px;color:#854F0B"><b>Perlu internet sekali saja.</b> Setelah aktif, aplikasi bisa dipakai tanpa internet untuk kegiatan sehari-hari.</p>' +
    '</div>' +
    '</td></tr>' +

    '<tr><td style="padding:18px 24px 24px 24px;font-family:Arial,Helvetica,sans-serif">' +
    '<p style="margin:0;font-size:12px;line-height:19px;color:#9CA3AF">Email ini dikirim otomatis setelah pembayaran Anda terkonfirmasi. Kalau ada pertanyaan, balas email ini.</p>' +
    '</td></tr>' +

    '</table></td></tr></table></body></html>';

  return { subject, html, text: teks };
}


export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // 1. BUAT TRANSAKSI DARI HALAMAN SALES
    if (request.method === "POST" && url.pathname === "/api/checkout") {
      try {
        const body = await request.json();
        const customerName = (body.name || "").trim();
        const customerEmail = (body.email || "").trim();
        const requestedAmount = body.amount || 99000;
        const requestedMethod = body.method || "payment_link";

        if (!customerName || !customerEmail) {
          return new Response(JSON.stringify({ error: "Nama dan Email wajib diisi" }), { status: 400 });
        }

        const API_KEY = (env.PAKASIR_API_KEY || "").trim();
        const SLUG = (env.PAKASIR_SLUG || "").trim();
        const orderId = "INV-" + Date.now();

        // Panggil Pakasir API
        const apiUrl = `https://app.pakasir.com/api/v2/create-transaction/${SLUG}/${orderId}`;
        const response = await fetch(apiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Api-Key": API_KEY
          },
          body: JSON.stringify({
            method: requestedMethod,
            amount: requestedAmount
          })
        });

        const data = await response.json();
        if (!data.payment_link && !data.qr_string && !data.va_number) {
          return new Response(JSON.stringify({ error: "Gagal memproses Pakasir" }), { status: 500 });
        }

        // SIMPAN DATA KE DATABASE SEBAGAI PENDING
        // Kita simpan statusnya "pending" dulu, sampai webhook masuk
        await env.DB.prepare(
          'INSERT INTO vouchers (code, batch, customer_name, customer_email, order_ref, status, created_at) ' +
          "VALUES (?, ?, ?, ?, ?, 'pending', ?)"
        )
        .bind(
           // Kita gunakan OrderId sementara sebagai kode, nanti diganti saat lunas
           orderId, 
           'pakasir-web', 
           customerName, 
           customerEmail, 
           orderId, 
           new Date().toISOString()
        )
        .run();

        // KABARI CRM
        try {
          await fetch("https://lisensi.dompetkuai.my.id/webhook/internal-crm", {
             method: "POST",
             headers: { "Content-Type": "application/json" },
             body: JSON.stringify({
                event: "checkout",
                email: customerEmail,
                name: customerName,
                amount: requestedAmount,
                order_id: orderId,
                source: "tokoku.dompetkuai.my.id"
             })
          });
        } catch (e) {}

        return new Response(JSON.stringify(data), {
          headers: { "Content-Type": "application/json" }
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), { status: 500 });
      }
    }

    // ENDPOINT UNTUK PENGECEKAN STATUS PEMBAYARAN (POLLING)
    if (request.method === "GET" && url.pathname === "/api/check-payment") {
      try {
        const orderId = url.searchParams.get("order_id");
        if (!orderId) return new Response("Order ID missing", { status: 400 });

        const stmt = await env.DB.prepare("SELECT status FROM vouchers WHERE order_ref = ?").bind(orderId).first();
        if (!stmt) return new Response("Not found", { status: 404 });

        return new Response(JSON.stringify({ status: stmt.status }), {
          headers: { "Content-Type": "application/json" }
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), { status: 500 });
      }
    }


    // 2. TERIMA WEBHOOK DARI PAKASIR
    if (request.method === "POST" && !url.pathname.includes("/api/checkout")) {
      const secretHeader = request.headers.get("X-Secret");
      const WEBHOOK_SECRET = (env.PAKASIR_WEBHOOK_SECRET || "").trim();

      const rawPayload = await request.text();
      let payload = {};
      try { payload = JSON.parse(rawPayload); } catch(e) {}

      // LOGGING
      try {
        await env.DB.prepare(
          'INSERT INTO webhook_events (delivery_id, sumber, event, status, voucher_code, email, email_status, alasan, received_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        ).bind(
          String(payload.txn_id || "unknown"), 
          "pakasir", 
          "webhook", 
          String(payload.status || "no_status"), 
          String(payload.order_id || "no_order"), 
          "", 
          "", 
          String(rawPayload).slice(0, 100), 
          new Date().toISOString()
        ).run();
      } catch(e) {
        try {
          await env.DB.prepare(
            'INSERT INTO webhook_events (delivery_id, sumber, event, status, voucher_code, email, email_status, alasan, received_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
          ).bind("error", "pakasir", "webhook", "error", "", "", "", String(e.message).slice(0, 100), new Date().toISOString()).run();
        } catch(e2) {}
      }

      // Jika secret cocok, ini adalah webhook Pakasir yang sah
      if (secretHeader && secretHeader === WEBHOOK_SECRET) {
        try {
          if (payload.status === "completed") {
            const orderId = payload.order_id;
            const order = await env.DB.prepare("SELECT * FROM vouchers WHERE order_ref = ? AND status = 'pending'").bind(orderId).first();
            
            if (order) {
              const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
              const bytes = new Uint8Array(12);
              crypto.getRandomValues(bytes);
              let rawCode = "";
              for (let i = 0; i < 12; i++) {
                 rawCode += charset[bytes[i] % charset.length];
              }
              const voucherCode = `VC-${rawCode.slice(0,4)}-${rawCode.slice(4,8)}-${rawCode.slice(8,12)}`;

              await env.DB.prepare("UPDATE vouchers SET code = ?, status = 'unused' WHERE order_ref = ?")
                .bind(voucherCode, orderId)
                .run();

              const RESEND_API_KEY = (env.RESEND_API_KEY || "").trim();
              if (RESEND_API_KEY) {
                const emailContent = emailVoucher({
                  namaPembeli: order.customer_name,
                  kodeVoucher: voucherCode,
                  namaAplikasi: "TokoKu",
                  halamanUnduh: "https://lisensi.dompetkuai.my.id/unduh",
                  portal: "https://lisensi.dompetkuai.my.id"
                });

                const resendResponse = await fetch('https://api.resend.com/emails', {
                  method: 'POST',
                  headers: {
                    'Authorization': `Bearer ${RESEND_API_KEY}`,
                    'Content-Type': 'application/json'
                  },
                  body: JSON.stringify({
                    from: `TokoKu Support <support@dompetkuai.my.id>`,
                    to: [order.customer_email],
                    subject: emailContent.subject,
                    html: emailContent.html,
                    text: emailContent.text
                  })
                });
                const resendText = await resendResponse.text();
                try {
                  await env.DB.prepare("UPDATE webhook_events SET email_status = ?, email = ? WHERE delivery_id = ?").bind(resendText.slice(0, 100), order.customer_email, String(payload.txn_id || "unknown")).run();
                } catch(e) {}
              }
            }
          }
          return new Response("OK", { status: 200 });
        } catch (err) {
          return new Response(err.message, { status: 500 });
        }
      } else {
        // Jika POST tapi secret salah/tidak ada, abaikan
        return new Response(JSON.stringify({
          error: "Method Not Allowed (Invalid Secret)",
          receivedSecret: secretHeader || "null",
          expectedSecret: WEBHOOK_SECRET || "null",
          payload: rawPayload.slice(0, 200)
        }), { status: 405, headers: { "Content-Type": "application/json" } });

      }
    }

    // Jika bukan ke /api/checkout atau webhook, load file HTML/CSS dari assets (GET /)
    return env.ASSETS.fetch(request);
  }
};
