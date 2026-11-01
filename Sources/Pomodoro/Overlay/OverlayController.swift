import AppKit
import SwiftUI
import Combine

/// Хостинг-вью, с которого можно тянуть окно за любое место.
/// Без него SwiftUI-контент перехватывает мышь, и isMovableByWindowBackground не работает.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

/// Плавающее borderless-окно, которое держится поверх всего,
/// включая полноэкранные приложения, и не крадёт фокус.
final class OverlayPanel: NSPanel {

    /// true — окно тянется за любую точку (для чипа без кнопок).
    /// false — тянется только за области WindowDragArea (для панели с кнопками).
    var dragAnywhere = false

    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    /// Перемещаем панель по глобальным координатам мыши. Это надёжнее, чем
    /// performDrag для borderless/nonactivating панели и не зависит от того,
    /// какой именно SwiftUI-host view вернёт hitTest.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if canStartDragging(at: event.locationInWindow) {
                dragStartMouseLocation = NSEvent.mouseLocation
                dragStartWindowOrigin = frame.origin
                return
            }
        case .leftMouseDragged:
            if let startMouse = dragStartMouseLocation,
               let startOrigin = dragStartWindowOrigin {
                let mouseLocation = NSEvent.mouseLocation
                setFrameOrigin(NSPoint(
                    x: startOrigin.x + mouseLocation.x - startMouse.x,
                    y: startOrigin.y + mouseLocation.y - startMouse.y
                ))
                return
            }
        case .leftMouseUp:
            if dragStartMouseLocation != nil {
                dragStartMouseLocation = nil
                dragStartWindowOrigin = nil
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }

    private func canStartDragging(at pointInWindow: NSPoint) -> Bool {
        guard let contentView else { return false }
        if dragAnywhere { return true }

        let pointInContent = contentView.convert(pointInWindow, from: nil)
        var hitView = contentView.hitTest(pointInContent)
        while let view = hitView {
            if view is DragNSView { return true }
            hitView = view.superview
        }
        return false
    }

    init(autosaveName: String, defaultRect: NSRect, dragAnywhere: Bool = false) {
        self.dragAnywhere = dragAnywhere
        super.init(contentRect: defaultRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // тень рисует сам SwiftUI-слой
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        setFrameAutosaveName(autosaveName)
    }
}

/// Управляет двумя независимыми оверлеями: чип-таймер и панель управления.
/// Видимость: когда таймер активен (идёт или на паузе) И оверлей включён.
///
/// Панели создаются лениво, а показ/скрытие всегда уходит на следующий
/// виток runloop — иначе показ окна изнутри @Published-события падает
/// в AttributeGraph (показ окна во время обновления ViewGraph).
@MainActor
final class OverlayController: ObservableObject {

    /// Вкл/выкл оверлея (переключатель в меню-баре). Сохраняется между запусками.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            scheduleVisibilityUpdate()
        }
    }

    private static let enabledKey = "overlay.enabled"

    private weak var vm: TimerViewModel?
    private var chipPanel: OverlayPanel?
    private var controlPanel: OverlayPanel?
    private var timerActive = false
    private var cancellables: Set<AnyCancellable> = []

    init(vm: TimerViewModel) {
        self.vm = vm
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true

        vm.$engine
            .map { $0.state != .idle }
            .removeDuplicates()
            .sink { [weak self] active in
                guard let self else { return }
                self.timerActive = active
                self.scheduleVisibilityUpdate()
            }
            .store(in: &cancellables)

        // Подхватываем изменение переключателя из окна настроек.
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let stored = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
                if stored != self.isEnabled { self.isEnabled = stored }
            }
            .store(in: &cancellables)
    }

    /// Откладываем показ/скрытие на следующий виток runloop,
    /// чтобы не трогать окна внутри цикла обновления SwiftUI.
    private func scheduleVisibilityUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.applyVisibility()
        }
    }

    private func applyVisibility() {
        let visible = isEnabled && timerActive
        guard let vm else { return }
        if visible {
            let panels = panelsIfNeeded(vm: vm)
            panels.chip.orderFront(nil)
            panels.controls.orderFront(nil)
        } else {
            chipPanel?.orderOut(nil)
            controlPanel?.orderOut(nil)
        }
    }

    private func panelsIfNeeded(vm: TimerViewModel) -> (chip: OverlayPanel, controls: OverlayPanel) {
        if let chipPanel, let controlPanel { return (chipPanel, controlPanel) }

        let chip = OverlayPanel(
            autosaveName: "overlay.chip",
            defaultRect: Self.defaultRect(width: 150, height: 50, offsetY: -40),
            dragAnywhere: true
        )
        chip.contentView = DraggableHostingView(rootView: TimerChipView(vm: vm))

        let controls = OverlayPanel(
            autosaveName: "overlay.controls",
            defaultRect: Self.defaultRect(width: 150, height: 46, offsetY: -100)
        )
        controls.contentView = DraggableHostingView(rootView: ControlPanelView(vm: vm))

        chipPanel = chip
        controlPanel = controls
        return (chip, controls)
    }

    /// Дефолтная позиция — правый верхний угол основного экрана.
    private static func defaultRect(width: CGFloat, height: CGFloat, offsetY: CGFloat) -> NSRect {
        guard let screen = NSScreen.main?.visibleFrame else {
            return NSRect(x: 200, y: 600, width: width, height: height)
        }
        return NSRect(
            x: screen.maxX - width - 24,
            y: screen.maxY + offsetY - height,
            width: width, height: height
        )
    }
}
