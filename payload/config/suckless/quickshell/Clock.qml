import QtQuick
import Quickshell

// Date + 12-hour time (the slstatus formats), with a calendar on click.
BarModule {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Qt.formatDateTime ignores the locale (gives "Fri 23 Oct 6:45 pm"
    // even under es_MX); the Date.toLocale* calls do localize
    label: clock.date.toLocaleString(Qt.locale(), "ddd d MMM") + "  "
         + clock.date.toLocaleTimeString(Qt.locale(), "h:mm a")

    onClicked: calendar.visible = !calendar.visible

    CalendarPopup {
        id: calendar
        anchorItem: root
    }
}
