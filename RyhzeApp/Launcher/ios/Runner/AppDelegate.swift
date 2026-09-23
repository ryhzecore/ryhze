import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  ASWebAuthenticationPresentationContextProviding
{
  private var websiteSession: ASWebAuthenticationSession?
  private var websiteChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RyhzeWebAuth") else {
      assertionFailure("Ryhze website sign-in registrar is unavailable")
      return
    }
    let channel = FlutterMethodChannel(
      name: "ryhze/web-auth",
      binaryMessenger: registrar.messenger()
    )
    websiteChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "authenticate",
        let values = call.arguments as? [String: Any],
        let rawURL = values["url"] as? String,
        let url = URL(string: rawURL),
        url.scheme == "https",
        let callbackScheme = values["callbackScheme"] as? String,
        callbackScheme == "ryhze"
      else {
        result(FlutterError(code: "invalid", message: "Invalid website sign-in request.", details: nil))
        return
      }
      self?.websiteSession?.cancel()
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { [weak self] callback, error in
        defer { self?.websiteSession = nil }
        if let callback {
          result(callback.absoluteString)
        } else if let authError = error as? ASWebAuthenticationSessionError,
          authError.code == .canceledLogin
        {
          result(FlutterError(code: "cancelled", message: "Website sign-in was cancelled.", details: nil))
        } else {
          result(FlutterError(code: "failed", message: "Website sign-in failed.", details: nil))
        }
      }
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      self?.websiteSession = session
      if !session.start() {
        self?.websiteSession = nil
        result(FlutterError(code: "failed", message: "Website sign-in could not open.", details: nil))
      }
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window { return window }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
  }
}
