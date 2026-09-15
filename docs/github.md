# GitHub presentation

## Repository name

`BloxQA`

## Description

Automated QA and gameplay testing plugin for Roblox Studio.

## Suggested topics

`roblox`, `roblox-studio`, `luau`, `testing`, `qa`, `automation`, `game-development`, `studio-plugin`

## Suggested About settings

- Website: leave empty until there is a real project page or release.
- Releases: create a `v0.1.0` release only after a downloadable package has been built and verified.
- Packages: not currently used.
- Discussions: optional; Issues are sufficient for this early preview.

Do not add CI, coverage, download, Creator Store, or production-ready badges unless those claims become true.

## Publish as a public repository

Before publishing, replace `BloxQA contributors` in `LICENSE` with your preferred public/legal name if you want personal copyright attribution. Add reviewed screenshots only after cropping private Studio information.

From the exported `BloxQA` folder:

```text
git init -b main
git add .
git commit -m "Publish BloxQA v0.1.0 developer preview"
```

Then:

1. Sign in to GitHub and choose **New repository**.
2. Set the repository name to `BloxQA`.
3. Paste the description above and select **Public**.
4. Do not add another README, `.gitignore`, or license because they already exist locally.
5. Create the repository.
6. Run the commands GitHub displays, using your real account name:

```text
git remote add origin https://github.com/<your-github-username>/BloxQA.git
git push -u origin main
```

7. Open the repository's **About** settings and add the suggested topics.
8. Check the rendered README, Mermaid diagrams, relative documentation links, and public file list while signed out or in a private browser window.
9. Pin the repository on your GitHub profile when you are satisfied with the public view.

Create a GitHub Release only after a downloadable plugin artifact has been built and installed successfully in a clean Studio environment. Until then, the source commit itself can accurately represent v0.1.0.
