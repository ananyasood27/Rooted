import SwiftUI
import PhotosUI

struct VolunteerSection: View {
    @EnvironmentObject var appState: AppState
    @State private var filter: VolunteerCategory? = nil
    @State private var logging: LogTarget? = nil
    @State private var banner: String? = nil
    @State private var showMap = false
    @State private var showDropOffs = true
    @State private var showHistory = false

    private var opportunities: [Opportunity] {
        guard let filter else { return Opportunity.baytown }
        return Opportunity.baytown.filter { $0.category == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let banner {
                bannerView(banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Your places")
                VStack(spacing: 14) {
                    ForEach(VolunteerCategory.allCases) { category in
                        PlaceProgressRow(
                            category: category,
                            hours: appState.volunteerHours(in: category),
                            lively: appState.isLively(category)
                        )
                    }
                }
                .padding(14)
                .ecoCard()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Opportunities near you")
                    Spacer()
                    listMapSwitch
                }
                filterChips
                if showMap {
                    CommunityMapView(filter: filter, showDropOffs: showDropOffs) { opportunity in
                        logging = LogTarget(opportunity: opportunity, category: opportunity.category)
                    }
                } else {
                    ForEach(opportunities) { opportunity in
                        OpportunityCard(opportunity: opportunity) {
                            logging = LogTarget(opportunity: opportunity, category: opportunity.category)
                        }
                    }
                }
                otherVolunteeringCard
            }

            if !appState.volunteerLog.isEmpty {
                recentSection
            }
        }
        .sheet(isPresented: $showHistory) {
            VolunteerHistoryView().environmentObject(appState)
        }
        .sheet(item: $logging) { target in
            LogHoursSheet(target: target, onSaved: showBanner)
                .environmentObject(appState)
        }
        .onAppear(perform: applyFocus)
        .onChange(of: appState.volunteerFocus) { _, _ in applyFocus() }
    }

    // Set by a building's "Find ways to help" button.
    private func applyFocus() {
        guard let focus = appState.volunteerFocus else { return }
        filter = focus
        appState.volunteerFocus = nil
    }

    private func showBanner(_ message: String) {
        withAnimation(.easeInOut(duration: 0.3)) { banner = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeInOut(duration: 0.3)) { banner = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Volunteer")
                .font(Theme.heading(22))
                .foregroundColor(Theme.bark)
            Text("Help out around Baytown. Every hour you give builds a place on your community's street.")
                .font(Theme.body(14))
                .foregroundColor(Theme.stone)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bannerView(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundColor(Theme.sunflower)
            Text(text)
                .font(Theme.display(14, weight: .semibold))
                .foregroundColor(Theme.bark)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Theme.sunflower.opacity(0.15)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(Theme.sunflower.opacity(0.35), lineWidth: 1)
        )
    }

    private var listMapSwitch: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { isMap in
                let selected = showMap == isMap
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showMap = isMap }
                } label: {
                    Label(isMap ? "Map" : "List", systemImage: isMap ? "map.fill" : "list.bullet")
                        .font(Theme.caption(11.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(selected ? Theme.moss : .clear))
                        .foregroundColor(selected ? .white : Theme.stone)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().strokeBorder(Theme.sage.opacity(0.4), lineWidth: 1))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", icon: nil, value: nil)
                ForEach(VolunteerCategory.allCases) { category in
                    chip(title: category.title, icon: category.icon, value: category)
                }
                // Only the map shows drop-off sites, so the toggle only appears there.
                if showMap {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showDropOffs.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.3.trianglepath")
                            Text("Drop-offs")
                        }
                        .font(Theme.caption(12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(showDropOffs ? Theme.soil : Theme.card))
                        .overlay(Capsule().strokeBorder(Theme.sage.opacity(showDropOffs ? 0 : 0.4), lineWidth: 1))
                        .foregroundColor(showDropOffs ? .white : Theme.bark)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, icon: String?, value: VolunteerCategory?) -> some View {
        let selected = filter == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { filter = value }
        } label: {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(Theme.caption(12))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(selected ? Theme.moss : Theme.card))
            .overlay(Capsule().strokeBorder(Theme.sage.opacity(selected ? 0 : 0.4), lineWidth: 1))
            .foregroundColor(selected ? .white : Theme.bark)
        }
        .buttonStyle(.plain)
    }

    private var otherVolunteeringCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Volunteered somewhere else?")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text("Log hours for any organization.")
                    .font(Theme.body(12.5))
                    .foregroundColor(Theme.stone)
            }
            Spacer()
            LogHoursButton {
                logging = LogTarget(opportunity: nil, category: filter ?? .animals)
            }
        }
        .padding(16)
        .ecoCard()
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Recent hours")
                Spacer()
                if appState.volunteerLog.count > 5 {
                    Button("See all \(appState.volunteerLog.count)") { showHistory = true }
                        .font(Theme.caption(12))
                        .foregroundColor(Theme.moss)
                }
            }
            VStack(spacing: 0) {
                let recent = appState.volunteerLog.sorted { $0.date > $1.date }.prefix(5)
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider().padding(.leading, 56) }
                    HStack(spacing: 12) {
                        if let file = entry.proofFileName, let photo = ProofStore.image(named: file) {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            CategoryBadge(category: entry.category, size: 32)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.organization)
                                .font(Theme.display(13.5, weight: .semibold))
                                .foregroundColor(Theme.bark)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(Theme.body(11.5))
                                .foregroundColor(Theme.stone)
                        }
                        Spacer()
                        Text("\(formatHours(entry.hours)) hrs")
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundColor(Theme.moss)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 14)
            .ecoCard()
        }
    }
}

// opportunity == nil means "somewhere else"
private struct LogTarget: Identifiable {
    let id = UUID()
    let opportunity: Opportunity?
    let category: VolunteerCategory
}

struct CategoryBadge: View {
    let category: VolunteerCategory
    var size: CGFloat = 40

    var body: some View {
        IconTile(systemName: category.icon, tint: category.color, size: size)
    }
}

struct LogHoursButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Log hours", systemImage: "plus")
                .font(Theme.caption(12))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.moss))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct PlaceProgressRow: View {
    let category: VolunteerCategory
    let hours: Double
    let lively: Bool

    private var level: Int { VolunteerCategory.level(forHours: hours) }

    private var progress: Double {
        let thresholds = VolunteerCategory.hourThresholds
        guard level + 1 < thresholds.count else { return 1 }
        let start = thresholds[level]
        let end = thresholds[level + 1]
        return (hours - start) / (end - start)
    }

    private var status: (text: String, color: Color) {
        if level == 0 { return ("Empty lot", Theme.stone) }
        return lively ? ("Lively", Theme.moss) : ("Quiet", Theme.ember)
    }

    private var detail: String {
        var text = "\(formatHours(hours)) hrs · \(VolunteerCategory.stageNames[level])"
        if let remaining = VolunteerCategory.hoursToNextLevel(from: hours) {
            text += " · \(formatHours(remaining)) to \(VolunteerCategory.stageNames[level + 1])"
        }
        return text
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(category.buildingName)
                        .font(Theme.display(14, weight: .semibold))
                        .foregroundColor(Theme.bark)
                    Spacer()
                    Text(status.text)
                        .font(Theme.caption(10.5))
                        .foregroundColor(status.color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.sage.opacity(0.25))
                        Capsule()
                            .fill(category.color)
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 5)
                Text(detail)
                    .font(Theme.body(11.5))
                    .foregroundColor(Theme.stone)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OpportunityCard: View {
    let opportunity: Opportunity
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                CategoryBadge(category: opportunity.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(opportunity.organization.uppercased())
                        .font(Theme.caption(10))
                        .foregroundColor(Theme.stone)
                        .tracking(0.5)
                    Text(opportunity.title)
                        .font(Theme.display(15, weight: .semibold))
                        .foregroundColor(Theme.bark)
                }
            }

            Text(opportunity.details)
                .font(Theme.body(13))
                .foregroundColor(Theme.stone)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Label(opportunity.location, systemImage: "mappin.and.ellipse")
                Label(opportunity.ageNote, systemImage: "person.2.fill")
            }
            .font(Theme.body(12))
            .foregroundColor(Theme.stone)

            HStack {
                if let url = URL(string: opportunity.url) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Open page")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.caption(12))
                        .foregroundColor(Theme.moss)
                    }
                }
                Spacer()
                LogHoursButton(action: onLog)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ecoCard(tint: opportunity.category.color)
    }
}

private struct LogHoursSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let target: LogTarget
    let onSaved: (String) -> Void

    @State private var category: VolunteerCategory
    @State private var organization: String
    @State private var hours: Double = 1
    @State private var date = Date()
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoFile: String? = nil
    @State private var loadingPhoto = false
    @State private var photoFailed = false
    @State private var didSave = false

    init(target: LogTarget, onSaved: @escaping (String) -> Void) {
        self.target = target
        self.onSaved = onSaved
        _category = State(initialValue: target.category)
        _organization = State(initialValue: target.opportunity?.organization ?? "")
    }

    // You can log up to two months back, but not in the future.
    private var dateRange: ClosedRange<Date> {
        (Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date())...Date()
    }

    private var coinsEarned: Int {
        Int((hours * Double(AppState.coinsPerVolunteerHour)).rounded())
    }

    private var canSave: Bool {
        !organization.trimmingCharacters(in: .whitespaces).isEmpty && !loadingPhoto
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let opportunity = target.opportunity {
                        HStack(spacing: 12) {
                            CategoryBadge(category: opportunity.category, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opportunity.organization.uppercased())
                                    .font(Theme.caption(10))
                                    .foregroundColor(Theme.stone)
                                    .tracking(0.5)
                                Text(opportunity.title)
                                    .font(Theme.display(19, weight: .semibold))
                                    .foregroundColor(Theme.bark)
                            }
                        }
                    } else {
                        EcoField(label: "Organization", prompt: "Where did you volunteer?", text: $organization)
                        categoryPicker
                    }

                    hoursPicker

                    DatePicker("Date", selection: $date, in: dateRange, displayedComponents: .date)
                        .font(Theme.body(15))
                        .foregroundColor(Theme.bark)
                        .padding(14)
                        .ecoCard()

                    photoPicker

                    HStack(spacing: 6) {
                        Circle().fill(Theme.sunflower).frame(width: 14, height: 14)
                        Text("+\(coinsEarned) coins · builds your \(category.buildingName)")
                            .font(Theme.caption(12))
                            .foregroundColor(Theme.stone)
                    }

                    Button("Save hours", action: save)
                        .buttonStyle(EcoPrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle("Log volunteering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, item in loadPhoto(item) }
            // delete the photo if they cancel, otherwise it stays on the phone
            .onDisappear {
                if !didSave, let photoFile { ProofStore.delete(named: photoFile) }
            }
            .alert("Couldn't use that photo", isPresented: $photoFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Try a different photo, or save without one.")
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT KIND OF HELP")
                .font(Theme.caption(11))
                .foregroundColor(Theme.stone)
                .tracking(0.5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VolunteerCategory.allCases) { option in
                        let selected = option == category
                        Button {
                            category = option
                        } label: {
                            Label(option.title, systemImage: option.icon)
                                .font(Theme.caption(12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selected ? Theme.moss : Theme.card))
                                .overlay(Capsule().strokeBorder(Theme.sage.opacity(selected ? 0 : 0.4), lineWidth: 1))
                                .foregroundColor(selected ? .white : Theme.bark)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var hoursPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOURS")
                .font(Theme.caption(11))
                .foregroundColor(Theme.stone)
                .tracking(0.5)
            HStack {
                Text("\(formatHours(hours)) \(hours == 1 ? "hour" : "hours")")
                    .font(Theme.heading(22))
                    .foregroundColor(Theme.bark)
                Spacer()
                Stepper("Hours", value: $hours, in: 0.5...8, step: 0.5)
                    .labelsHidden()
            }
            .padding(14)
            .ecoCard()
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 12) {
                Group {
                    if let photoFile, let photo = ProofStore.image(named: photoFile) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Theme.sage.opacity(0.2)
                            if loadingPhoto {
                                ProgressView()
                            } else {
                                Image(systemName: "camera.fill").foregroundColor(Theme.moss)
                            }
                        }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(photoFile == nil ? "Add a photo" : "Change photo")
                        .font(Theme.display(14, weight: .semibold))
                        .foregroundColor(Theme.bark)
                    Text("Optional. Add a picture from the day.")
                        .font(Theme.body(12))
                        .foregroundColor(Theme.stone)
                }
                Spacer()
            }
            .padding(14)
            .ecoCard()
        }
        .buttonStyle(.plain)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        loadingPhoto = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let file = await Task.detached { data.flatMap(ProofStore.save) }.value
            loadingPhoto = false
            photoItem = nil
            guard let file else {
                photoFailed = true
                return
            }
            if let old = photoFile { ProofStore.delete(named: old) }
            photoFile = file
        }
    }

    private func save() {
        let levelBefore = VolunteerCategory.level(forHours: appState.volunteerHours(in: category))
        appState.logVolunteering(
            category: category,
            organization: organization.trimmingCharacters(in: .whitespaces),
            opportunityID: target.opportunity?.id,
            hours: hours,
            date: date,
            proofFile: photoFile
        )
        didSave = true
        let levelAfter = VolunteerCategory.level(forHours: appState.volunteerHours(in: category))

        if levelAfter > levelBefore {
            onSaved("Your \(category.buildingName) is now \(VolunteerCategory.stageNames[levelAfter])! Go see it in Community.")
        } else {
            onSaved("Logged \(formatHours(hours)) hrs · +\(coinsEarned) coins")
        }
        dismiss()
    }
}

// All logged volunteer hours with totals. Can be used as a service hours record.
struct VolunteerHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var photoOnDisplay: ProofPhoto? = nil

    private var entries: [VolunteerEntry] {
        appState.volunteerLog.sorted { $0.date > $1.date }
    }

    private func hoursLabel(_ hours: Double) -> String {
        "\(formatHours(hours)) \(hours == 1 ? "hr" : "hrs")"
    }

    private var totalHours: Double {
        entries.reduce(0) { $0 + $1.hours }
    }

    // Newest month first, entries newest first inside each month.
    private var months: [(title: String, entries: [VolunteerEntry])] {
        var groups: [(title: String, entries: [VolunteerEntry])] = []
        for entry in entries {
            let title = entry.date.formatted(.dateTime.month(.wide).year())
            if groups.last?.title == title {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((title: title, entries: [entry]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    totals

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "By place")
                        VStack(spacing: 0) {
                            let used = VolunteerCategory.allCases.filter { appState.volunteerHours(in: $0) > 0 }
                            ForEach(Array(used.enumerated()), id: \.element) { index, category in
                                if index > 0 { Divider().padding(.leading, 52) }
                                HStack(spacing: 12) {
                                    CategoryBadge(category: category, size: 36)
                                    Text(category.buildingName)
                                        .font(Theme.display(14, weight: .semibold))
                                        .foregroundColor(Theme.bark)
                                    Spacer()
                                    Text(hoursLabel(appState.volunteerHours(in: category)))
                                        .font(Theme.display(13, weight: .semibold))
                                        .foregroundColor(Theme.moss)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 14)
                        .ecoCard()
                    }

                    ForEach(months, id: \.title) { month in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SectionLabel(text: month.title)
                                Spacer()
                                Text(hoursLabel(month.entries.reduce(0) { $0 + $1.hours }))
                                    .font(Theme.caption(11))
                                    .foregroundColor(Theme.stone)
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(month.entries.enumerated()), id: \.element.id) { index, entry in
                                    if index > 0 { Divider().padding(.leading, 56) }
                                    entryRow(entry)
                                }
                            }
                            .padding(.horizontal, 14)
                            .ecoCard()
                        }
                    }
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle("Volunteer History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $photoOnDisplay) { photo in
                ProofViewer(proof: photo)
            }
        }
    }

    private var totals: some View {
        HStack(spacing: 0) {
            totalItem(formatHours(totalHours), totalHours == 1 ? "hour" : "hours")
            Divider().frame(height: 36)
            totalItem("\(entries.count)", entries.count == 1 ? "time" : "times")
            Divider().frame(height: 36)
            totalItem("\(Set(entries.map(\.organization)).count)", "places")
        }
        .padding(.vertical, 16)
        .ecoCard()
    }

    private func totalItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.heading(24))
                .foregroundColor(Theme.bark)
            Text(label)
                .font(Theme.caption(11))
                .foregroundColor(Theme.stone)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func entryRow(_ entry: VolunteerEntry) -> some View {
        HStack(spacing: 12) {
            if let file = entry.proofFileName, let photo = ProofStore.image(named: file) {
                Button {
                    photoOnDisplay = ProofPhoto(fileName: file, title: entry.organization)
                } label: {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View photo from \(entry.organization)")
            } else {
                CategoryBadge(category: entry.category, size: 34)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.organization)
                    .font(Theme.display(13.5, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text("\(entry.category.buildingName) · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(Theme.body(11.5))
                    .foregroundColor(Theme.stone)
            }
            Spacer()
            Text(hoursLabel(entry.hours))
                .font(Theme.display(13, weight: .semibold))
                .foregroundColor(Theme.moss)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    ScrollView { VolunteerSection().padding() }.environmentObject(AppState())
}
