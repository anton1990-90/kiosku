const fs = require('fs');
const emailVoucherCode = fs.readFileSync('cloudflare/src/email-voucher.js', 'utf8');
let workerCode = fs.readFileSync('sales_page/worker.js', 'utf8');

// Replace import statement
workerCode = workerCode.replace(/import\s*\{\s*emailVoucher\s*\}\s*from\s*['"].*?email-voucher\.js['"];?/, emailVoucherCode.replace('export function emailVoucher', 'function emailVoucher'));

fs.writeFileSync('sales_page/_worker.js', workerCode);
console.log('Merged _worker.js created.');
