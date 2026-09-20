import SwiftUI

/// Overlay nach Prototyp mit Suche und Tastaturnavigation (P3).
/// Kopieren (P4) sowie Editieren und Anlegen (P5) sind noch nicht aktiv.
struct OverlayView: View {
    @ObservedObject var model: OverlayViewModel
    @FocusState private var focus: OverlayFocus?
    /// Was gerade gezogen wird und wo der Drop-Indikator steht (P8).
    @State private var dragging: DragItem?
    @State private var dropTarget: DragItem?
    /// Zeile unter dem Mauszeiger; blendet den Loeschen-Knopf ein (P9).
    @State private var hoveredRow: UUID?

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
        .onAppear { focus = .search }
        .onChange(of: model.focusRequest) { focus = model.requestedFocus }
        .onChange(of: focus) { _, neu in
            model.focusedField = neu
            // Blur eines Umbenennungsfelds uebernimmt, wie Enter.
            if neu != .rename, model.isRenaming { model.commitRename() }
        }
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
                .focused($focus, equals: .search)
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
            ForEach(model.tabs, id: \.self) { tab in
                tabButton(tab, shortcut: model.shortcut(for: tab))
                    .overlay(alignment: .leading) { dropLine(for: .tab(tab), vertical: true) }
                    .onDrag { beginDrag(.tab(tab)) }
                    .onDrop(of: [.text], isTargeted: targetBinding(.tab(tab))) { _ in
                        drop(before: .tab(tab))
                    }
            }
            addTabButton
            Spacer()
        }
        .padding(.horizontal, 22)
        .onDrop(of: [.text], isTargeted: nil) { _ in drop(before: nil) }
    }

    @ViewBuilder
    private func tabButton(_ tab: String, shortcut: Int?) -> some View {
        if model.renaming == .tab(tab) {
            renameField(width: 90)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
        } else {
            tabLabel(tab, shortcut: shortcut)
        }
    }

    private var addTabButton: some View {
        Button { model.addTab() } label: {
            Image(systemName: "plus")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .frame(width: 26, height: 26)
                // Ohne Fuellung ist nur das Glyph klickbar: strokeBorder zeichnet
                // eine Linie, .frame nur Layout. contentShape macht die ganze
                // Flaeche treffbar.
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.dashedBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        }
        .buttonStyle(.plain)
        .help("Reiter hinzufügen")
    }

    private func tabLabel(_ tab: String, shortcut: Int?) -> some View {
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
                if let shortcut {
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
                if model.canDeleteTab(tab) {
                    deleteButton { model.deleteTab(tab) }
                }
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
        .onTapGesture(count: 2) { model.beginRename(.tab(tab)) }
    }

    /// Eingabefeld fuer Reiter- und Gruppennamen (K3). Enter uebernimmt,
    /// esc verwirft (ueber die esc-Leiter im Panel).
    private func renameField(width: CGFloat) -> some View {
        TextField("", text: $model.renameDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .focused($focus, equals: .rename)
            .onSubmit { model.commitRename() }
            .padding(.horizontal, 8)
            .frame(width: width, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.commandField)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.accent, lineWidth: 1)
                    )
            )
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        if model.isImporting {
            importView
        } else {
            listContent
        }
    }

    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.tabs.isEmpty {
                        EmptyView()
                    } else if model.rows.isEmpty && model.isSearching {
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
                    row(item, index: index, isSelected: index == model.selection)
                        .id(item.id.uuidString)
                        .overlay(alignment: .top) { dropLine(for: .row(item.id), vertical: false) }
                        .onDrag { beginDrag(.row(item.id)) }
                        .onDrop(of: [.text], isTargeted: targetBinding(.row(item.id))) { _ in
                            drop(before: .row(item.id))
                        }
                        .padding(.bottom, 8)
                }
            }
            if !model.isSearching { addGroupButton }
        }
    }

    private var addGroupButton: some View {
        Button { model.addGroup() } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 10))
                Text("Gruppe hinzufügen").font(.system(size: 12))
            }
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldRadius)
                    .strokeBorder(Theme.dashedBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    // MARK: - Drag and Drop (P8)

    private func beginDrag(_ item: DragItem) -> NSItemProvider {
        dragging = model.canReorder ? item : nil
        return NSItemProvider(object: NSString(string: item.id))
    }

    private func targetBinding(_ item: DragItem) -> Binding<Bool> {
        Binding(
            get: { dropTarget == item },
            set: { isTargeted in
                if isTargeted { dropTarget = item } else if dropTarget == item { dropTarget = nil }
            }
        )
    }

    /// Ein 2-pt-Strich in Akzentfarbe an der Einfuegestelle.
    @ViewBuilder
    private func dropLine(for item: DragItem, vertical: Bool) -> some View {
        if dropTarget == item, dragging != nil, dragging != item {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: vertical ? 2 : nil, height: vertical ? nil : 2)
        }
    }

    /// `before == nil` heisst ans Ende der jeweiligen Liste.
    private func drop(before target: DragItem?) -> Bool {
        defer {
            dragging = nil
            dropTarget = nil
        }
        guard model.canReorder, let source = dragging, source != target else { return false }

        switch (source, target) {
        case (.row(let id), .row(let targetID)):
            model.moveItem(id: id, to: .before(targetID))
        case (.row(let id), .group(let name)):
            model.moveItem(id: id, to: .endOfGroup(name))
        case (.group(let name), .group(let targetName)):
            model.moveGroup(name, before: targetName)
        case (.group(let name), nil):
            model.moveGroup(name, before: nil)
        case (.tab(let name), .tab(let targetName)):
            model.moveTab(name, before: targetName)
        case (.tab(let name), nil):
            model.moveTab(name, before: nil)
        default:
            return false
        }
        return true
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
            Color.clear.frame(width: Theme.copyButtonWidth + Theme.rowGap + 28, height: 1)
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(11 * 0.06)
        .foregroundStyle(Theme.secondary)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func groupTitle(_ name: String) -> some View {
        if model.renaming == .group(name) {
            renameField(width: 220)
                .padding(.top, 14)
                .padding(.bottom, 2)
        } else {
            HStack(spacing: 6) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                if model.canDeleteGroup(name) {
                    deleteButton { model.deleteGroup(name) }
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 2)
            .overlay(alignment: .top) { dropLine(for: .group(name), vertical: false) }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { model.beginRename(.group(name)) }
            .onDrag { beginDrag(.group(name)) }
            .onDrop(of: [.text], isTargeted: targetBinding(.group(name))) { _ in
                drop(before: .group(name))
            }
        }
    }

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 14, height: 14)
                .background(Circle().fill(Theme.divider))
        }
        .buttonStyle(.plain)
        .help("Löschen")
    }

    private func row(_ item: LibraryItem, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: Theme.rowGap) {
            if model.isSearching {
                tabBadge(item.cat)
            }
            editableField(
                text: descriptionBinding(item),
                placeholder: "Beschreibung",
                focusValue: .description(item.id),
                font: .system(size: 13),
                color: Theme.fieldText
            )
            .frame(width: Theme.descriptionWidth, height: Theme.fieldHeight, alignment: .leading)
            .background(fieldBackground(Theme.descriptionField, border: Theme.divider))

            editableField(
                text: labelBinding(item),
                placeholder: "Command / Prompt",
                focusValue: .command(item.id),
                font: .system(size: 14, weight: isSelected ? .semibold : .regular, design: .monospaced),
                color: isSelected ? Theme.accent : Theme.text
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Theme.fieldHeight)
            .background(fieldBackground(Theme.commandField, border: Theme.border))

            copyButton(for: item, index: index)
            rowDeleteButton(for: item)
        }
        .onHover { inside in
            if inside { hoveredRow = item.id } else if hoveredRow == item.id { hoveredRow = nil }
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

    /// TextField statt Text: im Fokus scrollt ein langer Wert bis zum
    /// Zeilenende, in Ruhe kuerzt AppKit mit Ellipsis (M5).
    private func editableField(
        text: Binding<String>,
        placeholder: String,
        focusValue: OverlayFocus,
        font: Font,
        color: Color
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .focused($focus, equals: focusValue)
            .padding(.horizontal, Theme.fieldPadding)
    }

    private func descriptionBinding(_ item: LibraryItem) -> Binding<String> {
        Binding(
            get: { model.item(id: item.id)?.desc ?? "" },
            set: { model.update(itemID: item.id, desc: $0) }
        )
    }

    private func labelBinding(_ item: LibraryItem) -> Binding<String> {
        Binding(
            get: { model.item(id: item.id)?.label ?? "" },
            set: { model.update(itemID: item.id, label: $0) }
        )
    }

    private func fieldBackground(_ fill: Color, border: Color) -> some View {
        RoundedRectangle(cornerRadius: Theme.fieldRadius)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldRadius)
                    .strokeBorder(border, lineWidth: 1)
            )
    }

    /// Erscheint bei Hover; der Platz bleibt immer reserviert, damit die
    /// Zeile beim Ueberfahren nicht springt (P9).
    @ViewBuilder
    private func rowDeleteButton(for item: LibraryItem) -> some View {
        if hoveredRow == item.id && model.canDelete {
            Button {
                model.select(index: model.rows.firstIndex(where: { $0.id == item.id }) ?? 0)
                model.deleteSelection()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 28, height: Theme.fieldHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Zeile löschen (⌫)")
        } else {
            Color.clear.frame(width: 28, height: Theme.fieldHeight)
        }
    }

    /// Kopiert die Zeile und setzt die Auswahl dorthin (M8).
    /// Gefuellter Zustand ist das Feedback nach SCR-04.
    private func copyButton(for item: LibraryItem, index: Int) -> some View {
        let isCopied = model.copiedItemID == item.id
        return Button {
            model.select(index: index)
            model.copy(item)
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 16))
                .foregroundStyle(isCopied ? Color.white : Theme.fieldText)
                .frame(width: Theme.copyButtonWidth, height: Theme.fieldHeight)
                .background(
                    fieldBackground(
                        isCopied ? Theme.accent : Theme.commandField,
                        border: isCopied ? Theme.accent : Theme.border
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import-View (P10)

    /// Laeuft IM Panel statt in einem Sheet oder Fenster: ein eigenes
    /// Key-Window wuerde dem Panel den Fokus nehmen und es schliessen lassen.
    private var importView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library importieren")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)

            ZStack(alignment: .topLeading) {
                if model.importText.isEmpty {
                    Text(OverlayViewModel.importPlaceholder)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.importText)
                    .textEditorStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .importField)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fieldBackground(Theme.commandField, border: Theme.border))

            if let error = model.importError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Abbrechen") { model.cancelImport() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.fieldRadius)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                Button("Importieren") { model.commitImport() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.fieldRadius).fill(Theme.accent)
                    )
            }
        }
        .padding(.horizontal, Theme.contentPaddingSides)
        .padding(.top, Theme.contentPaddingTop)
        .padding(.bottom, Theme.contentPaddingBottom)
        .frame(height: Theme.contentHeight)
    }

    // MARK: - Fussleiste

    private var footer: some View {
        HStack(spacing: 16) {
            addButton
            importButton
            Spacer()
            hints
            Spacer()
            Text(model.statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.hasCopyFeedback ? Theme.accent : Theme.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Theme.footer)
    }

    /// Neue leere Zeile am Ende der letzten Gruppe, direkt fokussiert (SCR-05).
    private var addButton: some View {
        Button {
            model.addEntry()
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

    /// Oeffnet dieselbe Import-View wie ⌘⇧V, nur mit leerem Feld (P10).
    private var importButton: some View {
        Button {
            model.openImport(prefillFromPasteboard: false)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 11))
                Text("Importieren").font(.system(size: 13))
                Text("⌘⇧V").font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
            }
            .foregroundStyle(Theme.fieldText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .contentShape(RoundedRectangle(cornerRadius: Theme.fieldRadius))
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
