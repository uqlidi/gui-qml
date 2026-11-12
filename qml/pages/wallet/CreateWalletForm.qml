// Copyright (c) 2026 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.bitcoincore.qt 1.0

import "../../controls"
import "../../components"

OnboardingView {
    id: root
    objectName: "createWalletFormPage"
    showNavigationBar: false
    usesSharedNavigation: true
    property bool watchOnly: false
    property bool modalView: false
    property bool creating: false
    property string nameError: ""
    // Without the chosen type, so the type options stay put while choosing.
    readonly property var keyInfo: watchOnly && loadedChildView
        ? walletController.describeViewOnlyImport(loadedChildView.importText) : ({ "status": "empty" })
    readonly property bool needsAddressType: keyInfo.status === "valid" && keyInfo.needsAddressType === true
    readonly property var importInfo: needsAddressType && loadedChildView.addressTypeChoice.length > 0
        ? walletController.describeViewOnlyImport(loadedChildView.importText, loadedChildView.addressTypeChoice) : keyInfo
    readonly property bool needsBirthDate: importInfo.status === "valid" && importInfo.needsBirthDate === true
    readonly property bool importReady: importInfo.status === "valid"
        && (!needsAddressType || loadedChildView.addressTypeChoice.length > 0)
        && (!needsBirthDate || loadedChildView.birthChoice.length > 0)
    readonly property bool passwordsMatch: loadedChildView
        && loadedChildView.passwordText.length > 0
        && loadedChildView.passwordText === loadedChildView.confirmText
    readonly property bool canCreate: loadedChildView && walletController.initialized && !creating
        && !walletController.walletLoadInProgress && loadedChildView.walletName.trim().length > 0
        && (watchOnly ? importReady : loadedChildView.encryptWallet
            ? passwordsMatch && loadedChildView.passwordLossAcknowledged
            : loadedChildView.unencryptedWalletAcknowledged)

    signal cancel()
    // birthTime is in seconds, or -1 when the input has its own dates.
    signal createRequested(string name, string importText, string passphrase, real birthTime, string addressType)

    function birthTime() {
        if (!needsBirthDate) return -1
        const now = Math.floor(Date.now() / 1000)
        const day = 24 * 60 * 60
        switch (loadedChildView.birthChoice) {
        case "month": return now - 31 * day
        case "year": return now - 366 * day
        default: return 0
        }
    }

    function importSummary() {
        if (importInfo.status !== "valid") return qsTr("Only public information is imported. Private keys stay with your signer.")
        const types = importInfo.addressTypes.join(", ")
        if (importInfo.kind === "extendedKey" && importInfo.addressTypes.length === 0) {
            return qsTr("Extended key. Choose its address type below.")
        }
        if (importInfo.kind === "extendedKey") {
            //: %1 is an address type, such as "Bech32 (SegWit)".
            return qsTr("Extended key. Imported as %1 receive and change addresses.").arg(types)
        }
        let summary = importInfo.descriptorCount === 1
            //: %1 is an address type, such as "Bech32 (SegWit)".
            ? qsTr("1 descriptor: %1.").arg(types)
            //: %1 is a number of descriptors, %2 lists address types, such as "Bech32 (SegWit), Bech32m (Taproot)".
            : qsTr("%1 descriptors: %2.").arg(importInfo.descriptorCount).arg(types)
        if (importInfo.createdTime >= 0) {
            //: %1 is the date the oldest pasted descriptor was created.
            summary += " " + qsTr("Created %1.").arg(new Date(importInfo.createdTime * 1000).toLocaleDateString(Qt.locale(), "d MMM yyyy"))
        }
        return summary
    }

    function submit() {
        if (!canCreate) return
        const availabilityError = walletController.walletNameAvailabilityError(loadedChildView.walletName)
        if (availabilityError.length > 0) {
            nameError = availabilityError
            return
        }
        createRequested(loadedChildView.walletName.trim(), watchOnly ? loadedChildView.importText.trim() : "",
            watchOnly || !loadedChildView.encryptWallet ? "" : loadedChildView.passwordText,
            watchOnly ? birthTime() : -1,
            watchOnly && needsAddressType ? loadedChildView.addressTypeChoice : "")
    }

    function clearSecrets() {
        if (loadedChildView) loadedChildView.clearSecrets()
    }

    title: ""
    heading: watchOnly ? qsTr("View-only wallet") : qsTr("Single-key wallet")
    subheading: watchOnly
        ? qsTr("See balances and activity without keeping spending keys in this app. An external signer is needed to spend.")
        : qsTr("You can control it in this application.\nWallet data will be stored locally in your hard drive.")
    maximumContentWidth: 800
    showBackButton: !creating && navigationStack
        ? (navigationStack.canGoBack !== undefined
            ? navigationStack.canGoBack : navigationStack.depth > 1) : false
    showCloseButton: modalView && !creating
    primaryButtonText: creating ? (watchOnly ? qsTr("Importing…") : qsTr("Creating…")) : qsTr("Create wallet")
    primaryButtonObjectName: "createWalletFormCreateButton"
    primaryButtonEnabled: canCreate
    onCloseClicked: root.cancel()
    onPrimaryClicked: {
        if (!root.canCreate) return
        if (root.watchOnly || root.loadedChildView.encryptWallet) root.submit()
        else root.loadedChildView.openUnencryptedWarning()
    }

    Component.onCompleted: {
        walletController.clearWalletCreateStatus()
        walletController.clearWalletLoadStatus()
    }
    Component.onDestruction: clearSecrets()

    childView: ColumnLayout {
        id: fields
        property alias walletName: nameEntry.text
        property alias importText: xpubEntry.text
        property string addressTypeChoice: ""
        property string birthChoice: ""
        property alias encryptWallet: encryptCheck.checked
        property alias passwordText: passwordEntry.text
        property alias confirmText: confirmEntry.text
        readonly property bool passwordLossAcknowledged: acknowledgement.loadedTrailingItem
            ? acknowledgement.loadedTrailingItem.checked : false
        readonly property bool unencryptedWalletAcknowledged: unencryptedAcknowledgement.loadedTrailingItem
            ? unencryptedAcknowledgement.loadedTrailingItem.checked : false

        function clearSecrets() {
            passwordEntry.text = ""
            confirmEntry.text = ""
        }
        function openUnencryptedWarning() {
            unencryptedWarning.open()
        }

        spacing: 16

        LabeledTextField {
            id: nameEntry
            objectName: "createWalletNameEntry"
            Layout.fillWidth: true
            label: qsTr("Wallet name")
            fieldObjectName: "createWalletNameInput"
            placeholderText: qsTr("Eg. My bitcoin wallet...")
            supportingText: qsTr("You cannot change this later.")
            fieldSurface: true
            labelSpacing: 6
            messageSpacing: 8
            fieldBackgroundColor: Theme.color.neutral2
            onTextEdited: {
                root.nameError = ""
                walletController.clearWalletCreateStatus()
                walletController.clearWalletLoadStatus()
            }
        }

        Separator {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        CoreText {
            visible: !root.watchOnly
            Layout.fillWidth: true
            text: qsTr("SECURITY")
            color: Theme.color.neutral6
            font: Theme.text.captionStrong.font
            horizontalAlignment: Text.AlignLeft
        }

        CheckBox {
            id: encryptCheck
            objectName: "createWalletEncryptCheckBox"
            visible: !root.watchOnly
            Layout.fillWidth: true
            text: qsTr("Encrypt this wallet with a strong password.")
            checked: true
            onCheckedChanged: {
                if (!checked && acknowledgement.loadedTrailingItem)
                    acknowledgement.loadedTrailingItem.checked = false
                if (checked && unencryptedAcknowledgement.loadedTrailingItem)
                    unencryptedAcknowledgement.loadedTrailingItem.checked = false
            }
        }
        CoreText {
            visible: !root.watchOnly
            Layout.fillWidth: true
            Layout.leftMargin: 30
            Layout.topMargin: -12
            text: qsTr("Recommended")
            color: Theme.color.neutral7
            font: Theme.text.caption.font
            horizontalAlignment: Text.AlignLeft
        }

        PasswordTextField {
            id: passwordEntry
            objectName: "createWalletPasswordEntry"
            visible: !root.watchOnly && encryptCheck.checked
            Layout.fillWidth: true
            label: qsTr("Password")
            fieldObjectName: "createWalletPasswordInput"
            placeholderText: qsTr("Enter password...")
            fieldSurface: true
            labelSpacing: 6
            messageSpacing: 8
            fieldBackgroundColor: Theme.color.neutral2
            onTextEdited: walletController.clearWalletCreateStatus()
        }
        PasswordTextField {
            id: confirmEntry
            objectName: "createWalletConfirmPasswordEntry"
            visible: !root.watchOnly && encryptCheck.checked
            Layout.fillWidth: true
            label: qsTr("Confirm password")
            fieldObjectName: "createWalletPasswordRepeatInput"
            placeholderText: qsTr("Enter password again...")
            fieldSurface: true
            labelSpacing: 6
            messageSpacing: 8
            fieldBackgroundColor: Theme.color.neutral2
            errorText: text.length > 0 && passwordEntry.text !== text
                ? qsTr("Passwords don't match") : ""
            onTextEdited: walletController.clearWalletCreateStatus()
        }

        ListRow {
            id: acknowledgement
            objectName: "createWalletPasswordConfirmToggle"
            visible: !root.watchOnly && encryptCheck.checked
            Layout.fillWidth: true
            description: qsTr("I understand that if I lose or forget this password I might lose access to the bitcoin stored in this wallet.")
            showDivider: false
            accessibleRole: Accessible.CheckBox
            trailingItem: OptionSwitch { }
            onClicked: loadedTrailingItem.toggle()
        }

        ListRow {
            id: unencryptedAcknowledgement
            objectName: "createWalletUnencryptedConfirmToggle"
            visible: !root.watchOnly && !encryptCheck.checked
            Layout.fillWidth: true
            description: qsTr("I understand this wallet will be unencrypted. Anyone with access to its file may be able to spend my bitcoin. I cannot set a password later.")
            showDivider: false
            accessibleRole: Accessible.CheckBox
            trailingItem: OptionSwitch { }
            onClicked: loadedTrailingItem.toggle()
        }

        LabeledTextArea {
            id: xpubEntry
            objectName: "createWalletXpubEntry"
            visible: root.watchOnly
            Layout.fillWidth: true
            label: qsTr("Descriptors or extended public key")
            inputObjectName: "watchOnlyXpubInput"
            textStyle: Theme.text.monoDescription
            maximumInputHeight: 200
            //: "listdescriptors" is a Bitcoin Core command and is not translated.
            placeholderText: qsTr("Paste descriptors one per line, the output of listdescriptors, or an xpub...")
            supportingText: root.importSummary()
            fieldSurface: true
            labelSpacing: 6
            messageSpacing: 8
            fieldBackgroundColor: Theme.color.neutral2
            errorText: root.importInfo.status === "invalid" ? root.importInfo.error : ""
            onTextEdited: walletController.clearWalletLoadStatus()
        }

        DescriptorHighlighter {
            objectName: "watchOnlyImportHighlighter"
            textDocument: root.watchOnly ? xpubEntry.textDocument : null
            scriptColor: Theme.color.orange
            originColor: Theme.color.neutral7
            keyColor: Theme.color.neutral9
            keyAlternateColor: Theme.color.neutral7
            pathColor: Theme.color.blue
            checksumColor: Theme.color.neutral6
            jsonNameColor: Theme.color.purple
            jsonValueColor: Theme.color.green
            errorColor: Qt.rgba(Theme.color.red.r, Theme.color.red.g, Theme.color.red.b, 0.2)
            errorLine: root.importInfo.status === "invalid" && root.importInfo.errorLine !== undefined
                ? root.importInfo.errorLine : -1
        }

        ColumnLayout {
            id: importRows
            objectName: "watchOnlyImportRows"
            // Columns take the widest row's width, so they line up.
            function columnWidth(column) {
                let width = 0
                for (let i = 0; i < rowRepeater.count; ++i) {
                    const item = rowRepeater.itemAt(i)
                    if (item) width = Math.max(width, item[column])
                }
                return width
            }
            readonly property real typeWidth: columnWidth("typeWidth")
            readonly property real coverageWidth: columnWidth("coverageWidth")
            readonly property real createdWidth: columnWidth("createdWidth")
            readonly property real inactiveWidth: columnWidth("inactiveWidth")
            visible: root.watchOnly && root.importReady && root.importInfo.kind !== "extendedKey"
            Layout.fillWidth: true
            Layout.topMargin: -8
            spacing: 4

            Repeater {
                id: rowRepeater
                model: importRows.visible ? root.importInfo.rows : []
                RowLayout {
                    required property var modelData
                    required property int index
                    readonly property bool inactive: modelData.ranged && !modelData.active
                    readonly property real typeWidth: typeText.implicitWidth
                    readonly property real coverageWidth: coverageText.implicitWidth
                    readonly property real createdWidth: createdText.text.length > 0 ? createdText.implicitWidth : 0
                    readonly property real inactiveWidth: inactive ? inactivePill.implicitWidth : 0
                    objectName: "watchOnlyImportRow_" + index
                    Layout.fillWidth: true
                    spacing: 12

                    CoreText {
                        id: typeText
                        Layout.preferredWidth: importRows.typeWidth
                        text: modelData.addressType
                        color: Theme.color.neutral8
                        font: Theme.text.caption.font
                        wrap: false
                        horizontalAlignment: Text.AlignLeft
                    }
                    CoreText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        text: modelData.key
                        color: Theme.color.neutral7
                        font: Theme.text.monoCaption.font
                        wrap: false
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignLeft
                    }
                    CoreText {
                        id: coverageText
                        objectName: "watchOnlyImportRowCoverage"
                        Layout.preferredWidth: importRows.coverageWidth
                        text: !modelData.ranged ? qsTr("single address")
                            : modelData.receive && modelData.change ? qsTr("receive and change")
                            : modelData.receive ? qsTr("receive") : qsTr("change")
                        color: Theme.color.neutral7
                        font: Theme.text.caption.font
                        wrap: false
                        horizontalAlignment: Text.AlignLeft
                    }
                    CoreText {
                        id: createdText
                        objectName: "watchOnlyImportRowCreated"
                        visible: importRows.createdWidth > 0
                        Layout.preferredWidth: importRows.createdWidth
                        text: {
                            const format = "d MMM yyyy"
                            const created = new Date(modelData.createdTime * 1000).toLocaleDateString(Qt.locale(), format)
                            if (modelData.createdTime < 0 || root.importInfo.createdTime < 0
                                    || created === new Date(root.importInfo.createdTime * 1000).toLocaleDateString(Qt.locale(), format)) {
                                return ""
                            }
                            //: %1 is the date a descriptor was created.
                            return qsTr("created %1").arg(created)
                        }
                        color: Theme.color.neutral7
                        font: Theme.text.caption.font
                        wrap: false
                        horizontalAlignment: Text.AlignLeft
                    }
                    Item {
                        visible: importRows.inactiveWidth > 0
                        Layout.preferredWidth: importRows.inactiveWidth
                        Layout.preferredHeight: inactivePill.implicitHeight
                        StatusPill {
                            id: inactivePill
                            objectName: "watchOnlyImportRowInactive"
                            visible: inactive
                            text: qsTr("Not active")
                            showDot: false
                            leftPadding: 6
                            rightPadding: 6
                            topPadding: 1
                            bottomPadding: 1
                            implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
                        }
                    }
                }
            }
        }

        ColumnLayout {
            objectName: "watchOnlyAddressType"
            visible: root.watchOnly && root.needsAddressType
            Layout.fillWidth: true
            spacing: 10

            CoreText {
                Layout.fillWidth: true
                text: qsTr("Which addresses does this key use?")
                color: Theme.color.neutral8
                font: Theme.text.description.font
                horizontalAlignment: Text.AlignLeft
            }

            CoreText {
                Layout.fillWidth: true
                Layout.topMargin: -6
                text: qsTr("An xpub does not say. Check the wallet it came from.")
                color: Theme.color.neutral7
                font: Theme.text.caption.font
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
            }

            ButtonGroup { id: addressTypeGroup }

            Repeater {
                model: root.needsAddressType ? root.keyInfo.addressTypeOptions : []
                OptionButton {
                    required property var modelData
                    readonly property var descriptions: ({
                        "bech32": qsTr("Native SegWit, BIP84. Often exported as a zpub."),
                        "bech32m": qsTr("Taproot, BIP86."),
                        "p2sh-segwit": qsTr("Nested SegWit, BIP49. Often exported as a ypub."),
                        "legacy": qsTr("Legacy, BIP44.")
                    })
                    objectName: "watchOnlyAddressType_" + modelData.id
                    Layout.fillWidth: true
                    ButtonGroup.group: addressTypeGroup
                    surfaceSelectionStyle: true
                    text: modelData.label
                    description: descriptions[modelData.id] || ""
                    checked: fields.addressTypeChoice === modelData.id
                    onClicked: fields.addressTypeChoice = modelData.id
                }
            }
        }

        ColumnLayout {
            objectName: "watchOnlyBirthDate"
            visible: root.watchOnly && root.needsBirthDate
            Layout.fillWidth: true
            spacing: 10

            CoreText {
                Layout.fillWidth: true
                text: qsTr("When was this wallet created?")
                color: Theme.color.neutral8
                font: Theme.text.description.font
                horizontalAlignment: Text.AlignLeft
            }

            ButtonGroup { id: birthGroup }

            Repeater {
                model: [
                    { "choice": "month", "text": qsTr("In the last month"),
                      "description": qsTr("Fastest. Finds transactions from the last 31 days.") },
                    { "choice": "year", "text": qsTr("In the last year"),
                      "description": qsTr("Finds transactions from the last 12 months.") },
                    { "choice": "unknown", "text": qsTr("Earlier, or not sure"),
                      "description": qsTr("Searches the whole blockchain. This can take hours.") }
                ]
                OptionButton {
                    required property var modelData
                    objectName: "watchOnlyBirth_" + modelData.choice
                    Layout.fillWidth: true
                    ButtonGroup.group: birthGroup
                    surfaceSelectionStyle: true
                    text: modelData.text
                    description: modelData.description
                    checked: fields.birthChoice === modelData.choice
                    onClicked: fields.birthChoice = modelData.choice
                }
            }
        }

        CoreText {
            objectName: "watchOnlyScanNote"
            visible: root.watchOnly && root.creating
            Layout.fillWidth: true
            text: qsTr("Looking for this wallet's transactions. This can take a while.")
            color: Theme.color.neutral7
            font: Theme.text.caption.font
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        CoreText {
            objectName: "createWalletFormErrorText"
            visible: text.length > 0
            Layout.fillWidth: true
            text: root.nameError.length > 0 ? root.nameError
                : root.watchOnly ? walletController.walletLoadError : walletController.walletCreateError
            color: Theme.color.red
            font: Theme.text.caption.font
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        AlertPopup {
            id: unencryptedWarning
            objectName: "createWalletUnencryptedWarning"
            parent: Overlay.overlay
            title: qsTr("Create without encryption?")
            message: qsTr("This wallet file will be unencrypted. Anyone with access to it may be able to spend your bitcoin. You won't be able to set a password later.")
            AlertAction {
                text: qsTr("Cancel")
                role: AlertAction.Cancel
                buttonObjectName: "createWalletWarningCancelButton"
            }
            AlertAction {
                text: qsTr("Create wallet")
                role: AlertAction.Normal
                buttonObjectName: "createWalletWarningConfirmButton"
                onTriggered: root.submit()
            }
        }
    }
}
