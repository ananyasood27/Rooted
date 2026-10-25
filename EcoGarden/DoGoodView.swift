import SwiftUI

struct DoGoodView: View {
    @EnvironmentObject var appState: AppState
    @State private var showInfo = false
    @State private var showLevels = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(greeting)
                            .font(Theme.heading(24))
                            .foregroundColor(.white)
                        Text("What will you do for Baytown today?")
                            .font(Theme.body(14))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // kept small so you can see the tasks. Tap for the full details
                    HStack(spacing: 10) {
                        CommunityLevelTile { showLevels = true }
                        WeeklyChallengeTile { showLevels = true }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .greenHeader()

                VStack(alignment: .leading, spacing: 20) {
                    segmentSwitch

                    switch appState.doGoodSegment {
                    case .habits: HabitsSection()
                    case .volunteer: VolunteerSection()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Your impact so far")
                        ImpactTiles(impact: appState.impact)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(ScreenBackground())
            .greenNavigationBar()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                HeaderToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 19))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .accessibilityLabel("About Rooted")
                }
                HeaderToolbarItem(placement: .navigationBarTrailing) {
                    CoinBadge(amount: appState.coins, onDark: true)
                }
            }
            .sheet(isPresented: $showInfo) {
                InfoView().environmentObject(appState)
            }
            .sheet(isPresented: $showLevels) {
                CommunityLevelSheet().environmentObject(appState)
            }
        }
    }

    private var greeting: String {
        let name = appState.userName.isEmpty ? "there" : appState.userName
        let hour = Calendar.current.component(.hour, from: Date())
        let time = hour < 12 ? "Morning" : (hour < 18 ? "Afternoon" : "Evening")
        return "Good \(time.lowercased()), \(name)"
    }

    private var segmentSwitch: some View {
        HStack(spacing: 0) {
            segmentButton("Eco Habits", icon: "leaf.fill", value: .habits)
            segmentButton("Volunteer", icon: "hand.raised.fill", value: .volunteer)
        }
        .padding(3)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().strokeBorder(Theme.sage.opacity(0.4), lineWidth: 1))
    }

    private func segmentButton(_ title: String, icon: String, value: DoGoodSegment) -> some View {
        let selected = appState.doGoodSegment == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { appState.doGoodSegment = value }
        } label: {
            Label(title, systemImage: icon)
                .font(Theme.display(14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? Theme.moss : .clear))
                .foregroundColor(selected ? .white : Theme.stone)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary tiles

struct CommunityLevelTile: View {
    @EnvironmentObject var appState: AppState
    let onTap: () -> Void

    var body: some View {
        let points = appState.communityPoints
        let level = CommunityLevel.level(forPoints: points)

        Button(action: onTap) {
            HStack(spacing: 10) {
                LevelRing(level: level, progress: CommunityLevel.progress(forPoints: points), size: 34, light: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(CommunityLevel.names[level])
                        .font(Theme.display(13.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(CommunityLevel.pointsToNextLevel(from: points).map { "\($0) pts to next level" } ?? "Top level reached")
                        .font(Theme.body(11))
                        .opacity(0.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(.white)
                Spacer(minLength: 0)
            }
            .summaryTile()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your community level and what each level unlocks")
    }
}

struct WeeklyChallengeTile: View {
    @EnvironmentObject var appState: AppState
    let onTap: () -> Void

    var body: some View {
        let challenge = appState.weeklyChallenge
        let done = appState.weeklyChallengeDone
        let tasks = appState.ecoTasksThisWeek
        let hours = appState.volunteerHoursThisWeek

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.sunflower)
                    }
                    Text(done ? "Challenge done" : "Weekly challenge")
                        .font(Theme.display(13.5))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                // One bar: both halves count equally.
                miniBar(progress: (min(Double(tasks) / Double(challenge.ecoGoal), 1) + min(hours / challenge.hoursGoal, 1)) / 2)
                Text("\(min(tasks, challenge.ecoGoal))/\(challenge.ecoGoal) tasks · \(formatHours(min(hours, challenge.hoursGoal)))/\(formatHours(challenge.hoursGoal)) hrs")
                    .font(Theme.body(11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .summaryTile()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows this week's challenge")
    }

    private func miniBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(Theme.sunflower).frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 4)
    }
}

private extension View {
    // lighter green so it matches the header
    func summaryTile() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.1))
            )
    }
}

struct LevelRing: View {
    let level: Int
    let progress: Double
    var size: CGFloat = 54
    var light = false
    var accent: Color = Theme.sunflower

    var body: some View {
        ZStack {
            Circle()
                .stroke((light ? Color.white : Theme.sage).opacity(0.3), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(accent, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(level + 1)")
                .font(Theme.display(size * 0.4, weight: .bold))
                .foregroundColor(light ? .white : Theme.bark)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Community level \(level + 1)")
    }
}

// MARK: - Weekly challenge card

struct WeeklyChallengeCard: View {
    @EnvironmentObject var appState: AppState

    private var daysLeft: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return max(0, Int(ceil(week.end.timeIntervalSince(Date()) / 86_400)))
    }

    var body: some View {
        let challenge = appState.weeklyChallenge
        let done = appState.weeklyChallengeDone
        let tasks = appState.ecoTasksThisWeek
        let hours = appState.volunteerHoursThisWeek

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This week's challenge", systemImage: "flag.checkered")
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Spacer()
                Text(done ? "Complete!" : "\(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                    .font(Theme.caption(11))
                    .foregroundColor(done ? Theme.moss : Theme.stone)
            }

            Text("Do \(challenge.ecoGoal) eco tasks and volunteer \(formatHours(challenge.hoursGoal)) hour\(challenge.hoursGoal == 1 ? "" : "s").")
                .font(Theme.body(13))
                .foregroundColor(Theme.stone)

            challengeBar(
                title: "Eco tasks",
                icon: "leaf.fill",
                value: "\(min(tasks, challenge.ecoGoal))/\(challenge.ecoGoal)",
                progress: Double(tasks) / Double(challenge.ecoGoal)
            )
            challengeBar(
                title: "Volunteer hours",
                icon: "hand.raised.fill",
                value: "\(formatHours(min(hours, challenge.hoursGoal)))/\(formatHours(challenge.hoursGoal))",
                progress: hours / challenge.hoursGoal
            )

            HStack(spacing: 6) {
                Circle().fill(Theme.sunflower).frame(width: 12, height: 12)
                Text(done
                     ? "You earned +\(WeeklyChallenge.rewardCoins) coins and +\(WeeklyChallenge.rewardPoints) community points"
                     : "Reward: +\(WeeklyChallenge.rewardCoins) coins and +\(WeeklyChallenge.rewardPoints) community points")
                    .font(Theme.caption(11))
                    .foregroundColor(Theme.stone)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ecoCard()
    }

    private func challengeBar(title: String, icon: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(title, systemImage: icon)
                    .font(Theme.caption(12))
                    .foregroundColor(Theme.bark)
                Spacer()
                Text(value)
                    .font(Theme.caption(12))
                    .foregroundColor(Theme.stone)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.forest.opacity(0.08))
                    Capsule()
                        .fill(Theme.sunflower)
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Level sheet

struct CommunityLevelSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let points = appState.communityPoints
        let level = CommunityLevel.level(forPoints: points)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WeeklyChallengeCard()

                    HStack(spacing: 16) {
                        LevelRing(level: level, progress: CommunityLevel.progress(forPoints: points), size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CommunityLevel.names[level])
                                .font(Theme.display(20, weight: .semibold))
                                .foregroundColor(Theme.bark)
                            Text("\(points) community points")
                                .font(Theme.body(13))
                                .foregroundColor(Theme.stone)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "How you earn points")
                        VStack(alignment: .leading, spacing: 10) {
                            Label("\(CommunityLevel.pointsPerTask) point for every eco task", systemImage: "leaf.fill")
                            Label("\(CommunityLevel.pointsPerVolunteerHour) points for every volunteer hour", systemImage: "hand.raised.fill")
                            Label("\(WeeklyChallenge.rewardPoints) bonus points for each weekly challenge", systemImage: "flag.checkered")
                        }
                        .font(Theme.body(13.5))
                        .foregroundColor(Theme.bark)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ecoCard()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Levels")
                        VStack(spacing: 0) {
                            ForEach(CommunityLevel.names.indices, id: \.self) { index in
                                if index > 0 { Divider() }
                                levelRow(index, reached: index <= level)
                            }
                        }
                        .padding(.horizontal, 16)
                        .ecoCard()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Street upgrades from your habits")
                        VStack(spacing: 0) {
                            ForEach(Array(EcoTaskKind.allCases.enumerated()), id: \.element) { index, kind in
                                if index > 0 { Divider() }
                                upgradeRow(kind)
                            }
                        }
                        .padding(.horizontal, 16)
                        .ecoCard()
                    }
                }
                .padding(20)
            }
            .background(ScreenBackground())
            .navigationTitle("Your Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func levelRow(_ index: Int, reached: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                .foregroundColor(reached ? Theme.moss : Theme.stone.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(index + 1). \(CommunityLevel.names[index])")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundColor(reached ? Theme.bark : Theme.stone)
                Text(index == 0 ? "Where every street starts" : "\(CommunityLevel.thresholds[index]) pts · \(CommunityLevel.unlocks[index])")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.stone)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func upgradeRow(_ kind: EcoTaskKind) -> some View {
        let count = appState.lifetimeCompletions[kind.rawValue] ?? 0
        let tier = kind.upgradeTier(forCount: count)
        let detail: String
        if tier < EcoTaskKind.upgradeThresholds.count {
            let needed = EcoTaskKind.upgradeThresholds[tier] - count
            detail = "\(needed) more \(kind.habitPhrase) for \(kind.upgradeNames[tier])"
        } else {
            detail = "Fully upgraded"
        }
        return HStack(spacing: 12) {
            Image(systemName: tier > 0 ? "checkmark.seal.fill" : "seal")
                .foregroundColor(tier > 0 ? Theme.moss : Theme.stone.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(tier > 0 ? kind.upgradeNames[tier - 1] : kind.upgradeNames[0])
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundColor(tier > 0 ? Theme.bark : Theme.stone)
                Text(detail)
                    .font(Theme.body(12))
                    .foregroundColor(Theme.stone)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    DoGoodView().environmentObject(AppState())
}
