# Layout Redesign + Fix Xóa Clip Khi Chuyển Màn — Kế Hoạch Triển Khai

> **For agentic workers:** Dùng `superpowers:subagent-driven-development` hoặc `superpowers:executing-plans` để làm từng task. Checkbox `- [ ]` để theo dõi.

**Goal:** (1) Sửa hành vi **xóa clip/ghi âm** khi người dùng **chuyển màn hình** (ví dụ vào/rời Cleaning Lab, hoặc thao tác xóa không phản ánh đúng dữ liệu). (2) Thiết kế lại **Mixing Station** theo hướng hiện đại hơn, có thể tham chiếu visual “merge conveyor” (track + toán tử + kết quả) như app **Merge Audio Files** trên App Store, trong khi **giữ định vị Local-first + On-device AI** của SonicMerge.

**Architecture:**
- Tách **lifecycle tệp tạm** (Cleaning Lab merge WAV) khỏi **SwiftData clips** — dọn tệp và reset state khi `navigationDestination` đóng.
- Tách **lớp giao diện** (`MergeTimelineView` / token mới) khỏi logic `MixingStationViewModel` hiện có; ViewModel chỉ thêm API nếu cần (ví dụ `removeClip(id:)` thay vì chỉ `IndexSet`).
- Theme: thêm **`Appearance` (Light / Dark)** hoặc **một dark theme** tùy chọn, map sang `SonicMergeTheme` (semantic roles: `surfaceElevated`, `accentMerge`, `waveformPrimary`).

**Tech Stack:** SwiftUI, SwiftData, Observation, SF Symbols, (tuỳ chọn) `ScrollView` + custom layout thay cho `List` nếu cần full control gesture.

**Tham chiếu UX (không copy pixel):** App Store — “Merge Audio Files”: dark shell, accent nổi, thanh waveform ngang, ký hiệu `+` / `=` giữa các slot, CTA “MERGE” rõ ràng. SonicMerge thay “MERGE” bằng luồng **Export / Denoise** hiện có nhưng **cấu trúc bố cục** có thể tương tự.

---

## Phần A — Triage lỗi “switch qua vẫn chưa xóa được đoạn ghi âm”

### A.1 Giả thuyết đã biết (ưu tiên kiểm chứng)

| ID | Giả thuyết | Dấu hiệu | Hướng xử lý |
|----|-------------|----------|-------------|
| H1 | Tệp merge tạm `SonicMerge-CleaningLab-*.wav` **không bị xóa** khi pop khỏi Cleaning Lab; người dùng thấy file/âm thanh “cũ” trong app Khác / cache nội bộ. | File vẫn trong `temporaryDirectory` sau khi back. | `onChange(of: showCleaningLab)` hoặc `onDisappear` ở destination: `removeItem` + `mergedFileURLForCleaning = nil`. |
| H2 | `swipeActions` + `editMode == .active` xung đột gesture trên một số phiên bản iOS: thao tác xóa **không gọi** `deleteClip`. | Swipe không ra nút / không xóa. | Thêm **nút Delete** trong `contextMenu` hoặc trên card; hoặc tắt “always-on” edit mode, dùng `EditButton()` / trạng thái reorder riêng. |
| H3 | UI dùng `Section` + `ForEach`: index từ swipe **lệch** so với `viewModel.clips` (hiếm, đã có `MixingStationClipIndexResolver`). | Clip sai bị xóa / không xóa. | Chuẩn hoá `viewModel.deleteClip(id: UUID)` một nguồn sự thật; unit test. |
| H4 | Người dùng xóa trong app nhưng vẫn thấy file trong **Files** (bản export `SonicMerge-Export-…`), không phải clip trong App Group. | Tên file export, không phải UUID clip. | UX: giải thích trong UI hoặc mục “Exported files”; không nhầm với xóa clip. |

### A.2 Nhiệm vụ sửa lỗi (làm trước redesign)

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`
- Modify: `SonicMerge/Features/MixingStation/MixingStationViewModel.swift`
- Create: `SonicMergeTests/MixingStationDeleteByIdTests.swift` (hoặc mở rộng `MixingStationViewModelTests.swift`)

- [ ] **Task A2.1 — Cleanup temp Cleaning Lab khi rời màn**

Trong `MixingStationView`, thêm:

```swift
.onChange(of: showCleaningLab) { _, isShowing in
    if !isShowing, let url = mergedFileURLForCleaning {
        try? FileManager.default.removeItem(at: url)
        mergedFileURLForCleaning = nil
    }
}
```

(Re-check Apple API: `onChange` signature theo iOS target của project.)

- [ ] **Task A2.2 — API xóa theo `UUID`**

Trong `MixingStationViewModel`:

```swift
func deleteClip(id: UUID) {
    guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
    deleteClip(atOffsets: IndexSet(integer: index))
}
```

Cập nhật swipe / menu gọi `deleteClip(id: clip.id)` thay vì resolver (giảm rủi ro lệch index).

- [ ] **Task A2.3 — Unit test**

```swift
@Test func deleteClipById_removesClip() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
    let context = ModelContext(container)
    let vm = MixingStationViewModel(modelContext: context)
    let clip = AudioClip(displayName: "X", fileURLRelativePath: "x.m4a", duration: 1)
    clip.sortOrder = 0
    context.insert(clip)
    try context.save()
    await vm.fetchAll()
    let id = clip.id
    vm.deleteClip(id: id)
    #expect(vm.clips.isEmpty)
}
```

- [ ] **Task A2.4 — Affordance xóa rõ ràng (nếu H2 xác nhận)**

Modify: `SonicMerge/Features/MixingStation/ClipCardView.swift` — thêm `Menu` hoặc nút `ellipsis` với “Delete Clip” gọi callback `onDelete`.

- [ ] **Task A2.5 — Commit**

```bash
git add SonicMerge/Features/MixingStation/MixingStationView.swift \
  SonicMerge/Features/MixingStation/MixingStationViewModel.swift \
  SonicMerge/Features/MixingStation/ClipCardView.swift \
  SonicMergeTests/MixingStationViewModelTests.swift
git commit -m "fix(mixing): delete clip by id, cleanup Cleaning Lab temp on dismiss"
```

---

## Phần B — Redesign layout (Mixing Station)

### B.1 Nguyên tắc thiết kế (DIFF so với tham chiếu App Store)

- Giữ **Private by design** và **On-device AI** — đưa vào **1 vạch trạng thái** (pill) gọn, không chiếm nửa màn hình.
- Tham chiếu “Merge Audio Files”: **trục dọc** = các **slot** waveform, xen kẽ **toán tử** `+` và `=` (SVG/SF Symbols), cuối là **khối kết quả** (preview merged hoặc placeholder).
- **Dark theme** (tuỳ chọn): nền `#121212` hoặc gradient tím-than; accent có thể **xanh neon** hoặc **xanh hệ thống đậm** — tránh trùng bản quyền nhãn hiệu app khác; dùng palette riêng SonicMerge.
- **Typography:** `rounded` design + **uppercase nhỏ** cho nhãn section (“SEQUENCE”, “OUTPUT”) — học layout tham chiếu, không cần giống font.

### B.2 Cấu trúc file đề xuất

| Path | Responsibility |
|------|----------------|
| Create | `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` — `enum AppAppearance`, màu semantic dark/light |
| Create | `SonicMerge/Features/MixingStation/MergeTimelineView.swift` — layout conveyor (clips + operators + output slot) |
| Create | `SonicMerge/Features/MixingStation/MergeSlotRow.swift` — một “phanh” audio: waveform lớn hơn, play, drag handle |
| Create | `SonicMerge/Features/MixingStation/MergeOperatorLabel.swift` — view `+`, `=` |
| Modify | `SonicMerge/Features/MixingStation/MixingStationView.swift` — embed `MergeTimelineView`, giữ toolbar + sheets |
| Modify | `SonicMerge/DesignSystem/SonicMergeTheme.swift` — thêm tokens: `surfaceBase`, `surfaceSlot`, `accentAction`, `textSecondary` |

### B.3 Task breakdown

- [ ] **Task B3.1 — Theme dual-mode**

Implement `Color`/`UIColor` providers trong `SonicMergeTheme+Appearance.swift`; đọc `@AppStorage("appAppearance")` hoặc follow system `colorScheme`.

- [ ] **Task B3.2 — `MergeTimelineView` scaffold**

`ScrollView` + `LazyVStack`: với `clips.enumerated()` render `MergeSlotRow`; giữa hai slot chèn `TransitionStrip` (refactor từ `GapRowView` styling); giữa các cặp chèn `MergeOperatorLabel(kind: .plus)`; trước khối output chèn `MergeOperatorLabel(kind: .equals)`.

- [ ] **Task B3.3 — Output slot**

Vùng cuối: “Merged preview” — phase 1 chỉ hiển thị **tổng duration + nút Export**; phase 2 nối **AVPlayer** preview merged (optional, tránh scope quá lớn trong một PR).

- [ ] **Task B3.4 — Drag reorder ngoài `List`**

Dùng `.onDrag` / `dropDestination` (iOS API theo doc mới nhất của target) hoặc `List` chỉ cho reorder — **quyết định trong implement:** nếu custom ScrollView, implement `moveClip` qua gesture hoặc giữ `List` ẩn separators chỉ cho reorder.

- [ ] **Task B3.5 — Snapshot / Preview**

SwiftUI `#Preview("Dark conveyor")` với dummy clips.

- [ ] **Task B3.6 — Cleaning Lab alignment**

Đồng bộ dark tokens cho `CleaningLabView` khi `colorScheme == .dark` (cùng accent AI `#5856D6`).

- [ ] **Task B3.7 — Commit**

```bash
git commit -m "feat(ui): merge timeline conveyor layout and appearance tokens"
```

---

## Self-review

- **Báo cáo lỗi xóa:** Có track cụ thể (temp file + API `deleteClip(id:)` + affordance UI).
- **Redesign:** Có cấu trúc file, tách component, và giới hạn phase (preview merged = phase 2).
- **Không dùng placeholder:** Mọi task gắn file/path hoặc snippet cụ thể.

---

## Execution handoff

Plan lưu tại `docs/superpowers/plans/2026-04-06-layout-redesign-and-delete-fix.md`.

**Ưu tiên:** Làm **Phần A** trước (fix xóa + cleanup), sau đó **Phần B** (layout).

Bạn muốn thực thi **inline** hay **subagent từng task**?
