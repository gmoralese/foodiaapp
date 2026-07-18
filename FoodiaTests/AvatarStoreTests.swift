import Testing
import UIKit

@testable import Foodia

@MainActor
@Suite("AvatarStore — round-trip en disco")
struct AvatarStoreTests {
    @Test("guarda y vuelve a cargar el avatar")
    func saveThenLoad() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let data = image.jpegData(compressionQuality: 0.8)!

        AvatarStore.save(data)
        #expect(AvatarStore.load() != nil)

        AvatarStore.clear()
        #expect(AvatarStore.load() == nil)
    }
}
