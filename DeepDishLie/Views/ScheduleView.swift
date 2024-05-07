//
//  ScheduleView.swift
//  DeepDishLie
//
//  Created by Morten Bjerg Gregersen on 24/04/2024.
//

import ConfettiSwiftUI
import StoreKit
import SwiftUI

struct ScheduleView: View {
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    @State private var showsSettings = false
    @State private var toolbarRerenderTrigger = false
    @Environment(\.requestReview) private var requestReview
    @Environment(WelcomeController.self) private var welcomeController
    @Environment(SettingsController.self) private var settingsController
    @Environment(ScheduleController.self) private var scheduleController

    @State private var currentDateID: String?

    var body: some View {
        let dateFormatter = Event.dateFormatter(useLocalTimezone: settingsController.useLocalTimezone, use24hourClock: settingsController.use24hourClock)
        @Bindable var settingsController = settingsController
        NavigationStack {
            ScrollViewReader { proxy in
                List(scheduleController.days) { day in
                    Section {
                        ForEach(day.events) { event in
                            EventRow(dayName: day.name, event: event, dateFormatter: dateFormatter)
                                .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 12))
                        }
                    } header: {
                        Text(day.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Schedule 🍕")
                .toolbarBackground(toolbarRerenderTrigger ? Color.accentColor : Color.accentColor.opacity(0.99999999),
                                   for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    HStack {
                        if let currentDateID {
                            Button {
                                withAnimation {
                                    proxy.scrollTo(currentDateID, anchor: .center)
                                }
                            } label: {
                                Label("Now", systemImage: "clock")
                            }
                        }
                        Button {
                            showsSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
                .sheet(isPresented: $showsSettings, onDismiss: {
                    // There is a bug in SwiftUI where the navigation bar looses its color (turning gray)
                    // when a sheet is dismissed. This will trigger a rerender after the dismiss.
                    toolbarRerenderTrigger.toggle()
                }) {
                    SettingsView()
                }
                .onAppear {
                    currentDateID = scheduleController.currentDateEvent?.id
                    if let currentDateID {
                        proxy.scrollTo(currentDateID, anchor: .center)
                    }
                    if welcomeController.hasSeenWelcome, !welcomeController.hasRequestedReview {
                        welcomeController.hasRequestedReview = true
                        requestReview()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                    settingsController.triggerConfetti()
                }
                .overlay(alignment: .bottom) {
                    if welcomeController.hasJustSeenWelcome, settingsController.randomConfettiIntensity > 4 {
                        VStack {
                            Button {
                                welcomeController.hasJustSeenWelcome = false
                                showsSettings = true
                            } label: {
                                HStack(alignment: .center) {
                                    Text("🤪")
                                        .font(.largeTitle)
                                    Text("Okay... not that much!")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .shadow(color: Color.accentColor, radius: 20)
                            Button {
                                welcomeController.hasJustSeenWelcome = false
                            } label: {
                                HStack(alignment: .center) {
                                    Text("😍")
                                        .font(.largeTitle)
                                    Text("This is just awesome!")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .shadow(color: Color.accentColor, radius: 20)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            ConfettiCannon(counter: $settingsController.confettiTrigger,
                           num: 10,
                           confettis: [.text("🍕")],
                           confettiSize: 50,
                           rainHeight: 1200,
                           fadesOut: true,
                           openingAngle: .degrees(180),
                           closingAngle: .degrees(0),
                           radius: 160,
                           repetitionInterval: 1)
        }.onReceive(timer) { _ in
            currentDateID = scheduleController.currentDateEvent?.id
        }
    }
}

private struct EventRow: View {
    let dayName: String
    let event: Event
    let dateFormatter: DateFormatter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationLink {
            EventView(dayName: dayName, event: event)
        } label: {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing) {
                    Text(dateFormatter.string(from: event.start))
                    Text(dateFormatter.string(from: event.end))
                }
                .padding(.trailing, 2)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(event.dateTextColor)
                .containerRelativeFrame(.horizontal) { length, _ in
                    length / dateFrameDivider
                }
                VStack(alignment: .leading) {
                    Text(event.description)
                        .font(.headline)
                        .foregroundStyle(event.titleTextColor)
                    if let speakers = event.speakers {
                        Text(ListFormatter.localizedString(byJoining: speakers.map(\.name)))
                            .foregroundStyle(event.titleTextColor)
                    }
                }
                if let speakers = event.speakers {
                    Spacer(minLength: 12)
                    if horizontalSizeClass == .compact {
                        VStack(alignment: .trailing) {
                            speakerImages(speakers: speakers)
                        }
                    } else {
                        HStack {
                            speakerImages(speakers: speakers)
                        }
                    }
                } else if let emoji = event.emoji {
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing) {
                        VStack {
                            Text(emoji)
                                .font(.largeTitle)
                        }
                        .frame(width: 50, height: 50)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                    }
                }
            }
        }
        .listRowBackground(listRowBackgroundColor)
    }

    private func speakerImages(speakers: [Speaker]) -> some View {
        ForEach(speakers) { speaker in
            Image(speaker.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 50)
                .clipShape(Circle())
                .background {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 54, height: 54)
                }
                .shadow(color: .accent, radius: 1, x: 0, y: 1)
        }
    }

    private var listRowBackgroundColor: Color? {
        guard event.isHappeningNow else {
            return switch event {
            case .session: nil
            default: Color.accentColor.opacity(0.1)
            }
        }
        return Color.accentColor
    }

    private var dateFrameDivider: CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            6
        case .small:
            6
        case .medium:
            6
        case .large:
            5
        case .xLarge:
            4
        case .xxLarge:
            4
        case .xxxLarge:
            4
        case .accessibility1:
            3
        case .accessibility2:
            3
        case .accessibility3:
            2
        case .accessibility4:
            2
        case .accessibility5:
            2
        @unknown default:
            5
        }
    }
}

extension Event {
    var isHappeningNow: Bool {
        start ... end ~= Date()
    }

    var dateTextColor: Color {
        if isHappeningNow {
            .init(uiColor: UIColor.lightText)
        } else {
            .accentColor
        }
    }

    var titleTextColor: Color {
        if isHappeningNow {
            .init(uiColor: UIColor.systemBackground)
        } else {
            .primary
        }
    }
}

#Preview {
    ScheduleView()
        .environment(SettingsController.forPreview())
        .environment(ScheduleController.forPreview())
}
