//
//  NotchView.swift
//  ClaudeIsland
//
//  The main dynamic island SwiftUI view with accurate notch shape
//

import AppKit
import CoreGraphics
import SwiftUI

// Corner radius constants
private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()
    @StateObject private var activityCoordinator = NotchActivityCoordinator.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var previousPendingIds: Set<String> = []
    @State private var previousWaitingForInputIds: Set<String> = []
    @State private var previousActiveIds: Set<String> = []  // Track active sessions for completion detection
    @State private var waitingForInputTimestamps: [String: Date] = [:]  // sessionId -> when it entered waitingForInput
    @State private var completionTimestamps: [String: Date] = [:]  // sessionId -> when it completed
    @State private var lastCompletedSession: SessionState? = nil
    @State private var companion: Companion? = nil
    @State private var isVisible: Bool = false
    @State private var isHovering: Bool = false
    @State private var isBouncing: Bool = false

    @Namespace private var activityNamespace

    /// Whether any Claude session is currently processing or compacting
    private var isAnyProcessing: Bool {
        sessionMonitor.instances.contains { $0.phase == .processing || $0.phase == .compacting }
    }

    /// Whether any Claude session has a pending permission request
    private var hasPendingPermission: Bool {
        sessionMonitor.instances.contains { $0.phase.isWaitingForApproval }
    }

    /// Whether any Claude session is waiting for user input (done/ready state) within the display window
    private var hasWaitingForInput: Bool {
        let now = Date()
        let displayDuration: TimeInterval = 30  // Show checkmark for 30 seconds

        return sessionMonitor.instances.contains { session in
            guard session.phase == .waitingForInput else { return false }
            // Only show if within the 30-second display window
            if let enteredAt = waitingForInputTimestamps[session.stableId] {
                return now.timeIntervalSince(enteredAt) < displayDuration
            }
            return false
        }
    }

    /// Whether any session recently completed (for companion notification)
    private var hasRecentCompletion: Bool {
        let now = Date()
        let displayDuration: TimeInterval = 8  // Show companion for 8 seconds
        return completionTimestamps.values.contains { now.timeIntervalSince($0) < displayDuration }
    }

    // MARK: - Sizing

    private var closedNotchSize: CGSize {
        CGSize(
            width: viewModel.deviceNotchRect.width,
            height: viewModel.deviceNotchRect.height
        )
    }

    /// Extra width for expanding activities (like Dynamic Island)
    private var expansionWidth: CGFloat {
        // Permission indicator adds width on left side only
        let permissionIndicatorWidth: CGFloat = hasPendingPermission ? 18 : 0

        // Expand for processing activity
        if activityCoordinator.expandingActivity.show {
            switch activityCoordinator.expandingActivity.type {
            case .claude:
                let baseWidth = 2 * max(0, closedNotchSize.height - 12) + 20
                return baseWidth + permissionIndicatorWidth
            case .none:
                break
            }
        }

        // Expand for pending permissions (left indicator) or waiting for input (checkmark on right)
        if hasPendingPermission {
            return 2 * max(0, closedNotchSize.height - 12) + 20 + permissionIndicatorWidth
        }

        // Waiting for input just shows checkmark on right, no extra left indicator
        if hasWaitingForInput {
            return 2 * max(0, closedNotchSize.height - 12) + 20
        }

        return 0
    }

    private var notchSize: CGSize {
        switch viewModel.status {
        case .closed, .popping:
            return closedNotchSize
        case .opened:
            return viewModel.openedSize
        }
    }

    /// Width of the closed content (notch + any expansion)
    private var closedContentWidth: CGFloat {
        closedNotchSize.width + expansionWidth
    }

    // MARK: - Corner Radii

    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    // Animation springs
    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Outer container does NOT receive hits - only the notch content does
            VStack(spacing: 0) {
                notchLayout
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
                        alignment: .top
                    )
                    .padding(
                        .horizontal,
                        viewModel.status == .opened
                            ? cornerRadiusInsets.opened.top
                            : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], viewModel.status == .opened ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: (viewModel.status == .opened || isHovering) ? .black.opacity(0.7) : .clear,
                        radius: 6
                    )
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
                        maxHeight: viewModel.status == .opened ? notchSize.height : nil,
                        alignment: .top
                    )
                    .animation(viewModel.status == .opened ? openAnimation : closeAnimation, value: viewModel.status)
                    .animation(openAnimation, value: notchSize) // Animate container size changes between content types
                    .animation(.smooth, value: activityCoordinator.expandingActivity)
                    .animation(.smooth, value: hasPendingPermission)
                    .animation(.smooth, value: hasWaitingForInput)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                            isHovering = hovering
                        }
                    }
                    .onTapGesture {
                        if viewModel.status != .opened {
                            viewModel.notchOpen(reason: .click)
                        }
                    }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onAppear {
            sessionMonitor.startMonitoring()
            // On non-notched devices, keep visible so users have a target to interact with
            if !viewModel.hasPhysicalNotch {
                isVisible = true
            }
        }
        .onChange(of: viewModel.status) { oldStatus, newStatus in
            handleStatusChange(from: oldStatus, to: newStatus)
        }
        .onChange(of: sessionMonitor.pendingInstances) { _, sessions in
            handlePendingSessionsChange(sessions)
        }
        .onChange(of: sessionMonitor.instances) { _, instances in
            viewModel.hasPendingPermission = hasPendingPermission
            handleProcessingChange()
            handleWaitingForInputChange(instances)
            handleSessionCompletion(instances)
        }
        .onChange(of: sessionMonitor.pendingInstances) { _, _ in
            viewModel.hasPendingPermission = hasPendingPermission
        }
        .task {
            companion = await CompanionService.shared.getCompanion()
        }
    }

    // MARK: - Notch Layout

    private var isProcessing: Bool {
        activityCoordinator.expandingActivity.show && activityCoordinator.expandingActivity.type == .claude
    }

    /// Whether to show the expanded closed state (processing, pending permission, waiting for input, or recent completion)
    private var showClosedActivity: Bool {
        isProcessing || hasPendingPermission || hasWaitingForInput || hasRecentCompletion
    }

    @ViewBuilder
    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always present, contains crab and spinner that persist across states
            headerRow
                .frame(height: max(24, closedNotchSize.height))

            // Main content only when opened
            if viewModel.status == .opened {
                contentView
                    .frame(width: notchSize.width - 24) // Fixed width to prevent reflow
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .top)
                                .combined(with: .opacity)
                                .animation(.smooth(duration: 0.35)),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        )
                    )
            }
        }
    }

    // MARK: - Header Row (persists across states)

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Left side - crab + optional permission indicator (visible when processing, pending, or waiting for input)
            if showClosedActivity {
                HStack(spacing: 4) {
                    ClaudeCrabIcon(size: 14, animateLegs: isProcessing)
                        .matchedGeometryEffect(id: "crab", in: activityNamespace, isSource: showClosedActivity)

                    // Permission indicator only (amber) - waiting for input shows checkmark on right
                    if hasPendingPermission {
                        PermissionIndicatorIcon(size: 14, color: Color(red: 0.85, green: 0.47, blue: 0.34))
                            .matchedGeometryEffect(id: "status-indicator", in: activityNamespace, isSource: showClosedActivity)
                    }
                }
                .frame(width: viewModel.status == .opened ? nil : sideWidth + (hasPendingPermission ? 18 : 0))
                .padding(.leading, viewModel.status == .opened ? 8 : 0)
            }

            // Center content
            if viewModel.status == .opened {
                // Opened: show header content
                openedHeaderContent
            } else if !showClosedActivity {
                // Closed without activity: empty space
                Rectangle()
                    .fill(.clear)
                    .frame(width: closedNotchSize.width - 20)
            } else {
                // Closed with activity: black spacer (with optional bounce)
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top + (isBouncing ? 16 : 0))
            }

            // Right side - spinner when processing/pending, checkmark when waiting, companion on completion
            if showClosedActivity {
                if isProcessing || hasPendingPermission {
                    ProcessingSpinner()
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                } else if hasWaitingForInput {
                    // Checkmark for waiting-for-input on the right side
                    ReadyForInputIndicatorIcon(size: 14, color: TerminalColors.green)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                } else if hasRecentCompletion, let companion {
                    CompanionIcon(species: companion.species, size: 16, color: TerminalColors.green)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                }
            }
        }
        .frame(height: closedNotchSize.height)
    }

    private var sideWidth: CGFloat {
        max(0, closedNotchSize.height - 12) + 10
    }

    // MARK: - Opened Header Content

    @ViewBuilder
    private var openedHeaderContent: some View {
        HStack(spacing: 12) {
            // Show static crab only if not showing activity in headerRow
            // (headerRow handles crab + indicator when showClosedActivity is true)
            if !showClosedActivity {
                ClaudeCrabIcon(size: 14)
                    .matchedGeometryEffect(id: "crab", in: activityNamespace, isSource: !showClosedActivity)
                    .padding(.leading, 8)
            }

            Spacer()

            // Menu toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleMenu()
                    if viewModel.contentType == .menu {
                        updateManager.markUpdateSeen()
                    }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewModel.contentType == .menu ? "xmark" : "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())

                    // Green dot for unseen update
                    if updateManager.hasUnseenUpdate && viewModel.contentType != .menu {
                        Circle()
                            .fill(TerminalColors.green)
                            .frame(width: 6, height: 6)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content View (Opened State)

    @ViewBuilder
    private var contentView: some View {
        Group {
            if hasPendingPermission {
                // Immersive approval view — focused on the permission request
                approvalQueueView
            } else if viewModel.openReason == .notification && hasRecentCompletion {
                // Companion completion popup
                companionNotificationView
            } else {
                switch viewModel.contentType {
                case .instances:
                    ClaudeInstancesView(
                        sessionMonitor: sessionMonitor,
                        viewModel: viewModel
                    )
                case .menu:
                    NotchMenuView(viewModel: viewModel)
                case .chat(let session):
                    ChatView(
                        sessionId: session.sessionId,
                        initialSession: session,
                        sessionMonitor: sessionMonitor,
                        viewModel: viewModel
                    )
                }
            }
        }
        .frame(width: notchSize.width - 24)
    }

    @ViewBuilder
    private var companionNotificationView: some View {
        let projectName = lastCompletedSession?.cwd.components(separatedBy: "/").last ?? "Session"
        let message = lastCompletedSession?.lastStopMessage ?? lastCompletedSession?.lastMessage

        HStack(spacing: 12) {
            CompanionIcon(
                species: companion?.species ?? "octopus",
                size: 36,
                color: TerminalColors.green
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(projectName)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(3)
                } else {
                    Text("Done!")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Jump to terminal button
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            focusSessionTerminal()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - Immersive Approval View

    @ViewBuilder
    private var approvalQueueView: some View {
        let pendingSessions = sessionMonitor.instances.filter { $0.phase.isWaitingForApproval }

        ScrollView {
            VStack(spacing: 12) {
                ForEach(pendingSessions, id: \.sessionId) { session in
                    approvalCard(for: session)
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func approvalCard(for session: SessionState) -> some View {
        let projectName = session.cwd.components(separatedBy: "/").last ?? "Session"
        let toolName = session.activePermission?.toolName ?? "Unknown"
        let toolInput = formatToolInput(session.activePermission?.toolInput)

        VStack(alignment: .leading, spacing: 10) {
            // Header: project name
            HStack {
                Circle()
                    .fill(Color(red: 0.85, green: 0.47, blue: 0.34))
                    .frame(width: 8, height: 8)
                Text(projectName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text(toolName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.85, green: 0.47, blue: 0.34))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.15))
                    .cornerRadius(4)
            }

            // Tool input details
            if !toolInput.isEmpty {
                Text(toolInput)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }

            // Action buttons
            HStack(spacing: 10) {
                Spacer()

                Button {
                    sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
                } label: {
                    Text("Deny")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    sessionMonitor.approvePermission(sessionId: session.sessionId)
                } label: {
                    Text("Allow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .padding(.horizontal, 4)
    }

    private func formatToolInput(_ input: [String: AnyCodable]?) -> String {
        guard let input else { return "" }

        // Try common patterns
        if let command = input["command"]?.value as? String {
            return command
        }
        if let filePath = input["file_path"]?.value as? String {
            return filePath
        }
        if let patterns = input["patterns"]?.value as? [Any], let first = patterns.first as? String {
            return first
        }

        // Fallback: serialize to readable string
        if let data = try? JSONSerialization.data(withJSONObject: input.mapValues { $0.value }, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }

    /// Focus the terminal app for the completed session
    private func focusSessionTerminal() {
        guard let session = lastCompletedSession else { return }

        Task {
            // Try yabai first (for tmux pane switching)
            if let pid = session.pid {
                let success = await YabaiController.shared.focusWindow(forClaudePid: pid)
                if success {
                    await MainActor.run { viewModel.notchClose() }
                    return
                }
            }

            // Use CGWindowList to find the correct terminal window by PID or title
            await MainActor.run {
                if focusTerminalWindow(for: session) {
                    viewModel.notchClose()
                    return
                }

                // Last resort: activate any Ghostty instance
                let ghosttyApps = NSWorkspace.shared.runningApplications.filter {
                    $0.bundleIdentifier == "com.mitchellh.ghostty"
                }
                if let ghostty = ghosttyApps.first {
                    ghostty.activate()
                    viewModel.notchClose()
                }
            }
        }
    }

    /// Find and focus the correct terminal window using CGWindowList + Accessibility API
    @MainActor
    private func focusTerminalWindow(for session: SessionState) -> Bool {
        let projectName = session.cwd.components(separatedBy: "/").last ?? ""
        guard !projectName.isEmpty else { return false }

        // Get all on-screen windows
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        // Find terminal windows whose title contains the project name or session ID
        let sessionPrefix = String(session.sessionId.prefix(8))
        var targetPid: pid_t?
        var targetWindowNumber: CGWindowID?

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowPid = window[kCGWindowOwnerPID as String] as? Int,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  TerminalAppRegistry.isTerminal(ownerName) else { continue }

            let title = window[kCGWindowName as String] as? String ?? ""

            // Match by session ID prefix in title (set via OSC2) or project name
            if title.contains(sessionPrefix) || title.contains(projectName) {
                targetPid = pid_t(windowPid)
                targetWindowNumber = window[kCGWindowNumber as String] as? CGWindowID
                break
            }
        }

        // If we found a matching window, activate the app and raise the window
        if let targetPid {
            let app = NSRunningApplication(processIdentifier: targetPid)
            app?.activate()

            // Use Accessibility API to raise the specific window
            if let windowNumber = targetWindowNumber {
                raiseWindow(pid: targetPid, windowNumber: windowNumber, projectName: projectName, sessionPrefix: sessionPrefix)
            }
            return true
        }

        // Fallback: find by process tree PID
        if let claudePid = session.pid {
            let tree = ProcessTreeBuilder.shared.buildTree()
            if let termPid = ProcessTreeBuilder.shared.findTerminalPid(forProcess: claudePid, tree: tree) {
                let app = NSRunningApplication(processIdentifier: pid_t(termPid))
                app?.activate()
                return true
            }
        }

        return false
    }

    /// Raise a specific window using Accessibility API
    private func raiseWindow(pid: pid_t, windowNumber: CGWindowID, projectName: String, sessionPrefix: String) {
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return }

        for axWindow in axWindows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""

            if title.contains(sessionPrefix) || title.contains(projectName) {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                return
            }
        }
    }

    // MARK: - Event Handlers

    private func handleProcessingChange() {
        if isAnyProcessing || hasPendingPermission {
            // Show claude activity when processing or waiting for permission
            activityCoordinator.showActivity(type: .claude)
            isVisible = true
        } else if hasWaitingForInput || hasRecentCompletion {
            // Keep visible for waiting-for-input or recent completion (companion notification)
            activityCoordinator.hideActivity()
            isVisible = true
        } else {
            // Hide activity when done
            activityCoordinator.hideActivity()

            // Delay hiding the notch until animation completes
            // Don't hide on non-notched devices - users need a visible target
            if viewModel.status == .closed && viewModel.hasPhysicalNotch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isAnyProcessing && !hasPendingPermission && !hasWaitingForInput && viewModel.status == .closed {
                        isVisible = false
                    }
                }
            }
        }
    }

    private func handleStatusChange(from oldStatus: NotchStatus, to newStatus: NotchStatus) {
        switch newStatus {
        case .opened, .popping:
            isVisible = true
            // Clear waiting-for-input timestamps only when manually opened (user acknowledged)
            if viewModel.openReason == .click || viewModel.openReason == .hover {
                waitingForInputTimestamps.removeAll()
            }
        case .closed:
            // Re-open if there's a pending permission — user must approve/deny
            if hasPendingPermission {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if hasPendingPermission {
                        viewModel.notchOpen(reason: .notification)
                    }
                }
                return
            }
            // Don't hide on non-notched devices - users need a visible target
            guard viewModel.hasPhysicalNotch else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if viewModel.status == .closed && !isAnyProcessing && !hasPendingPermission && !hasWaitingForInput && !activityCoordinator.expandingActivity.show {
                    isVisible = false
                }
            }
        }
    }

    private func handlePendingSessionsChange(_ sessions: [SessionState]) {
        let currentIds = Set(sessions.map { $0.stableId })
        let newPendingIds = currentIds.subtracting(previousPendingIds)

        // Always auto-expand for permission requests — user needs to approve/deny
        if !newPendingIds.isEmpty && viewModel.status != .opened {
            viewModel.notchOpen(reason: .notification)

            // Play sound to alert
            if let soundName = AppSettings.notificationSound.soundName {
                NSSound(named: soundName)?.play()
            }
        }

        previousPendingIds = currentIds
    }

    private func handleWaitingForInputChange(_ instances: [SessionState]) {
        // Get sessions that are now waiting for input
        let waitingForInputSessions = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waitingForInputSessions.map { $0.stableId })
        let newWaitingIds = currentIds.subtracting(previousWaitingForInputIds)

        // Track timestamps for newly waiting sessions
        let now = Date()
        for session in waitingForInputSessions where newWaitingIds.contains(session.stableId) {
            waitingForInputTimestamps[session.stableId] = now
        }

        // Clean up timestamps for sessions no longer waiting
        let staleIds = Set(waitingForInputTimestamps.keys).subtracting(currentIds)
        for staleId in staleIds {
            waitingForInputTimestamps.removeValue(forKey: staleId)
        }

        // Bounce the notch when a session newly enters waitingForInput state
        if !newWaitingIds.isEmpty {
            // Get the sessions that just entered waitingForInput
            let newlyWaitingSessions = waitingForInputSessions.filter { newWaitingIds.contains($0.stableId) }

            // Play notification sound if the session is not actively focused
            if let soundName = AppSettings.notificationSound.soundName {
                // Check if we should play sound (async check for tmux pane focus)
                Task {
                    let shouldPlaySound = await shouldPlayNotificationSound(for: newlyWaitingSessions)
                    if shouldPlaySound {
                        await MainActor.run {
                            NSSound(named: soundName)?.play()
                        }
                    }
                }
            }

            // Trigger bounce animation to get user's attention
            DispatchQueue.main.async {
                isBouncing = true
                // Bounce back after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isBouncing = false
                }
            }

            // Schedule hiding the checkmark after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [self] in
                // Trigger a UI update to re-evaluate hasWaitingForInput
                handleProcessingChange()
            }
        }

        previousWaitingForInputIds = currentIds
    }

    /// Determine if notification sound should play for the given sessions
    /// Returns true if ANY session is not actively focused
    private func shouldPlayNotificationSound(for sessions: [SessionState]) async -> Bool {
        for session in sessions {
            guard let pid = session.pid else {
                // No PID means we can't check focus, assume not focused
                return true
            }

            let isFocused = await TerminalVisibilityDetector.isSessionFocused(sessionPid: pid)
            if !isFocused {
                return true
            }
        }

        return false
    }

    // MARK: - Session Completion Detection

    private func handleSessionCompletion(_ instances: [SessionState]) {
        // Active = processing or compacting
        let activeIds = Set(
            instances
                .filter { $0.phase == .processing || $0.phase == .compacting }
                .map { $0.stableId }
        )

        // Sessions that were active but are now idle = just completed
        let completedIds = previousActiveIds.subtracting(activeIds)

        if !completedIds.isEmpty {
            let now = Date()
            for id in completedIds {
                completionTimestamps[id] = now
            }

            // Store the completed session for notification display
            let completedSessions = instances.filter { completedIds.contains($0.stableId) }
            if let session = completedSessions.first {
                lastCompletedSession = session
            }

            // Play custom completion sound (Logic Pro jingle)
            if let soundURL = Bundle.main.url(forResource: "cc_done", withExtension: "wav") {
                NSSound(contentsOf: soundURL, byReference: true)?.play()
            } else if let soundName = AppSettings.notificationSound.soundName {
                NSSound(named: soundName)?.play()
            }

            // Always open notch to show companion notification
            if viewModel.status != .opened || viewModel.openReason != .click {
                viewModel.notchOpen(reason: .notification)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak viewModel] in
                    guard let viewModel, viewModel.openReason == .notification else { return }
                    viewModel.notchClose()
                }
            }

            // Auto-cleanup completion timestamps after display window
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) { [self] in
                let cutoff = Date().addingTimeInterval(-8)
                completionTimestamps = completionTimestamps.filter { $0.value > cutoff }
                handleProcessingChange()
            }
        }

        previousActiveIds = activeIds
    }
}
