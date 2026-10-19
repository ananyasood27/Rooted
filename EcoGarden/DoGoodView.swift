import SwiftUI

struct DoGoodView: View {
    @EnvironmentObject var appState: AppState
    @State private var showInfo = false
    @State private var showLevels = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greeting)
                        .font(Theme.body(14))
                        .foregroundColor(Theme.stone)
                        .padding(.bottom, -12)

                    CommunityLevelCard { showLevels = true }
                    WeeklyChallengeCard()

                    segmentSwitch
                        .padding(.top, 4)

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
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(
                LinearGradient(colors: [Theme.skyWash, Theme.sage.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Theme.moss)
                    }
                    .accessibilityLabel("About Rooted")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CoinBadge(amount: appState.coins)
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
        return "Good \(time), \(name)"
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

// MARK: - Community level card

struct CommunityLevelCard: View {
    @EnvironmentObject var appState: AppState
    let onTap: () -> Void

    var body: some View {
        let points = appState.communityPoints
        let level = CommunityLevel.level(forPoints: points)
        let tasksDone = appState.lifetimeCompletions.values.reduce(0, +)
        let hours = appState.volunteerLog.reduce(0) { $0 + $1.hours }

        Button(action: onTap) {
            HStack(spacing: 14) {
                LevelRing(level: level, progress: CommunityLevel.progress(forPoints: points), size: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("COMMUNITY LEVEL")
                        .font(Theme.caption(10))
                        .foregroundColor(Theme.stone)
                        .tracking(0.8)
                    Text(CommunityLevel.names[level])
                        .font(Theme.display(18, weight: .semibold))
                        .foregroundColor(Theme.bark)
                    Text("\(tasksDone) eco tasks and \(formatHours(hours)) volunteer hours, \(points) points total")
                        .font(Theme.body(12))
                        .foregroundColor(Theme.stone)
                    if let remaining = CommunityLevel.pointsToNextLevel(from: points) {
                        Text("\(remaining) more points to reach \(CommunityLevel.names[level + 1]), which adds \(CommunityLevel.unlocks[level + 1].lowercased())")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.moss)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.stone)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ecoCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows what each level unlocks")
    }
}

struct LevelRing: View {
    let level: Int
    let progress: Double
    var size: CGFloat = 54
    var light = false

    var body: some View {
        ZStack {
            Circle()
                .stroke((light ? Color.white : Theme.sage).opacity(0.3), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(Theme.sunflower, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
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
                progress: Double(tasks) / Double(challenge.ecoGoal),
                color: Theme.moss
            )
            challengeBar(
                title: "Volunteer hours",
                icon: "hand.raised.fill",
                value: "\(formatHours(min(hours, challenge.hoursGoal)))/\(formatHours(challenge.hoursGoal))",
                progress: hours / challenge.hoursGoal,
                color: Theme.petal
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
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(done ? Theme.sunflower.opacity(0.12) : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(done ? Theme.sunflower.opacity(0.5) : Theme.sage.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Theme.bark.opacity(0.05), radius: 8, y: 3)
    }

    private func challengeBar(title: String, icon: String, value: String, progress: Double, color: Color) -> some View {
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
                    Capsule().fill(Theme.sage.opacity(0.25))
                    Capsule()
                        .fill(color)
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
            .background(Theme.skyWash.ignoresSafeArea())
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
