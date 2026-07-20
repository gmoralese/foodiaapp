import Charts
import SwiftData
import SwiftUI

/// Métrica corporal graficable. El peso vive en el perfil; las medidas y el
/// % de grasa son opcionales por registro.
enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, waist, hip, chest, arm, thigh, neck, bodyFat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: String(localized: "Peso")
        case .waist: String(localized: "Cintura")
        case .hip: String(localized: "Cadera")
        case .chest: String(localized: "Pecho")
        case .arm: String(localized: "Brazo")
        case .thigh: String(localized: "Muslo")
        case .neck: String(localized: "Cuello")
        case .bodyFat: String(localized: "Grasa corporal")
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .bodyFat: "%"
        default: "cm"
        }
    }

    /// Rango válido (espeja los CHECK de la DB y la validación del backend).
    var range: ClosedRange<Double> {
        switch self {
        case .weight: 30...400
        case .waist, .hip, .chest: 20...300
        case .arm: 5...150
        case .thigh: 10...200
        case .neck: 10...150
        case .bodyFat: 1...70
        }
    }

    func value(_ measurement: BodyMeasurement) -> Double? {
        switch self {
        case .weight: measurement.weightKg
        case .waist: measurement.waistCm
        case .hip: measurement.hipCm
        case .chest: measurement.chestCm
        case .arm: measurement.armCm
        case .thigh: measurement.thighCm
        case .neck: measurement.neckCm
        case .bodyFat: measurement.bodyFatPct
        }
    }
}

/// Formatea sin decimales innecesarios: 74 en vez de 74.0, 74.5 tal cual.
func measurementText(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
}

private struct MetricPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Histórico de peso y medidas: peso actual, gráfico de tendencia por métrica
/// e historial de registros. Se presenta como sheet desde Ajustes.
struct BodyMeasurementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.measuredAt, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var metric: BodyMetric = .weight
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if measurements.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color.dsBackground)
            .navigationTitle("Peso y medidas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) { AddMeasurementSheet() }
        }
    }

    // MARK: Contenido

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weightCard
                chartCard
                registerButton
                historySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            DSIcon(id: "ruler", size: 40, tint: .dsTextTertiary)
                .frame(width: 88, height: 88)
                .background(Color.dsInset, in: .circle)
            Text("Aún no registras medidas")
                .font(.dsSection)
                .foregroundStyle(Color.dsTextPrimary)
            Text("Anota tu peso y medidas cada tanto para ver tu evolución en un gráfico.")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            Button("Registrar medición") { showAdd = true }
                .buttonStyle(.dsPrimary)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Peso actual

    /// Peso más reciente registrado; si no hay, el del perfil (onboarding).
    private var currentWeight: (value: Double, date: Date?)? {
        if let entry = measurements.first(where: { $0.weightKg != nil }),
           let weight = entry.weightKg {
            return (weight, entry.measuredAt)
        }
        if let profileWeight = GoalsStore.shared.profile?.weightKg {
            return (profileWeight, nil)
        }
        return nil
    }

    /// Cambio de peso respecto de la medición anterior con peso.
    private var weightDelta: Double? {
        let weights = measurements.compactMap(\.weightKg)
        guard weights.count >= 2 else { return nil }
        return weights[0] - weights[1]
    }

    @ViewBuilder
    private var weightCard: some View {
        if let current = currentWeight {
            VStack(alignment: .leading, spacing: 6) {
                Text("PESO ACTUAL")
                    .font(.dsSectionLabel)
                    .foregroundStyle(Color.dsTextTertiary)
                    .kerning(0.5)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(measurementText(current.value))
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("kg")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.dsTextSecondary)
                    Spacer()
                    if let delta = weightDelta, abs(delta) >= 0.05 {
                        deltaChip(delta)
                    }
                }
                if let date = current.date {
                    Text("Actualizado \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        }
    }

    private func deltaChip(_ delta: Double) -> some View {
        let down = delta < 0
        return HStack(spacing: 3) {
            Image(systemName: down ? "arrow.down" : "arrow.up")
            Text("\(measurementText(abs(delta))) kg")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(down ? Color.dsGreenText : .dsTextSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(down ? Color.dsGreenTint : .dsInset, in: .capsule)
    }

    // MARK: Gráfico

    private func points(for metric: BodyMetric) -> [MetricPoint] {
        // measurements viene de nuevo→viejo; el gráfico va viejo→nuevo.
        measurements.reversed().compactMap { measurement in
            metric.value(measurement).map { MetricPoint(date: measurement.measuredAt, value: $0) }
        }
    }

    private var chartCard: some View {
        let data = points(for: metric)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Evolución")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Menu {
                    ForEach(BodyMetric.allCases) { option in
                        Button(option.title) { metric = option }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(metric.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dsGreenText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.dsInset, in: .capsule)
                }
            }
            if data.count >= 2 {
                Chart(data) { point in
                    LineMark(
                        x: .value("Fecha", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.dsAccent)
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Fecha", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.dsAccent)
                    .symbolSize(28)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(preset: .aligned) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.dsHairline)
                        AxisValueLabel().foregroundStyle(Color.dsTextTertiary)
                    }
                }
                .frame(height: 170)
            } else {
                Text("Registra al menos dos mediciones de \(metric.title.lowercased()) para ver la tendencia.")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var registerButton: some View {
        Button("Registrar medición") { showAdd = true }
            .buttonStyle(.dsPrimary)
    }

    // MARK: Historial

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORIAL")
                .font(.dsSectionLabel)
                .foregroundStyle(Color.dsTextTertiary)
                .kerning(0.5)
            VStack(spacing: 1) {
                ForEach(measurements) { measurement in
                    historyRow(measurement)
                }
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            Text("Mantén presionado un registro para eliminarlo.")
                .font(.caption2)
                .foregroundStyle(Color.dsTextTertiary)
        }
    }

    private func historyRow(_ measurement: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(measurement.measuredAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                if measurement.recordedByPro {
                    Text("Nutricionista")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.dsGreenText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.dsGreenTint, in: .capsule)
                }
            }
            Text(summary(measurement))
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .contextMenu {
            Button("Eliminar", role: .destructive) { delete(measurement) }
        }
    }

    private func summary(_ measurement: BodyMeasurement) -> String {
        BodyMetric.allCases.compactMap { metric -> String? in
            guard let value = metric.value(measurement) else { return nil }
            switch metric {
            case .weight: return "\(measurementText(value)) kg"
            case .bodyFat: return "\(metric.title) \(measurementText(value)) %"
            default: return "\(metric.title) \(measurementText(value))"
            }
        }
        .joined(separator: " · ")
    }

    private func delete(_ measurement: BodyMeasurement) {
        SyncService.shared.deleteRemoteMeasurement(measurement.remoteID)
        context.delete(measurement)
        try? context.save()
    }
}

// MARK: - Nueva medición

private struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var draft = Draft()
    @State private var errorMessage: String?
    @State private var recalcWeight: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Registra lo que quieras — todo es opcional.")
                        .font(.callout)
                        .foregroundStyle(Color.dsTextSecondary)
                    dateRow
                    fieldsCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.dsRed)
                    }
                }
                .padding(20)
            }
            .background(Color.dsBackground)
            .navigationTitle("Nueva medición")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(!draft.hasAny)
                }
            }
            .alert("Peso actualizado", isPresented: recalcBinding) {
                Button("Recalcular metas") {
                    GoalsStore.shared.recalcGoalsFromProfile()
                    dismiss()
                }
                Button("Ahora no", role: .cancel) { dismiss() }
            } message: {
                Text("Tu peso actual pasó a \(measurementText(recalcWeight ?? 0)) kg. ¿Recalculo tus metas diarias con este peso?")
            }
        }
    }

    private var recalcBinding: Binding<Bool> {
        Binding(get: { recalcWeight != nil }, set: { if !$0 { recalcWeight = nil } })
    }

    private var dateRow: some View {
        HStack(spacing: 12) {
            DSIcon(id: "calendar", size: 20, tint: .dsTextSecondary)
            Text("Fecha")
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            DatePicker("", selection: $draft.date, in: ...Date.now, displayedComponents: .date)
                .labelsHidden()
                .tint(Color.dsAccent)
        }
        .padding(13)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var fieldsCard: some View {
        VStack(spacing: 1) {
            field("Peso", $draft.weight, unit: "kg")
            field("Cintura", $draft.waist, unit: "cm")
            field("Cadera", $draft.hip, unit: "cm")
            field("Pecho", $draft.chest, unit: "cm")
            field("Brazo", $draft.arm, unit: "cm")
            field("Muslo", $draft.thigh, unit: "cm")
            field("Cuello", $draft.neck, unit: "cm")
            field("Grasa corporal", $draft.bodyFat, unit: "%")
        }
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private func field(_ label: LocalizedStringKey, _ text: Binding<String>, unit: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.dsGreenText)
                .frame(maxWidth: 90)
            Text(unit)
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
                .frame(width: 26, alignment: .leading)
        }
        .padding(13)
    }

    private func save() {
        guard draft.hasAny else { return }
        if let error = draft.validationError() {
            errorMessage = error
            return
        }
        let measurement = BodyMeasurement(
            measuredAt: draft.date,
            weightKg: Draft.parse(draft.weight),
            waistCm: Draft.parse(draft.waist),
            hipCm: Draft.parse(draft.hip),
            chestCm: Draft.parse(draft.chest),
            armCm: Draft.parse(draft.arm),
            thighCm: Draft.parse(draft.thigh),
            neckCm: Draft.parse(draft.neck),
            bodyFatPct: Draft.parse(draft.bodyFat)
        )
        context.insert(measurement)
        try? context.save()
        SyncService.shared.syncNow()

        // Peso nuevo: actualiza el perfil y ofrece recalcular las metas.
        if let weight = measurement.weightKg, GoalsStore.shared.profile != nil {
            GoalsStore.shared.updateWeight(weight)
            recalcWeight = weight
        } else {
            dismiss()
        }
    }

    private struct Draft {
        var date = Date.now
        var weight = ""
        var waist = ""
        var hip = ""
        var chest = ""
        var arm = ""
        var thigh = ""
        var neck = ""
        var bodyFat = ""

        static func parse(_ raw: String) -> Double? {
            let cleaned = raw.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: ".")
            return cleaned.isEmpty ? nil : Double(cleaned)
        }

        var hasAny: Bool {
            [weight, waist, hip, chest, arm, thigh, neck, bodyFat]
                .contains { Self.parse($0) != nil }
        }

        /// Primer campo fuera de rango (o formato inválido), en tono humano.
        func validationError() -> String? {
            let fields: [(String, BodyMetric)] = [
                (weight, .weight), (waist, .waist), (hip, .hip), (chest, .chest),
                (arm, .arm), (thigh, .thigh), (neck, .neck), (bodyFat, .bodyFat),
            ]
            for (raw, metric) in fields where !raw.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let value = Self.parse(raw) else {
                    return "\(metric.title): escribe solo números."
                }
                if !metric.range.contains(value) {
                    return "\(metric.title): debe estar entre \(Int(metric.range.lowerBound)) y \(Int(metric.range.upperBound)) \(metric.unit)."
                }
            }
            return nil
        }
    }
}
