//
//  SidebarView.swift
//  Listuff
//
//  Created by MigMit on 10.01.2021.
//

import SwiftUI

struct SidebarView<Sidebar: View, Content: View>: View {
    let content: () -> TupleView<(Sidebar, Content)>
    @Binding var showSidebar: Bool
    init(showSidebar: Binding<Bool> = .constant(true), @ViewBuilder content: @escaping () -> TupleView<(Sidebar, Content)>) {
        self._showSidebar = showSidebar
        self.content = content
    }
    var body: some View {
        let cnt = content()
        GeometryReader {geometry in
            HStack {
                if showSidebar {
                    HStack {
                        cnt.value.0
                        Rectangle().fill(Color(UIColor.lightGray)).frame(width: 1)
                    }
                    .frame(width: geometry.size.width * 0.32)
                    .transition(.slide)
                }
                cnt.value.1
            }
        }
    }
}
