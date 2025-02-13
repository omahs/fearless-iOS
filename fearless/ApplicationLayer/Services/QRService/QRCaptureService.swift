import Foundation
import AVFoundation

protocol QRMatcherProtocol: AnyObject {
    func match(code: String) -> Bool
}

protocol QRCaptureServiceProtocol: AnyObject {
    var delegate: QRCaptureServiceDelegate? { get set }
    var delegateQueue: DispatchQueue { get set }

    func start()
    func stop()
}

protocol QRCaptureServiceFactoryProtocol {
    func createService(
        with matcher: QRMatcherProtocol,
        delegate: QRCaptureServiceDelegate?,
        delegateQueue: DispatchQueue?
    ) -> QRCaptureServiceProtocol
}

enum QRCaptureServiceError: Error {
    case deviceAccessDeniedPreviously
    case deviceAccessDeniedNow
    case deviceAccessRestricted
}

protocol QRCaptureServiceDelegate: AnyObject {
    func qrCapture(service: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession)
    func qrCapture(service: QRCaptureServiceProtocol, didMatch code: String)
    func qrCapture(service: QRCaptureServiceProtocol, didFailMatching code: String)
    func qrCapture(service: QRCaptureServiceProtocol, didReceive error: Error)
}

final class QRCaptureServiceFactory: QRCaptureServiceFactoryProtocol {
    func createService(
        with matcher: QRMatcherProtocol,
        delegate: QRCaptureServiceDelegate? = nil,
        delegateQueue: DispatchQueue?
    ) -> QRCaptureServiceProtocol {
        QRCaptureService(
            matcher: matcher,
            delegate: delegate,
            delegateQueue: delegateQueue
        )
    }
}

final class QRCaptureService: NSObject {
    static let processingQueue = DispatchQueue(label: "qr.capture.service.queue")

    private(set) var matcher: QRMatcherProtocol
    private(set) var captureSession: AVCaptureSession?

    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue: DispatchQueue

    init(
        matcher: QRMatcherProtocol,
        delegate: QRCaptureServiceDelegate?,
        delegateQueue: DispatchQueue? = nil
    ) {
        self.matcher = matcher
        self.delegate = delegate
        self.delegateQueue = delegateQueue ?? QRCaptureService.processingQueue

        super.init()
    }

    private func configureSessionIfNeeded() throws {
        guard self.captureSession == nil else {
            return
        }

        let device = AVCaptureDevice.devices(for: .video).first { $0.position == .back }

        guard let camera = device else {
            throw QRCaptureServiceError.deviceAccessRestricted
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            throw QRCaptureServiceError.deviceAccessRestricted
        }

        let output = AVCaptureMetadataOutput()

        let captureSession = AVCaptureSession()
        captureSession.addInput(input)
        captureSession.addOutput(output)

        self.captureSession = captureSession

        output.setMetadataObjectsDelegate(self, queue: QRCaptureService.processingQueue)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    }

    private func startAuthorizedSession() {
        QRCaptureService.processingQueue.async {
            do {
                try self.configureSessionIfNeeded()

                if let captureSession = self.captureSession {
                    captureSession.startRunning()

                    self.notifyDelegateWithCreation(of: captureSession)
                }
            } catch {
                self.notifyDelegate(with: error)
            }
        }
    }

    private func notifyDelegate(with error: Error) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didReceive: error)
        }
    }

    private func notifyDelegateWithCreation(of captureSession: AVCaptureSession) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didSetup: captureSession)
        }
    }

    private func notifyDelegateWithSuccessMatching(of code: String) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didMatch: code)
        }
    }

    private func notifyDelegateWithFailedMatching(of code: String) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didFailMatching: code)
        }
    }

    private func run(in _: DispatchQueue, block: @escaping () -> Void) {
        if delegateQueue != QRCaptureService.processingQueue {
            delegateQueue.async {
                block()
            }
        } else {
            block()
        }
    }
}

extension QRCaptureService: QRCaptureServiceProtocol {
    public func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.startAuthorizedSession()
                } else {
                    self.notifyDelegate(with: QRCaptureServiceError.deviceAccessDeniedNow)
                }
            }
        case .denied:
            notifyDelegate(with: QRCaptureServiceError.deviceAccessDeniedPreviously)
        case .restricted:
            notifyDelegate(with: QRCaptureServiceError.deviceAccessRestricted)
        @unknown default:
            break
        }
    }

    func stop() {
        QRCaptureService.processingQueue.async {
            self.captureSession?.stopRunning()
        }
    }
}

extension QRCaptureService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        guard let possibleCode = metadata.stringValue else {
            return
        }

        if matcher.match(code: possibleCode) {
            notifyDelegateWithSuccessMatching(of: possibleCode)
        } else {
            notifyDelegateWithFailedMatching(of: possibleCode)
        }
    }
}
