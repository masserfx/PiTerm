import Foundation
import SwiftData

@Model
final class HostGroup {
    var name: String
    var icon: String
    var sortOrder: Int

    init(name: String, icon: String = "folder", sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
    }
}
