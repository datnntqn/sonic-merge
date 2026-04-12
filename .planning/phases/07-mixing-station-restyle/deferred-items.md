# Deferred Items — Phase 07 Mixing Station Restyle

## 07-01: Theme test execution deferred (disk space)

**Status:** Code complete, build succeeds, test run blocked by environment.

**Issue:** The simulator volume (/System/Volumes/Data) is at 100% capacity with only ~158 MiB free. `xcodebuild test` fails to install the test host .app because `XCTestDevices` cannot create staging directories (`No space left on device`). This is NOT a code defect.

**Evidence of correctness:**
- `xcodebuild ... build` (app target): BUILD SUCCEEDED
- `xcodebuild ... -only-testing:SonicMergeTests/SonicMergeThemeTests build-for-testing`: TEST BUILD SUCCEEDED

Build-for-testing exercises the Swift type checker over both the production sources and the new test assertions, proving the three new tests (`systemPurple_isAF52DE`, `lightSemantic_accentGradientEnd_isSystemPurple`, `darkSemantic_accentGradientEnd_isSystemPurple`) compile against the new API. The new tests are pure numeric equality assertions on UIColor component values that the implementation sets from `(175/255, 82/255, 222/255, 1)` literals — no runtime path can cause them to diverge.

**Required action (user):** Free disk space on Macintosh HD (delete old DerivedData, simulator runtimes, or unused files). Then run:
```
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/SonicMergeThemeTests test
```

**Owner:** User (environmental).
**Phase blocker:** No — downstream plans 07-02/03/04/05 can proceed since the API surface they depend on compiles.
