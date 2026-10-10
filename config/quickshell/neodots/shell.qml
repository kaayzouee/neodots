import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        TopBar {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Dock {
            property var modelData
            screen: modelData
        }
    }
}
