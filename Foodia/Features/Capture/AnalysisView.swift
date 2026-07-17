import SwiftData
import SwiftUI

/// "Resumen de la imagen": el resultado editable del análisis.
/// Estados: normal · dictando contexto · reanalizando · sin comida detectada.
struct AnalysisView: View {
    private enum SearchTarget: Identifiable {
        case component(AnalysisModel.Component.ID)
        case newComponent

        var id: String {
            switch self {
            case .component(let id): id.uuidString
            case .newComponent: "new"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var model: AnalysisModel
    @State private var searchTarget: SearchTarget?
    @State private var dictation = SpeechDictation()
    @State private var confirmDiscard = false
    var onSaved: (() -> Void)?

    init(image: UIImage, onSaved: (() -> Void)? = nil) {
        _model = State(initialValue: AnalysisModel(image: image))
        self.onSaved = onSaved
    }

    /// La cámara ya corrió el análisis y entrega el modelo listo.
    init(model: AnalysisModel, onSaved: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    private var isReanalyzing: Bool {
        model.phase == .analyzing && !model.analyzedContext.isEmpty
    }

    var body: some View {
        List {
            photoSection
            content
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.dsBackground)
        .navigationTitle("Tu plato")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    if model.canSave {
                        confirmDiscard = true
                    } else {
                        dismiss()
                    }
                }
                .tint(Color.dsGreenText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            totalsBar
        }
        .confirmationDialog(
            "¿Descartar este análisis?",
            isPresented: $confirmDiscard,
            titleVisibility: .visible
        ) {
            Button("Descartar", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("La foto y tus ajustes se pierden.")
        }
        .sheet(item: $searchTarget) { target in
            FoodSearchView { food in
                switch target {
                case .component(let id): model.assign(food, toComponentWith: id)
                case .newComponent: model.addComponent(with: food)
                }
            }
        }
        .task {
            if !model.hasAnalyzed {
                await model.analyze()
            }
        }
    }

    // MARK: Secciones

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .preparingModel:
            loadingRow("Cargando el modelo local…")
        case .analyzing:
            if isReanalyzing {
                reanalyzingSection
            } else {
                loadingRow("Detectando alimentos…")
            }
        case .failed(let message):
            plainRow {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.dsTextSecondary)
            }
        case .done:
            if model.components.isEmpty {
                noFoodSection
            } else {
                componentsSection
                if model.engine == .vision, model.matches.count > 1 {
                    visionChipsSection
                }
                mealTypeSection
                contextSection
            }
        }
    }

    /// El usuario cataloga la comida — con la sugerencia por hora preseleccionada.
    private var mealTypeSection: some View {
        plainRow(topPadding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("¿Qué comida es?")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            SelectionChip(
                                title: type.title,
                                isSelected: model.mealType == type
                            ) {
                                model.mealType = type
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        plainRow {
            Group {
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Registro sin foto: placeholder con la descripción.
                    VStack(spacing: 8) {
                        DSIcon(id: "utensils-crossed", size: 36, tint: .dsTextTertiary)
                        if let description = model.mealDescription {
                            Text("\"\(description)\"")
                                .font(.subheadline)
                                .foregroundStyle(Color.dsTextSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dsInset)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isReanalyzing || dictation.state == .recording ? 150 : (model.image == nil ? 140 : 190))
            .clipShape(.rect(cornerRadius: DSRadius.large, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                EngineBadge(kind: badgeKind)
                    .padding(10)
            }
            .overlay(alignment: .bottomTrailing) {
                if model.image != nil {
                    Text(Date.now, format: .dateTime.hour().minute())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.45), in: .capsule)
                        .padding(10)
                }
            }
            .animation(.easeOut(duration: 0.25), value: isReanalyzing)
        }
    }

    private var badgeKind: EngineBadge.Kind {
        switch model.engine {
        case .cloud: .cloud
        case .vlm: EnginePreference.current == .cloud ? .autoUsedLocal : .local
        case .vision: .local
        }
    }

    private var componentsSection: some View {
        Group {
            plainRow(topPadding: 4) {
                Text("Detectamos \(model.components.count) componente\(model.components.count == 1 ? "" : "s") · ajusta los gramos")
                    .font(.footnote)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            ForEach($model.components) { $component in
                plainRow(topPadding: 4) {
                    ComponentEditRow(component: $component) {
                        searchTarget = .component(component.id)
                    }
                    .opacity(dictation.state == .recording ? 0.45 : 1)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Eliminar", systemImage: "trash", role: .destructive) {
                        model.removeComponent(with: component.id)
                    }
                }
            }
            plainRow(topPadding: 4) {
                Button {
                    searchTarget = .newComponent
                } label: {
                    Label("Agregar componente", systemImage: "plus")
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsGreenText)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay {
                            RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous)
                                .strokeBorder(Color.dsBorderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Chips del flujo Vision (un solo alimento): elegir entre candidatos.
    private var visionChipsSection: some View {
        plainRow(topPadding: 2) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(model.matches) { match in
                        SelectionChip(
                            title: match.food.localizedName,
                            isSelected: model.selectedFood?.id == match.food.id
                        ) {
                            model.select(match.food)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var contextSection: some View {
        plainRow(topPadding: 10) {
            VStack(alignment: .leading, spacing: 10) {
                if dictation.state == .recording {
                    DictationCard(
                        transcript: dictation.transcript,
                        onCancel: {
                            dictation.stop()
                            model.userContext = ""
                        },
                        onDone: { dictation.stop() }
                    )
                    Text("Al terminar, toca Reanalizar para que la IA use tu contexto.")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                } else {
                    ContextField(
                        text: $model.userContext,
                        placeholder: "Cuéntale algo a la IA… \"es sopa de lentejas\"",
                        onMic: { dictation.toggle() }
                    )
                    .onChange(of: dictation.transcript) { _, transcript in
                        if !transcript.isEmpty {
                            model.userContext = transcript
                        }
                    }
                }
                if dictation.state == .denied {
                    Text("Para dictar, permite el micrófono en Ajustes → Foodia.")
                        .font(.caption)
                        .foregroundStyle(Color.dsOver)
                }
                if model.canReanalyze, dictation.state != .recording {
                    Button {
                        Task { await model.reanalyze() }
                    } label: {
                        Label("Reanalizar", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.dsTinted)
                }
            }
        }
    }

    private var reanalyzingSection: some View {
        Group {
            plainRow {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.dsGreenText)
                    Text("**Reanalizando con tu contexto:** \"\(model.analyzedContext)\"")
                        .font(.footnote)
                        .foregroundStyle(Color.dsGreenText)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dsGreenTint, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            }
            ForEach(0..<3, id: \.self) { _ in
                plainRow(topPadding: 4) {
                    RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous)
                        .fill(Color.dsInsetAlt)
                        .frame(height: 64)
                }
            }
        }
    }

    private var noFoodSection: some View {
        plainRow(topPadding: 12) {
            VStack(spacing: 12) {
                DSIcon(id: "image-off", size: 40, tint: .dsTextTertiary)
                Text("No encontramos comida en la foto")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Text("Puede ser la luz, el ángulo, o un plato muy tapado. Cuéntanos qué es y lo intentamos de nuevo.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
                ContextField(
                    text: $model.userContext,
                    placeholder: "Dinos qué hay… \"milanesa con puré\"",
                    onMic: { dictation.toggle() }
                )
                .onChange(of: dictation.transcript) { _, transcript in
                    if !transcript.isEmpty { model.userContext = transcript }
                }
                Button {
                    Task { await model.reanalyze() }
                } label: {
                    Label("Reanalizar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.dsPrimary)
                .disabled(model.userContext.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cargar la comida a mano") {
                    searchTarget = .newComponent
                }
                .font(.dsButton)
                .foregroundStyle(Color.dsGreenText)
            }
        }
    }

    private var totalsBar: some View {
        VStack(spacing: 10) {
            if let totals = model.totalMacros {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(totals.kcal))")
                        .font(.dsBigNumber)
                        .foregroundStyle(Color.dsTextPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                    Spacer()
                    Text("\(Int(totals.protein)) g prot · \(Int(totals.carbs)) g carbos · \(Int(totals.fat)) g grasas")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .monospacedDigit()
                }
                .animation(.default, value: totals.kcal)
            }
            Button("Guardar comida") {
                model.save(in: modelContext)
                dismiss()
                onSaved?()
            }
            .buttonStyle(.dsPrimary)
            .disabled(!model.canSave || model.phase != .done)
            .sensoryFeedback(.success, trigger: model.phase)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: Helpers

    private func loadingRow(_ title: LocalizedStringKey) -> some View {
        plainRow(topPadding: 16) {
            HStack(spacing: 12) {
                ProgressView()
                Text(title)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func plainRow(topPadding: CGFloat = 8, @ViewBuilder content: () -> some View) -> some View {
        content()
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: topPadding, leading: 20, bottom: 4, trailing: 20))
    }
}

// MARK: - Fila de componente editable

private struct ComponentEditRow: View {
    @Binding var component: AnalysisModel.Component
    var onPick: () -> Void

    private var title: String {
        if let food = component.food { return food.localizedName }
        if component.remotePer100g != nil, !component.rawName.isEmpty { return component.rawName }
        return "Sin identificar"
    }

    private var detail: String {
        guard let per100g = component.effectivePer100g else {
            return "Toca para identificar"
        }
        let scaled = per100g.scaled(by: component.grams / 100)
        return "\(Int(scaled.kcal)) kcal · \(Int(scaled.protein)) g prot"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPick) {
                HStack(spacing: 10) {
                    FoodIconTile(icon: component.lucideIcon, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.dsRowTitle)
                            .foregroundStyle(component.effectivePer100g == nil ? Color.dsTextSecondary : .dsTextPrimary)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                            .monospacedDigit()
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            GramStepper(grams: $component.grams)
        }
        .padding(12)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
    }
}

// MARK: - Campo de contexto + dictado

private struct ContextField: View {
    @Binding var text: String
    let placeholder: String
    var onMic: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous)
                        .strokeBorder(Color.dsHairline, lineWidth: 1)
                }
            Button(action: onMic) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.dsGreenText)
                    .frame(width: 44, height: 44)
                    .background(Color.dsGreenTint, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dictar contexto")
        }
    }
}

/// Card "Escuchando…" con transcript en vivo (estado dictando).
private struct DictationCard: View {
    let transcript: String
    var onCancel: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.dsRed)
                    .frame(width: 9, height: 9)
                Text("Escuchando…")
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                WaveformView()
            }
            Text(transcript.isEmpty ? "…" : "\"\(transcript)\"")
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .lineLimit(3)
            HStack(spacing: 10) {
                Button("Cancelar", action: onCancel)
                    .buttonStyle(.dsSecondary)
                Button {
                    onDone()
                } label: {
                    Label("Listo", systemImage: "stop.fill")
                }
                .buttonStyle(.dsTinted)
            }
        }
        .padding(14)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(Color.dsAccent, lineWidth: 1.5)
        }
    }
}

/// Ondas animadas del dictado.
private struct WaveformView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.dsAccent)
                    .frame(width: 3, height: animating ? CGFloat([18, 10, 22, 8, 14][index]) : 6)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.09),
                        value: animating
                    )
            }
        }
        .frame(height: 22)
        .onAppear { animating = true }
    }
}
