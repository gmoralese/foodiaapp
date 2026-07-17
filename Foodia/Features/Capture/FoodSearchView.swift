import SwiftUI

/// Fallback manual: si Vision no identifica el plato, el usuario lo busca aquí.
struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var onSelect: (FoodItem) -> Void

    private var results: [FoodItem] {
        NutritionDatabase.shared.search(query)
    }

    var body: some View {
        NavigationStack {
            List(results) { food in
                Button {
                    onSelect(food)
                    dismiss()
                } label: {
                    HStack {
                        Text(food.emoji)
                        Text(food.localizedName)
                        Spacer()
                        Text("\(Int(food.kcal)) kcal / 100 g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $query, prompt: "Buscar alimento")
            .navigationTitle("Elegir alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
