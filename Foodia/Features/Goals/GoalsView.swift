import SwiftUI

/// Tab "Metas": plan actual + edición en vivo de las metas diarias.
/// A diferencia del sheet de Ajustes, aquí los cambios se guardan al instante.
struct GoalsView: View {
    @State private var goalsStore = GoalsStore.shared

    @State private var kcal: Double = GoalsStore.shared.goals.kcal
    @State private var protein: Double = GoalsStore.shared.goals.protein
    @State private var carbs: Double = GoalsStore.shared.goals.carbs
    @State private var fat: Double = GoalsStore.shared.goals.fat
    @State private var water: Double = GoalsStore.shared.goals.waterGoal

    private var suggested: DailyGoals? {
        guard let profile = goalsStore.profile else { return nil }
        return PlanCalculator.options(for: profile).first(where: \.isRecommended)?.goals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Metas")
                    .font(.dsScreenTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                planCard
                kcalCard
                macrosCard
                infoCard
                if suggested != nil {
                    Button("Restablecer las sugeridas") {
                        resetToSuggested()
                    }
                    .font(.dsButton)
                    .foregroundStyle(Color.dsGreenText)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.dsBackground)
        .onAppear(perform: syncFromStore)
        .onChange(of: kcal) { saveIfEdited() }
        .onChange(of: protein) { saveIfEdited() }
        .onChange(of: carbs) { saveIfEdited() }
        .onChange(of: fat) { saveIfEdited() }
        .onChange(of: water) { saveIfEdited() }
    }

    private var planCard: some View {
        HStack(spacing: 12) {
            DSIcon(id: goalsStore.profile?.objective.lucideId ?? "target", size: 22, tint: .dsGreenText)
                .frame(width: 44, height: 44)
                .background(Color.dsGreenTint, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .textCase(.uppercase)
                Text(goalsStore.planName)
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                if let objective = goalsStore.profile?.objective {
                    Text(objective.title)
                        .font(.footnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var kcalCard: some View {
        VStack(spacing: 8) {
            Text("Calorías")
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
            Text("objetivo del día")
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
            GramStepper(grams: $kcal, range: 800...5000, step: 50, unit: "")
                .scaleEffect(1.15)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var macrosCard: some View {
        VStack(spacing: 1) {
            macroRow("Proteínas", value: $protein)
            macroRow("Carbohidratos", value: $carbs)
            macroRow("Grasas", value: $fat)
            waterRow
        }
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var waterRow: some View {
        HStack {
            Text("Agua")
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            GramStepper(grams: $water, range: 500...5000, step: 250, unit: "ml")
        }
        .padding(13)
    }

    private func macroRow(_ title: LocalizedStringKey, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .font(.dsRowTitle)
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            GramStepper(grams: value, range: 0...600, step: 5)
        }
        .padding(13)
    }

    @ViewBuilder
    private var infoCard: some View {
        if let suggested {
            Text("**Sugerido por tu plan** (\(goalsStore.planName)): \(Int(suggested.kcal)) kcal · \(Int(suggested.protein)) / \(Int(suggested.carbs)) / \(Int(suggested.fat)) g. Si cambias los números, el plan pasa a \"Personalizado\".")
                .font(.footnote)
                .foregroundStyle(Color.dsGreenText)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dsGreenTint, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
        }
    }

    /// El sheet de Ajustes o el onboarding pudieron cambiar las metas.
    private func syncFromStore() {
        let goals = goalsStore.goals
        kcal = goals.kcal
        protein = goals.protein
        carbs = goals.carbs
        fat = goals.fat
        water = goals.waterGoal
    }

    private func saveIfEdited() {
        let edited = DailyGoals(kcal: kcal, protein: protein, carbs: carbs, fat: fat, waterMl: water)
        if edited != goalsStore.goals {
            goalsStore.applyCustom(goals: edited)
        }
    }

    private func resetToSuggested() {
        guard let profile = goalsStore.profile,
              let plan = PlanCalculator.options(for: profile).first(where: \.isRecommended) else { return }
        goalsStore.apply(plan: plan, profile: profile)
        syncFromStore()
    }
}

#Preview {
    GoalsView()
}
