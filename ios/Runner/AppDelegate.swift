import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Load API key from Info.plist for Google Maps
    // Flow: .env -> setup_env.sh -> GoogleMapsAPIKey.xcconfig -> (Xcode build) -> Info.plist -> here
    if let googleMapsKey = getGoogleMapsAPIKey() {
      GMSServices.provideAPIKey(googleMapsKey)
      print("✅ Google Maps API key successfully provided")
    } else {
      print("❌ ERROR: Google Maps API key not found in Info.plist")
      print("ℹ️  Please run: bash scripts/setup_env.sh")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Retrieve Google Maps API key from Info.plist
  private func getGoogleMapsAPIKey() -> String? {
    guard let apiKey = Bundle.main.infoDictionary?["GMSApiKey"] as? String else {
      print("❌ GMSApiKey not found in Info.plist")
      return nil
    }

    if apiKey.isEmpty || apiKey == "$(GOOGLE_MAPS_API_KEY)" {
      print("❌ GMSApiKey is empty or not substituted. Check build configuration.")
      return nil
    }

    print("📍 GMSApiKey found: \(apiKey.prefix(10))...")
    return apiKey
  }
}
