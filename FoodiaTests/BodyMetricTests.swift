import Testing

@testable import Foodia

@Suite("measurementText — formato sin decimales de más")
struct MeasurementTextTests {
    @Test("los enteros no muestran decimales")
    func integersDropDecimals() {
        #expect(measurementText(74.0) == "74")
        #expect(measurementText(100) == "100")
        #expect(measurementText(0) == "0")
    }

    @Test("los fraccionarios muestran un decimal")
    func fractionsKeepOneDecimal() {
        #expect(measurementText(74.5) == "74.5")
        #expect(measurementText(82.3) == "82.3")
    }
}

@Suite("BodyMetric — unidad, rango y lectura")
struct BodyMetricTests {
    @Test("la unidad depende de la métrica")
    func unitPerMetric() {
        #expect(BodyMetric.weight.unit == "kg")
        #expect(BodyMetric.bodyFat.unit == "%")
        #expect(BodyMetric.waist.unit == "cm")
        #expect(BodyMetric.neck.unit == "cm")
    }

    @Test("los rangos espejan los CHECK de la DB")
    func rangesMatchDatabase() {
        #expect(BodyMetric.weight.range == 30...400)
        #expect(BodyMetric.bodyFat.range == 1...70)
        #expect(BodyMetric.arm.range == 5...150)
        #expect(BodyMetric.thigh.range == 10...200)
    }

    @MainActor
    @Test("value lee el campo correcto y respeta los nil")
    func valueReadsRightField() {
        let measurement = BodyMeasurement(weightKg: 74, waistCm: 82)
        #expect(BodyMetric.weight.value(measurement) == 74)
        #expect(BodyMetric.waist.value(measurement) == 82)
        #expect(BodyMetric.hip.value(measurement) == nil)
        #expect(BodyMetric.bodyFat.value(measurement) == nil)
    }

    @Test("todas las métricas tienen título no vacío")
    func everyMetricHasTitle() {
        for metric in BodyMetric.allCases {
            #expect(!metric.title.isEmpty)
        }
    }
}
