//
//  StatusIcons.swift
//  ClaudeIsland
//
//  Pixel-art status icons for Claude instances
//

import SwiftUI

// MARK: - Waiting for Input Icon (speech bubble)
struct WaitingForInputIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 12, color: Color = TerminalColors.green) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let dotSize = 4 * scale

            // Grid positions that are "on" (full opacity)
            let solidDots: [(CGFloat, CGFloat)] = [
                // Top row
                (3, 3), (7, 3), (11, 3), (15, 3), (19, 3), (23, 3), (27, 3),
                // Left edge
                (3, 7), (3, 11), (3, 15), (3, 19), (3, 23), (3, 27),
                // Right edge
                (27, 7), (27, 11), (27, 15), (27, 19),
                // Bottom left corner (speech tail)
                (7, 23),
                // Inner dots forming the pattern
                (11, 19), (15, 19), (19, 19), (23, 19),
            ]

            // Semi-transparent dots
            let fadedDots: [(CGFloat, CGFloat)] = [
                (7, 11), (7, 15), (7, 19),
                (11, 11), (11, 15),
                (15, 11), (15, 15),
                (19, 15),
            ]

            // Draw solid dots
            for (x, y) in solidDots {
                let rect = CGRect(
                    x: x * scale - dotSize/2,
                    y: y * scale - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(rect), with: .color(color))
            }

            // Draw faded dots
            for (x, y) in fadedDots {
                let rect = CGRect(
                    x: x * scale - dotSize/2,
                    y: y * scale - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(rect), with: .color(color.opacity(0.4)))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Waiting for Approval Icon (hand/stop)
struct WaitingForApprovalIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 12, color: Color = TerminalColors.amber) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let dotSize = 4 * scale

            // Grid positions that are "on" - forms a hand/approval shape
            let solidDots: [(CGFloat, CGFloat)] = [
                // Fingers at top
                (7, 7), (7, 11),
                (11, 3),
                (15, 3), (19, 3),
                (23, 7), (23, 11),
                // Palm/wrist
                (15, 19), (15, 27),
                (19, 15),
            ]

            for (x, y) in solidDots {
                let rect = CGRect(
                    x: x * scale - dotSize/2,
                    y: y * scale - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Running/Processing Icon (hourglass) - Animated
struct RunningIcon: View {
    let size: CGFloat
    let color: Color
    @State private var rotation: Double = 0

    init(size: CGFloat = 12, color: Color = TerminalColors.cyan) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let dotSize = 4 * scale

            // Hourglass shape
            let solidDots: [(CGFloat, CGFloat)] = [
                // Top row
                (15, 3),
                // Upper part
                (7, 7), (15, 7), (23, 7),
                (15, 11), (15, 19),
                // Middle
                (3, 15), (7, 15), (11, 15), (19, 15), (23, 15), (27, 15),
                // Lower part
                (7, 23), (15, 23), (23, 23),
                (15, 27),
            ]

            let fadedDots: [(CGFloat, CGFloat)] = [
                (11, 11), (19, 11),
                (11, 19), (19, 19),
            ]

            // Draw solid dots
            for (x, y) in solidDots {
                let rect = CGRect(
                    x: x * scale - dotSize/2,
                    y: y * scale - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(rect), with: .color(color))
            }

            // Draw faded dots
            for (x, y) in fadedDots {
                let rect = CGRect(
                    x: x * scale - dotSize/2,
                    y: y * scale - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(rect), with: .color(color.opacity(0.4)))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(
                .linear(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
    }
}

// MARK: - Idle Icon (simple dash/dot)
struct IdleIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 12, color: Color = TerminalColors.dim) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let dotSize = 4 * scale

            // Simple horizontal line
            let dots: [(CGFloat, CGFloat)] = [
                (11, 15), (15, 15), (19, 15)
            ]

            for (x, y) in dots {
                let rect = CGRect(
                    x: x * scale - dotSize/2,
                    y: y * scale - dotSize/2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Companion Icon (species-based pixel art for notifications)
struct CompanionIcon: View {
    let species: String
    let size: CGFloat
    let color: Color
    @State private var wobble: Double = 0

    init(species: String = "octopus", size: CGFloat = 16, color: Color = TerminalColors.green) {
        self.species = species
        self.size = size
        self.color = color
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let dotSize = 4 * scale
            let (body, eyes, accent) = dotsForSpecies

            for (x, y) in body {
                let rect = CGRect(x: x * scale - dotSize/2, y: y * scale - dotSize/2, width: dotSize, height: dotSize)
                context.fill(Path(rect), with: .color(color))
            }
            for (x, y) in eyes {
                let rect = CGRect(x: x * scale - dotSize/2, y: y * scale - dotSize/2, width: dotSize, height: dotSize)
                context.fill(Path(rect), with: .color(.black))
            }
            for (x, y) in accent {
                let rect = CGRect(x: x * scale - dotSize/2, y: y * scale - dotSize/2, width: dotSize, height: dotSize)
                context.fill(Path(rect), with: .color(color.opacity(0.55)))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(wobble))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
                wobble = 8
            }
        }
    }

    private var dotsForSpecies: (body: [(CGFloat, CGFloat)], eyes: [(CGFloat, CGFloat)], accent: [(CGFloat, CGFloat)]) {
        switch species {
        case "octopus":
            return (
                body: [(11,3),(15,3),(19,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(15,11),(23,11)],
                eyes: [(11,9),(19,9)],
                accent: [(5,15),(9,15),(15,15),(21,15),(25,15),(3,19),(11,19),(19,19),(27,19),(3,23),(13,23),(17,23),(27,23),(5,27),(11,27),(19,27),(25,27)]
            )
        case "crab":
            return (
                body: [(11,7),(15,7),(19,7),(7,11),(11,11),(15,11),(19,11),(23,11),(7,15),(11,15),(15,15),(19,15),(23,15)],
                eyes: [(11,9),(19,9)],
                accent: [(3,7),(27,7),(3,11),(27,11),(5,19),(9,19),(21,19),(25,19),(3,23),(27,23)]
            )
        case "fox":
            return (
                body: [(7,3),(23,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(11,11),(15,11),(19,11),(23,11),(11,15),(15,15),(19,15),(15,19)],
                eyes: [(11,9),(19,9)],
                accent: [(3,7),(27,7),(15,13),(11,19),(19,19),(13,23),(17,23)]
            )
        case "cat":
            return (
                body: [(7,3),(23,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(15,11),(23,11),(11,15),(15,15),(19,15)],
                eyes: [(11,9),(19,9)],
                accent: [(5,5),(25,5),(15,13),(9,19),(15,19),(21,19),(7,23),(11,23),(19,23),(23,23)]
            )
        case "owl":
            return (
                body: [(11,3),(15,3),(19,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(23,11),(7,15),(11,15),(15,15),(19,15),(23,15)],
                eyes: [(11,9),(19,9)],
                accent: [(9,9),(13,9),(17,9),(21,9),(15,13),(5,19),(11,19),(19,19),(25,19),(7,23),(23,23)]
            )
        case "penguin":
            return (
                body: [(11,3),(15,3),(19,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(23,11),(7,15),(23,15),(11,19),(15,19),(19,19)],
                eyes: [(11,9),(19,9)],
                accent: [(11,11),(15,11),(19,11),(11,15),(15,15),(19,15),(9,23),(15,23),(21,23)]
            )
        case "dragon":
            return (
                body: [(11,3),(15,3),(19,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(15,11),(23,11),(7,15),(11,15),(15,15),(19,15),(23,15)],
                eyes: [(11,9),(19,9)],
                accent: [(3,3),(27,3),(27,11),(27,15),(23,19),(19,23),(15,27),(11,23),(7,19),(3,15)]
            )
        case "turtle":
            return (
                body: [(11,7),(15,7),(19,7),(7,11),(11,11),(15,11),(19,11),(23,11),(7,15),(11,15),(15,15),(19,15),(23,15),(11,19),(15,19),(19,19)],
                eyes: [(11,9),(19,9)],
                accent: [(15,11),(11,13),(19,13),(5,19),(25,19),(7,23),(23,23)]
            )
        case "rabbit":
            return (
                body: [(11,7),(15,7),(19,7),(7,11),(15,11),(23,11),(11,15),(15,15),(19,15)],
                eyes: [(11,9),(19,9)],
                accent: [(11,1),(13,1),(17,1),(19,1),(11,3),(19,3),(11,5),(19,5),(9,19),(15,19),(21,19)]
            )
        case "jellyfish":
            return (
                body: [(11,3),(15,3),(19,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(11,11),(15,11),(19,11),(23,11)],
                eyes: [(11,9),(19,9)],
                accent: [(7,15),(11,15),(15,15),(19,15),(23,15),(5,19),(9,19),(15,19),(21,19),(25,19),(3,23),(11,23),(19,23),(27,23),(5,27),(15,27),(25,27)]
            )
        case "axolotl":
            return (
                body: [(11,7),(15,7),(19,7),(7,11),(11,11),(15,11),(19,11),(23,11),(11,15),(15,15),(19,15)],
                eyes: [(11,9),(19,9)],
                accent: [(3,3),(5,5),(7,7),(23,7),(25,5),(27,3),(9,19),(15,19),(21,19),(7,23),(15,23),(23,23)]
            )
        default:
            // Generic round creature fallback
            return (
                body: [(11,3),(15,3),(19,3),(7,7),(11,7),(15,7),(19,7),(23,7),(7,11),(15,11),(23,11),(7,15),(11,15),(15,15),(19,15),(23,15),(11,19),(15,19),(19,19)],
                eyes: [(11,9),(19,9)],
                accent: []
            )
        }
    }
}

// MARK: - Status Icon View (unified)
struct StatusIcon: View {
    let phase: SessionPhase
    let size: CGFloat

    init(phase: SessionPhase, size: CGFloat = 12) {
        self.phase = phase
        self.size = size
    }

    var body: some View {
        switch phase {
        case .waitingForInput:
            WaitingForInputIcon(size: size)
        case .waitingForApproval:
            WaitingForApprovalIcon(size: size)
        case .processing, .compacting:
            RunningIcon(size: size)
        case .idle, .ended:
            IdleIcon(size: size)
        }
    }
}
