import Flutter
import UIKit
import PhotosUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PHPickerViewControllerDelegate {
  private var photoResult: FlutterResult?
  private var photoChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Original Android MainActivity sets FLAG_KEEP_SCREEN_ON (0x80).
    application.isIdleTimerDisabled = true
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SuhoCommunityPhoto") else { return }
    photoChannel = FlutterMethodChannel(name: "suho/community_photo", binaryMessenger: registrar.messenger())
    photoChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      guard call.method == "pick" else { result(FlutterMethodNotImplemented); return }
      guard self.photoResult == nil else { result(FlutterError(code: "busy", message: "사진 선택 중입니다.", details: nil)); return }
      guard let root = self.window?.rootViewController else { result(FlutterError(code: "unavailable", message: "사진 선택을 열지 못했습니다.", details: nil)); return }
      var configuration = PHPickerConfiguration()
      configuration.filter = .images
      configuration.selectionLimit = 1
      configuration.preferredAssetRepresentationMode = .compatible
      let picker = PHPickerViewController(configuration: configuration)
      picker.delegate = self
      self.photoResult = result
      var presenter = root
      while let presented = presenter.presentedViewController { presenter = presented }
      presenter.present(picker, animated: true)
    }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { finishPhoto(nil); return }
    provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
      DispatchQueue.main.async {
        guard let self = self else { return }
        guard let image = object as? UIImage else {
          self.finishPhoto(FlutterError(code: "invalid", message: "사진을 읽지 못했습니다.", details: nil)); return
        }
        let scale = min(1, 1280 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { context in
          UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
          image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in [0.82, 0.65, 0.45, 0.25] {
          if let data = resized.jpegData(compressionQuality: CGFloat(quality)), data.count <= 524288,
             let json = try? JSONSerialization.data(withJSONObject: ["mime": "image/jpeg", "data": data.base64EncodedString()]),
             let text = String(data: json, encoding: .utf8) { self.finishPhoto(text); return }
        }
        self.finishPhoto(FlutterError(code: "too_large", message: "사진 용량을 줄여 주세요.", details: nil))
      }
    }
  }

  private func finishPhoto(_ value: Any?) {
    let result = photoResult; photoResult = nil; result?(value)
  }
}
