import MacPlatform
import PopupBookCore
import PopupBookRuntime
import SwiftUI

@main struct BookHostApp: App {
    @StateObject private var model = HostModel()
    @NSApplicationDelegateAdaptor(BookDelegate.self) var delegate
    var body: some Scene {
        Window(L10n.text("开合之间"), id: "book") {
            BookView(model: model).onAppear { delegate.model = model }.onDisappear { model.stop() }
        }.defaultSize(width: 1440, height: 960).windowStyle(.hiddenTitleBar).commands {
            CommandMenu(L10n.text("互动")) {
                ForEach(model.state.output.actions, id: \.id) { action in
                    Button(action.title) { model.coordinator.handle(.action(action.id)) }.disabled(
                        !action.enabled || !model.state.active || model.state.phase != .idle || model.failed
                    )
                    .keyboardShortcut(
                        action.shortcut.flatMap { $0.first }.map {
                            KeyboardShortcut(KeyEquivalent($0), modifiers: [.option])
                        })
                }
            }
            CommandMenu(L10n.text("目录")) {
                Button(L10n.text("上一页")) { model.coordinator.move(-1) }
                Button(L10n.text("下一页")) { model.coordinator.move(1) }
                Button(L10n.text("目录")) { model.directory = true }
            }
        }
    }
}
@MainActor final class BookDelegate: NSObject, NSApplicationDelegate {
    weak var model: HostModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        model.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
struct CanvasView: NSViewRepresentable {
    @ObservedObject var model: HostModel
    func makeNSView(context: Context) -> SharedCanvas {
        let view = SharedCanvas(composition: model.composition)
        view.onWindow = { [weak model] window in model?.attach(window) }
        model.canvas = view
        return view
    }
    func updateNSView(_ view: SharedCanvas, context: Context) {
        if view.isPaused == model.state.active { view.isPaused = !model.state.active }
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        view.setAccessibilityLabel(model.state.output.accessibility)
    }
    static func dismantleNSView(_ view: SharedCanvas, coordinator: ()) {
        view.isPaused = true
        view.composition = nil
    }
}
struct BookView: View {
    @ObservedObject var model: HostModel
    var body: some View {
        ZStack {
            CanvasView(model: model).frame(maxWidth: .infinity, maxHeight: .infinity).ignoresSafeArea()
            VStack {
                if model.controlsVisible {
                    HStack {
                        Text(model.currentTitle).font(.title3)
                        Text(
                            model.coordinator.following
                                ? model.coordinator.fold.angle.map { L10n.text("铰链 %@°", String(Int($0))) }
                                    ?? L10n.text("铰链角度暂不可用") : L10n.text("手动预览")
                        ).font(.caption)
                        if !model.state.active { Text(L10n.text("已暂停")) }
                        Spacer()
                        Button(L10n.text("目录")) { model.directory = true }
                    }
                    .padding(12).background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14)).padding(
                        20)
                }
                Spacer()
                if model.failed {
                    VStack(spacing: 12) {
                        Text(L10n.text("此页暂不可用"))
                        Text(model.failureDetails).font(.caption)
                        Button(L10n.text("重试")) {
                            if let id = model.state.current { model.coordinator.open(id) }
                        }
                        Button(L10n.text("返回目录")) { model.directory = true }
                    }
                    .padding(30).background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18))
                } else if model.state.current == nil && model.composition.registry.pages.isEmpty {
                    Text(L10n.text("没有可用页面，请打开目录查看。 ")).padding().background(.thickMaterial)
                }
                Spacer(minLength: 0)
                if model.controlsVisible {
                    Text(model.state.output.caption).font(.system(size: 18, weight: .medium, design: .serif))
                        .padding(12).background(.thickMaterial, in: Capsule()).allowsHitTesting(false)
                    controls.padding(.horizontal, 24).padding(.bottom, 18)
                } else {
                    HStack {
                        Spacer()
                        Button(L10n.text("显示控制条")) { model.controlsVisible = true }.padding().background(
                            .thickMaterial, in: Capsule())
                    }.padding(18)
                }
            }
        }.foregroundStyle(.primary).frame(minWidth: 880, minHeight: 680)
            .sheet(isPresented: $model.directory) { directory }
    }
    private var pageActionButtons: some View {
        ForEach(model.state.output.actions, id: \.id) { action in
            Button {
                model.coordinator.handle(.action(action.id))
            } label: {
                Text(action.title).fixedSize()
            }.disabled(!action.enabled || !model.state.active || model.state.phase != .idle || model.failed)
        }
    }

    @ViewBuilder private var bookActionButtons: some View {
        Button(L10n.text("上一页")) { model.coordinator.move(-1) }.disabled(model.state.phase != .idle)
        Button(L10n.text("下一页")) { model.coordinator.move(1) }.disabled(model.state.phase != .idle)
        Button(model.coordinator.soundEnabled ? L10n.text("声音已开") : L10n.text("声音已关")) {
            model.coordinator.setSound(!model.coordinator.soundEnabled)
            model.refresh()
        }
        Button(L10n.text("收起")) { model.controlsVisible = false }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    pageActionButtons
                    Spacer(minLength: 12)
                    bookActionButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal) {
                        HStack { pageActionButtons }
                    }.scrollIndicators(.hidden)
                    HStack {
                        Spacer()
                        bookActionButtons
                    }
                }
            }.buttonStyle(.bordered)
            HStack {
                Text(L10n.text("展开"))
                Slider(
                    value: Binding(
                        get: { model.state.following ? model.state.progress : model.state.manualProgress },
                        set: { model.coordinator.setManual($0) }),
                    in: 0...1
                ).disabled(model.coordinator.following)
                Text("\(Int(model.state.progress*100))%").monospacedDigit().frame(width: 48)
                Toggle(
                    L10n.text("跟随屏幕"),
                    isOn: Binding(
                        get: { model.coordinator.following },
                        set: {
                            model.coordinator.setFollowing($0)
                            model.refresh()
                        })
                ).toggleStyle(.switch).fixedSize()
                Button(L10n.text("校准")) { _ = model.coordinator.calibrate() }.disabled(
                    model.coordinator.fold.angle == nil || !model.coordinator.following)
            }
            Text(model.notice).font(.caption).lineLimit(2).frame(
                maxWidth: .infinity, minHeight: 32, maxHeight: 32, alignment: .leading)
        }.padding(16).background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
    private func isPageUnavailable(_ id: String) -> Bool {
        if case .failed = model.state.pageStates[id] { return true }
        return false
    }

    private var directory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("目录")).font(.title2)
            ForEach(model.composition.registry.pages, id: \.id) { page in
                Button {
                    model.coordinator.open(page.id)
                    model.directory = false
                } label: {
                    Text(page.title())
                }.disabled(isPageUnavailable(page.id))
            }
            ForEach(model.composition.registry.unavailablePublishedIDs, id: \.self) { id in
                Button(id) {}.disabled(true)
            }
            Button(L10n.text("关闭")) { model.directory = false }
        }.padding(28).frame(minWidth: 320)
    }
}
