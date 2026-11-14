//
//  KurlyProjectApp.swift
//  KurlyProject
//
//  Created by 이상봉 on 11/13/26.
//

import SwiftUI

@main
struct KurlyProjectApp: App {
    var body: some Scene {
        WindowGroup {
            SearchView(viewModel: SearchViewModel(
                repository: DefaultSearchResultRepository(),
                recentSearchUseCase: RecentSearchUseCase(repository: UserDefaultsRecentSearchRepository())
            ))
        }
    }
}
