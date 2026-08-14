# FrameGuard documentation site

Static site for GitHub Pages. Source of truth for tokens/logo remains `branding/`;
the Pages workflow copies brand assets into `docs/assets/` on deploy.

## Local preview

Open `docs/index.html` in a browser, or serve the folder:

```bash
# from repo root
python -m http.server 8080 --directory docs
```

## Enable on GitHub

1. Push to `main`
2. Repo **Settings → Pages → Source: GitHub Actions**
3. The `Pages` workflow deploys this folder to `https://theworker02.github.io/frameguard/`
