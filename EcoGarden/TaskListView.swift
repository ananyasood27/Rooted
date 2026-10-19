import SwiftUI
import PhotosUI

struct HabitsSection: View {
    @EnvironmentObject var appState: AppState

    @State private var taskPendingPhoto: EcoTask? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    @State private var photoFailed = false
    @State private var proofOnDisplay: ProofPhoto? = nil
    @State private var expandedTaskID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if appState.justEarnedFullClearBonus {
                celebrationBanner
            }

            VStack(alignment: .leading, spacing: 10) {

                VStack(spacing: 10) {
                    ForEach(appState.tasks) { task in
                        TaskRow(
                            task: task,
                            nextReward: appState.nextReward(for: task),
                            streetText: streetText(for: task),
                            isExpanded: expandedTaskID == task.id,
                            onAttachPhoto: {
                                taskPendingPhoto = task
                                // Wait for the dialog to close or the picker may not open.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showPhotoPicker = true }
                            },
                            onCompleteWithoutPhoto: { appState.completeTask(task, proofFile: nil) },
                            onShowProof: {
                                if let fileName = task.proofFileName {
                                    proofOnDisplay = ProofPhoto(fileName: fileName, title: task.title)
                                }
                            },
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
        // Kept separate from taskPendingPhoto because the picker closes before the selection arrives.
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem, let task = taskPendingPhoto else { return }
            selectedPhotoItem = nil
            taskPendingPhoto = nil
            Task {
                let data = try? await newItem.loadTransferable(type: Data.self)
                // Resize off the main thread.
                let fileName = await Task.detached { data.flatMap(ProofStore.save) }.value
                if let fileName {
                    appState.completeTask(task, proofFile: fileName)
                } else {
                    photoFailed = true
                }
            }
        }
        .alert("Couldn't use that photo", isPresented: $photoFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The task wasn't marked complete. Try another photo, or complete it without one.")
        }
        .sheet(item: $proofOnDisplay) { proof in
            ProofViewer(proof: proof)
        }
    }

    // e.g. "Street: Bike Rack · 2/3"
    private func streetText(for task: EcoTask) -> String? {
        guard let kind = task.kind else { return nil }
        let count = appState.lifetimeCompletions[kind.rawValue] ?? 0
        let tier = kind.upgradeTier(forCount: count)
        guard tier < EcoTaskKind.upgradeThresholds.count else {
            return "Street: \(kind.upgradeNames[tier - 1]) built"
        }
        return "Street: \(kind.upgradeNames[tier]) · \(count)/\(EcoTaskKind.upgradeThresholds[tier])"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SectionLabel(text: "Today")
                Spacer()
                Text(appState.allTasksCompletedToday ? "All done" : "\(completedCount) of \(appState.tasks.count) done")
                    .font(Theme.body(13))
                    .foregroundColor(Theme.stone)

                if appState.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Theme.sunflower)
                        Text("\(appState.streak)")
                            .font(Theme.display(14, weight: .semibold))
                            .foregroundColor(Theme.bark)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.sunflower.opacity(0.16)))
                }
            }

            ProgressBar(progress: appState.tasks.isEmpty ? 0 : Double(completedCount) / Double(appState.tasks.count))
                .frame(height: 6)
                .padding(.top, 2)

            Text("Do a task again today for a bigger bonus.")
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
                Text(appState.streak > 1 ? "\(appState.streak)-day streak. Keep it going!" : "Streak started. Come back tomorrow.")
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
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.forest.opacity(0.08))
                Capsule()
                    .fill(Theme.sunflower)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
    }
}

private struct TaskRow: View {
    let task: EcoTask
    let nextReward: Int
    let streetText: String?
    let isExpanded: Bool
    let onAttachPhoto: () -> Void
    let onCompleteWithoutPhoto: () -> Void
    let onShowProof: () -> Void
    let onToggleExpand: () -> Void

    @State private var showProofChoice = false

    private var done: Bool { task.completionsToday >= 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    IconTile(systemName: task.icon, tint: tint, size: 42)
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white, Theme.moss)
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.display(15))
                        .foregroundColor(Theme.bark)
                    Text(task.description)
                        .font(Theme.body(12.5))
                        .foregroundColor(Theme.stone)
                        .lineLimit(2)

                    if task.completionsToday == 0, let bonus = task.kind?.gardenBonusText {
                        Label(bonus, systemImage: "leaf.fill")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.moss)
                            .padding(.top, 1)
                    }

                    if task.completionsToday > 0 {
                        Text("Done \(task.completionsToday)× today")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.moss)
                    }

                    if let streetText {
                        Label(streetText, systemImage: "signpost.right.fill")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.soil)
                            .padding(.top, 1)
                    }
                }

                Spacer(minLength: 8)

                Button { showProofChoice = true } label: {
                    VStack(spacing: 1) {
                        Text("+\(nextReward)")
                            .font(Theme.display(13, weight: .semibold))
                        if task.completionsToday > 0 {
                            Text("combo").font(Theme.caption(9))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(done ? Theme.sunflower.opacity(0.22) : .clear)
                    )
                    .overlay(Capsule().strokeBorder(done ? Theme.sunflower : tint.opacity(0.5), lineWidth: 1.2))
                    .foregroundColor(done ? Theme.bark : tint)
                }
                .buttonStyle(.plain)
                // Attached to the button so iOS 26 anchors the dialog here, not at the top of the list.
                .confirmationDialog("Add a photo as proof?", isPresented: $showProofChoice, titleVisibility: .visible) {
                    Button("Attach Photo", action: onAttachPhoto)
                    Button("Mark Complete (No Photo)", action: onCompleteWithoutPhoto)
                    Button("Cancel", role: .cancel) { }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { if !task.localTip.isEmpty { onToggleExpand() } }

            if let fileName = task.proofFileName, let photo = ProofStore.image(named: fileName) {
                Button(action: onShowProof) {
                    HStack(spacing: 10) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Photo proof")
                                .font(Theme.caption(11))
                                .foregroundColor(Theme.bark)
                            if let date = task.proofDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(Theme.body(11))
                                    .foregroundColor(Theme.stone)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.stone)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View photo proof for \(task.title)")
            }

            if isExpanded && !task.localTip.isEmpty {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.moss)
                            .padding(.top, 1)
                        Text(task.localTip)
                            .font(Theme.body(12))
                            .foregroundColor(Theme.stone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let link = task.localURL, let url = URL(string: link) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text("Open the local page")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.moss)
                        }
                        .padding(.leading, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .ecoCard(tint: tint)
    }

    private var tint: Color { task.kind?.tint ?? Theme.moss }
}

struct ProofPhoto: Identifiable {
    let fileName: String
    let title: String
    var id: String { fileName }
}

struct ProofViewer: View {
    let proof: ProofPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let photo = ProofStore.image(named: proof.fileName) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                }
            }
            .navigationTitle(proof.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ScrollView { HabitsSection().padding() }.environmentObject(AppState())
}
