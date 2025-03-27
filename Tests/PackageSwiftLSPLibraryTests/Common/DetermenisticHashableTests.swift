@testable import PackageSwiftLSPLibrary
import Testing

@Test
func arrayOfDeterministicHashableValueAlwaysReturnsSameHashToAnyOrder() {
    let value1 = DeterministicHashableValue(value: 1)
    let value2 = DeterministicHashableValue(value: 2)
    let value3 = DeterministicHashableValue(value: 3)

    #expect(
        [value1, value2, value3].deterministicHashValue == [value3, value2, value1].deterministicHashValue,
        "Expected same hash for different order of values"
    )
}

private struct DeterministicHashableValue: DeterministicHashable {
    let value: Int

    var deterministicHashValue: String {
        "DeterministicHashableValue(\(value))"
    }
}
