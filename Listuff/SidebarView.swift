//
//  SidebarView.swift
//  Listuff
//
//  Created by MigMit on 10.01.2021.
//

import Combine
import SwiftUI

struct ViewWithControls: ViewModifier {
    class FontModel: ObservableObject {
        @Published var headlineFont = UIFont.preferredFont(forTextStyle: .headline)
        private var cancellableSet: Set<AnyCancellable> = []
        init() {
            NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification).map{_ in UIFont.preferredFont(forTextStyle: .headline)}.assign(to: \.headlineFont, on: self).store(in: &cancellableSet)
        }
    }
    @ObservedObject var fontModel: FontModel
    let controls: AnyView
    init(controls: AnyView) {
        self.controls = controls
        self.fontModel = FontModel()
    }
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(UIColor.systemGray4)
                HStack {
                    controls
                }.padding([.leading, .trailing], 5)
            }.frame(height: fontModel.headlineFont.pointSize + 15).padding(5)
            content
        }
    }
}

extension View {
    func controls<Controls: View>(@ViewBuilder controls: () -> Controls) -> some View {
        modifier(ViewWithControls(controls: AnyView(controls())))
    }
}

struct SidebarView<Sidebar: View, Content: View>: View {
    @Binding var showSidebar: Bool
    let content: () -> TupleView<(Sidebar, Content)>
    init(showSidebar: Binding<Bool> = .constant(true), @ViewBuilder content: @escaping () -> TupleView<(Sidebar, Content)>) {
        self._showSidebar = showSidebar
        self.content = content
    }
    var body: some View {
        let cnt = content()
        GeometryReader {geometry in
            HStack(spacing: 0) {
                if showSidebar {
                    HStack(spacing: 0) {
                        cnt.value.0
                        Rectangle().fill(Color(UIColor.lightGray)).frame(width: 1)
                    }
                    .frame(width: geometry.size.width * 0.32)
                    .transition(.move(edge: .leading))
                }
                cnt.value.1
            }
        }
    }
}
