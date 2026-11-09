import SwiftUI
import Speech
import ServiceManagement

final class UIState: ObservableObject {
    @Published var isCapturingHotkey = false
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: Permissions
    @ObservedObject var ui: UIState
    let startCapture: () -> Void
    let cancelCapture: () -> Void

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var hotkeyChoices: [Hotkey] {
        Hotkey.presets.contains(settings.hotkey) ? Hotkey.presets : Hotkey.presets + [settings.hotkey]
    }

    private var languages: [(id: String, name: String)] {
        let ru = Locale(identifier: "ru")
        return SFSpeechRecognizer.supportedLocales()
            .map { ($0.identifier, ru.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                Picker("Клавиша", selection: $settings.hotkey) {
                    ForEach(hotkeyChoices, id: \.self) { hk in Text(hk.name).tag(hk) }
                }
                HStack {
                    if ui.isCapturingHotkey {
                        Text("Нажмите нужную клавишу… (Esc — отмена)").foregroundStyle(.orange)
                        Spacer()
                        Button("Отмена", action: cancelCapture)
                    } else {
                        Button("Назначить другую клавишу…", action: startCapture)
                            .disabled(!permissions.accessibility)
                    }
                }
            } header: {
                Text("Клавиша для диктовки")
            } footer: {
                Text("Зажмите клавишу, говорите, отпустите — текст появится там, где стоит курсор.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Распознавание") {
                Picker("Язык", selection: $settings.localeID) {
                    ForEach(languages, id: \.id) { lang in Text(lang.name).tag(lang.id) }
                }
                Toggle("Распознавать на устройстве (офлайн, если доступно)", isOn: $settings.onDevice)
            }

            Section("Поведение") {
                Toggle("Добавлять пробел после текста", isOn: $settings.addTrailingSpace)
                Toggle("Звуки начала и конца записи", isOn: $settings.playSounds)
                Toggle("Показывать окошко с текстом во время записи", isOn: $settings.showOverlay)
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section {
                permissionRow("Микрофон", granted: permissions.microphone, action: permissions.requestMicrophone)
                permissionRow("Распознавание речи", granted: permissions.speech, action: permissions.requestSpeech)
                permissionRow("Универсальный доступ (клавиша и вставка)", granted: permissions.accessibility,
                              action: permissions.requestAccessibility)
            } header: {
                Text("Разрешения")
            } footer: {
                if !permissions.accessibility {
                    Text("Системные настройки → Конфиденциальность и безопасность → Универсальный доступ → включите HoldToTalk. Если он уже включён, но не работает — удалите его из списка (–) и добавьте снова.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func permissionRow(_ title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
            Spacer()
            if !granted { Button("Разрешить", action: action) }
        }
    }
}
