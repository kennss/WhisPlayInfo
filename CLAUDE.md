# SiliconScope

Apple Silicon 전용 네이티브 macOS 시스템 모니터.
**btop의 GUI 디자인 감성 + NeoAsitop의 칩-레벨 지표**를 결합하고, **sudo 없이** 동작한다.

> 이 문서는 SiliconScope 코드베이스에서 작업하는 Claude를 위한 지침이다. 결정사항/규약은 여기서 확정한다.
> (구명 WhisPlayInfo → 2026-06-14 SiliconScope 로 리네임. 로컬 작업 디렉터리명은 `ktop` 으로 유지될 수 있음.)

---

## 1. 목표 (Goals)

- **E코어 / P코어 구분 표시** — btop·asitop에 없는 핵심 차별점
- GPU 사용률, **ANE**(전력 기반 추정), 팬 속도, 온도
- 전력(CPU / GPU / DRAM / 시스템) 실시간 차트 — 피크·이동평균
- btop 수준의 정보 밀도와 실시간 그래프 룩
- **sudo 불필요**, 가볍게 (모니터 앱이 자원을 잡아먹으면 안 됨)

## 2. 확정된 핵심 결정 (Decisions)

| 항목 | 결정 | 비고 |
|---|---|---|
| UI 스택 | **SwiftUI + Swift Charts** | Electron 배제(무거움) |
| 앱 형태 | **메뉴바 상주 + 전체창 대시보드 둘 다** | `MenuBarExtra` + `WindowGroup` |
| 플랫폼 | macOS (Apple Silicon 전용) | M1 이상 |
| "btop 기반"의 의미 | **디자인 언어만 계승**, 코드 포크 아님 | btop은 C++ TUI라 재사용 불가 |
| 데이터 레이어 | NeoAsitop(MIT) 로직을 **적응(adapt)** | 출처 표기 필수 |

## 3. 아키텍처 — 2개 레이어 분리가 핵심

```
┌──────────────────────────────────────────┐
│ UI 레이어 (SwiftUI)                        │
│   ├ 전체창 대시보드 (btop 룩)               │
│   └ 메뉴바 미니뷰 (MenuBarExtra)            │
├──────────────────────────────────────────┤
│ SiliconScopeCore (데이터 라이브러리, UI 비의존)      │  ← 두 UI가 공유
│   ├ IOReport 샘플러 (전력/residency)        │
│   ├ E/P 토폴로지 + 코어별 사용률            │
│   ├ SMC 팬/온도 리더                        │
│   └ HID 센서 (온도/전력)                    │
└──────────────────────────────────────────┘
```

**원칙**: SiliconScopeCore는 SwiftUI에 의존하지 않는다. 메뉴바·전체창·CLI가 모두 같은 SiliconScopeCore를 링크한다.

## 4. 데이터 소스 매핑 (전부 sudoless)

| 기능 | 소스 | API |
|---|---|---|
| E/P코어 토폴로지 | `sysctl hw.perflevel0/1` | sysctl |
| 코어별 사용률 | `host_processor_info` | mach |
| 클러스터 주파수/residency | IOReport `CPU Stats` | IOReport |
| GPU 사용률 | IOReport `GPU Stats` / IOAccelerator | IOReport / IOKit |
| ANE "사용률" | IOReport `Energy Model`(ANE **전력** 정규화) | IOReport |
| 전력(CPU/GPU/DRAM) | IOReport `Energy Model` | IOReport |
| 온도 | `IOHIDEventSystemClient` (appleSiliconSensors) | IOKit HID |
| 팬 속도 | SMC 키 (AppleSMC) | IOKit |

⚠️ **주의사항**
- **ANE 사용률은 진짜 점유율이 아니다** — 애플이 API 미공개. 전력값을 정규화한 근사치.
- **MacBook Air는 팬리스** — 팬 패널은 기기별 분기 필요(`fan_exist`).
- IOReport 샘플링은 두 시점(약 175ms 간격) 델타로 계산한다.

## 5. IOReport 링크 — ✅ 검증 완료 (2026-06-07)

macOS SDK에 IOReport **스텁(.tbd)이 없어** `-framework IOReport`는 실패한다.
**해결책 = 링커가 미정의 심볼을 런타임(dyld 공유 캐시)에서 찾게 한다:**

```
-Xlinker -undefined -Xlinker dynamic_lookup
```
→ SPM: `linkerSettings: [.unsafeFlags(["-Xlinker","-undefined","-Xlinker","dynamic_lookup"])]`

검증 결과 (M1 Max, sudo 없이): IOReport 채널 9,794개 + 실시간 델타 값 읽기 성공.
- 필요한 그룹 전부 존재: `Energy Model`(전력), `CPU Stats`/`GPU Stats`(residency), `PMP`, `SoC Stats`.
- **E/P코어 전력이 이미 분리 제공됨**: `EACC_CPU`(E-cluster) / `PACC0_CPU`,`PACC1_CPU`(P-cluster 0/1) / `CPU Energy`(합).

**함정 / 주의**
- swiftly 툴체인은 SDK를 못 찾으니 `xcrun` 사용 또는 `-sdk "$(xcrun --show-sdk-path)"` 명시.
- 비공개 API 사용 → **App Store 샌드박스 불가**. 자체 배포(직접 서명/공증)만 가능. (NeoAsitop/macmon/Stats 동일.)
- 검증 스크래치: `/tmp/iortest/` (bridge.h, main.swift). CIOReport 타깃 작성 시 참고.

## 6. 디렉토리 구조 (계획)

```
SiliconScope/               # 로컬 체크아웃 폴더명은 ktop 일 수 있음 (repo 명은 SiliconScope)
├── CLAUDE.md
├── Package.swift            # SPM: SiliconScopeCore 라이브러리 + CLI + 앱
├── Sources/
│   ├── CIOReport/           # IOReport extern 선언 (C 타깃)  ← 내부 심볼은 kKtop* 유지
│   ├── SiliconScopeCore/    # 데이터 레이어 (UI 비의존)
│   ├── sscope-cli/          # 지표 터미널 출력 (검증용)
│   └── SiliconScope/        # SwiftUI 앱 (메뉴바 + 전체창, @main)
├── scripts/package.sh       # Developer ID 서명 + 공증 + DMG
└── reference/NeoAsitop/     # MIT 참고 소스 (gitignore, 빌드 제외)
```

## 7. 빌드 & 실행

⚠️ **반드시 `xcrun` 사용.** 기본 `swift`(swiftly 6.1)는 macOS SDK(Swift 6.2 빌드)와
호환되지 않아 `Failed to build module 'Foundation'` 으로 실패한다. `xcrun`은 Xcode
툴체인(6.2)을 쓴다. (에디터/SourceKit 진단도 같은 이유로 뜨지만 빌드와 무관.)

```bash
xcrun swift build                  # 전체 빌드 (CIOReport + SiliconScopeCore + CLI + app)
xcrun swift run -q sscope-cli      # 지표 출력으로 데이터 레이어 검증 (sudo 불필요)
xcrun swift run SiliconScope       # SwiftUI GUI (대시보드 창 + 메뉴바). sudo 불필요
xcrun swift test                   # SiliconScopeCore 단위 테스트
```

GUI는 현재 SPM 실행 타깃(`Sources/SiliconScope`, SwiftUI `@main`)으로 개발용 실행한다.
(앱 표시명·실행파일·프로세스명 모두 **SiliconScope**. 범용 Apple Silicon/SoC 인스펙터.
 시초는 온디바이스 AI/미디어 워크로드의 ANE/Media 사용 추적이었음.)
배포용 `.app` 번들(LSUIElement, 서명/공증)은 추후 패키징 단계. 런타임에
`NSApplication.setActivationPolicy(.regular)`로 창+Dock 표시.

빌드/실행 후에는 **실제 M1 Max에서 값이 합리적인지** 눈으로 확인할 것(전력 W, 온도 °C, 코어 % 범위).
부하 검증 팁: `yes > /dev/null &` 로 CPU를 띄우면 P-CPU/SoC 전력 상승이 보인다.

## 8. 코딩 컨벤션

### 8.1 언어 규칙 (필수)
- **모든 주석은 영어로 작성한다** (헤더 주석 포함, 예외 없음).
- **앱 내 모든 텍스트(UI 라벨/메뉴/툴팁/단위 표기 등)는 영어로 통일한다.**
- (이 CLAUDE.md 같은 설계 문서만 한국어 허용 — 코드/앱 산출물은 전부 영어.)

### 8.2 파일 헤더 (필수)
**모든 소스 파일** 최상단에 영어 헤더 주석을 단다. 필드:
파일명 / 생성일 / 최종 수정일 / 개발자(Kennt Kim) / 파일 개요·목적 / 주요 변수 등 개발자 필요사항.

```swift
//
//  File:      <FileName>.swift
//  Created:   2026-06-07
//  Updated:   2026-06-07
//  Developer: Kennt Kim / Calida Lab
//  Overview:  <What this file does and why it exists>
//  Notes:     <Key variables/types, units, gotchas — anything a developer needs>
//
```

- 파일 수정 시 **Updated** 날짜를 갱신한다.
- NeoAsitop(MIT) 적응 파일은 Notes 또는 별도 줄에 출처 표기(§9).

### 8.3 일반
- Swift 6.1 기준. 동시성은 명시적으로(필요 시 `@MainActor`는 UI 레이어에서만).
- SiliconScopeCore에 **SwiftUI import 금지** (레이어 분리 유지).
- 비공개 API 호출부는 한 곳(`CIOReport`)에 격리하고 안전한 Swift 래퍼로 감싼다.
- 값 단위/스케일은 변수명이나 주석에 명시(W, mW, °C, RPM, MHz).

## 9. 라이선스 / 출처

- ktop 자체 라이선스: 미정 (추후 결정).
- **NeoAsitop (MIT)** 코드를 적응한 파일은 헤더에 원저작자/출처를 명시:
  `// Adapted from NeoAsitop (op06072/NeoAsitop), MIT License.`
- btop은 **디자인만 참고**, 코드 미사용.

## 10. 참고 자료 (로컬)

- **`docs/display-spec.md`** — 표시 정보 정의서 (무엇을 보여줄지 / AI 워크로드 뷰 / MVP 범위) ★
- **`docs/ioreport-channels.md`** — 실측 검증된 IOReport 채널 맵 (전력/사용률/대역폭/DVFS) ★
- `reference/NeoAsitop/socpowerbuddy_swift/socpwrbud.h` — IOReport extern 선언 (열쇠 파일)
- `reference/NeoAsitop/IOReportDump/main.swift` — 최소 IOReport 덤프 예제
- `reference/NeoAsitop/socpowerbuddy_swift/sampler.swift` — 샘플링 본체(880줄)
- `reference/NeoAsitop/socpowerbuddy_swift/static.swift` — E/P 토폴로지(751줄)
- `reference/NeoAsitop/SensorUtil/smc.swift` — SMC 팬/온도(477줄)

## 11. 작업자(사용자) 컨텍스트

- 사용자는 **아키텍처/비전 담당**. 코드는 Claude가 단계별로 구현하고, 사용자가 방향을 검토.
- 응답·문서는 한국어(기술 용어는 영어 병기).
