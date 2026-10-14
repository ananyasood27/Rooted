import Foundation
import UserNotifications

/// Local notifications — scheduled on the phone itself, no server involved.
/// Two kinds: a nudge every evening, and one alert when the first plant is due for care.
enum Reminders {
    private static let dailyID = "ecogarden.daily"
    private static let thirstyID = "ecogarden.thirsty"

    /// Shows the system "Allow notifications?" prompt the first time; afterwards it just
    /// reports what the user chose.
    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Replaces whatever was scheduled before, so call it again whenever plants are tended.
    static func schedule(for placedItems: [PlacedItem]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID, thirstyID])

        let daily = UNMutableNotificationContent()
        daily.title = "Your garden is waiting"
        daily.body = "Finish today's eco tasks to keep your streak growing."
        daily.sound = .default
        var sixPM = DateComponents()
        sixPM.hour = 18
        center.add(UNNotificationRequest(
            identifier: dailyID,
            content: daily,
            trigger: UNCalendarNotificationTrigger(dateMatching: sixPM, repeats: true)
        ))

        // A plant counts as needing care once its health drops under 40%,
        // which is 60% of the way through the decay window.
        guard let longestWithoutCare = placedItems.map(\.lastWateredDate).min() else { return }
        let needsCareAt = longestWithoutCare.addingTimeInterval(PlacedItem.decayWindowHours * 3600 * 0.6)
        let secondsFromNow = needsCareAt.timeIntervalSinceNow
        guard secondsFromNow > 60 else { return }

        let thirsty = UNMutableNotificationContent()
        thirsty.title = "Your garden needs you"
        thirsty.body = "Something in your garden is ready for some care."
        thirsty.sound = .default
        center.add(UNNotificationRequest(
            identifier: thirstyID,
            content: thirsty,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow, repeats: false)
        ))
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyID, thirstyID])
    }
}
