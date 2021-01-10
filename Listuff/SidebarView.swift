//
//  SidebarView.swift
//  Listuff
//
//  Created by MigMit on 10.01.2021.
//

import SwiftUI

struct ViewWithControlsWrapper<Content: View, Controls: View>: View {
    let content: Content
    let controls: Controls
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(UIColor.systemGray4)
                HStack {
                    controls
                }.padding([.leading, .trailing], 10)
            }.frame(height: 40)
            content
        }
    }
}

extension View {
    func controls<Controls>(@ViewBuilder controls: () -> Controls) -> ViewWithControlsWrapper<Self, Controls> {
        return ViewWithControlsWrapper(content: self, controls: controls())
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
