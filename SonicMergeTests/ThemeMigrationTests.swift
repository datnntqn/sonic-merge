import Testing
import Foundation
@testable import SonicMerge

struct ThemeMigrationTests {

    @Test func migrateLegacySystemValueReturnsLight() {
        let result = SonicMergeApp.migrateLegacyTheme("system")
        #expect(result == ThemePreference.light.rawValue)
    }

    @Test func migrateRecognizedLightValueReturnsNil() {
        let result = SonicMergeApp.migrateLegacyTheme(ThemePreference.light.rawValue)
        #expect(result == nil)
    }

    @Test func migrateRecognizedDarkValueReturnsNil() {
        let result = SonicMergeApp.migrateLegacyTheme(ThemePreference.dark.rawValue)
        #expect(result == nil)
    }

    @Test func migrateUnknownValueReturnsLight() {
        let result = SonicMergeApp.migrateLegacyTheme("garbage")
        #expect(result == ThemePreference.light.rawValue)
    }

    @Test func nextAfterLightIsDark() {
        #expect(ThemePreference.next(after: .light) == .dark)
    }

    @Test func nextAfterDarkIsLight() {
        #expect(ThemePreference.next(after: .dark) == .light)
    }
}
