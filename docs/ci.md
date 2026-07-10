# CI: Gitea Actions on a self-hosted macOS runner

Part of epic #43 (CI & releases on self-hosted Gitea). This document covers the
one-time setup of the `act_runner` on this Mac; the workflow itself lives at
`.gitea/workflows/ci.yml` and is checked into the repo.

## What runs

On every push and pull request, the workflow:

1. Checks out the repo.
2. Runs `xcodegen generate` to produce `Rhea.xcodeproj` (not committed —
   `project.yml` is the source of truth).
3. Runs `xcodebuild build test -scheme Rhea -destination 'platform=macOS'`,
   which builds the app and runs both `RheaTests` (unit) and `RheaUITests`
   (XCUITest) targets, writing a result bundle.
4. Uploads the `.xcresult` bundle as a workflow artifact, always (even on
   failure), so a failing run's logs/screenshots are inspectable from the
   Gitea Actions UI without re-running locally.

A failing build or any failing test fails the check and is reported on the
Gitea PR page.

## Runner prerequisites (one-time, on this Mac)

The runner machine needs, ahead of any CI run:

- **Xcode** installed, with the license accepted:
  `sudo xcodebuild -license accept`
- **XcodeGen**: `brew install xcodegen`
- A stable, always-logged-in user session (see the Accessibility caveat
  below — this rules out running the runner as a headless/background-only
  service user).

## Registering `act_runner`

1. Install the runner binary:
   ```
   brew install act_runner
   ```
   (or download the binary for macOS from the Gitea releases page if not
   available via Homebrew on this system).

2. Get a registration token from the Gitea instance: **repo or org Settings
   → Actions → Runners → Create new runner**, copy the token shown.

3. Register the runner with the `macos` label so `runs-on: macos` in the
   workflow resolves to this machine:
   ```
   act_runner register \
     --instance https://git.danieldaum.net \
     --token <TOKEN> \
     --name mac-runner-1 \
     --labels macos
   ```
   This writes `.runner` config in the working directory you run it from —
   pick a stable location, e.g. `~/gitea-runner/`.

4. Daemonize with `launchd` so the runner survives reboots. Create
   `~/Library/LaunchAgents/net.danieldaum.act-runner.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>Label</key>
     <string>net.danieldaum.act-runner</string>
     <key>ProgramArguments</key>
     <array>
       <string>/opt/homebrew/bin/act_runner</string>
       <string>daemon</string>
     </array>
     <key>WorkingDirectory</key>
     <string>/Users/YOUR_USER/gitea-runner</string>
     <key>RunAtLoad</key>
     <true/>
     <key>KeepAlive</key>
     <true/>
     <key>StandardOutPath</key>
     <string>/Users/YOUR_USER/gitea-runner/runner.log</string>
     <key>StandardErrorPath</key>
     <string>/Users/YOUR_USER/gitea-runner/runner.err</string>
   </dict>
   </plist>
   ```
   Load it:
   ```
   launchctl load ~/Library/LaunchAgents/net.danieldaum.act-runner.plist
   ```
   Use a `LaunchAgent` (not a `LaunchDaemon`) — the runner must execute in a
   real logged-in GUI session for the reason below, and LaunchDaemons run
   outside any user session.

## Known blocker: XCUITest needs Accessibility permission granted manually

`RheaUITests` exercises the app via XCUITest, which requires the test
runner's automation session to have **System Settings → Privacy & Security →
Accessibility** access. This is a one-time grant tied to the specific process
(Xcode's generated `XCTRunner` host app / `xcodebuild`'s test runner) and
**cannot be granted by a workflow YAML or any CI script** — it's a manual,
interactive step on the runner machine itself, done once after Xcode/the
runner is set up:

1. Run the test suite once locally on the runner Mac
   (`xcodebuild ... test`) so macOS prompts for Accessibility access, or
   trigger the prompt via **System Settings → Privacy & Security →
   Accessibility → +** and add the relevant `xcodebuild`/`XCTRunner` binary
   manually.
2. Enable the toggle.

Without this, `RheaUITests` will fail or hang on the runner even though the
same suite passes when run interactively from Xcode by a user who has
already granted the permission. If CI test runs fail specifically in
`RheaUITests` with no clear assertion failure (timeouts, "Failed to get
matching snapshot" errors, or the run hanging), check this first.

This also means the runner must operate under a real, logged-in GUI user
session (not a headless SSH-only login) — another reason to register it as
a `LaunchAgent` under the interactive user rather than a system
`LaunchDaemon`.

## Verifying the workflow

Push a branch and check **Gitea → repo → Actions** for a running/completed
job, or the checks panel on the PR page. A red check with logs in the
`test-results` artifact means a real build/test failure; a run that never
starts usually means the runner isn't registered, isn't labeled `macos`, or
isn't running (`launchctl list | grep act-runner`).
