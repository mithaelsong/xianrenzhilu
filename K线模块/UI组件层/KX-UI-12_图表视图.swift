//
//  KX-UI-12_图表视图.swift
//  仙人指路测试项目|K线模块
//
//  版本:2.3
//  职责:K线主图表视图。真实 CALayer 绘制:蜡烛图、成交量、价格轴、时间轴、十字线、实时价格线、手势
//  禁止事项:禁止 UI 直接查库作为唯一数据源;这里仅作为 UI 数据桥接,优先使用管道/DB/OKX,失败时显示明确降级样例数据
//

import AppKit
import Foundation
import os.log

// 导入K线日志工具

// 日志实例
private let logger = klineLogger


private extension Decimal {
    var cg: CGFloat { CGFloat(NSDecimalNumber(decimal: self).doubleValue) }
    var dbl: Double { NSDecimalNumber(decimal: self).doubleValue }
}

public final class KLChartThemeBundle {
    var background = KLUITheme.chartBackground.cgColor
    var grid = KLUITheme.gridColor.cgColor
    var axis = KLUITheme.axisText.cgColor
    var up = KLUITheme.candleUp.cgColor
    var down = KLUITheme.candleDown.cgColor
    var crosshair = KLUITheme.crosshair.cgColor
    var splitter = KLUITheme.splitter.cgColor
}


private extension NSColor {
    convenience init?(kxHex string: String) {
        var hex = string.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 { hex += "FF" }
        guard hex.count == 8, let int = UInt64(hex, radix: 16) else { return nil }
        let r = CGFloat((int >> 24) & 0xff) / 255
        let g = CGFloat((int >> 16) & 0xff) / 255
        let b = CGFloat((int >> 8) & 0xff) / 255
        let a = CGFloat(int & 0xff) / 255
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }

    var kxRGBAHex: String {
        let c = usingColorSpace(.deviceRGB) ?? self
        return String(format: "#%02X%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255), Int(c.alphaComponent * 255))
    }
}

// MARK: - 蜡烛图渲染 Layer

private final class CandlePlotLayer: CALayer {
    var candles: [KLCandlePoint] = []
    var viewport = KLViewportAdjustResult()
    var theme = KLChartThemeBundle()
    // 缓存预计算结果,避免 draw(in:) 每帧重复计算
    private var cachedVisibleCandles: [KLCandlePoint] = []
    private var cachedMinPrice: Double = 0
    private var cachedMaxPrice: Double = 1
    private var cachedSignature: String = ""

    func prepareForDrawing() {
        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(bounds.width / candleWidth) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else {
            cachedVisibleCandles = []
            cachedSignature = "empty"
            return
        }
        // 签名加入数据内容:最后一根K线的 close/high/low/openTime,确保数据变化时缓存刷新
        let last = candles.last
        let dataHash = "\(last?.close.description ?? "nil")|\(last?.high.description ?? "nil")|\(last?.low.description ?? "nil")|\(last?.openTime.timeIntervalSince1970 ?? 0)"
        let signature = "\(startIdx)-\(endIdx)-\(candles.count)-\(dataHash)"
        guard signature != cachedSignature else { return }
        cachedSignature = signature
        let visible = Array(candles[startIdx..<endIdx])
        cachedVisibleCandles = visible
        cachedMinPrice = visible.map { $0.low.dbl }.min() ?? 0
        cachedMaxPrice = visible.map { $0.high.dbl }.max() ?? 1
    }

    override func draw(in ctx: CGContext) {
        ctx.setFillColor(theme.background)
        ctx.fill(bounds)
        guard !cachedVisibleCandles.isEmpty, bounds.width > 8, bounds.height > 8 else { return }

        let range = max(cachedMaxPrice - cachedMinPrice, 0.00000001)
        let plotH = max(bounds.height - 16, 1)
        let top: CGFloat = 8
        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let bodyW = max(1 / max(contentsScale, 1), min(candleWidth * 0.72, candleWidth - 1))
        let wickW = max(1 / max(contentsScale, 1), min(2, candleWidth * 0.16))

        func y(_ price: Double) -> CGFloat {
            top + plotH * CGFloat((price - cachedMinPrice) / range)
        }

        // 网格
        ctx.setStrokeColor(theme.grid)
        ctx.setLineWidth(1 / max(contentsScale, 1))
        for i in 0...5 {
            let yy = top + plotH * CGFloat(i) / 5.0
            ctx.move(to: CGPoint(x: 0, y: yy.rounded()))
            ctx.addLine(to: CGPoint(x: bounds.width, y: yy.rounded()))
            ctx.strokePath()
        }

        ctx.setLineWidth(wickW)
        for (offset, candle) in cachedVisibleCandles.enumerated() {
            let centerX = CGFloat(offset) * candleWidth + candleWidth / 2
            let highY = y(candle.high.dbl)
            let lowY = y(candle.low.dbl)
            let openY = y(candle.open.dbl)
            let closeY = y(candle.close.dbl)
            let isUp = candle.close >= candle.open
            let color = isUp ? theme.up : theme.down
            ctx.setStrokeColor(color)
            ctx.setFillColor(color)
            ctx.move(to: CGPoint(x: centerX.rounded(), y: highY))
            ctx.addLine(to: CGPoint(x: centerX.rounded(), y: lowY))
            ctx.strokePath()
            let bodyY = min(openY, closeY)
            let bodyH = max(1 / max(contentsScale, 1), abs(closeY - openY))
            let rect = CGRect(x: centerX - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)
            ctx.fill(rect.integral)
        }
    }
}

private final class VolumePlotLayer: CALayer {
    var candles: [KLCandlePoint] = []
    var viewport = KLViewportAdjustResult()
    var theme = KLChartThemeBundle()
    // 缓存预计算结果
    private var cachedVisibleCandles: [KLCandlePoint] = []
    private var cachedMaxVol: Double = 1
    private var cachedSignature: String = ""

    func prepareForDrawing() {
        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(bounds.width / candleWidth) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else {
            cachedVisibleCandles = []
            cachedSignature = "empty"
            return
        }
        let signature = "\(startIdx)-\(endIdx)-\(candles.count)"
        guard signature != cachedSignature else { return }
        cachedSignature = signature
        let visible = Array(candles[startIdx..<endIdx])
        cachedVisibleCandles = visible
        cachedMaxVol = max(visible.map { $0.volume.dbl }.max() ?? 1, 0.00000001)
    }

    override func draw(in ctx: CGContext) {
        ctx.setFillColor(theme.background)
        ctx.fill(bounds)
        guard !cachedVisibleCandles.isEmpty, bounds.width > 8, bounds.height > 8 else { return }
        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let bodyW = max(1 / max(contentsScale, 1), min(candleWidth * 0.72, candleWidth - 1))
        let plotH = max(bounds.height - 8, 1)
        for (offset, candle) in cachedVisibleCandles.enumerated() {
            let centerX = CGFloat(offset) * candleWidth + candleWidth / 2
            let volDbl = candle.volume.dbl
            let h = max(volDbl > 0 ? 1 / max(contentsScale, 1) : 0, CGFloat(volDbl / cachedMaxVol) * plotH)
            let fillColor = candle.close >= candle.open
                ? (NSColor(cgColor: theme.up) ?? .systemGreen).withAlphaComponent(0.62).cgColor
                : (NSColor(cgColor: theme.down) ?? .systemRed).withAlphaComponent(0.62).cgColor
            ctx.setFillColor(fillColor)
            ctx.fill(CGRect(x: centerX - bodyW / 2, y: 4, width: bodyW, height: h).integral)
        }
    }
}

private final class AxisLayer: CALayer {
    enum AxisKind { case price, time }
    var kind: AxisKind = .price
    var candles: [KLCandlePoint] = []
    var viewport = KLViewportAdjustResult()
    var timeframe: KXTimeframe = .oneHour
    var theme = KLChartThemeBundle()
    var pricePrecision = 2

    // DateFormatter 缓存:按 timeframe 复用,避免每帧 draw 新建 ICU 对象(CPU 瓶颈)
    private static var _cachedFormatter: DateFormatter?
    private static var _cachedTimeframe: KXTimeframe?
    private static var _formatterLock = os_unfair_lock()

    private static func sharedFormatter(for tf: KXTimeframe) -> DateFormatter {
        os_unfair_lock_lock(&_formatterLock)
        defer { os_unfair_lock_unlock(&_formatterLock) }
        if let cached = _cachedFormatter, _cachedTimeframe == tf { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        switch tf {
        case .oneSecond: formatter.dateFormat = "HH:mm:ss"
        case .oneMinute, .threeMinutes, .fiveMinutes, .fifteenMinutes, .thirtyMinutes: formatter.dateFormat = "HH:mm"
        case .oneHour, .twoHours, .fourHours, .sixHours, .twelveHours: formatter.dateFormat = "MM/dd HH"
        case .oneDay, .twoDays, .threeDays, .oneWeek: formatter.dateFormat = "MM/dd"
        case .oneMonth, .threeMonths: formatter.dateFormat = "yyyy/MM"
        }
        _cachedFormatter = formatter
        _cachedTimeframe = tf
        return formatter
    }
    // ⚠️ 2026-06-22:价格轴以量柱分界线为界,上面画价格、下面画成交量最大值。
    // volumeHeight 由外部 layout() 根据当前 volumeRatio 传入,拖动分界线时动态变化。
    var volumeHeight: CGFloat = 0
    var splitterHeight: CGFloat = 1

    override func draw(in ctx: CGContext) {
        // ⚠️ 2026-06-22:CALayer 的 draw(in:) 不会自动设置 NSGraphicsContext,
        // NSString.draw 依赖它才能输出文字,必须先手动设置。
        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsContext
        ctx.setFillColor(theme.background)
        ctx.fill(bounds)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor(cgColor: theme.axis) ?? NSColor.secondaryLabelColor
        ]
        switch kind {
        case .price: drawPrice(ctx, attrs: attrs)
        case .time: drawTime(ctx, attrs: attrs)
        }
        NSGraphicsContext.current = nil
    }

    private func drawPrice(_ ctx: CGContext, attrs: [NSAttributedString.Key: Any]) {
        guard !candles.isEmpty else { return }
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(max(bounds.width, 280) / max(CGFloat(viewport.candleWidth), 1.5)) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else { return }
        let visible = Array(candles[startIdx..<endIdx])
        let minP = visible.map(\.low).min() ?? 0
        let maxP = visible.map(\.high).max() ?? 1
        let range = max(maxP.dbl - minP.dbl, 0.00000001)
        // 价格轴只覆盖 K线区域,整个 bounds 就是 K线区域,6等分均匀分布。
        for i in 0...5 {
            let price = maxP.dbl - range * Double(i) / 5.0
            let text = NSString(string: String(format: "%.*f", pricePrecision, price))
            let size = text.size(withAttributes: attrs)
            let y = (bounds.height - size.height) * CGFloat(5 - i) / 5.0
            text.draw(at: CGPoint(x: 4, y: y), withAttributes: attrs)
        }
    }

    private func drawTime(_ ctx: CGContext, attrs: [NSAttributedString.Key: Any]) {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 1 { logger.info("[PERF][KX-UI-12] AxisLayer.drawTime ms=\(dt) candles=\(candles.count)") }
        }
        guard !candles.isEmpty else { return }
        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(bounds.width / candleWidth) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else { return }
        let formatter = AxisLayer.sharedFormatter(for: timeframe)
        let step = max(1, visibleCount / 6)
        var lastRight: CGFloat = -999
        for absoluteIndex in stride(from: startIdx, to: endIdx, by: step) {
            let x = CGFloat(absoluteIndex - startIdx) * candleWidth + candleWidth / 2
            let label = NSString(string: formatter.string(from: candles[absoluteIndex].openTime))
            let size = label.size(withAttributes: attrs)
            let lx = max(2, min(x - size.width / 2, bounds.width - size.width - 2))
            if lx < lastRight + 8 { continue }
            label.draw(at: CGPoint(x: lx, y: (bounds.height - size.height) / 2), withAttributes: attrs)
            lastRight = lx + size.width
        }
    }
}

private final class CrosshairLayer: CALayer {
    var point = CGPoint.zero
    var active = false
    var theme = KLChartThemeBundle()
    var timeLabel = ""
    var priceLabel = ""

    override func draw(in ctx: CGContext) {
        guard active else { return }
        ctx.setStrokeColor(theme.crosshair)
        ctx.setLineWidth(1 / max(contentsScale, 1))
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        ctx.move(to: CGPoint(x: point.x.rounded(), y: 0))
        ctx.addLine(to: CGPoint(x: point.x.rounded(), y: bounds.height))
        ctx.move(to: CGPoint(x: 0, y: point.y.rounded()))
        ctx.addLine(to: CGPoint(x: bounds.width, y: point.y.rounded()))
        ctx.strokePath()
    }
}

private final class RealtimePriceLineLayer: CALayer {
    var y: CGFloat = 0
    var label = ""
    var direction: KLPriceDirection = .flat
    var theme = KLChartThemeBundle()

    override func draw(in ctx: CGContext) {
        guard bounds.width > 0, !label.isEmpty else { return }
        let color: CGColor = direction == .down ? theme.down : (direction == .up ? theme.up : theme.axis)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(1 / max(contentsScale, 1))
        ctx.setLineDash(phase: 0, lengths: [5, 3])
        ctx.move(to: CGPoint(x: 0, y: y.rounded()))
        ctx.addLine(to: CGPoint(x: bounds.width, y: y.rounded()))
        ctx.strokePath()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor(cgColor: color) ?? NSColor.labelColor]
        let text = NSString(string: label)
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: max(2, bounds.width - size.width - 6), y: max(2, min(y - size.height / 2, bounds.height - size.height - 2))), withAttributes: attrs)
    }
}

// MARK: - 主图表视图

public class KXUI12KLineChartView: NSView {
    private let candleLayer = CandlePlotLayer()
    private let volumeLayer = VolumePlotLayer()
    private let priceAxisLayer = AxisLayer()
    private let volumeMaxLabel = NSTextField(labelWithString: "")
    private let timeAxisLayer = AxisLayer()
    private let crosshairLayer = CrosshairLayer()
    private let realtimeLineLayer = RealtimePriceLineLayer()
    private let splitterLayer = CALayer()
    private let timeAxisTopBorderLayer = CALayer()
    private let theme = KLChartThemeBundle()
    private var professionalIndicatorInstanceIDs: Set<String> = []
    public var currentProfessionalIndicatorInstanceIDs: Set<String> { professionalIndicatorInstanceIDs }
    public func syncProfessionalIndicatorInstanceIDs(_ ids: Set<String>) {
        for id in ids where !professionalIndicatorInstanceIDs.contains(id) {
            professionalIndicatorInstanceIDs.insert(id)
        }
    }

    public func recalculateAllProfessionalIndicators() {
        let context = makeCurrentIndicatorCalculationContext()
        isRecalculatingIndicators = true
        defer { isRecalculatingIndicators = false }
        for instanceID in professionalIndicatorInstanceIDs {
            try? KXProfessionalIndicatorInstanceManager.shared.recalculateAndSubmit(instanceID: instanceID, context: context)
        }
        reloadExternalOverlays()
        rebuildIndicatorHeader()
    }

    private let indicatorChipOverlay = NSView()
    private var embeddedSettingsPanel: NSView?
    private var embeddedSettingsArrowLayer: CAShapeLayer?
    // 新链路
    private let newOverlayRenderer = KXUI19ChartOverlayRendererLayer()
    // 十字光标时间标签(显示在时间轴上,跟随时间虚线左右移动)
    private let crosshairTimeLabel = CATextLayer()
    // 十字光标价格标签(显示在价格轴上,跟随价格虚线上下移动)
    private let crosshairPriceLabel = CATextLayer()
    // 量柱折叠按钮
    private var volumeCollapseButton = KXUIGlassIconButton(icon: .chevronDown, size: 18)
    // 附图折叠/关闭按钮(直接放在附图右上角,无标题栏)
    private var subpaneCollapseButtons: [KXUIGlassIconButton] = []
    private var subpaneCloseButtons: [KXUIGlassIconButton] = []
    // 附图主题分界线图层(可拖动)
    private var subpaneDividerLayers: [KXUIThemedDividerLayer] = []
    // 副图 plot layer 数组(与 subpaneSlots 一一对应)
    private var subpaneLayers: [CALayer] = []
    private var isVolumeCollapsed: Bool = false
    private let volumeCollapsedRatio: CGFloat = 0.15
    private let subpaneExpandedRatio: CGFloat = 0.85
    private var isDraggingInnerSplitter = false
    private var activeInnerSplitterIndex: Int?
    private let innerSplitterHotZone: CGFloat = 4

    public var symbol: String = "BTC-USDT"
    // 多画布/性能改造:实时 tick 只更新最后一根时走轻量刷新,不走全量 refreshData(不重算指标/不重建chip/不 reloadExternalOverlays)。
    // nil = 全量(切换/首次加载/缩放/拖动/加指标);.lightweight = 实时跳动只刷绘图层。
    private enum RealtimeRefreshMode { case lightweight }
    private var pendingRealtimeRefreshMode: RealtimeRefreshMode? = nil
    // 多画布:隐藏画布收到 tick 只更新数据,不做绘制;标记"显示时需刷一次"。
    private var needsRefreshOnShow = false
    // 多画布性能:隐藏画布收到 tick 时只标脏,不维护数组;显示时从缓存一次性补齐。
    private var needsRealtimeResyncOnShow = false
    public var candles: [KLCandlePoint] = [] { didSet {
        // [DIAG] 蜡烛数据变更诊断日志
        if oldValue.count != candles.count || oldValue.last?.openTime != candles.last?.openTime {
            logger.info("[KLine][DIAG] candles.didSet symbol=\(symbol) tf=\(timeframe.rawValue) count=\(candles.count) prev=\(oldValue.count) hidden=\(isHidden)")
        }
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][KX-UI-12] candles.didSet ms=\(dt) count=\(candles.count) prev=\(oldValue.count) mode=\(String(describing: pendingRealtimeRefreshMode))") }
        }
        // 清除指标上下文缓存(数据变化时需要重建)
        if oldValue.count != candles.count || oldValue.last?.openTime != candles.last?.openTime {
            cachedIndicatorContext = nil
            cachedTooltipTexts.removeAll()
            cachedTooltipSignature = ""
        }
        // ⚠️ 2026-06-23:数据变化同步到 UI-GL-71(唯一视口真相源)。
        let prevCount = viewportCalculator.viewport.totalCount
        viewportCalculator.viewport.totalCount = candles.count
        let vw = chartPlotWidth
        if vw > 1, !candles.isEmpty {
            // 首次加载或停在尾部(最新可见)时定位最新到屏幕中间;否则只按宽度重约束,不打扰用户看历史。
            if !hasInitialCentered || oldValue.isEmpty || (candles.count > prevCount && viewportCalculator.isNearRightEdge) {
                applyViewport(viewportCalculator.centerOnLatest(viewWidth: vw))
                hasInitialCentered = true
            } else {
                applyViewport(viewportCalculator.updateForViewWidth(vw))
            }
        }
        if isHidden && pendingRealtimeRefreshMode == .lightweight {
            // 隐藏画布收到实时 tick:只更新数据,不做绘制/图层工作,省 CPU。显示时再刷。
            needsRefreshOnShow = true
        } else if pendingRealtimeRefreshMode == .lightweight {
            lightweightRealtimeRefresh()
            needsDisplay = true
        } else if candles.count > 500 {
            // 大数据量(>500根):先轻量刷新快速显示,再异步全量刷新避免主线程阻塞
            lightweightRealtimeRefresh()
            needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.refreshData()
            }
        } else if pendingRealtimeRefreshMode == nil {
            // mode=nil 时(直接赋值 candles),检查数据是否实质变化
            let hasRealChange = oldValue.count != candles.count
                || oldValue.last?.openTime != candles.last?.openTime
                || (oldValue.count > 0 && oldValue[oldValue.count-1].close != candles[candles.count-1].close)
            if hasRealChange {
                refreshData()
                needsDisplay = true
            } else {
                // 数据无实质变化(如切换 viewport 后赋值相同数据),只走轻量刷新
                lightweightRealtimeRefresh()
                needsDisplay = true
            }
        } else {
            refreshData()
            needsDisplay = true
        }
    } }
    public var timeframe: KXTimeframe = .oneHour { didSet {
        // 时间框架切换时强制刷新,不受 refreshData 限流影响
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][KX-UI-12] timeframe.didSet ms=\(dt)") }
        }
        // 先直接重新计算并提交指标 overlay,确保新 timeframe 的 overlay 立即提交
        let context = makeCurrentIndicatorCalculationContext()
        isRecalculatingIndicators = true
        defer { isRecalculatingIndicators = false }
        for instanceID in professionalIndicatorInstanceIDs {
            try? KXProfessionalIndicatorInstanceManager.shared.recalculateAndSubmit(instanceID: instanceID, context: context)
        }
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsDisplay = true
    }}
    public var viewport = KLViewportAdjustResult(candleWidth: 8)
    public var realtimePrice = KLRealtimePriceLineState()
    public var crosshairActive = false
    public var crosshairPoint = CGPoint.zero
    public var onCrosshairUpdated: ((Date?, Decimal?) -> Void)?
    private var tracking: NSTrackingArea?
    private var realtimeObserver: NSObjectProtocol?
    private var indicatorOverlayDidChangeObserver: NSObjectProtocol?
    private var chartPaneLayoutDidChangeObserver: NSObjectProtocol?
    private var patternSettingsObserver: NSObjectProtocol?
    private var patternSettingsRefreshWorkItem: DispatchWorkItem?
    private var viewportSettledRefreshWorkItem: DispatchWorkItem?
    private var memoryUpdatedObserver: NSObjectProtocol?
    private var lastPatternRecognitionSignature: String?
    private var loadingMessage: String? = "正在请求 OKX..."
    private var isShowingPreviewCandles = false
    private var lastRealtimeLogAt: TimeInterval = 0
    private var isRecalculatingIndicators = false
    private var isRefreshingData = false
    private var lastLightweightRefreshAt: TimeInterval = 0
    private var lastCrosshairUpdateAt: TimeInterval = 0
    private var lastIndicatorHeaderSignature: String = ""
    private var indicatorChipButtons: [String: NSButton] = [:]
    private var cachedIndicatorContext: KXIndicatorCalculationContext?
    private var cachedIndicatorContextSignature: String = ""
    private var cachedTooltipTexts: [String: String] = [:]
    private var cachedTooltipSignature: String = ""
    // ⚠️ 2026-06-22:K线/量柱分界线可拖动。volumeRatio 从写死改为可存储,拖动时调整。
    private var volumeRatio: CGFloat = 0.24
    private var isDraggingSplitter = false
    private let splitterHotZone: CGFloat = 6
    // ⚠️ 2026-06-23:鼠标左键拖动平移用。NSEvent.deltaX 在 mouseDragged 恒为0,
    // 必须用 locationInWindow 自己算增量。mouseDown 记起点,mouseDragged 算 dx。
    private var lastDragX: CGFloat?
    // ⚠️ 2026-06-23:接回UI模块通用图表索引视口计算器(UI-GL-71)。
    // 分工:K线模块(业务层)只提供手势指令和图层刷新,视口计算全部由UI模块负责。
    private var viewportCalculator = UIChartIndexViewportCalculator()
    // 首次有效布局后定位最新K线到屏幕中间(只做一次,后续靠跟随逻辑)。
    private var hasInitialCentered = false
    // K线实际绘图区宽度(= 总宽 - 价格轴宽),必须与 layout() 的 plotW 算法完全一致。
    // 这是传给 UI-GL-71 的 viewWidth 口径(图层 candleLayer.frame.width 也是这个值),否则 clamp 不匹配。
    private var chartPlotWidth: Double {
        let bw = bounds.width
        let priceAxisWidth: CGFloat = max(72, min(96, bw * 0.12))
        return Double(max(0, bw - priceAxisWidth))
    }

    // MARK: - 副图系统(2026-07-05)
    private struct SubpaneSlot {
        let id: String
        var isExpanded: Bool
        var height: CGFloat
        var indicators: [KXTechnicalIndicator]
        var instanceID: String?  // 专业指标实例ID(新链路)
    }
    private var subpaneSlots: [SubpaneSlot] = []
    private var subpaneOverlayRenderers: [KXUI19ChartOverlayRendererLayer] = []
    private var subpaneTitleLabels: [NSTextField] = []
    private var subpaneSettingsButtons: [KXUIGlassIconButton] = []

    public override init(frame frameRect: NSRect) { super.init(frame: frameRect); commonInit() }
    public required init?(coder: NSCoder) { super.init(coder: coder); commonInit() }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = KLUITheme.chartBackground.cgColor
        priceAxisLayer.kind = .price
        volumeMaxLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        volumeMaxLabel.textColor = KLUITheme.axisText
        volumeMaxLabel.backgroundColor = NSColor.clear
        volumeMaxLabel.isBordered = false
        volumeMaxLabel.alignment = .left
        addSubview(volumeMaxLabel)
        // ⚠️ 2026-06-23:配置 UI-GL-71 回调。手势/数据变化由计算器算出视口后回调到K线刷新。
        viewportCalculator.onPanEnded = { [weak self] in
            // 移动结束只做轻量刷新。形态识别不得挂在 K线移动链路上,否则会造成拖动卡死。
            self?.lightRefresh()
        }
        viewportCalculator.onViewportChanged = { [weak self] vp in
            // 视口实时变化只同步 viewport + 轻量重画。
            // 禁止在移动过程中调度形态识别/指标计算/WorkItem。
            guard let self else { return }
            self.applyViewport(vp)
            self.lightRefresh()
        }
        // 将 priceAxisLayer 只覆盖 K线区域(分界线上方),避免价格画到量柱区域。
        timeAxisLayer.kind = .time
        // 时间轴上边缘主题描边
        timeAxisTopBorderLayer.backgroundColor = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.22) : NSColor.black.withAlphaComponent(0.16)).cgColor
        timeAxisTopBorderLayer.zPosition = 1  // 确保在 volumeLayer 之上,避免左侧被遮挡
        layer?.addSublayer(timeAxisTopBorderLayer)
        // 量柱折叠按钮
        volumeCollapseButton.onTap = { [weak self] in self?.toggleVolumeCollapse() }
        volumeCollapseButton.updateIcon(.chevronDown, size: 22)
        addSubview(volumeCollapseButton)
        // ⚠️ 2026-06-22:splitterLayer 提到价格轴之上(realtimeLine 之后、crosshair 之前),否则价格轴图层用背景色填满会遮住右侧分界线。
        let layers: [CALayer] = [candleLayer, volumeLayer, priceAxisLayer, timeAxisLayer, realtimeLineLayer, splitterLayer, crosshairLayer]
        for item in layers {
            item.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            item.needsDisplayOnBoundsChange = true
            item.actions = [
                "bounds": NSNull(),
                "position": NSNull(),
                "frame": NSNull(),
                "contents": NSNull(),
                "backgroundColor": NSNull()
            ]
            layer?.addSublayer(item)
        }
        indicatorChipOverlay.wantsLayer = true
        indicatorChipOverlay.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(indicatorChipOverlay)
        splitterLayer.backgroundColor = KLUITheme.splitter.cgColor
        applyTheme()
        installRealtimeObserver()
        installMemoryUpdatedObserver()
        installIndicatorOverlayObserver()
        installChartPaneLayoutObserver()
        installPatternSettingsObserver()
        // 新链路 overlay renderer
        newOverlayRenderer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        newOverlayRenderer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "contents": NSNull(),
            "backgroundColor": NSNull()
        ]
        layer?.addSublayer(newOverlayRenderer)

        // 十字光标时间标签(显示在时间轴区域,跟随竖虚线左右移动)
        crosshairTimeLabel.fontSize = 10
        crosshairTimeLabel.alignmentMode = .center
        crosshairTimeLabel.backgroundColor = KLUITheme.chartBackground.withAlphaComponent(0.85).cgColor
        crosshairTimeLabel.foregroundColor = KLUITheme.axisText.cgColor
        crosshairTimeLabel.cornerRadius = 3
        crosshairTimeLabel.borderWidth = 0.5
        crosshairTimeLabel.borderColor = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.35)).cgColor
        crosshairTimeLabel.isHidden = true
        crosshairTimeLabel.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        crosshairTimeLabel.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull(), "backgroundColor": NSNull()]
        layer?.addSublayer(crosshairTimeLabel)

        // 十字光标价格标签(显示在价格轴区域,跟随横虚线上下移动)
        crosshairPriceLabel.fontSize = 10
        crosshairPriceLabel.alignmentMode = .center
        crosshairPriceLabel.backgroundColor = KLUITheme.chartBackground.withAlphaComponent(0.85).cgColor
        crosshairPriceLabel.foregroundColor = KLUITheme.axisText.cgColor
        crosshairPriceLabel.cornerRadius = 3
        crosshairPriceLabel.borderWidth = 0.5
        crosshairPriceLabel.borderColor = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.35)).cgColor
        crosshairPriceLabel.isHidden = true
        crosshairPriceLabel.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        crosshairPriceLabel.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull(), "backgroundColor": NSNull()]
        layer?.addSublayer(crosshairPriceLabel)

        // 加载持久化的专业指标实例
        loadPersistedProfessionalIndicators()
    }

    func loadPersistedProfessionalIndicators() {
        let manager = KXProfessionalIndicatorInstanceManager.shared
        let persistedInstances = manager.allInstances().sorted { $0.updatedAt > $1.updatedAt }
        guard !persistedInstances.isEmpty else { return }
        for instance in persistedInstances {
            professionalIndicatorInstanceIDs.insert(instance.id)
            // 副图指标:恢复对应的 subpane slot
            if instance.pane == .sub, subpaneSlots.first(where: { $0.instanceID == instance.id }) == nil {
                syncProfessionalSubpaneSlot(for: instance)
            }
        }
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsLayout = true
        logger.info("[KLine][Init] loaded \(persistedInstances.count) persisted instances")
    }

    deinit {
        if let realtimeObserver { NotificationCenter.default.removeObserver(realtimeObserver) }
        if let memoryUpdatedObserver { NotificationCenter.default.removeObserver(memoryUpdatedObserver) }
        if let indicatorOverlayDidChangeObserver { NotificationCenter.default.removeObserver(indicatorOverlayDidChangeObserver) }
        if let chartPaneLayoutDidChangeObserver { NotificationCenter.default.removeObserver(chartPaneLayoutDidChangeObserver) }
        if let patternSettingsObserver { NotificationCenter.default.removeObserver(patternSettingsObserver) }
        patternSettingsRefreshWorkItem?.cancel()
        viewportSettledRefreshWorkItem?.cancel()
        // 多画布改造:画布销毁不得停掉全局实时聚合引擎(聚合器是单例多币对,由面板整体生命周期管)。
        // 原来这里调 KLOKXRealtimeKLineRuntime.shared.stop() 会让关一个标签=所有币对断流。退订某币对改由 closeInstrumentTab 调 unsubscribe(symbol:)。
        // ⚠️ 画布销毁时不得移除全局实例管理器中的指标实例。
        // KXProfessionalIndicatorInstanceManager 是单例,所有币对共享。
        // 移除实例会导致其他币对的MA标签消失。
        // 指标实例的生命周期由用户通过设置面板控制(添加/删除),不由画布deinit控制。
        professionalIndicatorInstanceIDs.removeAll()
    }

    private func installRealtimeObserver() {
        if realtimeObserver != nil { return }
        realtimeObserver = NotificationCenter.default.addObserver(forName: .KLRealtimeCandleUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            // 多画布性能:实时通知是全局广播,每 tick 会触发所有画布的观察者。
            // 隐藏画布不需要实时跳动(显示时从缓存补齐),在最前面直接返回,
            // 避免为几十张隐藏画布做 userInfo 取值/类型转换/日志。
            guard !self.isHidden else { return }
            guard let instID = notification.userInfo?[KLRealtimeCandleNotificationKey.instrumentID] as? String,
                  let tf = notification.userInfo?[KLRealtimeCandleNotificationKey.timeframe] as? KXTimeframe,
                  let candle = notification.userInfo?[KLRealtimeCandleNotificationKey.candle] as? KLCandlePoint else {
                return
            }
            // 不是本画布的币对/周期直接忽略(不再写 ignore 日志,原来那句会随画布数×每 tick 刷屏造成 CPU 尖峰)。
            guard instID == self.symbol, tf == self.timeframe else { return }
            self.applyRealtimeCandle(candle)
        }
    }

    private func installIndicatorOverlayObserver() {
        if indicatorOverlayDidChangeObserver != nil { return }
        indicatorOverlayDidChangeObserver = NotificationCenter.default.addObserver(forName: .KXIndicatorOverlayDidChange, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            // 隐藏画布不响应 overlay 变更通知,避免隐藏 canvas 消耗 CPU
            guard !self.isHidden else { return }
            // 多画布:新专业指标变更只刷新本画布自己的实例;旧广播(object=nil)仍兼容。
            if let instanceID = note.object as? String, !self.professionalIndicatorInstanceIDs.contains(instanceID) { return }
            // 避免在 refreshData/recalculateAndSubmit 过程中接收自己刚发出去的通知,
            // 否则同一帧内会形成调用链:recalculateAndSubmit -> post -> reloadExternalOverlays -> calculate。
            guard !self.isRecalculatingIndicators else { return }
            self.reloadExternalOverlays()
        }
    }

    private func recalculateAndSubmitProfessional(instanceID: String, context: KXIndicatorCalculationContext) {
        isRecalculatingIndicators = true
        defer { isRecalculatingIndicators = false }
        try? KXProfessionalIndicatorInstanceManager.shared.recalculateAndSubmit(instanceID: instanceID, context: context)
    }

    private func installChartPaneLayoutObserver() {
        if chartPaneLayoutDidChangeObserver != nil { return }
        chartPaneLayoutDidChangeObserver = NotificationCenter.default.addObserver(forName: .KXChartPaneLayoutDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadPaneLayout()
        }
    }

    private func installPatternSettingsObserver() {
        if patternSettingsObserver != nil { return }
        patternSettingsObserver = NotificationCenter.default.addObserver(forName: .KPPatternSettingsDidChange, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            // 设置面板一次点击会保存 UserDefaults 并发通知。这里不能同步重算指标/形态;
            // 否则 mouseDown -> Notification -> refreshPatternRecognitionOverlays -> 依赖指标全量计算 会在主线程把 CPU 打满。
            let state = note.userInfo?["state"] as? KPPatternSettingState
            self.schedulePatternSettingsRefresh(reason: String(describing: note.object), changedState: state)
        }
    }

    private func schedulePatternSettingsRefresh(reason: String, changedState: KPPatternSettingState? = nil) {
        patternSettingsRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let changedState, !changedState.enabled {
                self.cleanupPatternOverlaysAndEvents(patternID: changedState.id, reason: reason)
            } else {
                self.lastPatternRecognitionSignature = nil
                self.reloadExternalOverlays()
            }
            self.needsDisplay = true
        }
        patternSettingsRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }
    
    private func cleanupPatternOverlaysAndEvents(patternID: String, reason: String) {
        let target = currentOverlayTarget()
        let manager = KLDefaultOverlayManager.shared
        let oldOverlays = manager.overlays(moduleID: "candle-pattern-recognition").filter { overlay in
            overlay.target.instrumentID == target.instrumentID &&
            overlay.target.timeframe == target.timeframe &&
            overlay.target.tabID == target.tabID &&
            (patternIDFromOverlayPayload(overlay) == patternID)
        }
        do {
            for overlay in oldOverlays {
                try manager.removeOverlay(moduleID: "candle-pattern-recognition", overlayID: overlay.id)
            }
            _ = try? KXFN26PatternAlertBridge.submitEvents(from: [], target: target)
        } catch {
            logger.error("[KLine][Pattern] cleanup failed id=\(patternID) error=\(error.localizedDescription)")
        }
    }
    
    private func patternIDFromOverlayPayload(_ overlay: KLExternalChartOverlay) -> String? {
        if case .candlePatternMarker(let payload) = overlay.payload {
            return payload.patternID
        }
        return nil
    }

    private func scheduleViewportSettledPatternRefresh(reason: String) {
        viewportSettledRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isHidden else { return }
            self.lastPatternRecognitionSignature = nil
            self.reloadExternalOverlays()
            self.needsDisplay = true
            logger.info("[KLine][Pattern] viewport settled, refresh visible pattern overlays reason=\(reason)")
        }
        viewportSettledRefreshWorkItem = workItem
        // 鼠标/触控板滚动会持续触发,这里只在停下后刷新一次。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func currentVisibleCandleRange() -> ClosedRange<Int> {
        guard !candles.isEmpty else { return 0...0 }
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let plotWidth = max(candleLayer.bounds.width, CGFloat(chartPlotWidth), 1)
        let visibleCount = max(1, Int(plotWidth / max(CGFloat(viewport.candleWidth), 1.5)) + 2)
        let endExclusive = min(candles.count, startIdx + visibleCount)
        let endIdx = max(startIdx, endExclusive - 1)
        return startIdx...endIdx
    }

    private func currentOverlayTarget() -> KLOverlayTarget {
        KLOverlayTarget(
            exchange: "OKX",
            instrumentType: "SPOT",
            instrumentID: symbol,
            timeframe: timeframe,
            appliesToAllTimeframes: false,
            tabID: nil
        )
    }

    private func makeCurrentIndicatorCalculationContext() -> KXIndicatorCalculationContext {
        let signature = "\(symbol)|\(timeframe.rawValue)|\(candles.count)|\(candles.last?.openTime.timeIntervalSince1970 ?? 0)"
        if let cached = cachedIndicatorContext, cachedIndicatorContextSignature == signature {
            return cached
        }
        let query = KLKLineQuery(symbol: symbol, timeframe: timeframe)
        let context = KXIndicatorCalculationContext(
            candles: candles,
            ohlcv: KXFN221IndicatorDataInterface.makeOHLCVSeries(candles: candles, query: query),
            query: query,
            target: currentOverlayTarget()
        )
        cachedIndicatorContext = context
        cachedIndicatorContextSignature = signature
        return context
    }

    private func refreshPatternRecognitionOverlays() {
        let t0 = CFAbsoluteTimeGetCurrent()
        let states = KPPatternSettingsStore.loadStates()
        let currentTimeframe = timeframe.rawValue
        let enabledPatternIDs = Set(states.values.filter { state in
            state.enabled && state.selectedTimeframes.contains(currentTimeframe)
        }.map(\.id))
        
        // [DIAG] 详细诊断日志：记录每个时间框架的形态识别状态
        logger.info("[KLine][Pattern][DIAG] refreshPatternRecognitionOverlays symbol=\(symbol) tf=\(currentTimeframe) candles=\(candles.count) enabledPatterns=\(enabledPatternIDs.count) ids=\(enabledPatternIDs.sorted().joined(separator: ","))")
        
        let settingsSignature = states.values
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\($0.enabled):\($0.selectedTimeframes.sorted().joined(separator: ","))" }
            .joined(separator: "|")
        let lastCandle = candles.last
        let dataSignature = "\(symbol)|\(currentTimeframe)|\(candles.count)|\(Int(lastCandle?.openTime.timeIntervalSince1970 ?? 0))|\(lastCandle?.close.description ?? "nil")|\(settingsSignature)"
        if dataSignature == lastPatternRecognitionSignature {
            logger.info("[KLine][Pattern][DIAG] skip identical signature symbol=\(symbol) tf=\(currentTimeframe)")
            return
        }
        lastPatternRecognitionSignature = dataSignature

        let target = currentOverlayTarget()
        guard !symbol.isEmpty, !candles.isEmpty, !enabledPatternIDs.isEmpty else {
            _ = try? KXFN26PatternAlertBridge.submitEvents(from: [], target: target)
            logger.info("[KLine][Pattern][DIAG] skip empty symbol=\(symbol.isEmpty) candles=\(candles.isEmpty) enabled=\(enabledPatternIDs.isEmpty)")
            return
        }

        let visibleRange = currentVisibleCandleRange()
        let visibleClosedIndices = visibleRange.compactMap { idx -> Int? in
            guard candles.indices.contains(idx), candles[idx].isClosed else { return nil }
            return idx
        }
        guard !visibleClosedIndices.isEmpty else {
            logger.info("[KLine][Pattern][DIAG] skip no closed visible candles symbol=\(symbol) tf=\(currentTimeframe) range=\(visibleRange.lowerBound)..\(visibleRange.upperBound)")
            return
        }
        
        logger.info("[KLine][Pattern][DIAG] scanning visibleRange=\(visibleRange.lowerBound)..\(visibleRange.upperBound) closed=\(visibleClosedIndices.count)")
        
        let requiredIndicatorIDs = KPPatternSettingsCatalog.requiredIndicatorIDs(for: enabledPatternIDs)
        var bestByKey: [String: PatternMatchResult] = [:]
        var snapshotByKey: [String: CandlePatternIndicatorSnapshot] = [:]
        for endIndex in visibleClosedIndices {
            let patternStartIndex = max(visibleRange.lowerBound, endIndex - 4)
            let patternWindow = (patternStartIndex...endIndex).compactMap { candles.indices.contains($0) && candles[$0].isClosed ? candles[$0] : nil }
            let contextWindow = (visibleRange.lowerBound...endIndex).compactMap { candles.indices.contains($0) && candles[$0].isClosed ? candles[$0] : nil }
            guard !patternWindow.isEmpty else { continue }
            let snapshot = CandlePatternIndicatorBridge.makeSnapshot(candles: contextWindow, requiredIndicatorIDs: requiredIndicatorIDs)
            let results = CandlePatternIndicatorBridge.recognize(candles: patternWindow, snapshot: snapshot, allowedPatternIDs: enabledPatternIDs)
            for result in results where enabledPatternIDs.contains(result.pattern.id) {
                let anchor = result.anchorTime ?? patternWindow.last?.openTime ?? Date(timeIntervalSince1970: 0)
                let key = "\(result.pattern.id):\(Int(anchor.timeIntervalSince1970))"
                if let existing = bestByKey[key], existing.confidence >= result.confidence { continue }
                bestByKey[key] = result
                snapshotByKey[key] = snapshot
            }
        }

        let keyedResults = bestByKey.map { key, result in (key: key, result: result) }.sorted { lhs, rhs in
            let lt = lhs.result.anchorTime ?? Date.distantPast
            let rt = rhs.result.anchorTime ?? Date.distantPast
            if lt != rt { return lt < rt }
            return lhs.result.confidence > rhs.result.confidence
        }
        let markers = keyedResults.flatMap { item in
            KPAD05PatternResultMarkerBridge.markers(
                from: [item.result],
                symbol: symbol,
                timeframe: timeframe,
                snapshot: snapshotByKey[item.key]
            )
        }
        let alertDescriptors = markers.compactMap { marker -> KLAlertEventDescriptor? in
            guard marker.severity == .high || marker.severity == .critical else { return nil }
            return KLAlertEventDescriptor(
                id: "KP-ALERT:\(marker.id)",
                ruleID: nil,
                symbol: marker.symbol,
                timeframe: marker.timeframe,
                kind: .patternSignal,
                title: marker.title,
                message: marker.message ?? "\(marker.symbol) \(marker.timeframe.rawValue) 出现形态信号",
                occurredAt: marker.coordinate.time ?? marker.createdAt,
                deliveryState: .pending,
                sound: KLSoundDescriptor(soundID: "pattern_\(marker.severity == .critical ? "critical" : "high")", displayName: "K线形态识别", volume: 0.9, repeatCount: marker.severity == .critical ? 2 : 1)
            )
        }
        do {
            let overlays = try KXFN25PatternOverlayBridge.submitOverlays(from: markers, target: target)
            let events = try KXFN26PatternAlertBridge.submitEvents(from: alertDescriptors, target: target)
            logger.info("[KLine][Pattern][DIAG] refreshed results symbol=\(symbol) tf=\(currentTimeframe) visibleClosed=\(visibleClosedIndices.count) results=\(keyedResults.count) markers=\(markers.count) overlays=\(overlays.count) alerts=\(events.count)")
        } catch {
            logger.error("[KLine][Pattern][DIAG] submit overlays/events failed: \(error.localizedDescription)")
        }
        let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        if dt > 1 { logger.info("[PERF][KX-UI-12] refreshPatternRecognitionOverlays ms=\(dt) candles=\(candles.count)") }
    }

    private var lastReloadExternalOverlaysAt: TimeInterval = 0

    public func reloadExternalOverlays() {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 1 { logger.info("[PERF][KX-UI-12] reloadExternalOverlays ms=\(dt)") }
        }
        let now = Date().timeIntervalSince1970
        if now - lastReloadExternalOverlaysAt < 0.03 { return }
        lastReloadExternalOverlaysAt = now
        refreshPatternRecognitionOverlays()
        reloadExternalOverlaysImpl()
    }

    private func reloadExternalOverlaysForce() {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 1 { logger.info("[PERF][KX-UI-12] reloadExternalOverlaysForce ms=\(dt)") }
        }
        lastReloadExternalOverlaysAt = Date().timeIntervalSince1970
        refreshPatternRecognitionOverlays()  // 修复：数据加载后触发形态识别
        reloadExternalOverlaysImpl()
    }

    private func reloadExternalOverlaysImpl() {
        let target = currentOverlayTarget()
        guard !candles.isEmpty else {
            logger.info("[DIAG][KX-UI-12] reloadExternalOverlays skipped: candles is empty")
            return
        }
        let overlays = KLDefaultOverlayManager.shared.allVisibleOverlays(target: target).filter { overlay in
            guard let instanceID = overlay.instanceID else { return true }
            return KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID)?.visible == true
        }
        let mainOverlays = overlays.filter { $0.pane == .main || $0.pane == nil }
        let subOverlays = overlays.filter { $0.pane == .sub }

        // 主图 overlay 渲染器
        newOverlayRenderer.candles = candles
        newOverlayRenderer.viewport = viewport
        newOverlayRenderer.apply(overlays: mainOverlays)

        // 副图 overlay 渲染器:按 instanceID 分发到对应 slot
        var overlaysByInstance: [String: [KLExternalChartOverlay]] = [:]
        for ov in subOverlays {
            guard let iid = ov.instanceID else { continue }
            overlaysByInstance[iid, default: []].append(ov)
        }
        for (index, slot) in subpaneSlots.enumerated() {
            guard index < subpaneOverlayRenderers.count, let iid = slot.instanceID else { continue }
            let renderer = subpaneOverlayRenderers[index]
            renderer.candles = candles
            renderer.viewport = viewport
            renderer.pane = .sub
            renderer.apply(overlays: overlaysByInstance[iid] ?? [])
        }

        // 更新 chip:用跨调用缓存,candles 不变时不重算指标。
        let tooltipSignature = "\(symbol)|\(timeframe.rawValue)|\(candles.count)|\(candles.last?.openTime.timeIntervalSince1970 ?? 0)"
        let shouldRecalculateTooltips = tooltipSignature != cachedTooltipSignature
        if shouldRecalculateTooltips {
            cachedTooltipTexts.removeAll()
            cachedTooltipSignature = tooltipSignature
        }
        let context = shouldRecalculateTooltips ? makeCurrentIndicatorCalculationContext() : cachedIndicatorContext ?? makeCurrentIndicatorCalculationContext()
        var chips: [KXIndicatorChipSnapshot] = []
        for ov in overlays {
            guard let instanceID = ov.instanceID else { continue }
            guard KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID) != nil else { continue }
            let text: String
            if let cached = cachedTooltipTexts[instanceID] {
                text = cached
            } else if let tooltipText = KXProfessionalIndicatorInstanceManager.shared.tooltipText(instanceID: instanceID, context: context) {
                text = tooltipText
                cachedTooltipTexts[instanceID] = tooltipText
            } else {
                text = "\(ov.moduleName)"
            }
            chips.append(KXIndicatorChipSnapshot(
                instanceID: instanceID,
                outputKey: ov.outputKey,
                pane: ov.pane ?? .main,
                text: text,
                colorHex: ov.style.fallbackHexColor,
                visible: true
            ))
        }
        logger.info("[DIAG][KX-UI-12] reloadExternalOverlays target=\(target.timeframe?.rawValue ?? "nil") candles=\(candles.count) overlays=\(overlays.count) main=\(mainOverlays.count) sub=\(subOverlays.count) visibleInstances=\(overlaysByInstance.keys.count)")
    }

    public func reloadPaneLayout() {
        // TODO: 接入 KX-FN-36 pane layout manager
        logger.info("[KLine][Pane] reloadPaneLayout")
    }

    private func installMemoryUpdatedObserver() {
        memoryUpdatedObserver = NotificationCenter.default.addObserver(forName: .KXTimeframeMemoryUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            guard let instID = notification.userInfo?[KXTimeframeMemoryUpdatedNotificationKey.instrumentID] as? String,
                  let tf = notification.userInfo?[KXTimeframeMemoryUpdatedNotificationKey.timeframe] as? KXTimeframe else { return }
            guard instID == self.symbol, tf == self.timeframe else { return }
            // 隐藏画布不需要通过内存更新持续重绘;显示时从缓存一次性补齐即可。
            guard !self.isHidden else { return }
            let cached = KLLowTimeframeCache.shared.allCandles(exchange: "OKX", instrumentID: instID, timeframe: tf)
            let validCached = cached.filter { $0.symbol == instID && $0.timeframe == tf && $0.source != "preview" }
            let ready = KLLowTimeframeCache.shared.historyReady(exchange: "OKX", instrumentID: instID, timeframe: tf)
            guard ready, !validCached.isEmpty else {
                let err = KLLowTimeframeCache.shared.historyError(exchange: "OKX", instrumentID: instID, timeframe: tf)
                if self.candles.isEmpty {
                    self.loadingMessage = err.map { "历史K线加载失败:\($0)" } ?? "正在按策略加载 \(instID) \(tf.rawValue) 真实K线..."
                    self.needsDisplay = true
                }
                logger.info("[KLine][UI] memory updated not-ready instID=\(instID) timeframe=\(tf.rawValue) ready=\(ready) count=\(cached.count) valid=\(validCached.count) error=\(err ?? "nil")")
                return
            }
            logger.info("[KLine][UI] memory updated apply instID=\(instID) timeframe=\(tf.rawValue) count=\(validCached.count)")
            self.loadingMessage = nil
            self.isShowingPreviewCandles = false
            self.candles = validCached
            self.applyLatestRealtimeCandleFromCacheIfAvailable(symbol: instID, timeframe: tf)
        }
    }

    public func applyTheme() {
        layer?.backgroundColor = KLUITheme.chartBackground.cgColor
        theme.background = KLUITheme.chartBackground.cgColor
        theme.grid = KLUITheme.gridColor.cgColor
        theme.axis = KLUITheme.axisText.cgColor
        theme.up = KLUITheme.candleUp.cgColor
        theme.down = KLUITheme.candleDown.cgColor
        theme.crosshair = KLUITheme.crosshair.cgColor
        theme.splitter = KLUITheme.splitter.cgColor
        volumeMaxLabel.textColor = NSColor(cgColor: theme.axis) ?? NSColor.secondaryLabelColor
        let crosshairBorder = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.35)).cgColor
        crosshairTimeLabel.backgroundColor = KLUITheme.chartBackground.withAlphaComponent(0.85).cgColor
        crosshairTimeLabel.foregroundColor = KLUITheme.axisText.cgColor
        crosshairTimeLabel.borderColor = crosshairBorder
        crosshairPriceLabel.backgroundColor = KLUITheme.chartBackground.withAlphaComponent(0.85).cgColor
        crosshairPriceLabel.foregroundColor = KLUITheme.axisText.cgColor
        crosshairPriceLabel.borderColor = crosshairBorder
        [candleLayer, volumeLayer, priceAxisLayer, timeAxisLayer, crosshairLayer, realtimeLineLayer].forEach { layer in
            if let l = layer as? CandlePlotLayer { l.theme = theme }
            if let l = layer as? VolumePlotLayer { l.theme = theme }
            if let l = layer as? AxisLayer { l.theme = theme }
            if let l = layer as? CrosshairLayer { l.theme = theme }
            if let l = layer as? RealtimePriceLineLayer { l.theme = theme }
            layer.setNeedsDisplay()
        }
        // 标记层也需要跟随浅/深主题重绘。形态标签文字/底色会读取 KLUITheme,
        // 这里必须在主题切换时显式标记 newOverlayRenderer 重绘。
        newOverlayRenderer.theme = theme
        newOverlayRenderer.setNeedsDisplay()
        splitterLayer.backgroundColor = theme.splitter
        timeAxisTopBorderLayer.backgroundColor = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.22) : NSColor.black.withAlphaComponent(0.16)).cgColor
        volumeCollapseButton.updateAppearance()
        for button in subpaneCollapseButtons + subpaneCloseButtons { button.updateAppearance() }
        for divider in subpaneDividerLayers { divider.theme = theme; divider.setNeedsDisplay() }
        for renderer in subpaneOverlayRenderers { renderer.theme = theme; renderer.setNeedsDisplay() }
        needsDisplay = true
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let newTracking = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(newTracking)
        tracking = newTracking
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let bw = bounds.width
        let bh = bounds.height
        let priceAxisWidth: CGFloat = max(72, min(96, bw * 0.12))
        let timeAxisHeight: CGFloat = 26
        let splitterHeight: CGFloat = 1
        let headerHeight: CGFloat = 18
        let plotW = max(0, bw - priceAxisWidth)

        // 量柱基础高度 H(未折叠时的预设值)
        let baseVolumeH = max(56, (bh - timeAxisHeight) * volumeRatio)

        // 量柱实际高度
        let volumeH: CGFloat
        if subpaneSlots.isEmpty {
            volumeH = baseVolumeH
            isVolumeCollapsed = false
        } else {
            volumeH = isVolumeCollapsed ? max(headerHeight, baseVolumeH * volumeCollapsedRatio) : baseVolumeH
        }

        // 计算各副图高度
        var subpaneHeights: [CGFloat] = []
        for slot in subpaneSlots {
            let h = slot.isExpanded ? max(headerHeight + 6, slot.height) : max(headerHeight, baseVolumeH * volumeCollapsedRatio)
            subpaneHeights.append(h)
        }

        // 内部分界线总高度
        let innerSplittersH = CGFloat(max(0, subpaneSlots.count)) * splitterHeight

        // 底部区域总高度(附图 + 内部分界线 + 量柱)
        let bottomTotalH = subpaneHeights.reduce(0, +) + innerSplittersH + volumeH

        // K线区域高度(保证最小80px)
        let candleH = max(80, bh - timeAxisHeight - bottomTotalH - splitterHeight)

        // 从底部向上堆叠布局(y=0 在底部)
        var currentY: CGFloat = timeAxisHeight

        // 时间轴上边缘描边
        timeAxisTopBorderLayer.frame = CGRect(x: 0, y: timeAxisHeight, width: bw, height: splitterHeight)

        // 附图:新添加的在下方(索引 0 在最下面)
        for (index, height) in subpaneHeights.enumerated() {
            if index < subpaneOverlayRenderers.count {
                subpaneOverlayRenderers[index].frame = CGRect(x: 0, y: currentY, width: plotW, height: height)
                subpaneOverlayRenderers[index].isHidden = false
            }
            // 折叠/关闭按钮放在附图右上角(无标题栏)
            let buttonSize: CGFloat = 18
            let buttonPadding: CGFloat = 4
            if index < subpaneCloseButtons.count {
                subpaneCloseButtons[index].frame = CGRect(x: plotW - buttonSize - buttonPadding, y: currentY + height - buttonSize - 4, width: buttonSize, height: buttonSize)
                subpaneCloseButtons[index].isHidden = false
            }
            if index < subpaneCollapseButtons.count {
                subpaneCollapseButtons[index].frame = CGRect(x: plotW - buttonSize * 2 - buttonPadding * 2, y: currentY + height - buttonSize - 4, width: buttonSize, height: buttonSize)
                subpaneCollapseButtons[index].isHidden = false
                subpaneCollapseButtons[index].updateIcon(subpaneSlots[index].isExpanded ? .chevronDown : .chevronUp, size: buttonSize)
            }
            // 附图标题栏(左上角)
            if index < subpaneTitleLabels.count {
                let titleLabel = subpaneTitleLabels[index]
                titleLabel.frame = CGRect(x: 6, y: currentY + height - 18, width: 120, height: 16)
                titleLabel.isHidden = false
                // 更新标题(从 instanceID 获取实例名字)
                if let instanceID = subpaneSlots[index].instanceID,
                   let instance = KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID) {
                    titleLabel.stringValue = instance.indicatorName
                }
            }
            // 附图设置按钮(标题右侧)
            if index < subpaneSettingsButtons.count {
                let settingsButton = subpaneSettingsButtons[index]
                settingsButton.frame = CGRect(x: 70, y: currentY + height - 20, width: 18, height: 18)
                settingsButton.isHidden = false
            }
            if index < subpaneDividerLayers.count {
                subpaneDividerLayers[index].frame = CGRect(x: 0, y: currentY + height, width: bw, height: splitterHeight)
                subpaneDividerLayers[index].isHidden = false
            }
            currentY += height + splitterHeight
        }

        // 隐藏未使用的按钮
        for index in subpaneSlots.count..<subpaneCloseButtons.count {
            subpaneCloseButtons[index].isHidden = true
            subpaneCollapseButtons[index].isHidden = true
            if index < subpaneTitleLabels.count {
                subpaneTitleLabels[index].isHidden = true
            }
            if index < subpaneSettingsButtons.count {
                subpaneSettingsButtons[index].isHidden = true
            }
        }

        // 量柱层(在最上面)
        volumeLayer.frame = CGRect(x: 0, y: currentY, width: plotW, height: volumeH)
        volumeMaxLabel.frame = CGRect(x: plotW, y: currentY, width: priceAxisWidth, height: volumeH)
        // 量柱折叠按钮固定在量柱右上角:18x18,与附图折叠按钮左对齐
        let volButtonSize: CGFloat = 18
        let buttonPadding: CGFloat = 4
        let minVisibleButtonH = headerHeight
        volumeCollapseButton.frame = CGRect(x: plotW - volButtonSize * 2 - buttonPadding * 2, y: currentY + volumeH - volButtonSize - 4, width: volButtonSize, height: volButtonSize)
        volumeCollapseButton.isHidden = subpaneSlots.isEmpty || volumeH < minVisibleButtonH
        currentY += volumeH

        // 外部分界线(K线/底部区域分界)
        splitterLayer.frame = CGRect(x: 0, y: currentY, width: bw, height: splitterHeight)
        currentY += splitterHeight

        // K线层
        candleLayer.frame = CGRect(x: 0, y: currentY, width: plotW, height: candleH)
        priceAxisLayer.frame = CGRect(x: plotW, y: currentY, width: priceAxisWidth, height: candleH)
        realtimeLineLayer.frame = candleLayer.frame
        newOverlayRenderer.frame = candleLayer.frame

        // 十字光标响应区域(从时间轴底部到K线顶部)
        crosshairLayer.frame = CGRect(x: 0, y: timeAxisHeight, width: plotW, height: currentY + candleH - timeAxisHeight)

        // 时间轴
        timeAxisLayer.frame = CGRect(x: 0, y: 0, width: plotW, height: timeAxisHeight)

        // 指标 chip
        indicatorChipOverlay.frame = CGRect(
            x: candleLayer.frame.minX + 6,
            y: candleLayer.frame.maxY - 24,
            width: max(100, candleLayer.frame.width - 12),
            height: 20
        )

        // 拖动时只几何重排+重画
        if isDraggingSplitter || isDraggingInnerSplitter {
            candleLayer.setNeedsDisplay()
            volumeLayer.setNeedsDisplay()
            splitterLayer.setNeedsDisplay()
            priceAxisLayer.setNeedsDisplay()
        } else {
            let vw = chartPlotWidth
            if vw > 1, !candles.isEmpty {
                if hasInitialCentered {
                    applyViewport(viewportCalculator.updateForViewWidth(vw))
                } else {
                    applyViewport(viewportCalculator.centerOnLatest(viewWidth: vw))
                    hasInitialCentered = true
                }
            }
            if !isRefreshingData {
                isRefreshingData = true
                defer { isRefreshingData = false }
                refreshData()
            }
        }
        updateButtonFrames()
    }

    private func updateButtonFrames() {
        let plotW = max(0, bounds.width - max(72, min(96, bounds.width * 0.12)))
        let bh = bounds.height
        let timeAxisHeight: CGFloat = 26
        let baseVolumeH = max(56, (bh - timeAxisHeight) * volumeRatio)
        let volumeH = isVolumeCollapsed ? max(14, baseVolumeH * volumeCollapsedRatio) : baseVolumeH

        volumeCollapseButton.frame = NSRect(x: plotW - 30, y: timeAxisHeight + volumeH - 24, width: 24, height: 20)
        volumeCollapseButton.isHidden = subpaneSlots.isEmpty

        var currentY: CGFloat = timeAxisHeight + volumeH + 1
        for (index, slot) in subpaneSlots.enumerated() {
            let slotH = slot.isExpanded ? max(14, slot.height) : max(14, baseVolumeH * volumeCollapsedRatio)
            if index < subpaneCollapseButtons.count {
                subpaneCollapseButtons[index].frame = NSRect(x: plotW - 52, y: currentY + slotH - 24, width: 24, height: 20)
            }
            if index < subpaneCloseButtons.count {
                subpaneCloseButtons[index].frame = NSRect(x: plotW - 28, y: currentY + slotH - 24, width: 20, height: 20)
            }
            currentY += 1 + slotH
        }
    }

    private func createCollapseButton() -> KXUIGlassIconButton {
        let btn = KXUIGlassIconButton(icon: .chevronDown, size: 18)
        btn.frame = NSRect(x: 0, y: 0, width: 24, height: 20)
        return btn
    }

    private func createCloseButton() -> KXUIGlassIconButton {
        let btn = KXUIGlassIconButton(icon: .xmark, size: 14)
        btn.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        return btn
    }

    @objc private func toggleVolumeCollapse() {
        isVolumeCollapsed.toggle()
        needsLayout = true
        logger.info("[KLine][Volume] collapsed=\(isVolumeCollapsed)")
    }

    @objc private func toggleSubpaneCollapse(_ sender: KXUIGlassIconButton) {
        guard let index = subpaneCollapseButtons.firstIndex(of: sender) else { return }
        guard index < subpaneSlots.count else { return }
        subpaneSlots[index].isExpanded.toggle()
        needsLayout = true
        logger.info("[KLine][Subpane] slot=\(index) expanded=\(subpaneSlots[index].isExpanded)")
    }

    @objc private func closeSubpane(_ sender: KXUIGlassIconButton) {
        guard let index = subpaneCloseButtons.firstIndex(of: sender) else { return }
        removeSubpaneSlot(at: index)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard candles.isEmpty else { return }
        let text = loadingMessage ?? "暂无K线数据"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: KLUITheme.axisText]
        let msg = NSString(string: text)
        let size = msg.size(withAttributes: attrs)
        msg.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }

    public func installInitialCandlesIfNeeded(symbol: String, timeframe: KXTimeframe, force: Bool = false) {
        guard force || candles.isEmpty else { return }
        self.symbol = symbol
        self.timeframe = timeframe
        self.isShowingPreviewCandles = false
        self.candles = []
        loadingMessage = "正在请求 OKX 真实K线数据..."
    }

    nonisolated private static func persistentMemoryStartDate(for timeframe: KXTimeframe, now: Date = Date()) -> Date? {
        KLOKXTimeframePolicyCatalog.persistentMemoryStartDate(for: timeframe, now: now)
    }

    public func loadLatestCandlesFromDatabaseOrOKX(symbol: String, timeframe: KXTimeframe, triggerSyncIfMissing: Bool = true) {
        // UI 不再自己决定 REST/DB 规则;只读"打开软件/币对同步管道"按统一策略放进内存的结果。
        self.symbol = symbol
        self.timeframe = timeframe

        let cached = KLLowTimeframeCache.shared.allCandles(exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
        let validCached = cached.filter { $0.symbol == symbol && $0.timeframe == timeframe && $0.source != "preview" }
        let ready = KLLowTimeframeCache.shared.historyReady(exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
        if ready, !validCached.isEmpty {
            // [DIAG] 数据加载命中缓存
            logger.info("[KLine][DIAG] load from cache symbol=\(symbol) tf=\(timeframe.rawValue) count=\(validCached.count) triggerSync=\(triggerSyncIfMissing)")
            self.loadingMessage = nil
            self.isShowingPreviewCandles = false
            self.candles = validCached
            applyLatestRealtimeCandleFromCacheIfAvailable(symbol: symbol, timeframe: timeframe)
        } else {
            // [DIAG] 数据加载未命中缓存，将异步 hydrate
            logger.info("[KLine][DIAG] load miss cache symbol=\(symbol) tf=\(timeframe.rawValue) ready=\(ready) cache=\(cached.count) valid=\(validCached.count) triggerSync=\(triggerSyncIfMissing)")
            self.loadingMessage = "正在按策略加载 \(symbol) \(timeframe.rawValue) 真实K线..."
            self.isShowingPreviewCandles = false
            self.candles = []
            // 正确性优先:UI 始终先 hydrate 查库直接出图(兑底),不依赖 sync 通知。
            // (曾试过去重:delegate to sync 跳过 hydrate 靠通知 → 当 syncTimeframe 遭遇 skip duplicate 或预建队列被快速切换的 generation 取消时,通知收不到 → 部分周期不显示K线。故恢复 hydrate 兑底。)
            hydrateCandlesFromDatabaseIfAvailable(symbol: symbol, timeframe: timeframe)
            if triggerSyncIfMissing {
                KLDefaultStartupPipeline.shared.syncTimeframe(symbol: symbol, timeframe: timeframe)
            }
        }
    }

    private func hydrateCandlesFromDatabaseIfAvailable(symbol: String, timeframe: KXTimeframe) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let memoryStart = KLOKXTimeframePolicyCatalog.persistentMemoryStartDate(for: timeframe)
            var validCandles: [KLCandlePoint] = []

            if !KLOKXTimeframePolicyCatalog.isMemoryOnly(timeframe) {
                // 查库封顶行数:图表初始显示+滑动不需要上万根;4h/6h 等"全量"周期若 limit:0 会拉出 1.8w/1.2w 行全 parse,是启动 CPU 爆炸主因。
                // 统一取最新 displayCap 根(latest=true);更早历史由滑动懒加载回补。
                let displayCap = KLOKXTimeframePolicyCatalog.chartLoadCandleCount(for: timeframe)
                let dbCandles = (try? KLDefaultDatabaseExecutor.shared.queryLatestCandles(
                    exchange: "OKX",
                    instrumentID: symbol,
                    timeframe: timeframe,
                    startTime: memoryStart,
                    limit: displayCap
                )) ?? []
                validCandles = dbCandles.filter { $0.symbol == symbol && $0.timeframe == timeframe && $0.source != "preview" }
                logger.info("[KLine][UI] db hydrate checked instID=\(symbol) timeframe=\(timeframe.rawValue) cap=\(displayCap) raw=\(dbCandles.count) valid=\(validCandles.count)")
            }

            if validCandles.isEmpty {
                do {
                    let rest = KLOKXDefaultRESTExecutor(config: KLOKXRESTConfig.development)
                    let bar = KLOKXTimeframePolicyCatalog.policy(for: timeframe)?.okxBar ?? KLOKXTimeframePolicyCatalog.okxBar(for: timeframe) ?? timeframe.rawValue
                    let raw = try await rest.fetchRecentCandles(instID: symbol, bar: bar, limit: 300)
                    validCandles = KLOKXDefaultRESTExecutor.parseCandles(raw, symbol: symbol, timeframe: timeframe, source: "ui_direct_okx")
                        .filter { $0.symbol == symbol && $0.timeframe == timeframe && $0.source != "preview" }
                    logger.info("[KLine][UI] direct OKX apply-ready instID=\(symbol) timeframe=\(timeframe.rawValue) bar=\(bar) count=\(validCandles.count)")
                } catch {
                    logger.info("[KLine][UI] direct OKX failed instID=\(symbol) timeframe=\(timeframe.rawValue) error=\(error.localizedDescription)")
                }
            }

            guard !validCandles.isEmpty else { return }
            let finalCandles = validCandles
            let retention = KLOKXTimeframePolicyCatalog.memoryRetentionLimit(for: timeframe)
            KLLowTimeframeCache.shared.replace(candles: finalCandles, exchange: "OKX", instrumentID: symbol, timeframe: timeframe, maxCount: retention)
            await MainActor.run { [weak self, candles = finalCandles] in
                guard let self, self.symbol == symbol, self.timeframe == timeframe else { 
                    logger.info("[KLine][DIAG] hydrate abandoned symbol=\(symbol) tf=\(timeframe.rawValue) self mismatch")
                    return 
                }
                self.loadingMessage = nil
                self.isShowingPreviewCandles = false
                self.candles = candles
                self.applyLatestRealtimeCandleFromCacheIfAvailable(symbol: symbol, timeframe: timeframe)
                logger.info("[KLine][DIAG] hydrate applied symbol=\(symbol) tf=\(timeframe.rawValue) count=\(candles.count)")
            }
        }
    }

    private func applyLatestRealtimeCandleFromCacheIfAvailable(symbol: String, timeframe: KXTimeframe) {
        let realtimeCached = KLLowTimeframeCache.shared.allCandles(exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
        guard let latest = realtimeCached.last, latest.isClosed == false else { return }
        applyRealtimeCandle(latest)
    }

    public func applyRealtimeCandle(_ candle: KLCandlePoint) {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][KX-UI-12] applyRealtimeCandle ms=\(dt) symbol=\(candle.symbol)") }
        }
        let ready = KLLowTimeframeCache.shared.historyReady(exchange: "OKX", instrumentID: candle.symbol, timeframe: candle.timeframe)
        guard candle.symbol == symbol, candle.timeframe == timeframe, candle.source != "preview" else { return }
        // 多画布性能:隐藏画布不逐 tick 维护自己的整个数组(拷贝/merge/sort 是 O(N) 成本×几十张画布)。
        // 聚合器 KX-SY-08 会把每根 K线 upsert 进 KLLowTimeframeCache(与画布无关),缓存始终新鲜;
        // 所以隐藏画布只标脏,显示时从缓存一次性补齐即可。
        if isHidden {
            needsRealtimeResyncOnShow = true
            return
        }
        if (candles.isEmpty || isShowingPreviewCandles), !ready {
            // 历史窗口未 ready 时,聚合器推来的实时 1 根不能冒充完整历史K线图。
            loadingMessage = loadingMessage ?? "正在按策略加载 \(candle.symbol) \(candle.timeframe.rawValue) 真实K线..."
            logger.info("[KLine][UI] hold realtime until history ready timeframe=\(candle.timeframe.rawValue) close=\(candle.close) preview=\(self.isShowingPreviewCandles)")
            needsDisplay = true
            return
        }
        isShowingPreviewCandles = false
        var next = candles
        var isNewBucket = false
        if let idx = next.lastIndex(where: { $0.openTime == candle.openTime && $0.timeframe == candle.timeframe && $0.symbol == candle.symbol }) {
            next[idx] = mergeRealtime(base: next[idx], incoming: candle)
        } else {
            isNewBucket = true
            next.append(candle)
            next.sort { $0.openTime < $1.openTime }
            // 只裁剪 memoryOnly 低周期;15m+ 持久化周期的图表内存窗口由策略/数据库同步决定,
            // 实时最后一根不能把 4h/1d 等完整历史窗口硬裁成默认 1000 根。
            if KLOKXTimeframePolicyCatalog.isMemoryOnly(candle.timeframe) {
                let realtimeCap = max(600, KLLowTimeframeCache.recommendedRetentionLimit(for: candle.timeframe))
                if next.count > realtimeCap { next = Array(next.suffix(realtimeCap)) }
            }
        }
        // 如果同一根K线且close未变化,跳过完整刷新链,避免高频tick无效重绘
        if !isNewBucket, let last = candles.last, last.close == candle.close, last.high == candle.high, last.low == candle.low {
            logger.info("[PERF][KX-UI-12] applyRealtimeCandle SKIPPED same candle close=\(candle.close)")
            return
        }
        loadingMessage = nil
        let before = candles.count
        // 同一根更新(非新桶)走轻量刷新:只刷绘图层,不全量重算指标。
        // 新桶(闭合上一根+开新一根,每周期才一次)走全量 refreshData,让指标在闭合时重算。
        pendingRealtimeRefreshMode = isNewBucket ? nil : .lightweight
        candles = next
        pendingRealtimeRefreshMode = nil
        let now = Date().timeIntervalSince1970
        if now - lastRealtimeLogAt >= 5 {
            lastRealtimeLogAt = now
            logger.info("[KLine][UI] applied realtime timeframe=\(timeframe.rawValue) before=\(before) after=\(candles.count) lastTime=\(candles.last?.openTime.description ?? "nil") lastClose=\(candles.last?.close.description ?? "nil")")
        }
    }


    private func mergeRealtime(base: KLCandlePoint, incoming: KLCandlePoint) -> KLCandlePoint {
        KLCandlePoint(
            id: base.id,
            symbol: base.symbol,
            timeframe: base.timeframe,
            openTime: base.openTime,
            closeTime: incoming.closeTime ?? base.closeTime,
            open: base.open,
            high: max(base.high, incoming.high),
            low: min(base.low, incoming.low),
            close: incoming.close,
            volume: max(base.volume, incoming.volume),
            quoteVolume: [base.quoteVolume, incoming.quoteVolume].compactMap { $0 }.max(),
            tradeCount: max(base.tradeCount ?? 0, incoming.tradeCount ?? 0),
            isClosed: base.isClosed || incoming.isClosed,
            source: incoming.source ?? base.source
        )
    }

    /// 轻量实时刷新:只更新绘图层(蜡烛/成交量/价格轴/时间轴)+ 实时价格线。
    /// 【不】重算指标、【不】重建chip header、【不】reloadExternalOverlays。
    /// 用于实时 tick 只动最后一根未闭合 K线的场景(CPU 关键)。
    /// 图层 draw 内部本就只遍历可见区(startIdx..endIdx 约一两百根),所以刷可见区开销极小。
    private func lightweightRealtimeRefresh() {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][KX-UI-12] lightweightRealtimeRefresh ms=\(dt)") }
        }
        let now = Date().timeIntervalSince1970
        if now - lastLightweightRefreshAt < 0.03 { return }
        lastLightweightRefreshAt = now
        candleLayer.candles = candles; candleLayer.viewport = viewport
        volumeLayer.candles = candles; volumeLayer.viewport = viewport
        priceAxisLayer.candles = candles; priceAxisLayer.viewport = viewport; priceAxisLayer.timeframe = timeframe; priceAxisLayer.pricePrecision = pricePrecisionForSymbol()
        timeAxisLayer.candles = candles; timeAxisLayer.viewport = viewport; timeAxisLayer.timeframe = timeframe
        newOverlayRenderer.candles = candles; newOverlayRenderer.viewport = viewport
        // 诊断日志:检查 prepareForDrawing 是否被调用
        (candleLayer as? CandlePlotLayer)?.prepareForDrawing()
        (volumeLayer as? VolumePlotLayer)?.prepareForDrawing()
        logger.info("[DIAG][KX-UI-12] lightweightRealtimeRefresh prepareForDrawing called candles=\(candles.count)")
        // 副图渲染器轻量刷新
        for (index, slot) in subpaneSlots.enumerated() {
            guard index < subpaneOverlayRenderers.count, slot.instanceID != nil else { continue }
            let renderer = subpaneOverlayRenderers[index]
            renderer.candles = candles
            renderer.viewport = viewport
        }
        candleLayer.setNeedsDisplay()
        volumeLayer.setNeedsDisplay()
        priceAxisLayer.setNeedsDisplay()
        timeAxisLayer.setNeedsDisplay()
        newOverlayRenderer.setNeedsDisplay()
        for (index, slot) in subpaneSlots.enumerated() {
            guard index < subpaneOverlayRenderers.count, slot.instanceID != nil else { continue }
            subpaneOverlayRenderers[index].setNeedsDisplay()
        }
        updateRealtimeLine()
    }

    /// 多画布:画布从隐藏转为显示时调用。
    /// 隐藏期间不处理实时 tick(观察者最前面已 isHidden 返回),所以显示时从缓存一次性补齐最新数据(含隐藏期间新增闭合K线+未闭合最后一根)。
    /// 缓存是内存数组,读取极快;每次切换只走一次,不是每 tick。
    public func refreshIfNeededOnShow() {
        needsRealtimeResyncOnShow = false
        needsRefreshOnShow = false
        resyncFromCacheOnShow()
        // 修复:持久周期(1h/4h/1d等)从隐藏转显示时,resync 不触发 didSet,
        // viewport 可能停在历史位置 → 显示旧K线。显示时兜底确保最新K线在视野中。
        let vw = chartPlotWidth
        if vw > 1, !candles.isEmpty, !viewportCalculator.isNearRightEdge {
            applyViewport(viewportCalculator.centerOnLatest(viewWidth: vw))
        }
    }

    /// 从 KLLowTimeframeCache 一次性读取本(symbol,timeframe)最新数据(含隐藏期间形成的新K线+未闭合最后一根),刷新一次。
    private func resyncFromCacheOnShow() {
        let cached = KLLowTimeframeCache.shared.allCandles(exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
        let valid = cached.filter { $0.symbol == symbol && $0.timeframe == timeframe && $0.source != "preview" }
        // 关键修复:持久周期(15m+)的完整历史在画布自己的 candles 里,KLLowTimeframeCache 往往只有
        // 实时聚合的稀疏几根。若无脑 candles = valid,会用稀疏 cache 覆盖画布已加载的完整数据
        // → 切回该周期时画面几乎空白(实测:ETH 1h 有 1000 根但 cache 只 1 根,覆盖后不显示)。
        if candles.isEmpty {
            // 画布还没数据:用 cache;cache 也空则退回普通刷新。
            logger.info("[KLine][DIAG] resync \(symbol)/\(timeframe.rawValue) branch=emptyCanvas validCache=\(valid.count)")
            if valid.isEmpty { refreshData(); needsDisplay = true } else { candles = valid }
            return
        }
        if valid.count >= candles.count {
            // cache 不少于画布(低周期 memoryOnly:cache 是权威)→ 整体替换,把隐藏期间的新根画好。
            logger.info("[KLine][DIAG] resync \(symbol)/\(timeframe.rawValue) branch=replace validCache=\(valid.count) oldCanvas=\(candles.count)")
            candles = valid
        } else {
            // cache 比画布少(持久周期:完整历史在画布手里)→ 保留画布完整历史,只重画+补最后实时一根。
            logger.info("[KLine][DIAG] resync \(symbol)/\(timeframe.rawValue) branch=keepCanvas validCache=\(valid.count) keepCanvas=\(candles.count)")
            refreshData()
            applyLatestRealtimeCandleFromCacheIfAvailable(symbol: symbol, timeframe: timeframe)
            needsDisplay = true
        }
    }

    private var lastRefreshDataAt: TimeInterval = 0

    public func refreshData() {
        let now = Date().timeIntervalSince1970
        // throttle:200ms 内只执行一次,避免频繁调用导致 CPU 飙升
        if now - lastRefreshDataAt < 0.2 { return }
        lastRefreshDataAt = now
        let layersData: [(CALayer, (CALayer) -> Void)] = [
            (candleLayer, { [weak self] l in guard let self, let layer = l as? CandlePlotLayer else { return }; layer.candles = self.candles; layer.viewport = self.viewport }),
            (volumeLayer, { [weak self] l in guard let self, let layer = l as? VolumePlotLayer else { return }; layer.candles = self.candles; layer.viewport = self.viewport }),
            (priceAxisLayer, { [weak self] l in guard let self, let layer = l as? AxisLayer else { return }; layer.candles = self.candles; layer.viewport = self.viewport; layer.timeframe = self.timeframe; layer.pricePrecision = self.pricePrecisionForSymbol() }),
            (timeAxisLayer, { [weak self] l in guard let self, let layer = l as? AxisLayer else { return }; layer.candles = self.candles; layer.viewport = self.viewport; layer.timeframe = self.timeframe }),
        ]
        // 专业指标实例:用当前 candles 重新计算并提交 overlays,确保数据变化后overlay最新
        let context = makeCurrentIndicatorCalculationContext()
        // 计算期间屏蔽通知,避免 recalculateAndSubmit -> post -> reloadExternalOverlays 在同一帧内自我递归。
        isRecalculatingIndicators = true
        defer { isRecalculatingIndicators = false }
        for instanceID in professionalIndicatorInstanceIDs {
            try? KXProfessionalIndicatorInstanceManager.shared.recalculateAndSubmit(instanceID: instanceID, context: context)
        }
        volumeLayer.isHidden = false
        (candleLayer as? CandlePlotLayer)?.prepareForDrawing()
        (volumeLayer as? VolumePlotLayer)?.prepareForDrawing()
        layersData.forEach { layer, update in update(layer); layer.setNeedsDisplay() }
        rebuildIndicatorHeader()
        updateRealtimeLine()
        // 强制刷新 overlay,不受 reloadExternalOverlays 限流影响(避免数据加载后 overlay 不显示)
        reloadExternalOverlaysForce()
        updateVolumeMaxLabel()
        if candles.count <= 5 || candles.count % 50 == 0 {
            logger.info("[KLine][DRAW] refresh symbol=\(symbol) timeframe=\(timeframe.rawValue) candles=\(candles.count) source=\(candles.last?.source ?? "nil") viewport=\(viewport.startIndex)..\(viewport.endIndex) lastClose=\(candles.last?.close.description ?? "nil")")
        }
    }

    /// 更新右侧量柱区域最大成交量标签,基于当前 viewport 可见K线动态计算
    private func updateVolumeMaxLabel() {
        guard !candles.isEmpty else { volumeMaxLabel.stringValue = ""; return }
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(max(priceAxisLayer.bounds.width, 280) / max(CGFloat(viewport.candleWidth), 1.5)) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else { volumeMaxLabel.stringValue = ""; return }
        let visible = Array(candles[startIdx..<endIdx])
        let maxVol = visible.map { $0.volume.dbl }.max() ?? 0
        volumeMaxLabel.stringValue = String(format: "%.0f", maxVol)
    }

    public func addTechnicalIndicator(_ indicator: KXTechnicalIndicator) {
        // 所有指标统一交给专业指标实例管理器;老链路已废弃。
        let manager = KXProfessionalIndicatorInstanceManager.shared
        let indicatorID = professionalIndicatorID(for: indicator)
        guard manager.template(for: indicatorID) != nil else {
            logger.warning("[KLine][Indicator] no template for \(indicator.name) id=\(indicatorID)")
            return
        }

        // 主图单线指标:MA、EMA 等,允许多实例(不同周期)。
        if indicatorID == "ma" {
            addMAProfessionalIndicator(indicator)
            return
        }

        guard let instance = manager.createInstance(indicatorID: indicatorID, zIndex: 40 + professionalIndicatorInstanceIDs.count) else {
            logger.error("[KLine][Indicator] createInstance failed for \(indicatorID)")
            return
        }
        professionalIndicatorInstanceIDs.insert(instance.id)

        // 副图指标:创建独立 subpane slot
        if instance.pane == .sub {
            syncProfessionalSubpaneSlot(for: instance)
        }

        let context = makeCurrentIndicatorCalculationContext()
        recalculateAndSubmitProfessional(instanceID: instance.id, context: context)
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsLayout = true
        logger.info("[KLine][Indicator] added \(indicatorID) instance=\(instance.id) pane=\(instance.pane)")
    }

    /// 将 KXTechnicalIndicator 映射到专业指标系统的 indicatorID。
    private func professionalIndicatorID(for indicator: KXTechnicalIndicator) -> String {
        switch indicator.id.lowercased() {
        case "kx-in-01-ma", "ma": return "ma"
        case "kx-in-02-ema", "ema": return "ema"
        case "kx-in-02-macd", "macd": return "macd"
        case "kx-in-03-kdj", "kdj": return "kdj"
        case "kx-in-01-rsi", "rsi": return "rsi"
        case "kx-in-01-布林带", "boll": return "boll"
        default:
            // 尝试直接用指标名小写匹配模板
            return indicator.name.lowercased()
        }
    }

    // MARK: - 专业指标子系统

    private func addMAProfessionalIndicator(_ indicator: KXTechnicalIndicator) {
        let context = makeCurrentIndicatorCalculationContext()
        let manager = KXProfessionalIndicatorInstanceManager.shared
        let allMAInstances = manager.allInstances().filter { $0.indicatorID == "ma" }
        guard allMAInstances.count < 5 else {
            logger.info("[KLine][Indicator] MA limit reached (max 5), not adding new MA")
            return
        }
        guard var instance = manager.createInstance(indicatorID: "ma", zIndex: 40 + allMAInstances.count) else { return }
        professionalIndicatorInstanceIDs.insert(instance.id)
        let usedPeriods = Set(allMAInstances.compactMap { $0.params["period"]?.intValue })
        let periodSequence = [20, 5, 10, 60, 120, 200]
        let nextPeriod = periodSequence.first { !usedPeriods.contains($0) } ?? 20
        instance.params["period"] = .int(nextPeriod)
        instance.styles["color"] = .colorHex(defaultColorHex(index: usedPeriods.count))
        manager.updateParams(instanceID: instance.id, params: instance.params)
        manager.updateStyle(instanceID: instance.id, styles: instance.styles)
        recalculateAndSubmitProfessional(instanceID: instance.id, context: context)
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        logger.info("[KLine][Indicator] MA added via new path instance=\(instance.id) period=\(nextPeriod)")
    }

    private func syncProfessionalSubpaneSlot(for instance: KXProfessionalIndicatorInstance) {
        let baseH = max(56, (bounds.height - 26) * volumeRatio)
        let defaultHeight = baseH * subpaneExpandedRatio
        let slot = SubpaneSlot(
            id: UUID().uuidString,
            isExpanded: true,
            height: defaultHeight,
            indicators: [],
            instanceID: instance.id
        )
        subpaneSlots.insert(slot, at: 0)

        // 专业指标用新 overlay renderer 渲染到副图
        let renderer = KXUI19ChartOverlayRendererLayer()
        renderer.pane = .sub
        renderer.theme = theme
        renderer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        renderer.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull(), "backgroundColor": NSNull()]
        self.layer?.addSublayer(renderer)
        subpaneOverlayRenderers.insert(renderer, at: 0)

        let collapseButton = KXUIGlassIconButton(icon: .chevronDown, size: 18)
        collapseButton.onTap = { [weak self] in self?.toggleSubpaneCollapse(at: 0) }
        addSubview(collapseButton)
        subpaneCollapseButtons.insert(collapseButton, at: 0)

        let closeButton = KXUIGlassIconButton(icon: .xmark, size: 18)
        closeButton.onTap = { [weak self] in self?.removeSubpaneSlot(at: 0) }
        addSubview(closeButton)
        subpaneCloseButtons.insert(closeButton, at: 0)

        // 附图标题栏(指标名字)
        let titleLabel = NSTextField(labelWithString: instance.indicatorName)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = KLUITheme.axisText
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        addSubview(titleLabel)
        subpaneTitleLabels.insert(titleLabel, at: 0)

        // 设置按钮(标题栏右侧)
        let settingsButton = KXUIGlassIconButton(icon: .line3Horizontal, size: 18)
        settingsButton.onTap = { [weak self] in
            guard let self = self else { return }
            self.showNewIndicatorSettings(instanceID: instance.id)
        }
        addSubview(settingsButton)
        subpaneSettingsButtons.insert(settingsButton, at: 0)

        let divider = KXUIThemedDividerLayer()
        divider.theme = theme
        divider.backgroundColor = theme.splitter
        divider.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull(), "backgroundColor": NSNull()]
        self.layer?.addSublayer(divider)
        subpaneDividerLayers.insert(divider, at: 0)

        isVolumeCollapsed = true
        needsLayout = true
    }

    // MARK: - 副图系统

    // 副图 plot layer 占位
    private class SubpanePlotLayer: CALayer {
        var theme: KLChartThemeBundle? = nil
    }

    private func addSubpaneIndicator(_ indicator: KXTechnicalIndicator) {
        let baseH = max(56, (bounds.height - 26) * volumeRatio)
        let defaultHeight = baseH * subpaneExpandedRatio

        if let index = subpaneSlots.firstIndex(where: { $0.indicators.contains { $0.id == indicator.id } }) {
            subpaneSlots[index].indicators.append(indicator)
        } else if subpaneSlots.count < 2 {
            let slot = SubpaneSlot(id: UUID().uuidString, isExpanded: true, height: defaultHeight, indicators: [indicator])
            subpaneSlots.append(slot)
            let layer = SubpanePlotLayer()
            layer.theme = theme
            layer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            layer.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull(), "backgroundColor": NSNull()]
            self.layer?.addSublayer(layer)
            subpaneLayers.append(layer)
            isVolumeCollapsed = true
            // 创建按钮
            let collapseBtn = createCollapseButton()
            collapseBtn.target = self
            collapseBtn.action = #selector(toggleSubpaneCollapse(_:))
            addSubview(collapseBtn)
            subpaneCollapseButtons.append(collapseBtn)
            let closeBtn = createCloseButton()
            closeBtn.target = self
            closeBtn.action = #selector(closeSubpane(_:))
            addSubview(closeBtn)
            subpaneCloseButtons.append(closeBtn)
        } else {
            let removed = subpaneSlots.removeFirst()
            let removedLayer = subpaneLayers.removeFirst()
            removedLayer.removeFromSuperlayer()
            // 移除旧按钮
            if !subpaneCollapseButtons.isEmpty {
                subpaneCollapseButtons[0].removeFromSuperview()
                subpaneCollapseButtons.removeFirst()
            }
            if !subpaneCloseButtons.isEmpty {
                subpaneCloseButtons[0].removeFromSuperview()
                subpaneCloseButtons.removeFirst()
            }
            logger.info("[KLine][Subpane] removed oldest slot=\(removed.id) to make room for \(indicator.name)")

            let slot = SubpaneSlot(id: UUID().uuidString, isExpanded: true, height: defaultHeight, indicators: [indicator])
            subpaneSlots.append(slot)
            let layer = SubpanePlotLayer()
            layer.theme = theme
            layer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            layer.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull(), "backgroundColor": NSNull()]
            self.layer?.addSublayer(layer)
            subpaneLayers.append(layer)
            // 创建新按钮
            let collapseBtn = createCollapseButton()
            collapseBtn.target = self
            collapseBtn.action = #selector(toggleSubpaneCollapse(_:))
            addSubview(collapseBtn)
            subpaneCollapseButtons.append(collapseBtn)
            let closeBtn = createCloseButton()
            closeBtn.target = self
            closeBtn.action = #selector(closeSubpane(_:))
            addSubview(closeBtn)
            subpaneCloseButtons.append(closeBtn)
        }

        recalculateSubpaneData()
        needsLayout = true
        logger.info("[KLine][Subpane] added \(indicator.name) to slot, total slots=\(subpaneSlots.count)")
    }

    private func removeSubpaneSlot(at index: Int) {
        guard index < subpaneSlots.count else { return }
        let instanceID = subpaneSlots[index].instanceID
        subpaneSlots.remove(at: index)
        // 统一走专业指标清理逻辑,确保 manager 与 overlay 同步移除。
        if let instanceID {
            removeProfessionalIndicatorInstanceAndOverlay(instanceID: instanceID)
        }
        if index < subpaneOverlayRenderers.count {
            subpaneOverlayRenderers[index].removeFromSuperlayer()
            subpaneOverlayRenderers.remove(at: index)
        }
        if index < subpaneCollapseButtons.count {
            subpaneCollapseButtons[index].removeFromSuperview()
            subpaneCollapseButtons.remove(at: index)
        }
        if index < subpaneCloseButtons.count {
            subpaneCloseButtons[index].removeFromSuperview()
            subpaneCloseButtons.remove(at: index)
        }
        if index < subpaneTitleLabels.count {
            subpaneTitleLabels[index].removeFromSuperview()
            subpaneTitleLabels.remove(at: index)
        }
        if index < subpaneSettingsButtons.count {
            subpaneSettingsButtons[index].removeFromSuperview()
            subpaneSettingsButtons.remove(at: index)
        }
        if index < subpaneDividerLayers.count {
            subpaneDividerLayers[index].removeFromSuperlayer()
            subpaneDividerLayers.remove(at: index)
        }
        // 移除按钮
        if index < subpaneCollapseButtons.count {
            subpaneCollapseButtons[index].removeFromSuperview()
            subpaneCollapseButtons.remove(at: index)
        }
        if index < subpaneCloseButtons.count {
            subpaneCloseButtons[index].removeFromSuperview()
            subpaneCloseButtons.remove(at: index)
        }
        if subpaneSlots.isEmpty {
            isVolumeCollapsed = false
            volumeCollapseButton.isHidden = true
        }
        needsLayout = true
    }

    private func toggleSubpaneCollapse(at index: Int) {
        guard index < subpaneSlots.count else { return }
        subpaneSlots[index].isExpanded.toggle()
        needsLayout = true
    }

    private func recalculateSubpaneData() {
        // 专业副图指标由 overlay renderer 渲染,这里只同步数据/视口
        for renderer in subpaneOverlayRenderers {
            renderer.candles = candles
            renderer.viewport = viewport
            renderer.setNeedsDisplay()
        }
    }

    private func removeProfessionalIndicatorInstanceAndOverlay(instanceID: String) {
        professionalIndicatorInstanceIDs.remove(instanceID)

        // 删除该实例对应的所有 overlay:先根据模板 figureSchema 精确清理,
        // 若模板或实例已不存在则回退到常见 key 兜底,避免老 overlay 残留。
        let manager = KXProfessionalIndicatorInstanceManager.shared
        if let instance = manager.instance(id: instanceID),
           let template = manager.template(for: instance.indicatorID) {
            for figure in template.figureSchema {
                try? KLDefaultOverlayManager.shared.removeOverlay(moduleID: "indicator", overlayID: "overlay.indicator.\(instanceID).\(figure.key)")
            }
        } else {
            let fallbackKeys = ["ma", "rsi", "ema", "dif", "dea", "hist", "K", "D", "J", "mid", "upper", "lower"]
            for key in fallbackKeys {
                try? KLDefaultOverlayManager.shared.removeOverlay(moduleID: "indicator", overlayID: "overlay.indicator.\(instanceID).\(key)")
            }
        }
        for signalType in ["buy", "sell", "strongBuy", "strongSell", "none"] {
            try? KLDefaultOverlayManager.shared.removeOverlay(moduleID: "indicator", overlayID: "overlay.indicator.\(instanceID).signals.\(signalType)")
        }

        manager.removeInstance(instanceID: instanceID)
        NotificationCenter.default.post(name: .KXIndicatorOverlayDidChange, object: instanceID)
    }

    private func removeAllProfessionalIndicators(indicatorID: String) {
        let instances = professionalIndicatorInstanceIDs
            .compactMap { KXProfessionalIndicatorInstanceManager.shared.instance(id: $0) }
            .filter { $0.indicatorID == indicatorID }
        for instance in instances {
            removeProfessionalIndicatorInstanceAndOverlay(instanceID: instance.id)
        }
    }

    public func updateTechnicalIndicatorInstance(id: UUID, params: [String: Double]? = nil, styles: [String: KXIndicatorParameterValue]? = nil) {
        let instanceID = id.uuidString
        guard KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID) != nil else { return }
        if let params {
            KXProfessionalIndicatorInstanceManager.shared.updateParams(instanceID: instanceID, params: params.mapValues { .double($0) })
        }
        if let styles {
            KXProfessionalIndicatorInstanceManager.shared.updateStyle(instanceID: instanceID, styles: styles)
        }
        recalculateAndSubmitProfessional(instanceID: instanceID, context: makeCurrentIndicatorCalculationContext())
        reloadExternalOverlays()
        rebuildIndicatorHeader()
    }

    public func removeTechnicalIndicatorInstance(id: UUID) {
        removeProfessionalIndicatorInstanceAndOverlay(instanceID: id.uuidString)
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsLayout = true
    }

    public func removeTechnicalIndicator(id: String) {
        removeAllProfessionalIndicators(indicatorID: id.lowercased())
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsLayout = true
    }

    public func clearTechnicalIndicators() {
        let ids = professionalIndicatorInstanceIDs
        for id in ids {
            removeProfessionalIndicatorInstanceAndOverlay(instanceID: id)
        }
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsLayout = true
    }

    private func defaultColorHex(index: Int) -> String {
        let colors: [NSColor] = [.systemYellow, .systemCyan, .systemPurple, .systemOrange, .systemPink, .systemGreen]
        return colors[index % colors.count].kxRGBAHex
    }

    private func updateRealtimeLine() {
        guard let last = candles.last else { realtimeLineLayer.label = ""; realtimeLineLayer.setNeedsDisplay(); return }
        let visible = visibleCandles()
        let minP = visible.map(\.low).min() ?? last.low
        let maxP = visible.map(\.high).max() ?? last.high
        let range = max(maxP.dbl - minP.dbl, 0.00000001)
        let y = candleLayer.frame.minY + candleLayer.bounds.height * CGFloat((last.close.dbl - minP.dbl) / range)
        realtimeLineLayer.y = max(0, min(y - realtimeLineLayer.frame.minY, realtimeLineLayer.bounds.height))
        realtimeLineLayer.direction = last.close >= last.open ? .up : .down
        realtimeLineLayer.label = String(format: "%.*f", pricePrecisionForSymbol(), last.close.dbl)
        realtimeLineLayer.setNeedsDisplay()
    }

    private func visibleCandles() -> [KLCandlePoint] {
        guard !candles.isEmpty else { return [] }
        let start = max(0, min(viewport.startIndex, candles.count - 1))
        let count = max(1, Int(candleLayer.bounds.width / max(CGFloat(viewport.candleWidth), 1.5)) + 2)
        let end = min(candles.count, start + count)
        return Array(candles[start..<end])
    }

    // ⚠️ 2026-06-23:normalizeViewport 已删除,视口定位/约束统一由 UI-GL-71 计算器负责。
    private var oldValueSafeCandlesCount: Int { candles.count }

    private func colorHexFromValue(_ value: KXIndicatorParameterValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .colorHex(let hex): return hex
        case .string(let str): return str
        default: return nil
        }
    }

    private var lastIndicatorHeaderRebuildAt: TimeInterval = 0

    func rebuildIndicatorHeader() {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 1 { logger.info("[PERF][KX-UI-12] rebuildIndicatorHeader ms=\(dt)") }
        }
        let manager = KXProfessionalIndicatorInstanceManager.shared
        let visibleInstances = professionalIndicatorInstanceIDs
            .compactMap { manager.instance(id: $0) }
            .filter { $0.visible && $0.pane == .main }
            .sorted { $0.updatedAt < $1.updatedAt }
        let context = makeCurrentIndicatorCalculationContext()
        let chips = visibleInstances.map { instance -> KXIndicatorChipSnapshot in
            let text = manager.tooltipText(instanceID: instance.id, context: context) ?? instance.indicatorName
            return KXIndicatorChipSnapshot(
                instanceID: instance.id,
                outputKey: nil,
                pane: .main,
                text: text,
                colorHex: colorHexFromValue(instance.styles["color"]),
                visible: true
            )
        }
        let signature = chips.map { "\($0.instanceID):\($0.text)" }.joined(separator: "|")
        if signature == lastIndicatorHeaderSignature { return }
        lastIndicatorHeaderSignature = signature
        // 确保 indicatorChipOverlay 有正确的 frame,即使 layout() 还未被调用
        if indicatorChipOverlay.frame.width <= 0 {
            indicatorChipOverlay.frame = CGRect(
                x: candleLayer.frame.minX + 6,
                y: candleLayer.frame.maxY - 24,
                width: max(400, candleLayer.frame.width - 12),
                height: 20
            )
        }
        indicatorChipOverlay.isHidden = chips.isEmpty
        var x: CGFloat = 0
        let maxWidth = max(400, indicatorChipOverlay.bounds.width)
        var usedIDs = Set<String>()
        for chip in chips.prefix(8) {
            let button: NSButton
            if let existing = indicatorChipButtons[chip.instanceID] {
                button = existing
                button.title = "  \(chip.text)  "
                button.contentTintColor = NSColor(kxHex: chip.colorHex ?? "#FFD60AFF") ?? .systemYellow
                button.identifier = NSUserInterfaceItemIdentifier(chip.instanceID)
            } else {
                button = makeIndicatorChip(for: chip)
                indicatorChipButtons[chip.instanceID] = button
                indicatorChipOverlay.addSubview(button)
            }
            usedIDs.insert(chip.instanceID)
            let size = button.fittingSize
            let width = min(max(size.width, 68), 170)
            if x + width > maxWidth { break }
            button.frame = CGRect(x: x, y: 0, width: width, height: 20)
            x += width + 5
        }
        for (id, button) in indicatorChipButtons where !usedIDs.contains(id) {
            button.removeFromSuperview()
        }
        indicatorChipButtons = indicatorChipButtons.filter { usedIDs.contains($0.key) }
        addSubview(indicatorChipOverlay, positioned: .above, relativeTo: nil)
    }

    private func makeIndicatorChip(for chip: KXIndicatorChipSnapshot) -> NSButton {
        let title = "  \(chip.text)  "
        let button = NSButton(title: title, target: self, action: #selector(indicatorChipClicked(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(chip.instanceID)
        button.isBordered = false
        button.bezelStyle = .inline
        button.alignment = .center
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        button.contentTintColor = NSColor(kxHex: chip.colorHex ?? "#FFD60AFF") ?? .systemYellow
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        button.layer?.cornerRadius = 4
        button.setButtonType(.momentaryChange)
        button.toolTip = "点击设置,右键显示/删除"
        // 让文字在按钮内垂直居中
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor(kxHex: chip.colorHex ?? "#FFD60AFF") ?? .systemYellow
            ]
        )
        return button
    }

    @objc private func indicatorChipClicked(_ sender: NSButton) {
        let rawID = sender.identifier?.rawValue ?? "nil"
        logger.info("[KLine][Chip] clicked identifier=\(rawID) professionalIDs=\(professionalIndicatorInstanceIDs)")
        // UUID 字符串大小写可能不一致,用 case-insensitive 比较
        let matchingID = professionalIndicatorInstanceIDs.first { $0.compare(rawID, options: .caseInsensitive) == .orderedSame }
        guard let matchedID = matchingID else {
            logger.info("[KLine][Chip] no instance found for identifier=\(rawID)")
            return
        }
        // toggle: 如果该实例的设置面板已打开,则关闭
        if embeddedSettingsPanel != nil {
            closeEmbeddedSettingsPanel()
            return
        }
        showNewIndicatorSettings(instanceID: matchedID)
    }

    private func showChipContextMenu(for instanceID: String, event: NSEvent) {
        guard let instance = KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID) else { return }
        let menu = NSMenu(title: instance.indicatorName)
        let visible = NSMenuItem(title: instance.visible ? "隐藏" : "显示", action: #selector(toggleIndicatorInstanceMenuItemSelected(_:)), keyEquivalent: "")
        visible.target = self
        visible.representedObject = instanceID
        menu.addItem(visible)
        let delete = NSMenuItem(title: "删除", action: #selector(deleteIndicatorInstanceMenuItemSelected(_:)), keyEquivalent: "")
        delete.target = self
        delete.representedObject = instanceID
        menu.addItem(delete)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func toggleIndicatorInstanceMenuItemSelected(_ sender: NSMenuItem) {
        guard let instanceID = sender.representedObject as? String,
              let instance = KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID) else { return }
        KXProfessionalIndicatorInstanceManager.shared.setVisible(instanceID: instanceID, visible: !instance.visible)
        reloadExternalOverlays()
        rebuildIndicatorHeader()
    }

    public override func rightMouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let chipPoint = indicatorChipOverlay.convert(event.locationInWindow, from: nil)
        if indicatorChipOverlay.bounds.contains(chipPoint) {
            for view in indicatorChipOverlay.subviews where view.frame.contains(chipPoint) {
                guard let button = view as? NSButton,
                      let instanceID = button.identifier?.rawValue else { continue }
                showChipContextMenu(for: instanceID, event: event)
                return
            }
        }
        guard bounds.contains(loc), !professionalIndicatorInstanceIDs.isEmpty else {
            super.rightMouseDown(with: event)
            return
        }
        showIndicatorInstanceMenu(event: event)
    }

    private func showIndicatorInstanceMenu(event: NSEvent) {
        let menu = NSMenu(title: "指标实例")
        let manager = KXProfessionalIndicatorInstanceManager.shared
        let instances = professionalIndicatorInstanceIDs
            .compactMap { manager.instance(id: $0) }
            .sorted { $0.zIndex < $1.zIndex }
        for instance in instances {
            let submenu = NSMenu(title: instance.indicatorName)
            let deleteItem = NSMenuItem(title: "删除 \(instance.indicatorName)", action: #selector(deleteIndicatorInstanceMenuItemSelected(_:)), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.representedObject = instance.id
            submenu.addItem(deleteItem)

            let root = NSMenuItem(title: instance.indicatorName, action: nil, keyEquivalent: "")
            root.submenu = submenu
            menu.addItem(root)
        }
        menu.addItem(NSMenuItem.separator())
        let clear = NSMenuItem(title: "清空全部指标", action: #selector(clearAllIndicatorInstancesMenuItemSelected(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func deleteIndicatorInstanceMenuItemSelected(_ sender: NSMenuItem) {
        guard let instanceID = sender.representedObject as? String else { return }
        removeProfessionalIndicatorInstanceAndOverlay(instanceID: instanceID)
        reloadExternalOverlays()
        rebuildIndicatorHeader()
        needsLayout = true
    }

    @objc private func clearAllIndicatorInstancesMenuItemSelected(_ sender: NSMenuItem) {
        clearTechnicalIndicators()
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        // 点击面板外部关闭设置面板
        if let panel = embeddedSettingsPanel, !panel.frame.contains(loc) {
            closeEmbeddedSettingsPanel()
        }
        // 检查内部分界线(优先于外部分界线)
        if let innerIndex = isNearInnerSplitter(loc) {
            isDraggingInnerSplitter = true
            activeInnerSplitterIndex = innerIndex
            NSCursor.resizeUpDown.set()
            return
        }
        // ⚠️ 2026-06-22:点在分界线上 → 进入拖动模式(压缩/拉伸 K线与量柱高度)。
        if isNearSplitter(loc) {
            isDraggingSplitter = true
            NSCursor.resizeUpDown.set()
            return
        }
        let overlayPoint = CGPoint(x: loc.x - newOverlayRenderer.frame.minX, y: loc.y - newOverlayRenderer.frame.minY)
        if newOverlayRenderer.frame.contains(loc), let patternPayload = newOverlayRenderer.hitTestCandlePattern(at: overlayPoint) {
            KXMK03PatternMarkerDetailPresenter.show(payload: patternPayload, at: loc, in: self)
            return
        }
        if bounds.contains(loc) {
            crosshairActive = true
            lastDragX = loc.x  // 记录拖动起点 X
            updateCrosshair(at: loc)
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if isNearInnerSplitter(loc) != nil || isNearSplitter(loc) {
            NSCursor.resizeUpDown.set()
            return
        } else {
            NSCursor.arrow.set()
        }
        guard crosshairActive else { return }
        updateCrosshair(at: loc)
    }

    public override func mouseExited(with event: NSEvent) { NSCursor.arrow.set(); if crosshairActive { crosshairLayer.isHidden = true; crosshairTimeLabel.isHidden = true; crosshairPriceLabel.isHidden = true } }
    public override func mouseEntered(with event: NSEvent) { if crosshairActive { crosshairLayer.isHidden = false; crosshairLayer.setNeedsDisplay(); crosshairTimeLabel.isHidden = false; crosshairPriceLabel.isHidden = false } }

    // ⚠️ 2026-06-22:拖动K线 → 调用UI模块视口计算器,不自己处理边界。
    public override func mouseDragged(with event: NSEvent) {
        if isDraggingInnerSplitter, let index = activeInnerSplitterIndex {
            let loc = convert(event.locationInWindow, from: nil)
            handleInnerSplitterDrag(index: index, location: loc)
            NSCursor.resizeUpDown.set()
            needsLayout = true
            return
        }
        if isDraggingSplitter {
            let loc = convert(event.locationInWindow, from: nil)
            let bh = bounds.height
            let timeAxisHeight: CGFloat = 26
            let splitterHeight: CGFloat = 1
            let available = bh - timeAxisHeight
            let minVol: CGFloat = 56
            let maxVol = max(minVol, available - 80 - splitterHeight)
            let newVolH = min(maxVol, max(minVol, loc.y - timeAxisHeight))
            volumeRatio = max(0.05, min(0.95, newVolH / max(1, available)))
            NSCursor.resizeUpDown.set()
            needsLayout = true
            return
        }
        // ⚠️ 2026-06-23:业务层提供平移指令,计算由 UI-GL-71 负责;viewWidth 用绘图区宽度。
        // NSEvent.deltaX 在 mouseDragged 恒为0,用 locationInWindow 算真实水平增量。
        let loc = convert(event.locationInWindow, from: nil)
        let prevX = lastDragX ?? loc.x
        let dx = loc.x - prevX
        lastDragX = loc.x
        if dx != 0 {
            _ = viewportCalculator.pan(deltaX: Double(dx), viewWidth: chartPlotWidth)
        }
    }

    public override func mouseUp(with event: NSEvent) {
        lastDragX = nil  // 清拖动起点
        if isDraggingInnerSplitter {
            isDraggingInnerSplitter = false
            activeInnerSplitterIndex = nil
            NSCursor.arrow.set()
            needsLayout = true
            return
        }
        if isDraggingSplitter {
            isDraggingSplitter = false
            NSCursor.arrow.set()
            needsLayout = true  // 拖动结束后走一次完整刷新,让指标/header 跟上。
        }
    }

    /// 判断鼠标是否在内部分界线热区内。返回分界线索引(0=副图1/副图2, ..., 最后一个=副图N/量柱)。
    private func isNearInnerSplitter(_ loc: CGPoint) -> Int? {
        guard !subpaneSlots.isEmpty else { return nil }
        let bh = bounds.height
        let timeAxisHeight: CGFloat = 26
        let splitterHeight: CGFloat = 1
        let headerHeight: CGFloat = 18
        let baseVolumeH = max(56, (bh - timeAxisHeight) * volumeRatio)

        var currentY: CGFloat = timeAxisHeight
        for (index, slot) in subpaneSlots.enumerated() {
            let slotH = slot.isExpanded ? max(headerHeight + 6, slot.height) : max(headerHeight, baseVolumeH * volumeCollapsedRatio)
            let splitterY = currentY + slotH
            if abs(loc.y - splitterY) <= innerSplitterHotZone && loc.x >= 0 && loc.x <= bounds.width {
                return index
            }
            currentY += slotH + splitterHeight
        }
        // 最后一条:量柱/副图 分界线
        let volumeSplitterY = currentY
        if abs(loc.y - volumeSplitterY) <= innerSplitterHotZone && loc.x >= 0 && loc.x <= bounds.width {
            return subpaneSlots.count
        }
        return nil
    }

    /// 处理内部分界线拖动。
    private func handleInnerSplitterDrag(index: Int, location: CGPoint) {
        let bh = bounds.height
        let timeAxisHeight: CGFloat = 26
        let splitterHeight: CGFloat = 1
        let headerHeight: CGFloat = 18
        let baseVolumeH = max(56, (bh - timeAxisHeight) * volumeRatio)
        let minH = max(headerHeight, baseVolumeH * volumeCollapsedRatio)

        // 计算各层当前高度 [slot0, slot1, ..., volume]
        var heights: [CGFloat] = []
        for slot in subpaneSlots {
            heights.append(slot.isExpanded ? max(headerHeight + 6, slot.height) : max(headerHeight, minH))
        }
        heights.append(isVolumeCollapsed ? max(headerHeight, baseVolumeH * volumeCollapsedRatio) : baseVolumeH)

        let upperIdx = index
        let lowerIdx = index + 1
        guard upperIdx < heights.count && lowerIdx < heights.count else { return }

        let locY = location.y - timeAxisHeight
        var accumulated: CGFloat = 0
        for i in 0..<upperIdx {
            accumulated += heights[i] + splitterHeight
        }
        let newUpperH = max(minH, min(locY - accumulated, heights[upperIdx] + heights[lowerIdx] - minH))
        let newLowerH = heights[upperIdx] + heights[lowerIdx] - newUpperH

        heights[upperIdx] = newUpperH
        heights[lowerIdx] = newLowerH

        if upperIdx < subpaneSlots.count {
            subpaneSlots[upperIdx].height = newUpperH
            subpaneSlots[upperIdx].isExpanded = newUpperH > minH + 2
        }

        if lowerIdx < subpaneSlots.count {
            subpaneSlots[lowerIdx].height = newLowerH
            subpaneSlots[lowerIdx].isExpanded = newLowerH > minH + 2
        } else {
            // lower 是量柱
            if newLowerH <= minH + 2 {
                isVolumeCollapsed = true
            } else {
                isVolumeCollapsed = false
            }
        }
    }

    /// 判断鼠标是否在 K线/底部区域分界线热区内。
    private func isNearSplitter(_ loc: CGPoint) -> Bool {
        let bh = bounds.height
        let timeAxisHeight: CGFloat = 26
        let splitterHeight: CGFloat = 1
        let headerHeight: CGFloat = 18
        let baseVolumeH = max(56, (bh - timeAxisHeight) * volumeRatio)
        let volumeH = isVolumeCollapsed ? max(headerHeight, baseVolumeH * volumeCollapsedRatio) : baseVolumeH

        var subpanesTotalH: CGFloat = 0
        for slot in subpaneSlots {
            let h = slot.isExpanded ? max(headerHeight + 6, slot.height) : max(headerHeight, baseVolumeH * volumeCollapsedRatio)
            subpanesTotalH += h
        }
        let innerSplittersH = CGFloat(max(0, subpaneSlots.count)) * splitterHeight
        let bottomTotalH = subpanesTotalH + innerSplittersH + volumeH

        let y = timeAxisHeight + bottomTotalH
        return abs(loc.y - y) <= splitterHotZone && loc.x >= 0 && loc.x <= bounds.width
    }

    // Magic Mouse/触控板水平手势 deltaX 通常很小,需放大才能产生明显移动。
    public override func scrollWheel(with event: NSEvent) {
        let vw = chartPlotWidth
        // 高频滚轮事件禁止逐帧打日志,否则移动 K线时 I/O + os_log 会造成卡顿。
        // ⚠️ 2026-06-23:方向判断用 scrollingDeltaX/Y(精密设备准确区分水平/垂直)。
        // 旧版 deltaX 在水平滑动时常≈0,导致 abs(deltaY)>abs(deltaX) 误判成缩放。
        let hDelta = event.scrollingDeltaX
        let vDelta = event.scrollingDeltaY
        if abs(hDelta) > abs(vDelta), hDelta != 0 {
            // 水平滑动优先 → 左右平移。
            _ = viewportCalculator.pan(deltaX: Double(hDelta), viewWidth: vw)
        } else if event.deltaY != 0 {
            // 垂直滑动 → 缩放(沿用已正常的 deltaY 逻辑,锚点用绘图区中点)。
            _ = viewportCalculator.zoom(factor: event.deltaY > 0 ? 1.12 : 0.88, viewWidth: vw, anchorX: vw / 2)
        }
    }

    // ⚠️ 2026-06-22:触控板捏合缩放 → 调用UI模块计算器。
    public override func magnify(with event: NSEvent) {
        let vw = chartPlotWidth
        _ = viewportCalculator.zoom(factor: 1 + event.magnification, viewWidth: vw, anchorX: vw / 2)
    }

    // ⚠️ 2026-06-24:Magic Mouse 单指左右滑被 macOS 解读为 swipe 轻扫手势(走这里,不产生 scrollingDeltaX)。
    // 业务手势归业务:调 71 号计算器做平移。swipe 是离散事件(deltaX=±1),一次轻扫平移约 1/3 屏。
    public override func swipe(with event: NSEvent) {
        klineLogger.info("👉swipe dx=\(event.deltaX) dy=\(event.deltaY)")
        let vw = chartPlotWidth
        guard vw > 1, event.deltaX != 0 else { return }
        let step = vw / 3.0
        _ = viewportCalculator.pan(deltaX: Double(event.deltaX) * step, viewWidth: vw)
    }


    private func lightRefresh() {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 1 { logger.info("[PERF][KX-UI-12] lightRefresh ms=\(dt)") }
        }
        // 轻量移动刷新必须同步 viewport 到所有图层;否则 onViewportChanged 只改了 view.viewport,
        // 图层仍拿旧 viewport 绘制,表现就是拖动/缩放后 K线半天不动,直到下一次全量 refreshData。
        candleLayer.candles = candles; candleLayer.viewport = viewport
        volumeLayer.candles = candles; volumeLayer.viewport = viewport
        priceAxisLayer.candles = candles; priceAxisLayer.viewport = viewport; priceAxisLayer.timeframe = timeframe; priceAxisLayer.pricePrecision = pricePrecisionForSymbol()
        timeAxisLayer.candles = candles; timeAxisLayer.viewport = viewport; timeAxisLayer.timeframe = timeframe
        newOverlayRenderer.candles = candles; newOverlayRenderer.viewport = viewport
        // 副图渲染器也必须同步 viewport,否则拖动时 RSI 等指标不跟随移动
        for (index, slot) in subpaneSlots.enumerated() {
            guard index < subpaneOverlayRenderers.count, slot.instanceID != nil else { continue }
            let renderer = subpaneOverlayRenderers[index]
            renderer.candles = candles
            renderer.viewport = viewport
            renderer.setNeedsDisplay()
        }
        candleLayer.prepareForDrawing()
        volumeLayer.prepareForDrawing()
        candleLayer.setNeedsDisplay()
        volumeLayer.setNeedsDisplay()
        priceAxisLayer.setNeedsDisplay()
        timeAxisLayer.setNeedsDisplay()
        crosshairLayer.setNeedsDisplay()
        newOverlayRenderer.setNeedsDisplay()
        realtimeLineLayer.setNeedsDisplay()
        if crosshairActive {
            let loc = CGPoint(x: crosshairPoint.x, y: crosshairPoint.y + crosshairLayer.frame.minY)
            updateCrosshair(at: loc)
        }
        // 更新右侧量柱区域最大成交量(viewport 移动时可见K线变化,最大成交量应跟随变化)
        updateVolumeMaxLabel()
    }

    // ⚠️ 2026-06-23:把 UI-GL-71 算出的 UIChartViewport 映射到 K线渲染用 viewport(只同步,不刷新;刷新由调用方决定)。
    // 图层只读 startIndex + candleWidth,故这里把这两个关键值精确映射过去。
    private func applyViewport(_ vp: UIChartViewport) {
        viewport = KLViewportAdjustResult(
            startIndex: vp.startIndex,
            endIndex: vp.endIndex,
            candleWidth: vp.candleWidth,
            contentOffsetX: vp.contentOffsetX
        )
    }

    private func updateCrosshair(at loc: CGPoint) {
        let now = Date().timeIntervalSince1970
        if now - lastCrosshairUpdateAt < 0.016 { return }
        lastCrosshairUpdateAt = now
        let point = CGPoint(x: max(0, min(loc.x, crosshairLayer.bounds.width)), y: max(0, min(loc.y - crosshairLayer.frame.minY, crosshairLayer.bounds.height)))
        crosshairPoint = point
        crosshairLayer.point = point
        crosshairLayer.active = true
        crosshairLayer.isHidden = false
        crosshairLayer.setNeedsDisplay()

        let idx = viewport.startIndex + Int(point.x / max(CGFloat(viewport.candleWidth), 1.5))
        guard idx >= 0, idx < candles.count else { return }
        let candle = candles[idx]

        // 计算价格:优先根据鼠标 Y 位置在 K线区域反查,更准确
        let price: Decimal
        let candleFrame = candleLayer.frame
        if loc.y >= candleFrame.minY && loc.y <= candleFrame.maxY {
            let visible = visibleCandles()
            let minP = visible.map(\.low).min() ?? candle.low
            let maxP = visible.map(\.high).max() ?? candle.high
            let minD = minP.dbl
            let maxD = maxP.dbl
            let range = max(maxD - minD, 0.00000001)
            let plotH = max(candleLayer.bounds.height - 16, 1)
            let relativeY = loc.y - candleFrame.minY
            let clampedY = max(8.0, min(Double(relativeY), 8.0 + Double(plotH)))
            price = Decimal(minD + (clampedY - 8.0) / Double(plotH) * range)
        } else {
            price = candle.close
        }

        onCrosshairUpdated?(candle.openTime, price)

        // === 更新时间标签(在时间轴上跟随竖虚线左右移动)===
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        switch timeframe {
        case .oneSecond: timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        case .oneMinute, .threeMinutes, .fiveMinutes, .fifteenMinutes, .thirtyMinutes: timeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        case .oneHour, .twoHours, .fourHours, .sixHours, .twelveHours: timeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        case .oneDay, .twoDays, .threeDays, .oneWeek: timeFormatter.dateFormat = "yyyy-MM-dd"
        case .oneMonth, .threeMonths: timeFormatter.dateFormat = "yyyy-MM"
        }
        let timeStr = timeFormatter.string(from: candle.openTime)
        crosshairTimeLabel.string = timeStr
        let timeWidth = CGFloat(timeStr.count * 7 + 16)
        let priceAxisW = max(72, min(96, bounds.width * 0.12))
        // 标签跟随竖虚线居中,但限制在可见范围内(不超出左边界、不遮挡价格轴)
        let timeX = max(4, min(loc.x - timeWidth / 2, bounds.width - priceAxisW - timeWidth - 4))
        crosshairTimeLabel.frame = CGRect(x: timeX, y: 3, width: timeWidth, height: 18)
        crosshairTimeLabel.isHidden = false

        // === 更新价格标签(在价格轴上跟随横虚线上下移动)===
        let priceStr = String(format: "%.*f", pricePrecisionForSymbol(), (price as NSDecimalNumber).doubleValue)
        crosshairPriceLabel.string = priceStr
        let priceWidth = CGFloat(priceStr.count * 7 + 16)
        let priceX = bounds.width - priceAxisW + 4
        let priceY = max(4, min(loc.y - 9, bounds.height - 22))
        crosshairPriceLabel.frame = CGRect(x: priceX, y: priceY, width: priceWidth, height: 18)
        crosshairPriceLabel.isHidden = false
    }

    public func deactivateCrosshair() {
        crosshairActive = false
        crosshairLayer.active = false
        crosshairLayer.isHidden = true
        crosshairLayer.setNeedsDisplay()
        crosshairTimeLabel.isHidden = true
        crosshairPriceLabel.isHidden = true
    }

    private func pricePrecisionForSymbol() -> Int {
        if symbol.contains("BTC") || symbol.contains("ETH") { return 2 }
        if symbol.contains("DOGE") || symbol.contains("SHIB") { return 5 }
        return 3
    }

    private static func makePreviewCandles(symbol: String, timeframe: KXTimeframe, count: Int) -> [KLCandlePoint] {
        // 正式 K线面板绝对禁止生成样品/模拟 K线。
        // 没有真实 OKX/DB 数据时必须显示加载或空态,不能画假行情误导用户。
        return []
    }

    public func showGrid(_ enabled: Bool) {
        // 实现网格显示/隐藏逻辑
    }

    public func showCrosshair(_ enabled: Bool) {
        crosshairActive = enabled
        needsDisplay = true
    }

    public func showVolumePanel(_ enabled: Bool) {
        if let volumeLayer = value(forKey: "volumeLayer") as? CALayer {
            volumeLayer.isHidden = !enabled
            needsLayout = true
        }
    }

    private func showNewIndicatorSettings(instanceID: String) {
        // 如果已有打开的面板,先关闭
        closeEmbeddedSettingsPanel()

        guard let instance = KXProfessionalIndicatorInstanceManager.shared.instance(id: instanceID),
              let template = KXProfessionalIndicatorInstanceManager.shared.template(for: instance.indicatorID) else { return }

        // 构建 settings schema
        var sections: [KXIndicatorSettingsSection] = []
        if !template.parameterSchema.isEmpty {
            let paramFields = template.parameterSchema.map { param in
                KXIndicatorSettingsField(
                    key: param.key,
                    title: param.title,
                    control: settingsControl(for: param.kind),
                    parameterSchema: param
                )
            }
            sections.append(KXIndicatorSettingsSection(id: "params", title: "参数", fields: paramFields, collapsible: false))
        }
        if !template.styleSchema.isEmpty {
            let styleFields = template.styleSchema.map { style in
                KXIndicatorSettingsField(
                    key: style.key,
                    title: style.title,
                    control: settingsControl(for: style.kind),
                    parameterSchema: style
                )
            }
            sections.append(KXIndicatorSettingsSection(id: "style", title: "样式", fields: styleFields, collapsible: true, defaultCollapsed: false))
        }
        let schema = KXIndicatorSettingsSchema(sections: sections, actions: [.apply, .reset, .delete])

        // 构建当前值字典
        var currentValues: [String: KXIndicatorParameterValue] = [:]
        for param in template.parameterSchema {
            currentValues[param.key] = instance.params[param.key] ?? param.defaultValue
        }
        for style in template.styleSchema {
            currentValues[style.key] = instance.styles[style.key] ?? style.defaultValue
        }

        // 找到被点击的芯片位置
        let chipButton = indicatorChipOverlay.subviews.first(where: {
            ($0 as? NSButton)?.identifier?.rawValue == instanceID
        })
        let chipFrame = chipButton?.frame ?? CGRect(x: 10, y: indicatorChipOverlay.frame.maxY, width: 80, height: 20)

        // 创建嵌入式面板容器
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 280
        let arrowHeight: CGFloat = 8
        let arrowWidth: CGFloat = 16

        // 面板位置:芯片下方(macOS坐标系y向上,所以是减)
        let chipFrameInSelf = indicatorChipOverlay.convert(chipFrame, to: self)
        let panelX = max(8, min(chipFrameInSelf.midX - panelWidth / 2, bounds.width - panelWidth - 8))
        let panelY = chipFrameInSelf.minY - panelHeight - arrowHeight - 4

        let containerFrame = CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight + arrowHeight)
        let containerView = NSView(frame: containerFrame)
        containerView.wantsLayer = true

        // 玻璃背景
        let bgLayer = CAShapeLayer()
        let path = CGMutablePath()
        let rect = CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        path.addRoundedRect(in: rect, cornerWidth: 8, cornerHeight: 8)
        // 箭头在顶部中间,指向芯片中心
        let chipCenterX = chipFrameInSelf.midX - panelX
        let arrowLeft = CGPoint(x: chipCenterX - arrowWidth / 2, y: panelHeight)
        let arrowRight = CGPoint(x: chipCenterX + arrowWidth / 2, y: panelHeight)
        let arrowTip = CGPoint(x: chipCenterX, y: panelHeight + arrowHeight)
        path.move(to: arrowLeft)
        path.addLine(to: arrowTip)
        path.addLine(to: arrowRight)
        path.closeSubpath()
        bgLayer.path = path
        bgLayer.fillColor = (KLUITheme.isDark ? NSColor.black.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.95)).cgColor
        bgLayer.strokeColor = KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.2).cgColor : NSColor.black.withAlphaComponent(0.1).cgColor
        bgLayer.lineWidth = 1
        containerView.layer?.addSublayer(bgLayer)

        // 设置内容视图
        let settingsView = KXUI21IndicatorSettingsPanel(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        settingsView.configure(instanceID: instanceID, schema: schema, currentValues: currentValues)

        // 玻璃皮肤适配
        settingsView.wantsLayer = true
        settingsView.layer?.backgroundColor = NSColor.clear.cgColor

        settingsView.onApply = { [weak self] iid, values in
            var params: [String: KXIndicatorParameterValue] = [:]
            var styles: [String: KXIndicatorParameterValue] = [:]
            for (key, value) in values {
                if template.parameterSchema.contains(where: { $0.key == key }) {
                    params[key] = value
                } else if template.styleSchema.contains(where: { $0.key == key }) {
                    styles[key] = value
                }
            }
            KXProfessionalIndicatorInstanceManager.shared.updateParams(instanceID: iid, params: params)
            KXProfessionalIndicatorInstanceManager.shared.updateStyle(instanceID: iid, styles: styles)
            if let context = self?.makeCurrentIndicatorCalculationContext() {
                self?.recalculateAndSubmitProfessional(instanceID: iid, context: context)
            }
            self?.reloadExternalOverlays()
            self?.rebuildIndicatorHeader()
            self?.closeEmbeddedSettingsPanel()
        }
        settingsView.onDelete = { [weak self] iid in
            self?.removeProfessionalIndicatorInstanceAndOverlay(instanceID: iid)
            self?.reloadExternalOverlays()
            self?.rebuildIndicatorHeader()
            self?.needsLayout = true
            self?.closeEmbeddedSettingsPanel()
        }

        containerView.addSubview(settingsView)
        addSubview(containerView, positioned: .above, relativeTo: indicatorChipOverlay)

        embeddedSettingsPanel = containerView
        logger.info("[KLine][Settings] embedded panel opened for instance=\(instanceID)")
    }

    private func closeEmbeddedSettingsPanel() {
        embeddedSettingsPanel?.removeFromSuperview()
        embeddedSettingsPanel = nil
        embeddedSettingsArrowLayer?.removeFromSuperlayer()
        embeddedSettingsArrowLayer = nil
    }

    private func settingsControl(for kind: KXIndicatorParameterKind) -> KXIndicatorSettingsControlType {
        switch kind {
        case .integer, .decimal: return .numberInput
        case .dataSource: return .dropdown
        case .option: return .dropdown
        case .boolean: return .checkbox
        case .color: return .colorPicker
        case .lineWidth: return .lineWidthSelector
        case .lineStyle: return .lineStyleSelector
        case .opacity: return .opacitySlider
        }
    }
}

// MARK: - 玻璃风格工具按钮

private final class KXUIGlassIconButton: NSButton {
    var onTap: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false
    private let iconLayer = CAShapeLayer()
    private let bgLayer = CAShapeLayer()

    init(icon: KXUIIconSymbol, size: CGFloat = 22) {
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        wantsLayer = true
        layer?.addSublayer(bgLayer)
        layer?.addSublayer(iconLayer)
        iconLayer.fillColor = NSColor.clear.cgColor
        iconLayer.strokeColor = KLUITheme.axisText.cgColor
        iconLayer.lineWidth = 1.2
        iconLayer.lineCap = .round
        iconLayer.lineJoin = .round
        iconLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        target = self
        action = #selector(clicked)
        isBordered = false
        title = ""
        updateIcon(icon, size: size)
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let bounds = self.bounds
        let corner = bounds.height / 2
        bgLayer.path = NSBezierPath(roundedRect: bounds, xRadius: corner, yRadius: corner).cgPath
        iconLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        updateIcon(symbol, size: bounds.width)
    }

    private var symbol: KXUIIconSymbol = .chevronDown

    func updateIcon(_ icon: KXUIIconSymbol, size: CGFloat) {
        symbol = icon
        iconLayer.path = icon.path(in: CGRect(x: 4, y: 4, width: size - 8, height: size - 8)).cgPath
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .mouseMoved], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        updateAppearance()
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onTap?()
        }
    }

    @objc private func clicked() { onTap?() }

    func updateAppearance() {
        let baseAlpha: CGFloat = KLUITheme.isDark ? 0.28 : 0.42
        let hoverAlpha: CGFloat = KLUITheme.isDark ? 0.48 : 0.62
        let pressAlpha: CGFloat = KLUITheme.isDark ? 0.22 : 0.34
        let alpha = isPressed ? pressAlpha : (isHovered ? hoverAlpha : baseAlpha)
        bgLayer.fillColor = (KLUITheme.isDark ? NSColor.black : NSColor.white).withAlphaComponent(alpha).cgColor
        bgLayer.strokeColor = KLUITheme.axisText.withAlphaComponent(0.24).cgColor
        bgLayer.lineWidth = 0.5
        iconLayer.strokeColor = KLUITheme.axisText.cgColor
        iconLayer.setNeedsDisplay()
    }
}

private enum KXUIIconSymbol {
    case chevronDown
    case chevronUp
    case xmark
    case line3Horizontal

    func path(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        switch self {
        case .chevronDown:
            path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY - 2))
            path.line(to: CGPoint(x: rect.midX, y: rect.midY + 3))
            path.line(to: CGPoint(x: rect.maxX - 2, y: rect.midY - 2))
        case .chevronUp:
            path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY + 2))
            path.line(to: CGPoint(x: rect.midX, y: rect.midY - 3))
            path.line(to: CGPoint(x: rect.maxX - 2, y: rect.midY + 2))
        case .xmark:
            path.move(to: CGPoint(x: rect.minX + 3, y: rect.minY + 3))
            path.line(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 3))
            path.move(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3))
            path.line(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        case .line3Horizontal:
            for i in 0..<3 {
                let y = rect.minY + 4 + CGFloat(i) * 5
                path.move(to: CGPoint(x: rect.minX + 2, y: y))
                path.line(to: CGPoint(x: rect.maxX - 2, y: y))
            }
        }
        return path
    }
}

// MARK: - 主题适配分界线图层

private final class KXUIThemedDividerLayer: CALayer {
    var isVertical = false
    var theme = KLChartThemeBundle()

    override func draw(in ctx: CGContext) {
        ctx.setFillColor(theme.splitter)
        ctx.fill(bounds)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI12Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-12", fileName: "KX-UI-12_图表视图.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-12_图表视图.swift", duty: "K线图表完整视图容器"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线图表视图骨架校验通过")
        return KXHealthCheckItem(name: "K线图表视图", passed: true, message: "K线图表完整视图容器")
    }
}
