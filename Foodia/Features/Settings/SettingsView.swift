import SwiftData
import SwiftUI

/// Ajustes: motor de análisis, modelo local, metas, Salud, datos y privacidad.
struct SettingsView: View {
    @AppStorage(EnginePreference.storageKey) private var engineRaw = EnginePreference.auto.rawValue
    @Environment(\.modelContext) private var modelContext

    @State private var health = HealthKitExporter.shared
    @State private var reminders = ReminderService.shared
    @State private var reminderDenied = false
    @State private var vlmManager = VLMModelManager.shared
    @State private var showMetasSheet = false
    @State private var confirmDeleteModel = false
    @State private var promptDownloadForLocal = false
    @State private var confirmWipe = false
    @State private var confirmWipeFinal = false
    @State private var healthDenied = false
    @State private var exportURL: URL?
    @State private var confirmSignOut = false

    private var goals: DailyGoals { GoalsStore.shared.goals }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Ajustes")
                    .font(.dsScreenTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                engineSection
                modelCard
                metasSection
                regionSection
                healthSection
                remindersSection
                dataSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.dsBackground)
        .sheet(isPresented: $showMetasSheet) {
            MetasSheet()
        }
        .sheet(item: $exportURL) { url in
            ExportSheet(url: url)
        }
    }

    // MARK: Motor

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("MOTOR DE ANÁLISIS")
            VStack(spacing: 1) {
                engineRow(.local, iconId: "lock", title: "Local",
                          subtitle: "100 % privado · funciona sin conexión",
                          disabled: !vlmManager.isDownloaded && vlmManager.container == nil)
                engineRow(.cloud, iconId: "cloud", title: "Nube",
                          subtitle: "Máxima precisión · requiere internet")
                engineRow(.auto, iconId: "sparkles", title: "Automático",
                          subtitle: "Nube con conexión; si no hay, Local")
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            Text("Con Local, tus fotos nunca salen de tu iPhone.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
        .confirmationDialog(
            "Para usar el motor Local, primero descarga el modelo (1 GB, se hace una sola vez).",
            isPresented: $promptDownloadForLocal,
            titleVisibility: .visible
        ) {
            Button("Descargar ahora") {
                Task { await vlmManager.prepare() }
            }
            Button("Más tarde", role: .cancel) {}
        }
    }

    private func engineRow(
        _ preference: EnginePreference, iconId: String, title: LocalizedStringKey,
        subtitle: LocalizedStringKey, disabled: Bool = false
    ) -> some View {
        let isSelected = engineRaw == preference.rawValue
        return Button {
            if disabled {
                promptDownloadForLocal = true
            } else {
                engineRaw = preference.rawValue
            }
        } label: {
            HStack(spacing: 12) {
                DSIcon(id: iconId, size: 20, tint: .dsTextSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(disabled ? LocalizedStringKey("Disponible cuando termine la descarga") : subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.dsAccent : .dsBorderStrong)
            }
            .padding(13)
            .contentShape(.rect)
            .opacity(disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: engineRaw)
    }

    // MARK: Modelo local

    @ViewBuilder
    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DSIcon(id: "brain", size: 20, tint: .dsTextSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modelo Foodia Vision")
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsTextPrimary)
                    modelStatusLine
                }
                Spacer()
                modelAction
            }
            modelProgress
        }
        .padding(14)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        .confirmationDialog(
            "¿Eliminar el modelo local (\(VLMModelManager.approximateSize))? Vas a necesitar internet para analizar comidas hasta que lo vuelvas a descargar.",
            isPresented: $confirmDeleteModel,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                vlmManager.removeDownload()
                if engineRaw == EnginePreference.local.rawValue {
                    engineRaw = EnginePreference.auto.rawValue
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var modelStatusLine: some View {
        switch vlmManager.state {
        case .downloading(let progress):
            Text("Descargando… \(Int(progress * 100)) %")
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        case .loading:
            Text("Cargando en memoria…")
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        case .failed:
            Text("La descarga se interrumpió")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dsRed)
        case .ready, .notDownloaded:
            Text(vlmManager.isDownloaded
                ? "Instalado · \(VLMModelManager.approximateSize) · \(VLMModelManager.displayName)"
                : "No descargado · \(VLMModelManager.approximateSize)")
                .font(.caption)
                .foregroundStyle(vlmManager.isDownloaded ? Color.dsGreenText : .dsTextSecondary)
        }
    }

    @ViewBuilder
    private var modelAction: some View {
        switch vlmManager.state {
        case .downloading, .loading:
            ProgressView()
        case .failed:
            Button("Reanudar") {
                Task { await vlmManager.prepare() }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.dsGreenText)
        case .ready, .notDownloaded:
            if vlmManager.isDownloaded {
                Button("Eliminar…") { confirmDeleteModel = true }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dsRed)
            } else {
                Button("Descargar") {
                    Task { await vlmManager.prepare() }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.dsGreenText)
            }
        }
    }

    @ViewBuilder
    private var modelProgress: some View {
        if case .downloading(let progress) = vlmManager.state {
            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: progress)
                    .tint(Color.dsAccent)
                Text("Puedes seguir usando la app; te avisamos cuando esté listo.")
                    .font(.caption2)
                    .foregroundStyle(Color.dsTextTertiary)
            }
        } else if case .failed(let message) = vlmManager.state {
            Text("Se cortó la descarga (\(message)). Lo descargado no se pierde: retomamos desde donde quedó.")
                .font(.caption2)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    // MARK: Metas

    private var metasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("METAS DIARIAS")
            VStack(spacing: 1) {
                navRow(title: "Plan", value: GoalsStore.shared.planName) {
                    showMetasSheet = true
                }
                navRow(
                    title: "Metas",
                    value: "\(Int(goals.kcal)) kcal · \(Int(goals.protein))/\(Int(goals.carbs))/\(Int(goals.fat)) g"
                ) {
                    showMetasSheet = true
                }
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        }
    }

    // MARK: Región

    @AppStorage(FoodLocale.countryKey) private var country = FoodLocale.country

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("REGIÓN")
            Menu {
                ForEach(FoodLocale.countries, id: \.self) { code in
                    Button(FoodLocale.countryName(for: code)) {
                        country = code
                        SyncService.shared.pushProfileSnapshot()
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    DSIcon(id: "earth", size: 20, tint: .dsTextSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("País")
                            .font(.dsRowTitle)
                            .foregroundStyle(Color.dsTextPrimary)
                        Text("La IA usa los nombres de comida de tu región")
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    Spacer()
                    Text(FoodLocale.countryName(for: country))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dsGreenText)
                }
                .padding(13)
                .contentShape(.rect)
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        }
    }

    // MARK: Salud

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("SALUD")
            HStack(spacing: 12) {
                DSIcon(id: "heart", size: 20, tint: .dsRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sincronizar con Salud")
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("Escribe kcal y macros en Apple Salud")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { health.isEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                healthDenied = !(await health.requestAndEnable())
                            }
                        } else {
                            health.disable()
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color.dsAccent)
            }
            .padding(13)
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            if healthDenied {
                Text("Activa el permiso en Salud → Compartir → Foodia.")
                    .font(.caption)
                    .foregroundStyle(Color.dsOver)
            }
        }
    }

    // MARK: Recordatorios

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("RECORDATORIOS")
            HStack(spacing: 12) {
                DSIcon(id: "bell", size: 20, tint: .dsTextSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recordatorio diario")
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("A las 20:30, si aún no registraste tu comida")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { reminders.isEnabled },
                    set: { newValue in
                        if newValue {
                            Task { reminderDenied = !(await reminders.enable()) }
                        } else {
                            reminders.disable()
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color.dsAccent)
            }
            .padding(13)
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            if reminderDenied {
                Text("Activa las notificaciones en Ajustes → Foodia → Notificaciones.")
                    .font(.caption)
                    .foregroundStyle(Color.dsOver)
            }
        }
    }

    // MARK: Datos y privacidad

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("DATOS Y PRIVACIDAD")
            VStack(spacing: 1) {
                navRow(title: "Exportar mis datos", value: nil) {
                    exportURL = exportData()
                }
                navRow(title: "Cerrar sesión", value: nil) {
                    confirmSignOut = true
                }
                Button {
                    confirmWipe = true
                } label: {
                    HStack {
                        Text("Eliminar todos mis datos…")
                            .font(.dsRowTitle)
                            .foregroundStyle(Color.dsRed)
                        Spacer()
                    }
                    .padding(13)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            Text("Foodia no vende datos ni guarda tus fotos en servidores. Las fotos analizadas con Nube se descartan al terminar.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
        .confirmationDialog(
            "Se borra todo: diario, fotos, metas.",
            isPresented: $confirmWipe,
            titleVisibility: .visible
        ) {
            Button("Continuar…", role: .destructive) { confirmWipeFinal = true }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("¿Seguro? No hay vuelta atrás.", isPresented: $confirmWipeFinal) {
            Button("Eliminar todo", role: .destructive) { wipeAllData() }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog(
            "Tu diario queda guardado. Puedes volver a entrar con tu Apple ID cuando quieras.",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Cerrar sesión", role: .destructive) {
                Task { await AuthService.shared.signOut() }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: Helpers

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.dsSectionLabel)
            .foregroundStyle(Color.dsTextTertiary)
            .kerning(0.5)
    }

    private func navRow(title: LocalizedStringKey, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsBorderStrong)
            }
            .padding(13)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func exportData() -> URL? {
        struct ExportEntry: Encodable {
            let fecha: Date
            let nombre: String
            let gramos: Double
            let kcal: Double
            let proteinas: Double
            let carbohidratos: Double
            let grasas: Double
        }
        guard let entries = try? modelContext.fetch(FetchDescriptor<MealEntry>()) else { return nil }
        let export = entries.map {
            ExportEntry(fecha: $0.timestamp, nombre: $0.name, gramos: $0.grams,
                        kcal: $0.calories, proteinas: $0.proteinG,
                        carbohidratos: $0.carbsG, grasas: $0.fatG)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(export) else { return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: "foodia-export.json")
        try? data.write(to: url)
        return url
    }

    private func wipeAllData() {
        SyncService.shared.wipeRemote()
        try? modelContext.delete(model: MealEntry.self)
        try? modelContext.delete(model: WaterEntry.self)
        try? FileManager.default.removeItem(at: PhotoStore.directory)
        GoalsStore.shared.applyCustom(goals: .fallback)
        GoalsStore.shared.planName = "Sugerido"
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Sheet mínimo para compartir el export.
private struct ExportSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            DSIcon(id: "package", size: 40, tint: .dsTextTertiary)
            Text("Tu archivo está listo")
                .font(.dsSection)
            ShareLink(item: url) {
                Label("Compartir foodia-export.json", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.dsPrimary)
            Button("Cerrar") { dismiss() }
                .foregroundStyle(Color.dsTextSecondary)
        }
        .padding(24)
        .presentationDetents([.height(260)])
    }
}
