import Foundation
import SwiftUI
import Speech
import AVFoundation
import Vision
import PhotosUI

@MainActor final class VoiceInput: ObservableObject {
    @Published var transcript=""
    @Published var listening=false
    @Published var errorMessage=""
    private let engine=AVAudioEngine()
    private let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"vi-VN"))
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var task:SFSpeechRecognitionTask?
    func start() async {
        let speech = await withCheckedContinuation { cont in SFSpeechRecognizer.requestAuthorization { cont.resume(returning:$0) } }
        guard speech == .authorized else {errorMessage="Chưa cấp quyền nhận dạng giọng nói.";return}
        let mic=await AVAudioApplication.requestRecordPermission()
        guard mic else {errorMessage="Chưa cấp quyền micro.";return}
        stop()
        do {
            transcript=""
            let request=SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults=true
            self.request=request
            let input=engine.inputNode
            input.installTap(onBus:0,bufferSize:1024,format:input.outputFormat(forBus:0)) { buffer,_ in request.append(buffer) }
            engine.prepare()
            try engine.start()
            listening=true
            task=recognizer?.recognitionTask(with:request) { [weak self] result,error in
                Task { @MainActor in
                    if let result {self?.transcript=result.bestTranscription.formattedString}
                    if error != nil || result?.isFinal == true {self?.stop()}
                }
            }
        }catch {errorMessage=error.localizedDescription;stop()}
    }
    func stop() {
        if engine.isRunning {engine.stop();engine.inputNode.removeTap(onBus:0)}
        request?.endAudio();task?.cancel();task=nil;request=nil;listening=false
    }
}
enum OCR {
    static func recognize(_ data:Data) async throws -> String {
        guard let image=UIImage(data:data)?.cgImage else {throw APIError.text("Ảnh không hợp lệ.")}
        return try await Task.detached(priority:.userInitiated) {
            let request=VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages=["vi-VN","en-US"]
            request.usesLanguageCorrection=true
            try VNImageRequestHandler(cgImage:image).perform([request])
            return (request.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n")
        }.value
    }
}
