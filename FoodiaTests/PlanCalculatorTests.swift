import Testing

@testable import Foodia

@Suite("PlanCalculator — Mifflin-St Jeor")
struct PlanCalculatorTests {
    /// Perfil base: 72 kg, 175 cm, 28 años. base MSJ = 10·72 + 6,25·175 − 5·28 = 1673,75.
    private func profile(
        sex: Sex = .unspecified,
        activity: ActivityLevel = .moderate,
        sports: [String] = [],
        objective: GoalObjective = .deficit
    ) -> UserProfile {
        UserProfile(
            sex: sex, age: 28, weightKg: 72, heightCm: 175,
            activity: activity, sports: sports, objective: objective
        )
    }

    @Test("BMR aplica el término de sexo de Mifflin-St Jeor")
    func bmrPerSex() {
        #expect(abs(PlanCalculator.bmr(for: profile(sex: .male)) - 1678.75) < 0.001)
        #expect(abs(PlanCalculator.bmr(for: profile(sex: .female)) - 1512.75) < 0.001)
        #expect(abs(PlanCalculator.bmr(for: profile(sex: .unspecified)) - 1595.75) < 0.001)
    }

    @Test("TDEE multiplica el BMR por el factor de actividad")
    func tdeeAppliesActivityFactor() {
        let p = profile(sex: .male, activity: .moderate) // factor 1,55
        #expect(abs(PlanCalculator.tdee(for: p) - 1678.75 * 1.55) < 0.001)

        let sedentary = profile(sex: .male, activity: .sedentary) // factor 1,2
        #expect(abs(PlanCalculator.tdee(for: sedentary) - 1678.75 * 1.2) < 0.001)
    }

    @Test("goals: proteína 1,8 g/kg, grasa 0,8 g/kg, resto en carbos")
    func goalsMacroSplitDefault() {
        let goals = PlanCalculator.goals(for: profile(), kcal: 2000)
        // proteína 129,6 → 130 · grasa 57,6 → 60 · carbos 240,8 → 240 · kcal → 2000
        #expect(goals == DailyGoals(kcal: 2000, protein: 130, carbs: 240, fat: 60))
    }

    @Test("goals: entrenar fuerza sube la proteína a 2,0 g/kg")
    func goalsMoreProteinForStrength() {
        let goals = PlanCalculator.goals(for: profile(sports: ["Fuerza"]), kcal: 2000)
        // proteína 144 → 145 · grasa 60 · carbos 226,4 → 225
        #expect(goals == DailyGoals(kcal: 2000, protein: 145, carbs: 225, fat: 60))
    }

    @Test("goals redondea las kcal al múltiplo de 50 más cercano")
    func goalsRoundsKcalToNearest50() {
        #expect(PlanCalculator.goals(for: profile(), kcal: 1975).kcal == 2000)
        #expect(PlanCalculator.goals(for: profile(), kcal: 1974).kcal == 1950)
    }

    @Test("options: cada objetivo ofrece exactamente un plan recomendado")
    func optionsHaveExactlyOneRecommended() {
        for objective in GoalObjective.allCases {
            let options = PlanCalculator.options(for: profile(objective: objective))
            #expect(!options.isEmpty)
            #expect(options.filter(\.isRecommended).count == 1)
        }
    }

    @Test("options: la cantidad de planes depende del objetivo")
    func optionsCountPerObjective() {
        #expect(PlanCalculator.options(for: profile(objective: .deficit)).count == 3)
        #expect(PlanCalculator.options(for: profile(objective: .maintenance)).count == 1)
        #expect(PlanCalculator.options(for: profile(objective: .surplus)).count == 2)
        #expect(PlanCalculator.options(for: profile(objective: .medical)).count == 1)
    }

    @Test("déficit: el plan recomendado apunta al 80% del mantenimiento")
    func deficitRecommendedTargetsEightyPercent() {
        let p = profile(objective: .deficit) // TDEE 2473,4125 · ·0,8 = 1978,73 → 2000
        let recommended = PlanCalculator.options(for: p).first { $0.isRecommended }
        #expect(recommended?.goals.kcal == 2000)
    }
}
