import SwiftUI

/// Tokens de color del design system de Foodia (canvas de Claude Design).
/// Cada token tiene variante clara/oscura en el asset catalog (ds*.colorset).
extension Color {
    // Superficies
    static let dsBackground = Color("dsBackground")
    static let dsCard = Color("dsCard")
    static let dsInset = Color("dsInset")
    static let dsInsetAlt = Color("dsInsetAlt")
    static let dsHairline = Color("dsHairline")
    static let dsBorderStrong = Color("dsBorderStrong")

    // Acento / verdes
    static let dsAccent = Color("dsAccent")
    static let dsAccentPressed = Color("dsAccentPressed")
    static let dsGreenText = Color("dsGreenText")
    static let dsGreenTint = Color("dsGreenTint")

    // Texto
    static let dsTextPrimary = Color("dsTextPrimary")
    static let dsTextSecondary = Color("dsTextSecondary")
    static let dsTextTertiary = Color("dsTextTertiary")

    // Macros (¡ojo!: P verde, C ámbar, G azul — según el diseño)
    static let dsProtein = Color("dsProtein")
    static let dsCarb = Color("dsCarb")
    static let dsFat = Color("dsFat")
    static let dsOver = Color("dsOver")

    // Semánticos
    static let dsRed = Color("dsRed")
    static let dsRedTint = Color("dsRedTint")
    static let dsWarnTint = Color("dsWarnTint")
    static let dsCloudText = Color("dsCloudText")
    static let dsCloudTint = Color("dsCloudTint")
    static let dsBarMeta = Color("dsBarMeta")
    static let dsBarOver = Color("dsBarOver")
}

/// Radios de esquina del sistema (siempre continuos).
enum DSRadius {
    static let large: CGFloat = 20
    static let card: CGFloat = 16
    static let row: CGFloat = 14
    static let thumb: CGFloat = 12
}

/// Tipografía: mapeo de los roles del diseño a estilos dinámicos del sistema.
extension Font {
    /// Título de pantalla (Hoy, Historial, Ajustes) — 32/800
    static let dsScreenTitle = Font.system(.largeTitle, design: .default, weight: .heavy)
    /// Headline de onboarding — 30/800
    static let dsHeadline = Font.system(.title, design: .default, weight: .heavy)
    /// Número grande (anillo de kcal, totales) — 26/800
    static let dsBigNumber = Font.system(.title2, design: .rounded, weight: .heavy)
    /// Header de sección — 18/700
    static let dsSection = Font.system(.headline, design: .default, weight: .bold)
    /// Botón primario — 17/600
    static let dsButton = Font.system(.body, design: .default, weight: .semibold)
    /// Título de fila — 15/600
    static let dsRowTitle = Font.system(.subheadline, design: .default, weight: .semibold)
    /// Valor trailing de fila — 15/700
    static let dsRowValue = Font.system(.subheadline, design: .default, weight: .bold)
    /// Etiqueta de sección en mayúsculas — 12/700
    static let dsSectionLabel = Font.system(.caption, design: .default, weight: .bold)
    /// Eyebrow (fecha, resumen IA) — 11-13/600-700
    static let dsEyebrow = Font.system(.footnote, design: .default, weight: .semibold)
}
