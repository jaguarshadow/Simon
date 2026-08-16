# Deployment — GitHub Pages

The game is playable at **https://jaguarshadow.github.io/Simon/**. Deployment is fully
automated — there is no manual export/upload step.

## How it works

`.github/workflows/ci.yml` runs on every push to `main`:

1. Checks out the repo (with LFS).
2. Builds the Godot 4 Web export headlessly, using the `Web` preset already committed in
   `export_presets.cfg` (`barichello/godot-ci` container, version pinned via the `GODOT_VERSION`
   env var at the top of the workflow — bump both together when upgrading engine versions).
3. Uploads the build as a workflow artifact (useful for inspecting a PR's build without deploying
   it — pull requests build but do not deploy).
4. On `main` only, pushes the build output to the `gh-pages` branch via
   `JamesIves/github-pages-deploy-action`, which force-replaces that branch's contents each time.

GitHub Pages itself is configured (repo Settings → Pages) to serve from the `gh-pages` branch —
that setting lives in the GitHub UI, not in this repo, and only needs to be touched again if the
branch name or publishing source ever changes.

## To deploy

Just commit and push to `main`:

```
git push origin main
```

Watch progress under the repo's Actions tab, or:

```
gh run watch
```

The live site updates a minute or two after the workflow's "Deploy to GitHub Pages" step
finishes. No local Godot install or manual export is required — the CI container has its own
export templates.

## Testing an export locally (optional)

Only needed if you want to sanity-check the Web export before pushing, and only works if Godot
4.7.1 with Web export templates is installed locally:

```
godot --headless --export-release "Web" build_web/Simon.html
```

Then serve `build_web/` with any static file server (opening the HTML file directly via
`file://` will fail — the WASM/threading setup needs real HTTP headers).
