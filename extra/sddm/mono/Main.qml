// Минималистичная монохромная тема SDDM (Qt6).
// Enter — войти, F2 / клик по строке сессии — сменить сессию.
import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0b0b0b"

    readonly property color fg:     "#c8c8c8"
    readonly property color bright: "#ededed"
    readonly property color muted:  "#6b6b6b"
    readonly property color dim:    "#3a3a3a"
    readonly property color field:  "#121212"
    readonly property color danger: "#b36b6b"
    readonly property string fontName: config.font || "monospace"

    // Язык по системной локали: русский для ru_*, иначе английский
    readonly property bool ru: Qt.locale().name.indexOf("ru") === 0
    function tr(en, ruText) { return root.ru ? ruText : en }

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    // Выбранная учётная запись (по умолчанию — последний вошедший пользователь)
    property string selectedUser: userModel.lastUser

    function doLogin() {
        error.text = ""
        var name = userNames.count > 0 ? root.selectedUser : manualUser.text
        sddm.login(name, password.text, root.sessionIndex)
    }

    // Стрелки вверх/вниз в поле пароля — соседняя учётная запись
    function stepUser(delta) {
        var n = userNames.count
        if (n < 2) return
        var cur = 0
        for (var i = 0; i < n; i++)
            if (userNames.itemAt(i).uname === root.selectedUser) cur = i
        root.selectedUser = userNames.itemAt((cur + delta + n) % n).uname
        error.text = ""
        password.text = ""
    }

    function sessionName(i, count) {
        var it = count > 0 ? sessionNames.itemAt(i) : null
        return it ? it.sname : ""
    }

    // Имена сессий и пользователей из моделей SDDM
    Repeater {
        id: sessionNames
        model: sessionModel
        delegate: Item { property string sname: model.name }
    }

    Repeater {
        id: userNames
        model: userModel
        delegate: Item { property string uname: model.name }
        onItemAdded: function(index, item) {
            if (root.selectedUser === "" && index === 0) root.selectedUser = item.uname
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            error.text = root.tr("login failed", "неверный пароль")
            password.forceActiveFocus()
        }
    }

    Image {
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }

    // ---------------------------------------------------------------- центр
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 14

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.bright
            font.family: root.fontName
            font.pixelSize: 84
            text: Qt.formatTime(new Date(), "HH:mm")
        }

        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.muted
            font.family: root.fontName
            font.pixelSize: 15
            text: Qt.locale().toString(new Date(), "dddd, d MMMM")
        }

        Item { width: 1; height: 26 }

        // учётные записи: клик выбирает пользователя
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: userModel
                delegate: Rectangle {
                    readonly property bool selected: model.name === root.selectedUser
                    width: 300; height: 44
                    color: selected ? "#1c1c1c" : (userArea.containsMouse ? "#151515" : root.field)
                    border.width: 1
                    border.color: selected ? root.muted : root.dim

                    Rectangle {          // метка выбранной записи
                        width: 3; height: parent.height - 2
                        x: 1; y: 1
                        color: root.bright
                        visible: parent.selected
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: parent.parent.selected ? root.bright : root.fg
                            font.family: root.fontName
                            font.pixelSize: 14
                            text: model.realName !== "" ? model.realName : model.name
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: model.realName !== "" && model.realName !== model.name
                            color: root.muted
                            font.family: root.fontName
                            font.pixelSize: 11
                            text: model.name
                        }
                    }

                    MouseArea {
                        id: userArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.selectedUser !== model.name) {
                                root.selectedUser = model.name
                                password.text = ""
                                error.text = ""
                            }
                            password.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // запасной вариант: SDDM не отдал список пользователей — вводим имя вручную
        Rectangle {
            visible: userNames.count === 0
            width: 300; height: 38
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.field
            border.width: 1
            border.color: manualUser.activeFocus ? root.muted : root.dim

            Text {
                anchors.centerIn: parent
                visible: manualUser.text === ""
                color: root.dim
                font.family: root.fontName
                font.pixelSize: 13
                text: root.tr("user", "пользователь")
            }

            TextInput {
                id: manualUser
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: root.fg
                font.family: root.fontName
                font.pixelSize: 14
                clip: true
                KeyNavigation.tab: password
                Keys.onReturnPressed: password.forceActiveFocus()
                Keys.onEnterPressed: password.forceActiveFocus()
            }
        }

        Item { width: 1; height: 4 }

        // пароль
        Rectangle {
            width: 300; height: 38
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.field
            border.width: 1
            border.color: error.text !== "" ? root.danger : (password.activeFocus ? root.muted : root.dim)

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: root.fg
                font.family: root.fontName
                font.pixelSize: 14
                echoMode: TextInput.Password
                passwordCharacter: "•"
                clip: true
                focus: true
                KeyNavigation.backtab: manualUser
                Keys.onUpPressed: root.stepUser(-1)
                Keys.onDownPressed: root.stepUser(1)
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
            }

            Text {
                anchors.centerIn: parent
                visible: password.text === "" && !password.activeFocus
                color: root.dim
                font.family: root.fontName
                font.pixelSize: 13
                text: root.tr("password", "пароль")
            }
        }

        Text {
            id: error
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.danger
            font.family: root.fontName
            font.pixelSize: 12
            text: ""
            height: 16
        }
    }

    // ------------------------------------------------------- низ: сессия
    Text {
        id: session
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        color: sessionArea.containsMouse ? root.fg : root.muted
        font.family: root.fontName
        font.pixelSize: 13
        text: root.tr("session", "сеанс") + "  " + root.sessionName(root.sessionIndex, sessionNames.count).toLowerCase()

        MouseArea {
            id: sessionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount())
        }
    }

    // ------------------------------------------------ низ: питание
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 24

        Repeater {
            model: [
                { label: root.tr("suspend", "сон"),  can: sddm.canSuspend,  act: function() { sddm.suspend() } },
                { label: root.tr("reboot", "перезагрузка"),  can: sddm.canReboot,   act: function() { sddm.reboot() } },
                { label: root.tr("shutdown", "выключение"), can: sddm.canPowerOff, act: function() { sddm.powerOff() } }
            ]
            delegate: Text {
                visible: modelData.can
                color: area.containsMouse ? root.bright : root.muted
                font.family: root.fontName
                font.pixelSize: 13
                text: modelData.label
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.act()
                }
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            clock.text = Qt.formatTime(new Date(), "HH:mm")
            date.text = Qt.locale().toString(new Date(), "dddd, d MMMM")
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F2) {
            root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount())
            event.accepted = true
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
