cask "macmiddleclick" do
  version "1.0.1"
  sha256 "d4f095287f3f92125951da369d9ec4dec80e4962531c2f19e7da64d740135bce"

  url "https://github.com/henrikhestnes/MacMiddleClick/releases/download/v#{version}/MacMiddleClick.zip"
  name "MacMiddleClick"
  desc "Middle-click with a three-finger tap or click on the trackpad"
  homepage "https://github.com/henrikhestnes/MacMiddleClick"

  depends_on macos: :sonoma

  app "MacMiddleClick.app"

  uninstall quit: "io.macmiddleclick.app"

  zap trash: "~/Library/Preferences/io.macmiddleclick.app.plist"

  caveats <<~EOS
    This build is signed with a self-signed certificate and has not been notarized by Apple.

    MacMiddleClick needs Accessibility access. Enable it in
    System Settings → Privacy & Security → Accessibility. Upgrades keep the permission.
  EOS
end
