//
//  SearchView.swift
//  KurlyProject
//

import SwiftUI

struct SearchView: View {

    @State private var viewModel: SearchViewModel

    /// 최근 검색어를 눌러 검색했을 때도 직접 입력했을 때처럼 검색바를 활성화해 "취소" 버튼을 보여주기 위해 둔다
    @State private var isSearchPresented = false

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // `.searchable`은 NavigationStack 안에서 큰 타이틀 아래 검색바와 "취소" 버튼을 기본으로 그린다
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: $viewModel.query, isPresented: $isSearchPresented, prompt: "저장소 검색")
                // 입력 중에는 호출하지 않고, 키보드 search를 눌렀을 때만 검색한다
                .onSubmit(of: .search) {
                    viewModel.search()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        // 검색 상태와 상관없이 입력이 비어 있으면 최근 검색어를 보여준다 ("취소"로 입력을 비운 경우 포함)
        if viewModel.query.isEmpty {
            recentSearchList
        } else {
            searchResultContent
        }
    }

    private var recentSearchList: some View {
        List {
            Section {
                // 대소문자 무시 중복 제거로 keyword가 유일하므로 id로 쓴다
                ForEach(viewModel.recentSearches, id: \.keyword) { recentSearch in
                    HStack {
                        // 기본 버튼 스타일이라 x 버튼(borderless)을 뺀 행 전체가 이 버튼에 반응한다
                        Button {
                            isSearchPresented = true
                            viewModel.search(keyword: recentSearch.keyword)
                        } label: {
                            Text(recentSearch.keyword)
                                // 버튼 안에서는 `.primary`가 강조색을 가리키므로 `Color.primary`로 일반 글자색을 지정한다
                                .foregroundStyle(Color.primary)
                        }
                        Spacer()
                        Button {
                            viewModel.delete(keyword: recentSearch.keyword)
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.secondary)
                        }
                        // List 행 안의 버튼은 기본적으로 행 전체 탭에 반응한다.
                        // 행 탭은 #7에서 검색에 쓰므로 버튼 영역만 반응하게 한다
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(recentSearch.keyword) 삭제")
                    }
                }
            } header: {
                Text("최근 검색")
            } footer: {
                if !viewModel.recentSearches.isEmpty {
                    HStack {
                        Spacer()
                        Button("전체삭제") {
                            viewModel.deleteAll()
                        }
                    }
                }
            }
        }
    }

    // 상태별 화면은 최소한으로만 둔다. 결과 행은 #8~#10, 에러 화면은 #12에서 만든다
    @ViewBuilder
    private var searchResultContent: some View {
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
    SearchView(viewModel: SearchViewModel(
        repository: DefaultSearchResultRepository(),
        recentSearchUseCase: RecentSearchUseCase(repository: UserDefaultsRecentSearchRepository())
    ))
}
