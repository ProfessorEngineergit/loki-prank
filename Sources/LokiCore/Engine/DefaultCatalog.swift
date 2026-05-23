import Foundation

public enum LokiFactory {
    /// Build an engine wired with the shared services and the full prank catalog.
    public static func makeEngine(store: StateStore = StateStore(),
                                  config: ConfigStore = ConfigStore()) -> PrankEngine {
        let context = PrankContext(runner: ScriptRunner(), store: store, config: config)
        let engine = PrankEngine(context: context)
        engine.register(allPranks())
        return engine
    }

    /// The complete catalog. Order here is the order shown in each category.
    public static func allPranks() -> [PrankModule] {
        [
            // Browser
            RickrollPrank(),
            TabFloodPrank(),
            AutoRefreshPrank(),
            // Display / UI
            HideDesktopIconsPrank(),
            FlipScreenPrank(),
            InvertColorsPrank(),
            WallpaperFreezePrank(),
            WallpaperSwapPrank(),
            AppearanceTogglePrank(),
            DockChaosPrank(),
            HotCornersPrank(),
            BigCursorPrank(),
            SlowAnimationsPrank(),
            ScreenSaverPrank(),
            AppActivatorPrank(),
            // Audio / voice
            SayPrank(),
            VolumeChaosPrank(),
            TalkingClockPrank(),
            RandomSoundsPrank(),
            ClipboardSpeakerPrank(),
            // Input / keyboard / mouse
            CursorJumpPrank(),
            ReverseScrollPrank(),
            SwapKeyboardLayoutPrank(),
            KeyRepeatChaosPrank(),
            TrackingSpeedPrank(),
            // Fake system
            FakeNotificationsPrank(),
            FakeDialogPrank(),
            HackerTerminalPrank(),
            GhostNotePrank(),
            CompanionPrank(),
            RevealPrank(),
        ]
    }
}
