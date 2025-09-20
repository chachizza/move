import Foundation
import SwiftData

extension Date {
    func setting(hour: Int, minute: Int = 0, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
}

extension ModelContext {
    func deleteAll<T: PersistentModel>(of _: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let models = try fetch(descriptor)
        for model in models {
            delete(model)
        }
    }
}
