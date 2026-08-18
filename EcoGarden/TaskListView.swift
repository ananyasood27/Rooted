import SwiftUI
import PhotosUI

struct TaskListView: View {
    @EnvironmentObject var appState: AppState

    @State private var taskPendingPhoto: EcoTask? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showProofChoice: EcoTask? = nil
    @State private var showInfo = false
    @State private var expandedTaskID: UUID? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if appState.justEarnedFullClearBonus {
                        celebrationBanner
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("TODAY")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.stone)
                            .tracking(1)
                            .padding(.leading, 2)

                        VStack(spacing: 10) {
                            ForEach(appState.tasks) { task in
                                TaskRow(
                                    task: task,
                                    nextReward: appState.nextReward(for: task),
                                    isExpanded: expandedTaskID == task.id,
                                    onComplete: { showProofChoice = task },
                                    onToggleExpand: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            expandedTaskID = (expandedTaskID == task.id) ? nil : task.id
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(
                LinearGradient(
                    colors: [Theme.skyWash, Theme.sage.opacity(0.12)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Theme.moss)
                    }
                    .accessibilityLabel("About EcoGarden")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CoinBadge(amount: appState.coins)
                }
            }
            .sheet(isPresented: $showInfo) {
                InfoView().environmentObject(appState)
            }
            .confirmationDialog(
                "Add a photo as proof?",
                isPresented: Binding(
                    get: { showProofChoice != nil },
                    set: { if !$0 { showProofChoice = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Attach Photo") {
                    taskPendingPhoto = showProofChoice
                    showProofChoice = nil
                }
                Button("Mark Complete (No Photo)") {
                    if let task = showProofChoice {
                        appState.completeTask(task, proofImage: nil)
                    }
                    showProofChoice = nil
                }
                Button("Cancel", role: .cancel) {
                    showProofChoice = nil
                }
            }
            .photosPicker(
                isPresented: Binding(
                    get: { taskPendingPhoto != nil },
                    set: { if !$0 { taskPendingPhoto = nil } }
                ),
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { newItem in
                guard let task = taskPendingPhoto, let newItem else { return }
                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    appState.completeTask(task, proofImage: data)
                    taskPendingPhoto = nil
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(Theme.body(14))
                .foregroundColor(Theme.stone)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(appState.allTasksCompletedToday ? "All tasks done today" : "\(completedCount) of \(appState.tasks.count) done")
                    .font(Theme.display(26))
                    .foregroundColor(Theme.bark)

                if appState.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.20))
                        Text("\(appState.streak)")
                            .font(Theme.display(14, weight: .semibold))
                            .foregroundColor(Theme.bark)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.45, blue: 0.20).opacity(0.14)))
                }
            }

            ProgressBar(progress: appState.tasks.isEmpty ? 0 : Double(completedCount) / Double(appState.tasks.count))
                .frame(height: 6)
                .padding(.top, 2)

            Text("Tasks repeat — do one again today for a bigger bonus.")
                .font(Theme.body(12.5))
                .foregroundColor(Theme.stone)
        }
        .padding(.bottom, 2)
    }

    private var celebrationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(Theme.sunflower)
            VStack(alignment: .leading, spacing: 2) {
                Text("Full clear bonus: +20 coins")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundColor(Theme.bark)
                Text(appState.streak > 1 ? "\(appState.streak)-day streak — keep it going." : "Streak started. Come back tomorrow.")
                    .font(Theme.body(12.5))
                    .foregroundColor(Theme.stone)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Theme.sunflower.opacity(0.15)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(Theme.sunflower.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation { appState.justEarnedFullClearBonus = false }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: appState.justEarnedFullClearBonus)
    }

    private var completedCount: Int {
        appState.tasks.filter { $0.completionsToday >= 1 }.count
    }

    private var greeting: String {
        let name = appState.userName.isEmpty ? "there" : appState.userName
        let hour = Calendar.current.component(.hour, from: Date())
        let time = hour < 12 ? "Morning" : (hour < 18 ? "Afternoon" : "Evening")
        return "Good \(time), \(name)"
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.sage.opacity(0.25))
                Capsule()
                    .fill(LinearGradient(colors: [Theme.moss, Theme.sage], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
    }
}

private struct TaskRow: View {
    let task: EcoTask
    let nextReward: Int
    let isExpanded: Bool
    let onComplete: () -> Void
    let onToggleExpand: () -> Void

    private var done: Bool { task.completionsToday >= 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.moss.opacity(0.14) : Theme.sage.opacity(0.20))
                        .frame(width: 46, height: 46)
                    Image(systemName: task.icon)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(done ? Theme.moss : Theme.soil)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.display(15, weight: .semibold))
                        .foregroundColor(Theme.bark)
                    Text(task.description)
                        .font(Theme.body(12.5))
                        .foregroundColor(Theme.stone)
                        .lineLimit(2)

                    if task.completionsToday > 0 {
                        Text("Done \(task.completionsToday)× today")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.moss)
                    }
                }

                Spacer(minLength: 8)

                Button(action: onComplete) {
                    VStack(spacing: 1) {
                        Text("+\(nextReward)")
                            .font(Theme.display(13, weight: .semibold))
                        if task.completionsToday > 0 {
                            Text("combo").font(Theme.caption(9))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(done ? Theme.sunflower.opacity(0.85) : Theme.moss))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { if !task.localTip.isEmpty { onToggleExpand() } }

            if isExpanded && !task.localTip.isEmpty {
                Divider().padding(.horizontal, 14)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.moss)
                        .padding(.top, 1)
                    Text(task.localTip)
                        .font(Theme.body(12))
                        .foregroundColor(Theme.stone)
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if !task.localTip.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    Text("Local tip")
                        .font(Theme.caption(10))
                }
                .foregroundColor(Theme.moss.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.sage.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Theme.bark.opacity(0.05), radius: 8, y: 3)
    }
}

#Preview {
    TaskListView().environmentObject(AppState())
}
