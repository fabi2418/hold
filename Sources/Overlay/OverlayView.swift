import SwiftUI

/// Overlay nach Prototyp mit Suche und Tastaturnavigation (P3).
/// Kopieren (P4) sowie Editieren und Anlegen (P5) sind noch nicht aktiv.
struct OverlayView: View {
    @ObservedObject var model: OverlayViewModel
    @FocusState private var searchFocused: Bool

    private var store: LibraryStore { model.store }

    var body: some View {
        VStack(spacing: 0) {
            searchRow
            hairline
            tabBar
            hairline
            content
            hairline
            footer
        }
        .frame(width: Theme.panelWidth)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelRadius)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .onAppear { searchFocused = true }
        .onChange(of: model.focusRequest) { searchFocused = true }
    }

    private var hairline: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
    }

    // MARK: - Suchzeile

    private var searchRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            TextField("Library durchsuchen …", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .foregroundStyle(Theme.text)
                .focused($searchFocused)
            holdPill
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var holdPill: some View {
        HStack(spacing: 4) {
            Text("⌘").font(.system(size: 15, design: .monospaced))
            Text("halten = umschalten").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.accent))
    }

    // MARK: - Reiter

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(LibraryStore.tabs.enumerated()), id: \.element) { index, tab in
                tabButton(tab, shortcut: index + 1)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
    }

    private func tabButton(_ tab: String, shortcut: Int) -> some View {
        let isActive = tab == model.activeTab && !model.isSearching
        return Button {
            model.selectTab(tab)
        } label: {
            HStack(spacing: 4) {
                Text(tab)
                    .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? Theme.text : Theme.secondary)
                Text("\(store.items(in: tab).count)")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? Theme.text : Theme.secondary)
                    .opacity(0.65)
                Text("⌘\(shortcut)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            }
            .fixedSize()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? Theme.accent : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inhalt

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.rows.isEmpty && model.isSearching {
                        emptyState
                    } else {
                        columnHeader
                        listBody
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.contentPaddingTop)
                .padding(.horizontal, Theme.contentPaddingSides)
                .padding(.bottom, Theme.contentPaddingBottom)
            }
            .onChange(of: model.selection) { scrollToSelection(proxy) }
            .onChange(of: model.activeTab) { scrollToSelection(proxy) }
            .onChange(of: model.query) { scrollToSelection(proxy) }
        }
        .frame(height: Theme.contentHeight)
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard let item = model.selectedItem else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(item.id.uuidString, anchor: .center)
        }
    }

    /// SCR-02E
    private var emptyState: some View {
        Text("Nichts gefunden.")
            .font(.system(size: 15))
            .foregroundStyle(Theme.secondary)
            .padding(48)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var listBody: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(model.entries) { entry in
                switch entry {
                case .group(let name):
                    groupTitle(name)
                case .item(let item, let index):
                    row(item, isSelected: index == model.selection)
                        .id(item.id.uuidString)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    /// Scrollt mit dem Inhalt, bewusst ohne Trennlinie.
    private var columnHeader: some View {
        HStack(spacing: Theme.rowGap) {
            if model.isSearching {
                Color.clear.frame(width: Theme.badgeWidth, height: 1)
            }
            Text("BESCHREIBUNG")
                .frame(width: Theme.descriptionWidth, alignment: .leading)
            Text("COMMAND / PROMPT")
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: Theme.copyButtonWidth, height: 1)
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(11 * 0.06)
        .foregroundStyle(Theme.secondary)
        .padding(.bottom, 6)
    }

    private func groupTitle(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.top, 14)
            .padding(.bottom, 2)
    }

    private func row(_ item: LibraryItem, isSelected: Bool) -> some View {
        HStack(spacing: Theme.rowGap) {
            if model.isSearching {
                tabBadge(item.cat)
            }
            fieldText(item.desc, font: .system(size: 13), color: Theme.fieldText)
                .frame(width: Theme.descriptionWidth, height: Theme.fieldHeight, alignment: .leading)
                .background(fieldBackground(Theme.descriptionField, border: Theme.divider))

            fieldText(
                item.label,
                font: .system(size: 14, weight: isSelected ? .semibold : .regular, design: .monospaced),
                color: isSelected ? Theme.accent : Theme.text
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Theme.fieldHeight)
            .background(fieldBackground(Theme.commandField, border: Theme.border))

            copyButton
        }
        .padding(.vertical, 4)
        .padding(.horizontal, Theme.rowInset)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius)
                .fill(isSelected ? Theme.selectionFill : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rowRadius)
                .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1)
        )
        .padding(.horizontal, -Theme.rowInset)
    }

    /// Reiter-Badge je Suchtreffer (M7).
    private func tabBadge(_ cat: String) -> some View {
        Text(cat.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(10 * 0.06)
            .foregroundStyle(Theme.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: Theme.badgeWidth)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }

    private func fieldText(_ value: String, font: Font, color: Color) -> some View {
        Text(value)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, Theme.fieldPadding)
    }

    private func fieldBackground(_ fill: Color, border: Color) -> some View {
        RoundedRectangle(cornerRadius: Theme.fieldRadius)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldRadius)
                    .strokeBorder(border, lineWidth: 1)
            )
    }

    /// Zeichnet den Button; das Kopieren selbst folgt in P4.
    private var copyButton: some View {
        Image(systemName: "doc.on.doc")
            .font(.system(size: 16))
            .foregroundStyle(Theme.fieldText)
            .frame(width: Theme.copyButtonWidth, height: Theme.fieldHeight)
            .background(fieldBackground(Theme.commandField, border: Theme.border))
    }

    // MARK: - Fussleiste

    private var footer: some View {
        HStack(spacing: 16) {
            addButton
            Spacer()
            hints
            Spacer()
            Text("\(model.rows.count) Einträge")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Theme.footer)
    }

    /// Zeichnet den Button; das Anlegen folgt in P5.
    private var addButton: some View {
        Button {
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 11))
                Text("Eintrag hinzufügen").font(.system(size: 13))
            }
            .foregroundStyle(Theme.fieldText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldRadius)
                    .strokeBorder(Theme.dashedBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }

    private var hints: some View {
        HStack(spacing: 16) {
            hint([("↑↓", true), ("auswählen", false)])
            hint([("⌘C / ⌃C", true), ("kopieren", false)])
            hint([("←→", true), ("oder", false), ("⌘1–4", true), ("Reiter wechseln", false)])
        }
    }

    private func hint(_ segments: [(text: String, mono: Bool)]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .font(segment.mono ? .system(size: 12, design: .monospaced) : .system(size: 12))
                    .foregroundStyle(segment.mono ? Theme.fieldText : Theme.secondary)
            }
        }
    }
}
