# Roadmap — next version

v1.0.0 is a general Apple Silicon monitor. The next version specializes toward
**AI-inference monitoring** on Apple Silicon — the niche neither terminal monitors
nor Activity Monitor cover.

## Shipped (v1.1.0 – v1.3.0)

- **AI Workload view (hero)** — a bottleneck classifier with a single verdict:
  *bandwidth-bound* / *compute-bound* / *thermal-throttled* / *memory-pressured*
  (plus *idle* / *GPU-active*). Front-and-center hero card on the dashboard, mirrored
  as a `Workload:` line in the menu bar. Precedence: memory > thermal > workload profile.
- **Per-chip memory-bandwidth ceiling table** + a **"% of ceiling" gauge**
  (M1–M4; Max bins disambiguated by P-core count; self-corrects up to the observed peak
  for chips outside the table).
- **GPU throttle detector** — flags the GPU clock held below its slowly-decaying rolling
  peak while thermal pressure has risen above nominal (banner + menu-bar flame).
- **Compact GPU menu-bar mode** — single line: `GPU% / GPU W / GPU GB/s / die °C`.
- **AI runtime detection** — recognizes `ollama`, `llama.cpp`, `LM Studio`, `MLX`, `Jan`,
  `GPT4All`, `vLLM` by process (bundle-first match) and surfaces them in an AI cockpit card.
- **Model memory budget** — two figures (fits-now / if-you-unload) + "largest model that
  fits" per quant, with a rate-based swap/compression risk signal.
- **Runtime API (opt-in)** — reads loaded model, authoritative GPU/CPU split (Ollama
  `size_vram/size`), and tokens/sec (llama.cpp `/metrics`) from `127.0.0.1`. Off by default.
  Design: [`ai-local-features-design.md`](ai-local-features-design.md).

## v1.4 roadmap — from "AI monitor" to "local-AI operations"

The metric local-LLM users live by is **tokens/sec**, and it's the biggest remaining
gap (we only get it from llama.cpp today). Build there first, then layer per-machine
learning and RAM hygiene on top — that's what turns a gauge into an operations tool.
Each tier is roughly ordered smallest-valuable-first; the validation here came from real
M1 Max runs (MoE 26B, dense 12B/31B) earlier in development.

### Tier 1 — speed (build first)

- **tokens/sec for every runtime, with history.** Ollama is feasible *now*: read the
  embedded `llama-server` `/metrics` (`predicted_tokens_seconds`) at the **dynamic argv
  port we already parse** (`AIRuntimeSample.ollamaEmbeddedPort`). llama.cpp is already
  done; LM Studio exposes no passive rate (note it in-UI). Add a tok/s sparkline.
- **tokens-per-watt (efficiency).** tok/s ÷ package power — Apple Silicon's signature
  metric, near-absent in other tools. Combines the runtime API with the chip power we
  already sample.

### Tier 2 — make it a tool, not just a gauge

- **Per-model performance log.** Record tok/s, peak temp, and power per model+quant over
  time → "what's fast on *my* Mac" (e.g. gemma-12b Q4 ≈ 38 tok/s, qwen-32b Q4 ≈ 12 tok/s).
  Builds directly on Tier 1.
- **Idle-model reclaim nudge.** A model loaded but unused for N minutes while holding
  X GB → suggest unloading. Sudoless — we already detect the loaded model (③) and activity.

### Tier 3 — nice to have

- **Model recommender** — beyond "largest that fits": concrete model/quant suggestions for
  the detected chip + free memory.
- **Context / KV-cache cost** — show how much memory the KV cache adds at 8k / 32k / 128k
  context; warn when a long context eats the budget.
- **AI menu-bar mode** — one line: current model · tok/s · GPU · headroom.
- **"AI app" pin (Settings)** — a user-pinned process name to surface in-app MLX/CoreML
  apps (e.g. WhisPlay via MLX-Swift) that have **no runtime process**. This is the only
  way around the in-app-inference blind spot (see below).
- **Engine attribution** (GPU/Metal vs ANE hint) · **Homebrew cask**.

## Out of scope (sudoless limits)

- **Per-process GPU / ANE attribution** — not reliably available without elevated access.
- **Auto-detecting in-app MLX/CoreML inference** — an app embedding MLX-Swift/CoreML has no
  separate runtime process, so it can't be attributed automatically. Surfaced only via the
  manual "AI app" pin (Tier 3). The tool stays honest meanwhile ("GPU active — type unknown").
- **tokens/sec from chip telemetry alone** — obtained instead from the runtimes' own HTTP
  APIs / metrics (opt-in), never fabricated from SoC counters.

## Compatibility notes / lessons learned

### macOS 27 — launch crash via `Bundle.module` (fixed in v1.0.2)

- **Symptom:** v1.0.0/v1.0.1 crashed immediately on launch under macOS 27
  (`EXC_BREAKPOINT` / `_assertionFailure` in `static NSBundle.module`). Reported in
  issue #1 (Mac14,9, macOS 27.0 beta). Did not reproduce on macOS 26 and earlier.
- **Root cause:** SwiftPM's generated `Bundle.module` accessor calls `fatalError`
  when it cannot locate its resource bundle. We hand-assemble the `.app` (SPM emits
  no bundle), and the copied resource bundle `ktop_WhisPlayInfo.bundle` is a *flat*
  folder with no `Info.plist`. macOS 27 tightened bundle validation and no longer
  treats such a folder as a valid bundle, so every `Bundle.module` candidate path
  returned nil → `fatalError`. Older macOS accepted the flat folder, hiding the bug.
- **Fix (v1.0.2):** the app icon is now resolved via `Bundle.main` (packaged
  `Contents/Resources/AppIcon.icns`) with a manual SwiftPM-bundle fallback for dev
  runs — every `Bundle.module` reference was removed, so the `fatalError` path is
  gone regardless of bundle validity.
- **Forward action (for the Packaging item above):**
  - Never depend on `Bundle.module` in a hand-assembled `.app`; load resources from
    `Bundle.main` or by explicit path.
  - If a SwiftPM resource bundle must be shipped, give it a valid `Info.plist` so it
    is a real bundle on current macOS.
  - Smoke-test releases against the **latest macOS beta** before publishing — this
    class of bug only surfaces on the newest OS.
