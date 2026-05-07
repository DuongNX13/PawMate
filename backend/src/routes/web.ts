import { type FastifyPluginAsync } from 'fastify';

const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const buildAuthLandingHtml = (appName: string) => `<!doctype html>
<html lang="vi">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(appName)} - Xác minh tài khoản</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #fff7f2;
        --card: #ffffff;
        --text: #1f2937;
        --muted: #6b7280;
        --primary: #ff8a5b;
        --primary-soft: #ffe6db;
        --success: #1d8f5a;
        --success-soft: #eaf8f1;
        --error: #c2410c;
        --error-soft: #fff1eb;
        --border: #f2d7c9;
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        padding: 24px;
        background:
          radial-gradient(circle at top right, rgba(255, 138, 91, 0.18), transparent 32%),
          linear-gradient(180deg, #fffaf7 0%, var(--bg) 100%);
        color: var(--text);
        font-family:
          "Segoe UI", "Be Vietnam Pro", Arial, sans-serif;
      }

      .card {
        width: min(100%, 560px);
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 24px;
        box-shadow: 0 18px 60px rgba(31, 41, 55, 0.08);
        padding: 28px;
      }

      .eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 999px;
        background: var(--primary-soft);
        color: var(--primary);
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.04em;
        text-transform: uppercase;
      }

      h1 {
        margin: 18px 0 10px;
        font-size: 32px;
        line-height: 1.15;
      }

      p {
        margin: 0;
        line-height: 1.6;
      }

      .panel {
        margin-top: 22px;
        border-radius: 18px;
        padding: 18px;
        background: #f9fafb;
        border: 1px solid #eef0f3;
      }

      .panel.success {
        background: var(--success-soft);
        border-color: #cbeedc;
      }

      .panel.error {
        background: var(--error-soft);
        border-color: #ffd8c7;
      }

      .label {
        margin-bottom: 8px;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--muted);
      }

      .status {
        font-size: 22px;
        font-weight: 800;
      }

      .status.success {
        color: var(--success);
      }

      .status.error {
        color: var(--error);
      }

      .hint-list {
        margin: 18px 0 0;
        padding-left: 20px;
        color: var(--muted);
      }

      .hint-list li + li {
        margin-top: 8px;
      }

      code {
        font-family: Consolas, "Courier New", monospace;
        padding: 2px 6px;
        border-radius: 6px;
        background: rgba(15, 23, 42, 0.06);
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 22px;
      }

      .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 46px;
        padding: 0 18px;
        border-radius: 14px;
        border: 1px solid transparent;
        text-decoration: none;
        font-weight: 700;
      }

      .button.primary {
        background: var(--primary);
        color: white;
      }

      .button.secondary {
        border-color: var(--border);
        color: var(--text);
        background: white;
      }

      .footnote {
        margin-top: 18px;
        font-size: 13px;
        color: var(--muted);
      }
    </style>
  </head>
  <body>
    <main class="card">
      <div class="eyebrow">PawMate Auth</div>
      <h1>Xác minh tài khoản</h1>
      <p id="summary">
        ${escapeHtml(appName)} đang đọc kết quả xác minh từ liên kết của Supabase.
      </p>

      <section id="panel" class="panel">
        <div class="label">Trạng thái</div>
        <div id="status" class="status">Đang xử lý...</div>
        <p id="detail" style="margin-top: 10px; color: var(--muted);">
          Vui lòng chờ trong giây lát.
        </p>
      </section>

      <ul id="hintList" class="hint-list">
        <li>Nếu bạn đang ở luồng MVP hiện tại, cách ổn định nhất vẫn là nhập mã OTP ngay trong app.</li>
        <li>Nếu link cũ bị lỗi, hãy dùng email mới nhất rồi chọn <code>Gửi lại mã</code> trong màn OTP.</li>
      </ul>

      <div class="actions">
        <a class="button primary" href="pawmate://auth/callback">Mở lại PawMate</a>
        <a class="button secondary" href="/health">Kiểm tra backend</a>
      </div>

      <p class="footnote">
        Trang này tồn tại để tránh việc redirect về localhost chỉ hiện lỗi <code>Route GET:/ not found</code>.
      </p>
    </main>

    <script>
      const statusEl = document.getElementById('status');
      const detailEl = document.getElementById('detail');
      const panelEl = document.getElementById('panel');
      const summaryEl = document.getElementById('summary');

      const setState = ({ status, detail, type = 'neutral', summary }) => {
        statusEl.textContent = status;
        detailEl.textContent = detail;
        summaryEl.textContent = summary;
        panelEl.className = 'panel' + (type === 'neutral' ? '' : ' ' + type);
        statusEl.className = 'status' + (type === 'neutral' ? '' : ' ' + type);
      };

      const hashParams = new URLSearchParams(window.location.hash.startsWith('#')
        ? window.location.hash.slice(1)
        : window.location.hash);
      const queryParams = new URLSearchParams(window.location.search);
      const tokenHash = queryParams.get('token_hash');
      const emailType = queryParams.get('type');

      const handleHashResult = () => {
        const errorDescription = hashParams.get('error_description');
        const errorCode = hashParams.get('error_code');
        if (errorDescription) {
          setState({
            status: errorCode === 'otp_expired' ? 'Liên kết đã hết hạn' : 'Xác minh chưa thành công',
            detail: decodeURIComponent(errorDescription.replaceAll('+', ' ')),
            type: 'error',
            summary: 'Supabase đã redirect về localhost nhưng trả về trạng thái lỗi thay vì mở app.',
          });
          return true;
        }

        if (hashParams.get('access_token') || hashParams.get('refresh_token')) {
          setState({
            status: 'Email đã được xác minh',
            detail: 'Bạn có thể quay lại PawMate và đăng nhập bằng email và mật khẩu vừa tạo.',
            type: 'success',
            summary: 'Supabase đã xác minh thành công và trả session về qua URL fragment.',
          });
          return true;
        }

        return false;
      };

      const verifyFromTokenHash = async () => {
        if (!tokenHash || !emailType) {
          return false;
        }

        setState({
          status: 'Đang xác minh token',
          detail: 'Trang đang dùng token_hash từ query để gọi backend verify-email.',
          summary: 'Liên kết đã tới đúng callback path và đang được xử lý.',
        });

        try {
          const response = await fetch('/auth/verify-email', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tokenHash }),
          });
          const payload = await response.json();

          if (!response.ok) {
            throw new Error(payload?.error?.message || 'Không thể xác minh token.');
          }

          setState({
            status: 'Email đã được xác minh',
            detail: payload?.message || 'Bạn có thể quay lại app để đăng nhập.',
            type: 'success',
            summary: 'Backend PawMate đã xác minh token_hash thành công.',
          });
        } catch (error) {
          setState({
            status: 'Xác minh chưa thành công',
            detail: error instanceof Error ? error.message : 'Không thể xác minh token.',
            type: 'error',
            summary: 'Liên kết callback đã tới backend nhưng bước verify-email trả lỗi.',
          });
        }

        return true;
      };

      const main = async () => {
        if (handleHashResult()) {
          return;
        }

        if (await verifyFromTokenHash()) {
          return;
        }

        setState({
          status: 'Đã tới backend PawMate',
          detail: 'Liên kết này không còn rơi vào lỗi 404 nữa. Nếu bạn vẫn chưa xác minh được, hãy quay lại app và nhập mã OTP.',
          summary: 'Backend đang mở đúng landing page cho luồng confirm email.',
        });
      };

      void main();
    </script>
  </body>
</html>`;

type WebRouteOptions = {
  appName?: string;
};

const webRoute: FastifyPluginAsync<WebRouteOptions> = async (app, options) => {
  const html = buildAuthLandingHtml(options.appName ?? 'PawMate');

  app.get('/', async (_, reply) => {
    reply.type('text/html; charset=utf-8').send(html);
  });

  app.get('/auth/callback', async (_, reply) => {
    reply.type('text/html; charset=utf-8').send(html);
  });
};

export default webRoute;
