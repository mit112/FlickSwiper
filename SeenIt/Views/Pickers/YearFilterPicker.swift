import SwiftUI

/// Year range filter picker view
struct YearFilterPicker: View {
    @Binding var yearMin: Int?
    @Binding var yearMax: Int?
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMinYear: Int = 1970
    @State private var selectedMaxYear: Int = 2025
    @State private var useMinYear: Bool = false
    @State private var useMaxYear: Bool = false
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let startYear = 1920
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("From Year", isOn: $useMinYear)
                    
                    if useMinYear {
                        Picker("From", selection: $selectedMinYear) {
                            ForEach((startYear...currentYear).reversed(), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }
                
                Section {
                    Toggle("To Year", isOn: $useMaxYear)
                    
                    if useMaxYear {
                        Picker("To", selection: $selectedMaxYear) {
                            ForEach((startYear...currentYear).reversed(), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }
                
                Section {
                    Button("Clear Filter", role: .destructive) {
                        yearMin = nil
                        yearMax = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Filter by Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        yearMin = useMinYear ? selectedMinYear : nil
                        yearMax = useMaxYear ? selectedMaxYear : nil
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Initialize from existing values
                if let min = yearMin {
                    selectedMinYear = min
                    useMinYear = true
                }
                if let max = yearMax {
                    selectedMaxYear = max
                    useMaxYear = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    YearFilterPicker(yearMin: .constant(2000), yearMax: .constant(2024))
}
