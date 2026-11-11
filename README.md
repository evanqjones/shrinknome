# Shrinknome

Godot 4.7.2 project for the Shrinknome game.

## Run in Godot

Open this folder in Godot and run the project. The main scene is level.tscn.

## Build and preview the web version

Install the Godot 4.7.2 export templates, then run:

    godot --headless --editor --path . --quit
    godot --headless --path . --export-release Web public/index.html
    python -m http.server 8000 --directory public

Open http://localhost:8000 in a WebAssembly/WebGL 2 capable browser. Do not open the HTML file directly from disk.

## Publish with GitHub Pages

The workflow at .github/workflows/pages.yml exports the project and deploys it to GitHub Pages whenever main is updated, or when the workflow is started manually.

1. Push this project to the repository's main branch.
2. In the repository, open Settings → Pages and choose GitHub Actions as the build and deployment source.
3. Open Actions and watch Build and deploy Shrinknome. The deployment URL appears on a successful run.

The web export uses Godot's single-threaded template, so it does not need custom cross-origin headers.

