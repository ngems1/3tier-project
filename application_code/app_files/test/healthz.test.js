const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { app } = require('../index');

function get(path, port) {
    return new Promise((resolve, reject) => {
        http.get({ host: '127.0.0.1', port, path }, (res) => {
            let body = '';
            res.on('data', (chunk) => { body += chunk; });
            res.on('end', () => resolve({ statusCode: res.statusCode, body }));
        }).on('error', reject);
    });
}

test('GET /healthz returns 200 and ok status', async () => {
    const server = app.listen(0);
    try {
        const { port } = server.address();
        const res = await get('/healthz', port);
        assert.equal(res.statusCode, 200);
        assert.deepEqual(JSON.parse(res.body), { status: 'ok' });
    } finally {
        server.close();
    }
});
