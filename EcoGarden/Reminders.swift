import Foundation
import UserNotifications

enum Reminders {
    private static let dailyID = "ecogarden.daily"
    private static let thirstyID = "ecogarden.thirsty"

    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // Clears and reschedules, so call it whenever plants are tended.
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

        // Needs care below 40% health = 60% through the decay window.
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
