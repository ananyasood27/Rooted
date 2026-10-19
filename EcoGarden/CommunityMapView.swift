import SwiftUI
import MapKit

struct CommunityMapView: View {
    let filter: VolunteerCategory?
    let showDropOffs: Bool
    let onLog: (Opportunity) -> Void

    @State private var selected: CommunityPlace? = nil
    @State private var camera: MapCameraPosition = .automatic

    private var places: [CommunityPlace] {
        CommunityPlace.baytown.filter { place in
            switch place.kind {
            case .dropOff: return showDropOffs
            case .volunteer(let category): return filter == nil || filter == category
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Map(position: $camera) {
                ForEach(places) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        PlacePin(place: place, isSelected: selected?.id == place.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selected = (selected?.id == place.id) ? nil : place
                                }
                            }
                            .accessibilityElement()
                            .accessibilityLabel("\(place.name). \(place.whatsHere)")
                            .accessibilityAddTraits(.isButton)
                    }
                    .annotationTitles(.hidden)
                }
            }
            // Hide Apple's own shops and restaurants so our pins stand out.
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.sage.opacity(0.25), lineWidth: 1)
            )
            .onAppear { camera = fittingCamera }
            .onChange(of: places.map(\.id)) { _, visibleIDs in
                withAnimation(.easeInOut(duration: 0.4)) { camera = fittingCamera }
                if let current = selected, !visibleIDs.contains(current.id) { selected = nil }
            }

            if let selected {
                PlaceCard(place: selected, onLog: onLog)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Tap a pin to see what's there.")
                    .font(Theme.body(12.5))
                    .foregroundColor(Theme.stone)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

extension CommunityMapView {
    // Fit Baytown only; including the Houston Food Bank squashes everything else together.
    private var fittingCamera: MapCameraPosition {
        let local = places.filter { $0.longitude > -95.1 }
        guard filter == nil, local.count > 1 else { return .automatic }
        let lats = local.map(\.latitude)
        let lons = local.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.5 + 0.01,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.5 + 0.01
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}

private extension CommunityPlace {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var color: Color {
        switch kind {
        case .volunteer(let category): return category.color
        case .dropOff: return Theme.soil
        }
    }

    var icon: String {
        switch kind {
        case .volunteer(let category): return category.icon
        case .dropOff: return "arrow.3.trianglepath"
        }
    }

    var opportunities: [Opportunity] {
        Opportunity.baytown.filter { opportunityIDs.contains($0.id) }
    }

    var directionsURL: URL? {
        let name = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)&q=\(name)")
    }
}

private struct PlacePin: View {
    let place: CommunityPlace
    let isSelected: Bool

    var body: some View {
        let size: CGFloat = isSelected ? 40 : 32
        VStack(spacing: -3) {
            ZStack {
                Circle()
                    .fill(place.color)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                Image(systemName: place.icon)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
            Triangle()
                .fill(.white)
                .frame(width: 10, height: 7)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PlaceCard: View {
    let place: CommunityPlace
    let onLog: (Opportunity) -> Void

    private var kindLabel: String {
        switch place.kind {
        case .volunteer(let category): return "Volunteer · \(category.title)"
        case .dropOff: return "Drop-off"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(place.color.opacity(0.15))
                    Image(systemName: place.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(place.color)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kindLabel.uppercased())
                        .font(Theme.caption(10))
                        .foregroundColor(Theme.stone)
                        .tracking(0.5)
                    Text(place.name)
                        .font(Theme.display(15, weight: .semibold))
                        .foregroundColor(Theme.bark)
                }
            }

            Text(place.whatsHere)
                .font(Theme.body(13))
                .foregroundColor(Theme.stone)
                .fixedSize(horizontal: false, vertical: true)
            Label(place.address, systemImage: "mappin.and.ellipse")
                .font(Theme.body(12))
                .foregroundColor(Theme.stone)

            HStack(spacing: 14) {
                if let directions = place.directionsURL {
                    Link(destination: directions) {
                        Label("Directions", systemImage: "car.fill")
                    }
                }
                if let page = URL(string: place.url) {
                    Link(destination: page) {
                        HStack(spacing: 4) {
                            Text("Open page")
                            Image(systemName: "arrow.up.right")
                        }
                    }
                }
                Spacer()
                logButton
            }
            .font(Theme.caption(12))
            .foregroundColor(Theme.moss)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ecoCard()
    }

    @ViewBuilder
    private var logButton: some View {
        let opportunities = place.opportunities
        if opportunities.count == 1, let only = opportunities.first {
            LogHoursButton { onLog(only) }
        } else if opportunities.count > 1 {
            Menu {
                ForEach(opportunities) { opportunity in
                    Button(opportunity.title) { onLog(opportunity) }
                }
            } label: {
                Label("Log hours", systemImage: "plus")
                    .font(Theme.caption(12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.moss))
                    .foregroundColor(.white)
            }
        }
    }
}
