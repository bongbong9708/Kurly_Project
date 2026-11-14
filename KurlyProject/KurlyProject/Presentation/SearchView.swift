//
//  SearchView.swift
//  KurlyProject
//

import SwiftUI

struct SearchView: View {

    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // `.searchable`은 NavigationStack 안에서 큰 타이틀 아래 검색바와 "취소" 버튼을 기본으로 그린다
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: $viewModel.query, prompt: "저장소 검색")
                // 입력 중에는 호출하지 않고, 키보드 search를 눌렀을 때만 검색한다
                .onSubmit(of: .search) {
                    viewModel.search()
                }
        }
    }

    // 상태별 화면은 최소한으로만 둔다. 결과 행은 #8~#10, 에러 화면은 #12에서 만든다
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear
        case .loading:
            ProgressView()
        case .loaded(let result):
            List(result.repositories) { repository in
                Text(repository.name)
            }
        case .failed:
            Text("검색에 실패했습니다")
        }
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel(repository: DefaultSearchResultRepository()))
}
