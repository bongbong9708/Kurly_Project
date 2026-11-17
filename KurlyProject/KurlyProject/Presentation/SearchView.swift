//
//  SearchView.swift
//  KurlyProject
//

import SwiftUI

struct SearchView: View {

    @State private var viewModel: SearchViewModel

    /// 검색바에 키보드가 올라와 있는지. 올라와 있으면 입력 중으로 보고 검색 결과 대신 자동완성을 보여준다.
    ///
    /// iOS 17에는 `.searchable` 검색바의 포커스를 읽는 API(`.searchFocused`, iOS 18+)가 없어
    /// 키보드가 뜨고 내려가는 알림으로 대신한다
    @State private var isEditing = false

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // `.searchable`은 NavigationStack 안에서 큰 타이틀 아래 검색바와 "취소" 버튼을 기본으로 그린다
        NavigationStack {
            content
                .scrollDismissesKeyboard(.immediately)
                // List 같은 lazy 컨테이너 안에 두면 동작하지 않아 List 바깥에 붙인다
                .navigationDestination(for: GitHubRepository.self) { repository in
                    SearchDetailWebView(repository: repository)
                }
                .navigationTitle("Search")
                .searchable(text: $viewModel.query, prompt: "저장소 검색")
                // 입력 중에는 호출하지 않고, 키보드 search를 눌렀을 때만 검색한다
                .onSubmit(of: .search) {
                    viewModel.search()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    isEditing = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    isEditing = false
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        // 검색 전(idle)이거나 키보드가 올라와 있으면(입력 중) 최근 검색어·자동완성을 보여준다.
        // "취소"로 입력을 비우면 ViewModel이 idle로 돌아가므로 이 경우도 포함된다
        if viewModel.state == .idle || isEditing {
            let isSuggestion = !viewModel.query.isEmpty
            let searches = isSuggestion ? viewModel.suggestions : viewModel.recentSearches

            if searches.isEmpty {
                Group {
                    if isSuggestion {
                        ContentUnavailableView(
                            "일치하는 최근 검색어 없음",
                            systemImage: "magnifyingglass",
                            description: Text("키보드의 검색 버튼을 누르면 저장소를 검색합니다.")
                        )
                    } else {
                        ContentUnavailableView(
                            "최근 검색어 없음",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("검색한 단어가 여기에 표시됩니다.")
                        )
                    }
                }
                // 빈 곳을 누르면 키보드를 내린다.
                // 목록 화면 전체에 붙이면 행 버튼보다 먼저 반응해 행을 눌러도 검색되지 않아, 행이 없는 빈 화면에만 붙인다
                .contentShape(Rectangle())
                .onTapGesture { UIApplication.shared.endEditing() }
            } else {
                recentSearchList(searches, isSuggestion: isSuggestion)
            }
        } else {
            searchResultContent
        }
    }

    /// 최근 검색어 목록. 입력이 비어 있으면 전체(x 삭제 + 헤더·전체삭제),
    /// 입력이 있으면 입력을 포함하는 것만(자동완성, 날짜 표시) 보여준다.
    /// 두 경우 모두 `[RecentSearch]`이고 행을 누르면 검색하는 동작이 같아 목록 하나로 그린다
    private func recentSearchList(_ searches: [RecentSearch], isSuggestion: Bool) -> some View {
        List {
            Section {
                // 대소문자 무시 중복 제거로 keyword가 유일하므로 id로 쓴다
                ForEach(searches, id: \.keyword) { recentSearch in
                    HStack {
                        // 기본 버튼 스타일이라 x 버튼(borderless)을 뺀 행 전체가 이 버튼에 반응한다
                        Button {
                            // 키보드가 남아 있으면 입력 중으로 보여 결과 대신 자동완성이 계속 보이므로 내린다
                            UIApplication.shared.endEditing()
                            viewModel.search(keyword: recentSearch.keyword)
                        } label: {
                            Text(recentSearch.keyword)
                                // 버튼 안에서는 `.primary`가 강조색을 가리키므로 `Color.primary`로 일반 글자색을 지정한다
                                .foregroundStyle(Color.primary)
                        }
                        Spacer()
                        if isSuggestion {
                            Text(recentSearch.searchedAt, formatter: Self.suggestionDateFormatter)
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        } else {
                            Button {
                                viewModel.delete(keyword: recentSearch.keyword)
                            } label: {
                                // 연회색 원 안의 회색 x. 버튼 안에서 `.secondary`는 강조색으로 바뀌므로 `Color`로 직접 지정한다
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.secondary, Color(.systemGray5))
                            }
                            // List 행 안의 버튼은 기본적으로 행 전체 탭에 반응한다.
                            // 행 탭은 #7에서 검색에 쓰므로 버튼 영역만 반응하게 한다
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(recentSearch.keyword) 삭제")
                        }
                    }
                }
            } header: {
                if !isSuggestion {
                    Text("최근 검색")
                }
            } footer: {
                // 최근 검색어가 비면 이 목록 대신 빈 화면을 보여주므로 여기서는 항상 항목이 있다
                if !isSuggestion {
                    HStack {
                        Spacer()
                        Button("전체삭제") {
                            viewModel.deleteAll()
                        }
                        // 지우는 동작이라 강조색 대신 시스템 빨간색으로 구분한다
                        .foregroundStyle(Color(.systemRed))
                    }
                }
            }
        }
    }

    /// 앱 언어 설정과 상관없이 같은 모양으로 보이도록 형식을 고정한다
    private static let suggestionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yy. MM. dd."
        return formatter
    }()

    @ViewBuilder
    private var searchResultContent: some View {
        switch viewModel.state {
        case .idle:
            // idle이면 위 content에서 최근 검색어를 보여주므로 여기에 오지 않는다. switch를 빠짐없이 채우려고 둔다
            Color.clear
        case .loading:
            ProgressView()
        case .loaded(let result) where result.repositories.isEmpty:
            // `ContentUnavailableView.search`는 앱 언어(현재 영어)로 문구가 나와 직접 쓴다
            ContentUnavailableView(
                "검색 결과 없음",
                systemImage: "magnifyingglass",
                description: Text("다른 검색어로 검색해 보세요.")
            )
        case .loaded(let result):
            List {
                Section {
                    ForEach(result.repositories) { repository in
                        NavigationLink(value: repository) {
                            RepositoryRow(repository: repository)
                        }
                        // 끝에 가까운 행이 보이면 다음 페이지를 미리 요청한다 (판단은 ViewModel)
                        .onAppear {
                            viewModel.loadNextPageIfNeeded(currentItem: repository)
                        }
                    }
                    nextPageFooter
                        // List가 이 행을 재사용하면 ProgressView가 두 번째부터 돌지 않아 빈 행으로 보였다.
                        // 받은 개수가 바뀔 때마다 다른 행으로 만들어 매번 새로 그리게 한다
                        .id(result.repositories.count)
                } header: {
                    // API의 total_count를 그대로 쓴다. 실제로 받을 수 있는 개수(최대 1,000)와는 다르다
                    Text("\(result.totalCount.formatted())개 저장소")
                }
            }
        case .failed(let error):
            ContentUnavailableView {
                Label(error.title, systemImage: error.systemImage)
            } description: {
                Text(error.message)
            } actions: {
                Button("다시 시도") {
                    viewModel.retry()
                }
            }
        }
    }
}

private extension SearchView {

    /// 목록 맨 아래: 다음 페이지를 불러오는 중이면 로딩 표시, 실패하면 이미 받은 결과 아래에 안내와 다시 시도 버튼
    @ViewBuilder
    var nextPageFooter: some View {
        switch viewModel.nextPageState {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .failed(let error):
            HStack {
                Text(error.title)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Button("다시 시도") {
                    viewModel.retryNextPage()
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// 검색 결과 한 행: 원형 썸네일 + 저장소 이름 + 소유자
private struct RepositoryRow: View {

    let repository: GitHubRepository

    var body: some View {
        HStack(spacing: 12) {
            // 캐시가 약해 스크롤 시 다시 받을 수 있다. 측정 전까지는 기본 동작을 쓴다
            AsyncImage(url: repository.ownerAvatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .font(.headline)
                Text(repository.ownerLogin)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel(
        repository: DefaultSearchResultRepository(),
        recentSearchUseCase: RecentSearchUseCase(repository: UserDefaultsRecentSearchRepository())
    ))
}
