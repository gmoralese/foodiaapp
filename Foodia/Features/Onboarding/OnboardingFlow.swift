import AVFoundation
import SwiftUI

/// Primera ejecución: Splash → Login (obligatorio) → Onboarding (7 pasos) → app.
/// Tras el login consulta el perfil en el backend: si el onboarding ya se
/// completó en otro dispositivo se salta entero, y si quedó a medias se
/// retoma en el paso siguiente con los datos ya ingresados.
struct FirstRunFlow: View {
    private enum Stage {
        case splash
        case login
        case preparing
        case onboarding(startAt: Int, profile: UserProfile)
    }

    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var stage: Stage = .splash

    var body: some View {
        switch stage {
        case .splash:
            SplashView()
                .task {
                    try? await Task.sleep(for: .seconds(1.6))
                    // Espera la restauración de la sesión guardada (es casi
                    // instantánea: lee del Keychain, sin red).
                    while AuthService.shared.isRestoring {
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    withAnimation(.easeOut) {
                        stage = AuthService.shared.isAuthenticated ? .preparing : .login
                    }
                }
        case .login:
            LoginView {
                withAnimation(.easeOut) { stage = .preparing }
            }
        case .preparing:
            // Mismo visual del splash mientras se consulta el perfil remoto.
            SplashView()
                .task { await resumeFromServer() }
        case .onboarding(let startAt, let profile):
            OnboardingFlow(initialStep: startAt, initialProfile: profile) {
                hasOnboarded = true
                SyncService.shared.syncNow()
            }
        }
    }

    private func resumeFromServer() async {
        guard let remote = try? await BackendClient.shared.profile() else {
            // Sin red: se arranca de cero; los PATCH por paso reconstruyen.
            withAnimation(.easeOut) { stage = .onboarding(startAt: 0, profile: UserProfile()) }
            return
        }
        if remote.onboardingCompletedAt != nil {
            remote.applyToLocalStores()
            SyncService.shared.syncNow()
            hasOnboarded = true // RootView pasa directo a la app
        } else {
            withAnimation(.easeOut) {
                stage = .onboarding(
                    startAt: min(remote.onboardingStep, 6),
                    profile: remote.asUserProfile
                )
            }
        }
    }
}

extension RemoteProfile {
    /// Mapea a UserProfile con defaults locales para lo que falte.
    var asUserProfile: UserProfile {
        var profile = UserProfile()
        if let sex, let value = Sex(rawValue: sex) { profile.sex = value }
        if let age { profile.age = age }
        if let weightKg { profile.weightKg = weightKg }
        if let heightCm { profile.heightCm = heightCm }
        if let activity, let value = ActivityLevel(rawValue: activity) { profile.activity = value }
        profile.sports = sports
        if let objective, let value = GoalObjective(rawValue: objective) { profile.objective = value }
        return profile
    }

    /// El perfil remoto es la fuente de verdad al entrar en un dispositivo
    /// nuevo: baja metas, plan y país a los stores locales.
    func applyToLocalStores() {
        GoalsStore.shared.profile = asUserProfile
        if let goalKcal, let goalProteinG, let goalCarbsG, let goalFatG {
            GoalsStore.shared.goals = DailyGoals(
                kcal: goalKcal, protein: goalProteinG,
                carbs: goalCarbsG, fat: goalFatG, waterMl: goalWaterMl
            )
        }
        if let planName { GoalsStore.shared.planName = planName }
        if let foodCountry {
            UserDefaults.standard.set(foodCountry, forKey: FoodLocale.countryKey)
        }
    }
}

// MARK: - Splash

private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.24, green: 0.71, blue: 0.42),
                         Color(red: 0.18, green: 0.62, blue: 0.35),
                         Color(red: 0.13, green: 0.46, blue: 0.26)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 14) {
                DSIcon(id: "salad", size: 48, tint: Color(red: 0.13, green: 0.46, blue: 0.26))
                    .frame(width: 96, height: 96)
                    .background(.white, in: .rect(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
                Text("Foodia")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Tus macros, con una foto")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .overlay(alignment: .bottom) {
            Label("Puede funcionar 100 % en tu iPhone", systemImage: "lock.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Onboarding

private struct OnboardingFlow: View {
    var onFinish: () -> Void

    @State private var step: Int
    @State private var profile: UserProfile
    @State private var skippedProfile = false

    private let totalSteps = 7

    init(initialStep: Int = 0, initialProfile: UserProfile = UserProfile(), onFinish: @escaping () -> Void) {
        _step = State(initialValue: initialStep)
        _profile = State(initialValue: initialProfile)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $step) {
                ValueStep(onContinue: next).tag(0)
                PrivacyStep(onContinue: next).tag(1)
                AboutYouStep(profile: $profile, onContinue: next).tag(2)
                ActivityStep(profile: $profile, onContinue: next).tag(3)
                ObjectiveStep(profile: $profile, onContinue: next).tag(4)
                PlanStep(profile: profile, skipped: skippedProfile, onContinue: next).tag(5)
                CameraPermissionStep(onContinue: { onFinish() }).tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut, value: step)
        }
        .background(Color.dsBackground)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.dsAccent : .dsHairline)
                        .frame(width: index == step ? 20 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.3), value: step)
            Spacer()
            if (2...4).contains(step) {
                Button("Omitir") {
                    skippedProfile = true
                    step = 5
                    push(ProfilePatch(onboardingStep: 5))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private func next() {
        pushProgress(afterCompleting: step)
        if step < totalSteps - 1 {
            step += 1
        } else {
            onFinish()
        }
    }

    /// Persiste el avance en el backend, con los datos del paso recién
    /// completado. Best-effort: si falla, el peor caso es repetir un paso.
    private func pushProgress(afterCompleting completed: Int) {
        var patch = ProfilePatch(onboardingStep: completed + 1)
        switch completed {
        case 2:
            patch.sex = profile.sex.rawValue
            patch.age = profile.age
            patch.weightKg = profile.weightKg
            patch.heightCm = profile.heightCm
            patch.foodCountry = FoodLocale.country
        case 3:
            patch.activity = profile.activity.rawValue
            patch.sports = profile.sports
        case 4:
            patch.objective = profile.objective.rawValue
        case 5:
            // PlanStep ya aplicó el plan a GoalsStore antes de avanzar.
            let goals = GoalsStore.shared.goals
            patch.planName = GoalsStore.shared.planName
            patch.goalKcal = goals.kcal
            patch.goalProteinG = goals.protein
            patch.goalCarbsG = goals.carbs
            patch.goalFatG = goals.fat
            patch.goalWaterMl = goals.waterMl
        case 6:
            patch.onboardingCompleted = true
        default:
            break
        }
        push(patch)
    }

    private func push(_ patch: ProfilePatch) {
        Task { try? await BackendClient.shared.updateProfile(patch) }
    }
}

/// Contenedor común de paso: contenido + CTA flotante.
private struct StepScaffold<Content: View>: View {
    let ctaTitle: LocalizedStringKey
    var ctaAction: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 90)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            Button(ctaTitle, action: ctaAction)
                .buttonStyle(.dsPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background {
                    LinearGradient(
                        colors: [Color.dsBackground.opacity(0), .dsBackground],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
        }
    }
}

// MARK: Paso 1 · Propuesta de valor

private struct ValueStep: View {
    var onContinue: () -> Void

    var body: some View {
        StepScaffold(ctaTitle: "Continuar", ctaAction: onContinue) {
            Spacer(minLength: 20)
            HStack(spacing: -14) {
                foodCircle("wheat", size: 76)
                foodCircle("egg-fried", size: 92).zIndex(1)
                foodCircle("apple", size: 76)
            }
            Text("640 kcal · P 24 g · C 68 g · G 29 g")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.dsGreenText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.dsGreenTint, in: .capsule)
            Text("Tómale una foto\na tu plato")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
            Text("Foodia detecta qué hay y estima calorías, proteínas, carbos y grasas en segundos. Tú solo ajustas los gramos.")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private func foodCircle(_ icon: String, size: CGFloat) -> some View {
        DSIcon(id: icon, size: size * 0.42, tint: .dsAccent)
            .frame(width: size, height: size)
            .background(Color.dsCard, in: .circle)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

// MARK: Paso 2 · Privacidad

private struct PrivacyStep: View {
    var onContinue: () -> Void

    var body: some View {
        StepScaffold(ctaTitle: "Continuar", ctaAction: onContinue) {
            Spacer(minLength: 12)
            DSIcon(id: "lock", size: 36, tint: .dsGreenText)
                .frame(width: 88, height: 88)
                .background(Color.dsGreenTint, in: .circle)
            Text("Tus comidas\nson tuyas")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
            Text("Foodia puede analizar todo en tu iPhone, sin subir nada a internet. Tú eliges el motor:")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            engineCard("lock", "Local — 100 % privado",
                       "Funciona sin conexión. Las fotos nunca salen de tu teléfono.")
            engineCard("cloud", "Nube — máxima precisión",
                       "Usa internet para el análisis más fino. Nunca guardamos tus fotos.")
            Text("Puedes cambiarlo cuando quieras en Ajustes.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
    }

    private func engineCard(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DSIcon(id: icon, size: 20, tint: .dsGreenText)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }
}

// MARK: Paso 3 · Sobre ti

private struct AboutYouStep: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    @AppStorage(FoodLocale.countryKey) private var country = FoodLocale.country
    @State private var editing: Field?

    private enum Field: String, Identifiable {
        case age, weight, height
        var id: String { rawValue }
    }

    var body: some View {
        StepScaffold(ctaTitle: "Continuar", ctaAction: onContinue) {
            Text("Cuéntanos de ti")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
            Text("Con esto calculamos tu gasto diario y tus metas. Queda solo en tu iPhone.")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            Picker("Sexo", selection: $profile.sex) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    Text(sex.title).tag(sex)
                }
            }
            .pickerStyle(.segmented)
            VStack(spacing: 1) {
                valueRow("Edad", value: "\(profile.age) años") { editing = .age }
                valueRow("Peso", value: "\(Int(profile.weightKg)) kg") { editing = .weight }
                valueRow("Altura", value: "\(Int(profile.heightCm)) cm") { editing = .height }
                countryRow
            }
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            Text("Con tu país, la IA usa los nombres de comida de tu región (palta, aguacate…).")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
        .sheet(item: $editing) { field in
            wheelSheet(for: field)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private var countryRow: some View {
        Menu {
            ForEach(FoodLocale.countries, id: \.self) { code in
                Button(FoodLocale.countryName(for: code)) {
                    country = code
                }
            }
        } label: {
            HStack {
                Text("País")
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Text(FoodLocale.countryName(for: country))
                    .font(.dsRowValue)
                    .foregroundStyle(Color.dsGreenText)
            }
            .padding(14)
            .contentShape(.rect)
        }
    }

    private func valueRow(_ title: LocalizedStringKey, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Text(value)
                    .font(.dsRowValue)
                    .foregroundStyle(Color.dsGreenText)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func wheelSheet(for field: Field) -> some View {
        switch field {
        case .age:
            wheelPicker("Edad", selection: $profile.age, range: 14...100, unit: "años")
        case .weight:
            wheelPicker("Peso", selection: Binding(
                get: { Int(profile.weightKg) },
                set: { profile.weightKg = Double($0) }
            ), range: 35...250, unit: "kg")
        case .height:
            wheelPicker("Altura", selection: Binding(
                get: { Int(profile.heightCm) },
                set: { profile.heightCm = Double($0) }
            ), range: 120...230, unit: "cm")
        }
    }

    private func wheelPicker(_ title: LocalizedStringKey, selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack {
            Text(title)
                .font(.dsSection)
                .padding(.top, 18)
            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text("\(value) \(unit)").tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
        .presentationBackground(Color.dsBackground)
    }
}

// MARK: Paso 4 · Actividad

private struct ActivityStep: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    /// (clave estable para PlanCalculator, etiqueta localizada)
    private let sports: [(key: String, label: String)] = [
        ("Fuerza", String(localized: "Fuerza")),
        ("Running", String(localized: "Running")),
        ("Fútbol", String(localized: "Fútbol")),
        ("Ciclismo", String(localized: "Ciclismo")),
        ("Natación", String(localized: "Natación")),
        ("Yoga", String(localized: "Yoga / pilates")),
        ("Otro", String(localized: "Otro")),
    ]

    var body: some View {
        StepScaffold(ctaTitle: "Continuar", ctaAction: onContinue) {
            Text("¿Cuánto te mueves?")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
            VStack(spacing: 8) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    OptionCard(
                        iconId: nil,
                        title: level.title,
                        subtitle: level.subtitle,
                        isSelected: profile.activity == level
                    ) {
                        profile.activity = level
                    }
                }
            }
            Text("¿Qué haces? (puedes elegir varios)")
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            FlowChips(items: sports, selected: Set(profile.sports)) { key in
                if let index = profile.sports.firstIndex(of: key) {
                    profile.sports.remove(at: index)
                } else {
                    profile.sports.append(key)
                }
            }
        }
    }
}

/// Chips en flow layout simple (dos filas máx. para 7 items).
private struct FlowChips: View {
    let items: [(key: String, label: String)]
    let selected: Set<String>
    var onTap: (String) -> Void

    var body: some View {
        let rows = [Array(items.prefix(3)), Array(items.dropFirst(3).prefix(2)), Array(items.dropFirst(5))]
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex], id: \.key) { item in
                        SelectionChip(title: item.label, isSelected: selected.contains(item.key)) {
                            onTap(item.key)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OptionCard: View {
    let iconId: String?
    let title: String
    let subtitle: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let iconId {
                    DSIcon(id: iconId, size: 20, tint: isSelected ? .dsGreenText : .dsTextSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.dsAccent : .dsBorderStrong)
            }
            .padding(13)
            .background(
                isSelected ? Color.dsGreenTint : .dsCard,
                in: .rect(cornerRadius: DSRadius.card, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Paso 5 · Objetivo

private struct ObjectiveStep: View {
    @Binding var profile: UserProfile
    var onContinue: () -> Void

    var body: some View {
        StepScaffold(ctaTitle: "Continuar", ctaAction: onContinue) {
            Text("¿Cuál es tu objetivo?")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
            Text("Define cuántas calorías te sugerimos por día.")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
            VStack(spacing: 8) {
                ForEach(GoalObjective.allCases, id: \.self) { objective in
                    OptionCard(
                        iconId: objective.lucideId,
                        title: objective.title,
                        subtitle: objective.subtitle,
                        isSelected: profile.objective == objective
                    ) {
                        profile.objective = objective
                    }
                }
            }
            Text("Puedes cambiar de etapa cuando quieras; tus metas se recalculan.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
        }
    }
}

// MARK: Paso 6 · Plan sugerido

private struct PlanStep: View {
    let profile: UserProfile
    let skipped: Bool
    var onContinue: () -> Void

    @State private var selectedPlan: PlanOption?

    private var options: [PlanOption] {
        PlanCalculator.options(for: profile)
    }

    var body: some View {
        StepScaffold(ctaTitle: "Usar este plan", ctaAction: apply) {
            Text("Tu plan sugerido")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            ForEach(options) { option in
                planCard(option)
            }
        }
        .onAppear {
            if selectedPlan == nil {
                selectedPlan = options.first(where: \.isRecommended) ?? options.first
            }
        }
    }

    private var subtitle: String {
        if skipped {
            return "Usamos valores estimados — completa tus datos en Ajustes cuando quieras."
        }
        let sports = profile.sports.isEmpty ? "" : ", \(profile.sports.joined(separator: " y ").lowercased())"
        return "Con tus datos — \(Int(profile.weightKg)) kg\(sports), \(profile.activity.title.lowercased()) — esto es lo que te recomendamos:"
    }

    private func planCard(_ option: PlanOption) -> some View {
        let isSelected = selectedPlan?.id == option.id
        return Button {
            selectedPlan = option
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                if option.isRecommended {
                    Text("RECOMENDADO")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.dsAccent, in: .capsule)
                }
                Text(option.name)
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(option.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                HStack(spacing: 8) {
                    macroTile("\(Int(option.goals.kcal))", "kcal", highlight: true)
                    macroTile("\(Int(option.goals.protein)) g", "Proteínas")
                    macroTile("\(Int(option.goals.carbs)) g", "Carbos")
                    macroTile("\(Int(option.goals.fat)) g", "Grasas")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .strokeBorder(isSelected ? Color.dsAccent : .dsHairline, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func macroTile(_ value: String, _ label: LocalizedStringKey, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote.weight(.bold))
                .foregroundStyle(highlight ? Color.white : .dsTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(highlight ? Color.white.opacity(0.85) : .dsTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            highlight ? Color.dsAccent : .dsInset,
            in: .rect(cornerRadius: 10, style: .continuous)
        )
    }

    private func apply() {
        guard let plan = selectedPlan else { return }
        GoalsStore.shared.apply(plan: plan, profile: profile)
        if skipped {
            GoalsStore.shared.planName = "\(plan.name) (estimado)"
        }
        onContinue()
    }
}

// MARK: Paso 7 · Permiso de cámara

private struct CameraPermissionStep: View {
    var onContinue: () -> Void

    var body: some View {
        StepScaffold(ctaTitle: "Permitir cámara", ctaAction: requestPermission) {
            Spacer(minLength: 12)
            DSIcon(id: "camera", size: 36, tint: .dsGreenText)
                .frame(width: 88, height: 88)
                .background(Color.dsGreenTint, in: .circle)
            Text("Lo único que falta:\nla cámara")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
            Text("Foodia necesita la cámara para ver tu plato. Con el motor Local, las fotos no salen de tu teléfono.")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            Button("Ahora no") { onContinue() }
                .font(.dsButton)
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.top, 6)
        }
    }

    private func requestPermission() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            onContinue()
        }
    }
}
