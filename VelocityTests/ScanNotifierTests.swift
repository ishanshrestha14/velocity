import Testing
@testable import Velocity

struct ScanNotifierTests {
    @Test func describesImportedCommitsOnly() {
        let body = ScanNotifier.body(newCommitCount: 3, failedRepositoryCount: 0)
        #expect(body == "3 commits imported")
    }

    @Test func singularCommitAndRepository() {
        let body = ScanNotifier.body(newCommitCount: 1, failedRepositoryCount: 1)
        #expect(body == "1 commit imported · 1 repository failed to scan")
    }

    @Test func describesFailuresOnly() {
        let body = ScanNotifier.body(newCommitCount: 0, failedRepositoryCount: 2)
        #expect(body == "2 repositories failed to scan")
    }

    @Test func combinesBoth() {
        let body = ScanNotifier.body(newCommitCount: 5, failedRepositoryCount: 2)
        #expect(body == "5 commits imported · 2 repositories failed to scan")
    }
}
