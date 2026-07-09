import SwiftData
import SwiftUI

enum ContactVoiceNotesLayout {
    case button
    case details
}

struct ContactVoiceNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(VoiceNoteRecorder.self) private var recorder
    @Bindable var contact: ContactSnapshot
    var layout: ContactVoiceNotesLayout = .details

    @State private var errorMessage: String?
    @State private var showPermissionAlert = false

    private var sortedNotes: [ContactVoiceNote] {
        contact.voiceNotes.sorted { $0.createdAt > $1.createdAt }
    }

    private var isRecording: Bool {
        recorder.state == .recording
    }

    var body: some View {
        Group {
            switch layout {
            case .button:
                recordButton
            case .details:
                VStack(alignment: .leading, spacing: K.Spacing.md) {
                    if isRecording {
                        recordingIndicator
                    }

                    if !sortedNotes.isEmpty {
                        notesList
                    }
                }
            }
        }
        .alert("Couldn’t Record", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong while recording.")
        }
        .alert("Microphone Access Needed", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow microphone access in Settings to capture voice notes about people you meet.")
        }
    }

    private var recordButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            Label(
                isRecording ? "Stop Recording" : "Voice Note",
                systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill"
            )
        }
        .buttonStyle(.kPrimary(size: .medium, corner: .prominent, expands: true))
    }

    private var recordingIndicator: some View {
        HStack(spacing: K.Spacing.sm) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse, options: .repeating)

            Text("Recording \(ContactVoiceNote.formatDuration(recorder.elapsedTime))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)

            Spacer()

            Button("Cancel") {
                recorder.cancelRecording()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(K.Spacing.md)
        .background(K.Color.tileBackground, in: RoundedRectangle.k(K.Radius.sm))
    }

    private var notesList: some View {
        VStack(spacing: K.Spacing.sm) {
            ForEach(sortedNotes, id: \.id) { note in
                VoiceNoteRow(
                    note: note,
                    isPlaying: recorder.isPlaying(note),
                    progress: recorder.isPlaying(note) ? recorder.elapsedTime : 0,
                    onPlay: {
                        togglePlayback(for: note)
                    },
                    onDelete: {
                        deleteNote(note)
                    }
                )
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func toggleRecording() async {
        if isRecording {
            finishRecording()
            return
        }

        guard await recorder.requestPermissionIfNeeded() else {
            showPermissionAlert = true
            return
        }

        do {
            try recorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishRecording() {
        guard let result = recorder.stopRecording() else { return }

        let note = ContactVoiceNote(fileName: result.fileName, duration: result.duration)
        note.contact = contact
        contact.voiceNotes.append(note)
        modelContext.insert(note)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "The voice note couldn’t be saved: \(error.localizedDescription)"
        }
    }

    private func togglePlayback(for note: ContactVoiceNote) {
        if recorder.isPlaying(note) {
            recorder.stopPlayback()
            return
        }

        do {
            try recorder.play(note: note)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteNote(_ note: ContactVoiceNote) {
        if recorder.isPlaying(note) {
            recorder.stopPlayback()
        }
        VoiceNoteFiles.deleteFile(named: note.fileName)
        contact.voiceNotes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        try? modelContext.save()
    }
}

private struct VoiceNoteRow: View {
    let note: ContactVoiceNote
    let isPlaying: Bool
    let progress: TimeInterval
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: K.Spacing.md) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(K.Color.primary)
                    .frame(width: 36, height: 36)
                    .background(K.Color.primarySoft, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop playback" : "Play voice note")

            VStack(alignment: .leading, spacing: 2) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))

                Text(isPlaying ? ContactVoiceNote.formatDuration(progress) : note.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete voice note")
        }
        .padding(K.Spacing.md)
        .background(K.Color.tileBackground, in: RoundedRectangle.k(K.Radius.sm))
    }
}
