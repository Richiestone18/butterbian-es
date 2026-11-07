import QtQuick

// Caps-lock warning: hidden until caps is on, then a red pill.
BarModule {
    visible: Sys.capsOn
    icon: "󰘲"
    label: "Mayús"
    alert: true
    interactive: false
}
