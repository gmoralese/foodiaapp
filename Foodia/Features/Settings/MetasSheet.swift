import SwiftUI

/// Sheet "Metas diarias": kcal objetivo + steppers de macros.
/// Editar a mano convierte el plan en "Personalizado".
struct MetasSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kcal: Double = GoalsStore.shared.goals.kcal
    @State private var protein: Double = GoalsStore.shared.goals.protein
    @State private var carbs: Double = GoalsStore.shared.goals.carbs
    @State private var fat: Double = GoalsStore.shared.goals.fat
    @State private var water: Double = GoalsStore.shared.goals.waterGoal

    private var suggested: DailyGoals? {
        guard let profile = GoalsStore.shared.profile else { return nil }
        return PlanCalculator.options(for: profile).first(where: \.isRecommended)?.goals
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(.top, 8)
            }
            .background(Color.dsBackground)
            .navigationTitle("Metas diarias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .tint(Color.dsGreenText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                        dismiss()
                    }
                    .tint(Color.dsGreenText)
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
            Text("**Sugerido por tu plan** (\(GoalsStore.shared.planName)): \(Int(suggested.kcal)) kcal · \(Int(suggested.protein)) / \(Int(suggested.carbs)) / \(Int(suggested.fat)) g. Si cambias los números, el plan pasa a \"Personalizado\".")
                .font(.footnote)
                .foregroundStyle(Color.dsGreenText)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dsGreenTint, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
        }
    }

    private func save() {
        let edited = DailyGoals(kcal: kcal, protein: protein, carbs: carbs, fat: fat, waterMl: water)
        if edited != GoalsStore.shared.goals {
            GoalsStore.shared.applyCustom(goals: edited)
        }
    }

    private func resetToSuggested() {
        guard let profile = GoalsStore.shared.profile,
              let plan = PlanCalculator.options(for: profile).first(where: \.isRecommended) else { return }
        kcal = plan.goals.kcal
        protein = plan.goals.protein
        carbs = plan.goals.carbs
        fat = plan.goals.fat
        GoalsStore.shared.apply(plan: plan, profile: profile)
    }
}
