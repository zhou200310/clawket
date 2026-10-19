# Clawket iOS 15.4 移植说明

## 结论

- iOS 部署目标已从 **16.4 → 15.4**（`Package.swift` + `project.pbxproj` 共 7 处）。
- iOS 16+ 专属 API 全部改为 **兼容封装 + `#available` 分支**：新系统仍走原生 API，iOS 15 走降级实现，功能不删除。
- 新增 GitHub Actions 工作流，产出 **未签名 IPA**（`Clawket-unsigned.ipa`）。
- ⚠️ **本机没有 macOS/Swift 工具链，全部改动未经编译器验证**，只做了逐文件人工核对 + 括号完整性 + 全量 grep 扫尾。首次在 macOS 上跑 CI 时可能还要修少量编译错误。

## 一、版本号改动

| 文件 | 改动 |
|---|---|
| `packages/apple/Package.swift` | `.iOS("16.4")` → `.iOS("15.4")`（macOS 仍是 `.v13`） |
| `apps/ios/Clawket.xcodeproj/project.pbxproj` | 6 处 `IPHONEOS_DEPLOYMENT_TARGET = 16.4` → `15.4`（工程级 2、App 2、测试 Target 2） |
| `.github/workflows/native-apple.yml` | SwiftUI/UIKit typecheck 目标从 `arm64-apple-ios16.4-simulator` 改为 `ios15.4-simulator`，这样漏掉可用性检查会真的报错 |

> 测试 Target 也留在 15.4（其代码已一并兼容，`NativeReadingLayoutTests` 里用到 `NavigationStack` 的地方加了 `@available(iOS 16.0, *)`）。

## 二、新增兼容层

### `packages/apple/Sources/ClawketUI/Compat.swift`（新文件）

| 封装 | iOS 16+ | iOS 15.4 降级 |
|---|---|---|
| `CompatNavigationStack` | `NavigationStack` | `NavigationView` + `.navigationViewStyle(.stack)` |
| `CompatNavigationLink(value:label:destination:)` | `NavigationLink(value:)` | `NavigationLink(destination:)`（值路由没有 `navigationDestination`，所以必须带真实目的地） |
| `CompatLabeledContent` | `LabeledContent` | `HStack`：左标题、右值（secondary 色） |
| `CompatViewThatFits(in:primary:fallback:)` | `ViewThatFits` | 直接渲染 `primary` |
| `.compatPresentationDetents(_:)` / `.compatPresentationDragIndicator(_:)` | 原生 | 无操作（sheet 全高） |
| `.compatScrollContentBackground(_:)` | 原生 | 无操作 |
| `.compatScrollDismissesKeyboard(_:)` | 原生 | 无操作 |
| `.compatScrollBounceBehavior(_:)`（iOS 16.4+） | 原生 | 无操作 |
| `.compatNavigationDestination(for:destination:)` | 原生 | 无操作 |

### `packages/apple/Sources/ClawketTransport/CompatDuration.swift`（新文件）

`Duration` / `ContinuousClock` 属于 **SwiftStdlib 5.7 = iOS 16 / macOS 13**，是原审计漏掉的一大批编译阻断点。

- 新增 `CompatDuration`（`Int64` 纳秒，`Sendable/Hashable/Comparable/AdditiveArithmetic`），提供 `.zero/.seconds/.milliseconds/.microseconds`、`+ - += -= 前缀- *`、`components`（seconds + attoseconds，与原 `Duration.components` 同形）、`description`、`duration(to:)`、`advanced(by:)`。
- 全仓 `Duration` → `CompatDuration`（21 个文件 / 112 处引用），并给跨模块使用处补 `import ClawketTransport`。
- `TransportClock` 协议签名随之改为 `CompatDuration`；`MonotonicTransportClock` 改用 `DispatchTime.now().uptimeNanoseconds` + `Task.sleep(nanoseconds:)`。

### 其它 Swift 5.7+ API

- `Task.sleep(for:)` / `Task.sleep(until:clock:)`（源码 + 测试共 28 处）→ `Task.sleep(nanoseconds:)` 或剩余时间换算。
- `ContinuousClock.now / .Instant / .advanced(by:)`（App 里 4 个文件、测试里 12 个文件）→ `Date()` / `timeIntervalSince`。
- `View.bold()`（iOS 16）→ `.fontWeight(.bold)`（`PendingMessageEditor.swift`）。
- `UITableView.selfSizingInvalidation` / `UIHostingConfiguration`（iOS 16）见下。

### `NativeTranscript.swift`（聊天记录列表）

- iOS 16+：`selfSizingInvalidation = .enabledIncludingConstraints` + `UIHostingConfiguration`（行为不变）。
- iOS 15：新增 `HostingMessageCell`（`UIHostingController` 承载行视图，约束贴 `contentView.layoutMarginsGuide`，重写 `systemLayoutSizeFitting` 返回 `sizeThatFits` 高度），保持 `automaticDimension` 估算行高。

## 三、未签名 IPA 工作流

`.github/workflows/build-unsigned-ipa.yml`

- 触发：`workflow_dispatch`，或 push 到 `ios15` 分支（只看 `packages/apple/**`、`apps/ios/**`、该工作流自身）。
- runner：`macos-15`，先 `xcodebuild -resolvePackageDependencies`（`-clonedSourcePackagesDirPath $RUNNER_TEMP/spm` 防止重复解析超时）。
- 构建：`xcodebuild -project apps/ios/Clawket.xcodeproj -scheme Clawket -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -jobs 2 build`
- 打包：`Payload/Clawket.app` → `ditto -c -k --sequesterRsrc --keepParent` → `Clawket-unsigned.ipa`，并打印 `CFBundleIdentifier` / `MinimumOSVersion`。
- 产物：artifact **`Clawket-unsigned-ipa`**，保留 14 天。
- 用法：推 `ios15` 分支 → Actions 里下载 artifact → TrollStore / 自签工具安装。`workflow_dispatch` 按钮需该文件先存在于默认分支。

## 四、风险点（请重点看）

1. **完全没编译过**：本机无 Swift/macOS。括号配平与符号扫描都过了，但类型推断、Swift 6 隔离、`UIHostingController.sizeThatFits(in:)` 这类细节只能等 CI 验证。
2. **iOS 15 的降级是有损的**：
   - sheet 的 `presentationDetents` 被忽略 → 一律全高；
   - `ViewThatFits` 恒取横向主布局，窄屏可能挤（原逻辑会自动换 `VStack`）；
   - `NavigationSplitView` 退化成单列 `NavigationView`（iPad 上没有左右分栏）；
   - 聊天列表的 `automaticDimension` 在 iOS 15 上没有 `selfSizingInvalidation`，**流式输出时行高可能不实时刷新**（滚动/重载后正常），这是最大的一处体验风险。
3. **`CompatDuration` 是公开 API 变更**：`ClawketTransport` 的公共签名（`RPCConnection`、`RelayHeartbeatConfiguration`、`RuntimeArtifactHTTPClient` 等）从 `Duration` 变成 `CompatDuration`。仓库内调用点已全部跟随；如果外部有别的消费方，需要同步。
4. **`Date` ≠ 单调时钟**：App 侧把 `ContinuousClock` 换成 `Date()` 用于去抖/统计。系统时间被手动改动时，`NativeTaskJournal` 的耗时统计、历史导出的 90s 截止会有偏差（传输层的 `MonotonicTransportClock` 仍是单调的，不受影响）。
5. **包内测试**（`packages/apple/Tests`）用到 `NSLock.withLock`（iOS 16 / macOS 13）。它们在 macOS 13 上 `swift test` 没问题；如果你的 CI 改成用 iOS 15 模拟器跑**包内**测试，需要再补一个锁封装。App 自身的 `ClawketTests` 不含该 API。
6. **依赖解析**：工程里还有 `purchases-ios-spm`（RevenueCat）远程包，首次构建要联网拉取，GitHub runner 正常，离线环境会卡住。
7. 工作流里**没有**覆盖 `CODE_SIGN_ENTITLEMENTS`。如果 Release 配置挂了需要授权的 entitlements（如 associated domains、push），`CODE_SIGNING_ALLOWED=NO` 通常仍能过；万一报 entitlements 相关错误，再加 `CODE_SIGN_ENTITLEMENTS=""`。
