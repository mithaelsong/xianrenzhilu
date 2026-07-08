//
//  KX-MK-03_形态标记详情弹窗.swift
//  仙人指路测试项目｜K线模块｜标记层
//
//  职责：点击 K线形态标签后展示详情弹窗（解释、判断依据、周期意义、风险提示、操作）。
//  边界：不计算形态、不修改 overlay、不刷新图表、不改变 K线移动/缩放链路。
//

import AppKit
import Foundation

final class KXMK03PatternMarkerDetailPopoverController: NSViewController {
    private let payload: KLCandlePatternMarkerPayload
    private weak var popover: NSPopover?

    init(payload: KLCandlePatternMarkerPayload, popover: NSPopover?) {
        self.payload = payload
        self.popover = popover
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 300))
        root.wantsLayer = true
        root.layer?.cornerRadius = 14
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])

        stack.addArrangedSubview(label("\(payload.patternName)  \(Int(payload.confidence * 100))%", size: 15, weight: .semibold))
        stack.addArrangedSubview(label("方向：\(directionText(payload.direction))    触发价：\(priceText(payload.anchorPrice))", size: 11, color: .secondaryLabelColor))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section("形态解释", explanationText()))
        stack.addArrangedSubview(section("判断依据", evidenceText()))
        stack.addArrangedSubview(section("周期意义", timeframeMeaningText()))
        stack.addArrangedSubview(section("风险提示", riskText()))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY
        buttons.addArrangedSubview(actionButton("观察", tooltip: "记录该形态，后续接入观察列表"))
        buttons.addArrangedSubview(actionButton("提醒", tooltip: "后续接入形态提醒规则"))
        let close = NSButton(title: "关闭", target: self, action: #selector(closePopover))
        close.bezelStyle = .rounded
        buttons.addArrangedSubview(close)
        stack.addArrangedSubview(buttons)

        self.view = root
    }

    private func section(_ title: String, _ body: String) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 2
        container.addArrangedSubview(label(title, size: 11, weight: .medium, color: .labelColor))
        container.addArrangedSubview(label(body, size: 10.5, color: .secondaryLabelColor))
        return container
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let v = NSTextField(labelWithString: text)
        v.font = .systemFont(ofSize: size, weight: weight)
        v.textColor = color
        v.lineBreakMode = .byWordWrapping
        v.maximumNumberOfLines = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(lessThanOrEqualToConstant: 312).isActive = true
        return v
    }

    private func separator() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 312).isActive = true
        return v
    }

    private func actionButton(_ title: String, tooltip: String) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .rounded
        b.toolTip = tooltip
        b.isEnabled = false
        return b
    }

    @objc private func closePopover() { popover?.close() }

    private func explanationText() -> String {
        if let description = payload.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return firstUsefulLine(from: description)
        }
        if payload.patternID == "hammer" || payload.patternName.contains("锤") {
            return "锤子线通常是下跌末端的看涨反转信号，长下影说明盘中有明显承接。"
        }
        if payload.patternID == "marubozu" || payload.patternName.contains("光头光脚") || payload.patternName.contains("满柱") {
            return "光头光脚（满柱）表示实体占比极高、上下影线很短，说明当前周期内一方力量持续主导，属于强动能/延续类信号。"
        }
        if payload.patternID == "bullish-engulfing" || payload.patternName.contains("看涨吞没") {
            return "看涨吞没表示一根阳线实体完全覆盖前一根阴线实体，通常出现在下跌后，属于潜在看涨反转信号。"
        }
        if payload.patternID == "bearish-engulfing" || payload.patternName.contains("看跌吞没") {
            return "看跌吞没表示一根阴线实体完全覆盖前一根阳线实体，通常出现在上涨后，属于潜在看跌反转信号。"
        }
        if payload.patternID == "dark-cloud-cover" || payload.patternName.contains("乌云盖顶") {
            return "乌云盖顶表示上涨后一根阴线高开低走，收盘价深入前一根阳线实体一半以下，属于潜在看跌反转信号。"
        }
        if payload.patternID == "piercing-line" || payload.patternName.contains("刺透") {
            return "刺透形态表示下跌后一根阳线低开高走，收盘价深入前一根阴线实体一半以上，属于潜在看涨反转信号。"
        }
        if payload.patternID == "bullish-harami" || payload.patternName.contains("看涨孕线") {
            return "看涨孕线表示下跌后一根小阳线实体完全位于前一根阴线实体内部，属于潜在看涨反转信号。"
        }
        if payload.patternID == "bearish-harami" || payload.patternName.contains("看跌孕线") {
            return "看跌孕线表示上涨后一根小阴线实体完全位于前一根阳线实体内部，属于潜在看跌反转信号。"
        }
        if payload.patternID == "harami-cross" || payload.patternName.contains("十字孕线") {
            return "十字孕线表示后一根为十字星且位于前一根实体内部，属于潜在反转信号，方向需结合前一根K线判断。"
        }
        if payload.patternID == "spinning-top" || payload.patternName.contains("纺锤") {
            return "纺锤线表示实体较小且上下影线明显，多空在当前周期内反复争夺但未形成明确方向，属于中性/犹豫信号。"
        }
        if payload.patternID == "long-lower-shadow" || payload.patternName.contains("长下影") {
            return "长下影线表示盘中一度下探但收盘回升，下影部分显示下方有买盘承接，属于潜在看涨或支撑确认信号。"
        }
        if payload.patternID == "long-upper-shadow" || payload.patternName.contains("长上影") {
            return "长上影线表示盘中一度冲高但收盘回落，上影部分显示上方有卖盘抛压，属于潜在看跌或阻力确认信号。"
        }
        if payload.patternID == "hanging-man" || payload.patternName.contains("吊颈") || payload.patternName.contains("上吊") {
            return "吊颈线通常出现在上涨后的高位区域，小实体长下影代表高位分歧，属于潜在看跌反转信号。"
        }
        if payload.patternID == "gravestone-doji" || payload.patternName.contains("墓碑十字星") {
            return "墓碑十字星表示开收盘接近且长上影明显，盘中冲高后回落，属于潜在看跌反转或高位抛压信号。"
        }
        if payload.patternID == "dragonfly-doji" || payload.patternName.contains("蜻蜓十字星") {
            return "蜻蜓十字星表示开收盘接近且长下影明显，盘中下探后回升，属于潜在看涨反转或低位承接信号。"
        }
        if payload.patternID == "long-legged-doji" || payload.patternName.contains("长腿十字星") || payload.patternName.contains("长脚十字星") {
            return "长腿十字星表示开盘价与收盘价接近，同时影线明显拉长；本阶段按设置面板语义突出长下影，代表当前周期内波动加剧和多空分歧扩大。"
        }
        if payload.patternID == "doji" || payload.patternName.contains("十字星") {
            return "十字星表示开盘价与收盘价非常接近，多空在当前K线周期内拉锯后暂时均衡，属于中性/分歧信号。"
        }
        return "系统在当前可见已闭合 K线上识别到该形态信号。"
    }

    private func evidenceText() -> String {
        let count = max(payload.candleTimes.count, 1)
        if payload.patternID == "marubozu" || payload.patternName.contains("光头光脚") || payload.patternName.contains("满柱") {
            return "触发K线数：\(count)；形态结构：实体占比极高、上下影线很短；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "bullish-engulfing" || payload.patternName.contains("看涨吞没") {
            return "触发K线数：\(count)；形态结构：阳线实体完全覆盖前阴线实体；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "bearish-engulfing" || payload.patternName.contains("看跌吞没") {
            return "触发K线数：\(count)；形态结构：阴线实体完全覆盖前阳线实体；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "piercing-line" || payload.patternName.contains("刺透") {
            return "触发K线数：\(count)；形态结构：阳线低开高走、收盘价深入前阴线实体一半以上；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "dark-cloud-cover" || payload.patternName.contains("乌云盖顶") {
            return "触发K线数：\(count)；形态结构：阴线高开低走、收盘价深入前阳线实体一半以下；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "bullish-harami" || payload.patternName.contains("看涨孕线") {
            return "触发K线数：\(count)；形态结构：前阴后阳、后实体被前实体完全包含；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "bearish-harami" || payload.patternName.contains("看跌孕线") {
            return "触发K线数：\(count)；形态结构：前阳后阴、后实体被前实体完全包含；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "harami-cross" || payload.patternName.contains("十字孕线") {
            return "触发K线数：\(count)；形态结构：后十字星位于前实体内部；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "spinning-top" || payload.patternName.contains("纺锤") {
            return "触发K线数：\(count)；形态结构：小实体、上下影线明显；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "long-lower-shadow" || payload.patternName.contains("长下影") {
            return "触发K线数：\(count)；形态结构：下影线明显、实体相对较小；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "long-upper-shadow" || payload.patternName.contains("长上影") {
            return "触发K线数：\(count)；形态结构：上影线明显、实体相对较小；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "hanging-man" || payload.patternName.contains("吊颈") || payload.patternName.contains("上吊") {
            return "触发K线数：\(count)；形态结构：小实体、长下影、短上影；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "gravestone-doji" || payload.patternName.contains("墓碑十字星") {
            return "触发K线数：\(count)；形态结构：开收盘接近、实体极小、长上影、短下影；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "dragonfly-doji" || payload.patternName.contains("蜻蜓十字星") {
            return "触发K线数：\(count)；形态结构：开收盘接近、实体极小、长下影、短上影；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "long-legged-doji" || payload.patternName.contains("长腿十字星") || payload.patternName.contains("长脚十字星") {
            return "触发K线数：\(count)；形态结构：开收盘接近、实体极小、影线拉长；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        if payload.patternID == "doji" || payload.patternName.contains("十字星") {
            return "触发K线数：\(count)；形态结构：开收盘接近、实体极小；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
        }
        return "触发K线数：\(count)；置信度：\(Int(payload.confidence * 100))%；方向：\(directionText(payload.direction))。"
    }

    private func timeframeMeaningText() -> String {
        if let description = payload.description, let range = description.range(of: "周期意义：") {
            let suffix = String(description[range.upperBound...])
            return firstUsefulLine(from: suffix)
        }
        return "该形态只代表当前图表周期的局部信号，周期越大，确认意义越强但滞后越明显。"
    }

    private func riskText() -> String {
        if payload.patternID == "marubozu" || payload.patternName.contains("光头光脚") || payload.patternName.contains("满柱") {
            return "光头光脚代表动能强，但追涨杀跌风险高；需要结合当前趋势、成交量、均线和下一根K线延续情况确认，避免在极端拉升/杀跌末端误判。"
        }
        if payload.patternID == "bullish-engulfing" || payload.patternName.contains("看涨吞没") {
            return "看涨吞没偏看涨，但不能单独作为买入依据；需要结合下跌位置、支撑位、成交量和后续K线确认，震荡区间内容易因正常波动误报。"
        }
        if payload.patternID == "bearish-engulfing" || payload.patternName.contains("看跌吞没") {
            return "看跌吞没偏看跌，但不能单独作为卖出依据；需要结合上涨位置、阻力位、成交量和后续K线确认，震荡区间内容易因正常波动误报。"
        }
        if payload.patternID == "piercing-line" || payload.patternName.contains("刺透") {
            return "刺透形态偏看涨，但不能单独作为买入依据；需要结合下跌位置、支撑位、成交量和后续K线确认，若阳线收盘未过半可能只是弱势反弹。"
        }
        if payload.patternID == "dark-cloud-cover" || payload.patternName.contains("乌云盖顶") {
            return "乌云盖顶偏看跌，但不能单独作为卖出依据；需要结合上涨位置、阻力位、成交量和后续K线确认，若阴线收盘未过半可能只是弱势回调。"
        }
        if payload.patternID == "bullish-harami" || payload.patternName.contains("看涨孕线") {
            return "看涨孕线偏看涨，但不能单独作为买入依据；需要结合下跌位置、支撑位、成交量和后续K线确认，若后实体过小或处于震荡区间可能只是弱势整理。"
        }
        if payload.patternID == "bearish-harami" || payload.patternName.contains("看跌孕线") {
            return "看跌孕线偏看跌，但不能单独作为卖出依据；需要结合上涨位置、阻力位、成交量和后续K线确认，若后实体过小或处于震荡区间可能只是弱势整理。"
        }
        if payload.patternID == "harami-cross" || payload.patternName.contains("十字孕线") {
            return "十字孕线表示多空分歧加剧，但不能单独作为买卖依据；需要结合所处位置、成交量和后续K线确认方向，震荡区间容易出现假信号。"
        }
        if payload.patternID == "spinning-top" || payload.patternName.contains("纺锤") {
            return "纺锤线本身只代表犹豫和分歧，不直接给出买卖方向；需要结合所处位置、成交量、趋势和下一根K线确认，震荡区间容易频繁出现。"
        }
        if payload.patternID == "long-lower-shadow" || payload.patternName.contains("长下影") {
            return "长下影线偏看涨，但不能单独作为买入依据；需要结合低位位置、支撑位、成交量和后续K线确认，高位出现可能只是短期回调。"
        }
        if payload.patternID == "long-upper-shadow" || payload.patternName.contains("长上影") {
            return "长上影线偏看跌，但不能单独作为卖出依据；需要结合高位位置、阻力位、成交量和后续K线确认，低位出现可能只是短期反弹。"
        }
        if payload.patternID == "hanging-man" || payload.patternName.contains("吊颈") || payload.patternName.contains("上吊") {
            return "吊颈线只是高位分歧提示，不能单独作为卖出依据；需结合阻力位、趋势强度、成交量和后续K线确认，震荡区间容易误报。"
        }
        if payload.patternID == "gravestone-doji" || payload.patternName.contains("墓碑十字星") {
            return "墓碑十字星偏看跌，但不能单独作为卖出依据；需要结合高位位置、阻力位、成交量和后续K线确认，低位或震荡区容易误报。"
        }
        if payload.patternID == "dragonfly-doji" || payload.patternName.contains("蜻蜓十字星") {
            return "蜻蜓十字星偏看涨，但不能单独作为买入依据；需要结合低位位置、支撑位、成交量和后续K线确认，高位或震荡区容易误报。"
        }
        if payload.patternID == "long-legged-doji" || payload.patternName.contains("长腿十字星") || payload.patternName.contains("长脚十字星") {
            return "长腿十字星说明当前周期波动和分歧放大，但本身不直接给出方向；需要结合位置、成交量、趋势和下一根K线确认，避免把剧烈震荡误判成反转。"
        }
        if payload.patternID == "doji" || payload.patternName.contains("十字星") {
            return "十字星本身只代表分歧和犹豫，不直接代表上涨或下跌；需要结合所处位置、成交量、趋势和下一根K线方向确认。"
        }
        return "单根形态不能单独作为买卖依据；需结合趋势、成交量、支撑阻力和后续K线确认，震荡区间容易误报。"
    }

    private func firstUsefulLine(from text: String) -> String {
        text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? text
    }

    private func directionText(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("bear") || raw.contains("跌") || raw.contains("空") { return "看跌" }
        if lower.contains("neutral") || raw.contains("中性") { return "中性" }
        if lower.contains("continuation") || raw.contains("延续") { return "延续" }
        return "看涨"
    }

    private func priceText(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        return NSDecimalNumber(decimal: value).stringValue
    }
}

enum KXMK03PatternMarkerDetailPresenter {
    private static var currentPopover: NSPopover?

    static func show(payload: KLCandlePatternMarkerPayload, at point: CGPoint, in view: NSView) {
        currentPopover?.close()
        let popover = NSPopover()
        let controller = KXMK03PatternMarkerDetailPopoverController(payload: payload, popover: popover)
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = CGSize(width: 340, height: 300)
        currentPopover = popover
        let anchor = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
        popover.show(relativeTo: anchor, of: view, preferredEdge: .maxY)
    }
}

public enum KXMK03Skeleton: KXFileSkeletonProtocol {
    public static let version = "1.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-MK-03", fileName: "KX-MK-03_形态标记详情弹窗.swift", layer: .ui,
        relativePath: "标记层/KX-MK-03_形态标记详情弹窗.swift", duty: "展示K线形态标记点击详情弹窗"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("形态标记详情弹窗骨架校验通过")
        return KXHealthCheckItem(name: "形态标记详情弹窗", passed: true, message: "已实现形态标记详情弹窗")
    }
}
